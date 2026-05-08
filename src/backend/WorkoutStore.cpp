#include "backend/WorkoutStore.h"

#include <QDateTime>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QJsonObject>
#include <QLocale>
#include <QSettings>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>

// ─── Constructor ──────────────────────────────────────────────────────────────

WorkoutStore::WorkoutStore(QObject *parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
{
    m_selectedDate = QDate::currentDate();
    m_monthStart   = QDate(m_selectedDate.year(), m_selectedDate.month(), 1);
    m_draftDate    = m_selectedDate;

    // Try to restore a saved session before the event loop starts
    QTimer::singleShot(0, this, [this]() {
        if (tryRestoreSession()) {
            emit loginStateChanged();
            emit loginSucceeded();
            initialLoad();
        }
        // No session → QML will show the AuthScreen automatically
    });
}

// ─── Session persistence ──────────────────────────────────────────────────────

void WorkoutStore::saveSession()
{
    QSettings s;
    s.setValue(QStringLiteral("auth/token"),      m_token);
    s.setValue(QStringLiteral("auth/userName"),   m_currentUserName);
    s.setValue(QStringLiteral("auth/userRole"),   m_currentUserRole);
    s.setValue(QStringLiteral("auth/athleteId"),  m_currentAthleteId);
}

void WorkoutStore::clearSession()
{
    QSettings s;
    s.remove(QStringLiteral("auth/token"));
    s.remove(QStringLiteral("auth/userName"));
    s.remove(QStringLiteral("auth/userRole"));
    s.remove(QStringLiteral("auth/athleteId"));
}

bool WorkoutStore::tryRestoreSession()
{
    QSettings s;
    const QString saved = s.value(QStringLiteral("auth/token")).toString();
    if (saved.isEmpty()) return false;

    // Restore directly from QSettings — no network call needed here.
    // If the JWT is actually expired the first real API call will return 401
    // and handleUnauthorized() will fire, showing the login screen.
    m_token            = saved;
    m_currentUserName  = s.value(QStringLiteral("auth/userName")).toString();
    m_currentUserRole  = s.value(QStringLiteral("auth/userRole")).toString();
    m_currentAthleteId = s.value(QStringLiteral("auth/athleteId")).toString();

    // For athletes their own athleteId IS their "selected athlete"
    if (m_currentUserRole == QStringLiteral("athlete") && !m_currentAthleteId.isEmpty())
        m_selectedAthleteId = m_currentAthleteId;

    return true;
}

// ─── Auth helpers ─────────────────────────────────────────────────────────────

void WorkoutStore::applyAuthResponse(const QJsonObject &obj)
{
    m_token            = obj[QStringLiteral("access_token")].toString();
    m_currentUserName  = obj[QStringLiteral("name")].toString();
    m_currentUserRole  = obj[QStringLiteral("role")].toString();
    m_currentAthleteId = obj[QStringLiteral("athlete_id")].toString();

    // For athletes their athleteId doubles as the selected athlete
    if (m_currentUserRole == QStringLiteral("athlete") && !m_currentAthleteId.isEmpty())
        m_selectedAthleteId = m_currentAthleteId;

    saveSession();
    emit loginStateChanged();
    emit loginSucceeded();
}

void WorkoutStore::handleUnauthorized()
{
    m_token.clear();
    m_currentUserName.clear();
    m_currentUserRole.clear();
    m_currentAthleteId.clear();
    clearSession();
    emit loginStateChanged();
    emit sessionExpired();
}

// ─── Auth invokables ──────────────────────────────────────────────────────────

void WorkoutStore::loginUser(const QString &email, const QString &password)
{
    m_authError.clear();
    emit authErrorChanged();

    QJsonObject body;
    body[QStringLiteral("email")]    = email.trimmed().toLower();
    body[QStringLiteral("password")] = password;

    QNetworkRequest req(QUrl(m_baseUrl + QStringLiteral("/api/auth/login")));
    req.setHeader(QNetworkRequest::ContentTypeHeader, QByteArray("application/json"));
    auto *reply = m_nam->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));

    QEventLoop loop;
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    const int      status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray data = reply->readAll();
    reply->deleteLater();

    if (status == 200) {
        QJsonDocument doc = QJsonDocument::fromJson(data);
        if (doc.isObject()) {
            applyAuthResponse(doc.object());
            initialLoad();
            return;
        }
    }

    // Error path — extract server message
    QString errMsg;
    QJsonDocument errDoc = QJsonDocument::fromJson(data);
    if (errDoc.isObject()) {
        const auto detail = errDoc.object()[QStringLiteral("detail")];
        if (detail.isString()) errMsg = detail.toString();
    }
    if (errMsg.isEmpty()) errMsg = QStringLiteral("Неверный email или пароль");
    setAuthError(errMsg);
    emit loginFailed(errMsg);
}

void WorkoutStore::registerUser(const QString &email, const QString &name,
                                const QString &password, const QString &role)
{
    m_authError.clear();
    emit authErrorChanged();

    QJsonObject body;
    body[QStringLiteral("email")]    = email.trimmed().toLower();
    body[QStringLiteral("name")]     = name.trimmed();
    body[QStringLiteral("password")] = password;
    body[QStringLiteral("role")]     = role;

    QNetworkRequest req(QUrl(m_baseUrl + QStringLiteral("/api/auth/register")));
    req.setHeader(QNetworkRequest::ContentTypeHeader, QByteArray("application/json"));
    auto *reply = m_nam->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));

    QEventLoop loop;
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    const int      status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray data = reply->readAll();
    reply->deleteLater();

    if (status == 201) {
        QJsonDocument doc = QJsonDocument::fromJson(data);
        if (doc.isObject()) {
            applyAuthResponse(doc.object());
            initialLoad();
            return;
        }
    }

    // Error — handle Pydantic validation array or plain string
    QString errMsg;
    QJsonDocument errDoc = QJsonDocument::fromJson(data);
    if (errDoc.isObject()) {
        const auto detail = errDoc.object()[QStringLiteral("detail")];
        if (detail.isString()) {
            errMsg = detail.toString();
        } else if (detail.isArray()) {
            QStringList msgs;
            for (const auto &v : detail.toArray())
                msgs << v.toObject()[QStringLiteral("msg")].toString();
            errMsg = msgs.join(QStringLiteral("; "));
        }
    }
    if (errMsg.isEmpty()) errMsg = QStringLiteral("Ошибка регистрации");
    setAuthError(errMsg);
    emit loginFailed(errMsg);
}

void WorkoutStore::logout()
{
    m_token.clear();
    m_currentUserName.clear();
    m_currentUserRole.clear();
    m_currentAthleteId.clear();
    clearSession();

    m_athletes.clear();
    m_dayCells.clear();
    m_selectedDayWorkouts.clear();
    m_selectedWorkout.clear();
    m_selectedWorkoutComments.clear();
    m_analyticsSummary.clear();
    m_templateLibrary.clear();
    m_selectedWorkoutId.clear();
    m_selectedAthleteId.clear();

    emit loginStateChanged();
    emit athletesChanged();
    emit calendarChanged();
    emit selectedWorkoutChanged();
    emit loggedOut();
}

void WorkoutStore::clearAuthError()
{
    if (m_authError.isEmpty()) return;
    m_authError.clear();
    emit authErrorChanged();
}

// ─── Athlete management ───────────────────────────────────────────────────────

void WorkoutStore::linkAthlete(const QString &athleteEmail)
{
    QJsonObject body;
    body[QStringLiteral("athlete_email")] = athleteEmail.trimmed().toLower();

    const auto doc = httpSync(QStringLiteral("POST"),
                              QStringLiteral("/api/athletes/link"), body);
    if (doc.isObject() && doc.object().contains(QStringLiteral("athleteId"))) {
        const QString name = doc.object()[QStringLiteral("name")].toString();
        fetchAthletes();
        emit athleteLinked(name);
    } else if (!m_errorMessage.isEmpty()) {
        emit athleteLinkFailed(m_errorMessage);
    }
}

// ─── Initial load (called after successful login) ─────────────────────────────

void WorkoutStore::initialLoad()
{
    fetchAthletes();    // also calls fetchDayWorkouts + fetchAnalytics internally
    fetchCalendar();
    fetchTemplates();
    fetchRoutes();
    fetchOpenAiKeyStatus();
}

// ─── HTTP layer ───────────────────────────────────────────────────────────────

QNetworkRequest WorkoutStore::makeRequest(const QString &path) const
{
    QNetworkRequest req(QUrl(m_baseUrl + path));
    req.setHeader(QNetworkRequest::ContentTypeHeader, QByteArray("application/json"));
    if (!m_token.isEmpty())
        req.setRawHeader(QByteArray("Authorization"),
                         QByteArray("Bearer ") + m_token.toUtf8());
    return req;
}

QJsonDocument WorkoutStore::httpSync(const QString &method, const QString &path,
                                     const QJsonObject &body)
{
    const QByteArray bodyBytes =
        body.isEmpty() ? QByteArray()
                       : QJsonDocument(body).toJson(QJsonDocument::Compact);

    const auto req = makeRequest(path);
    QNetworkReply *reply = nullptr;

    if      (method == QStringLiteral("GET"))    reply = m_nam->get(req);
    else if (method == QStringLiteral("POST"))   reply = m_nam->post(req, bodyBytes);
    else if (method == QStringLiteral("PUT"))    reply = m_nam->put(req, bodyBytes);
    else if (method == QStringLiteral("DELETE")) reply = m_nam->deleteResource(req);
    else reply = m_nam->sendCustomRequest(req, method.toUtf8(), bodyBytes);

    if (!reply) {
        setError(QStringLiteral("Не удалось выполнить HTTP-запрос."));
        return {};
    }

    QEventLoop loop;
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    const int        status     = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray data       = reply->readAll();
    reply->deleteLater();

    // Pure network failure (server not running)
    if (status == 0) {
        setError(QStringLiteral("Нет связи с сервером. "
                                "Убедитесь, что API-сервер запущен:\n"
                                "  uvicorn api.main:app --reload --port 8000"));
        return {};
    }

    if (status == 401) {
        handleUnauthorized();
        return {};
    }

    if (status >= 400) {
        QString errMsg;
        QJsonDocument errDoc = QJsonDocument::fromJson(data);
        if (errDoc.isObject()) {
            const auto detail = errDoc.object()[QStringLiteral("detail")];
            if (detail.isString())
                errMsg = detail.toString();
            else if (detail.isArray()) {
                QStringList msgs;
                for (const auto &v : detail.toArray())
                    msgs << v.toObject()[QStringLiteral("msg")].toString();
                errMsg = msgs.join(QStringLiteral("; "));
            }
        }
        if (errMsg.isEmpty())
            errMsg = QStringLiteral("HTTP ошибка %1").arg(status);
        setError(errMsg);
        return {};
    }

    if (data.isEmpty()) return {};

    QJsonParseError err;
    const auto doc = QJsonDocument::fromJson(data, &err);
    if (err.error != QJsonParseError::NoError)
        setError(QStringLiteral("Ошибка разбора ответа: ") + err.errorString());
    return doc;
}

void WorkoutStore::httpAsync(const QString &path,
                             std::function<void(const QJsonDocument &)> callback)
{
    auto *reply = m_nam->get(makeRequest(path));

    connect(reply, &QNetworkReply::finished, this,
            [this, reply, cb = std::move(callback)]() {

        const int status = reply->attribute(
            QNetworkRequest::HttpStatusCodeAttribute).toInt();

        if (status == 401) {
            handleUnauthorized();
            reply->deleteLater();
            return;
        }

        if (reply->error() == QNetworkReply::NoError) {
            QJsonParseError err;
            const auto doc = QJsonDocument::fromJson(reply->readAll(), &err);
            if (err.error == QJsonParseError::NoError)
                cb(doc);
        } else if (status == 0) {
            setError(QStringLiteral("Нет связи с сервером."));
        } else {
            setError(QStringLiteral("Ошибка сети: ") + reply->errorString());
        }
        reply->deleteLater();
    });
}

// ─── Async fetchers ───────────────────────────────────────────────────────────

// Build the 42-cell grid from local date math — no network needed.
// Workouts are populated separately when an athlete is selected.
void WorkoutStore::buildLocalCalendar()
{
    m_dayCells.clear();
    const QDate today   = QDate::currentDate();
    const QString selIso = m_selectedDate.toString(Qt::ISODate);
    const QString todIso = today.toString(Qt::ISODate);

    // Monday-anchored grid start
    int dow = m_monthStart.dayOfWeek(); // 1=Mon … 7=Sun
    QDate gridStart = m_monthStart.addDays(-(dow - 1));

    for (int i = 0; i < 42; ++i) {
        QDate d = gridStart.addDays(i);
        QString dIso = d.toString(Qt::ISODate);
        QVariantMap cell;
        cell[QStringLiteral("dateIso")]        = dIso;
        cell[QStringLiteral("dayNumber")]      = QString::number(d.day());
        cell[QStringLiteral("inCurrentMonth")] = (d.month() == m_monthStart.month());
        cell[QStringLiteral("isToday")]        = (dIso == todIso);
        cell[QStringLiteral("isSelected")]     = (dIso == selIso);
        cell[QStringLiteral("workouts")]       = QVariantList{};
        m_dayCells.append(cell);
    }
    emit calendarChanged();
}

void WorkoutStore::fetchCalendar()
{
    // Always render the grid first so the calendar is never blank
    buildLocalCalendar();

    // No athlete selected → nothing more to fetch
    if (m_selectedAthleteId.isEmpty()) return;

    const QString path = QStringLiteral("/api/calendar/%1/%2?athlete_id=%3")
        .arg(m_monthStart.year())
        .arg(m_monthStart.month())
        .arg(m_selectedAthleteId);

    httpAsync(path, [this](const QJsonDocument &doc) {
        if (!doc.isArray()) return;
        m_dayCells.clear();
        const QString selIso = m_selectedDate.toString(Qt::ISODate);
        for (const auto &v : doc.array()) {
            QVariantMap cell = v.toObject().toVariantMap();
            cell[QStringLiteral("isSelected")] =
                (cell[QStringLiteral("dateIso")].toString() == selIso);
            m_dayCells.append(cell);
        }
        emit calendarChanged();
    });
}

void WorkoutStore::fetchDayWorkouts()
{
    if (m_selectedAthleteId.isEmpty()) return;

    const QString path =
        QStringLiteral("/api/workouts?athlete_id=%1&date=%2")
            .arg(m_selectedAthleteId,
                 m_selectedDate.toString(Qt::ISODate));

    httpAsync(path, [this](const QJsonDocument &doc) {
        if (!doc.isArray()) return;
        m_selectedDayWorkouts.clear();
        for (const auto &v : doc.array())
            m_selectedDayWorkouts.append(v.toObject().toVariantMap());
        emit selectedDayChanged();
    });
}

void WorkoutStore::fetchSelectedWorkout()
{
    if (m_selectedWorkoutId.isEmpty()) {
        m_selectedWorkout.clear();
        emit selectedWorkoutChanged();
        return;
    }
    httpAsync(QStringLiteral("/api/workouts/") + m_selectedWorkoutId,
              [this](const QJsonDocument &doc) {
        if (!doc.isObject()) return;
        m_selectedWorkout = doc.object().toVariantMap();
        emit selectedWorkoutChanged();
    });
}

void WorkoutStore::fetchComments()
{
    if (m_selectedWorkoutId.isEmpty()) {
        m_selectedWorkoutComments.clear();
        emit selectedWorkoutCommentsChanged();
        return;
    }
    httpAsync(QStringLiteral("/api/workouts/") + m_selectedWorkoutId + QStringLiteral("/comments"),
              [this](const QJsonDocument &doc) {
        if (!doc.isArray()) return;
        m_selectedWorkoutComments.clear();
        for (const auto &v : doc.array())
            m_selectedWorkoutComments.append(v.toObject().toVariantMap());
        emit selectedWorkoutCommentsChanged();
    });
}

void WorkoutStore::fetchTemplates()
{
    httpAsync(QStringLiteral("/api/templates"), [this](const QJsonDocument &doc) {
        if (!doc.isArray()) return;
        m_templateLibrary.clear();
        for (const auto &v : doc.array())
            m_templateLibrary.append(v.toObject().toVariantMap());
        emit templatesChanged();
    });
}

void WorkoutStore::fetchAnalytics()
{
    if (m_selectedAthleteId.isEmpty()) return;
    const QString path = QStringLiteral("/api/analytics?athlete_id=%1&period=%2")
        .arg(m_selectedAthleteId, m_analyticsPeriod);
    httpAsync(path, [this](const QJsonDocument &doc) {
        if (!doc.isObject()) return;
        m_analyticsSummary = doc.object().toVariantMap();
        emit analyticsChanged();
    });
}

void WorkoutStore::fetchGoals()
{
    if (m_selectedAthleteId.isEmpty()) {
        m_goals.clear();
        emit goalsChanged();
        return;
    }
    httpAsync(QStringLiteral("/api/goals?athlete_id=") + m_selectedAthleteId,
              [this](const QJsonDocument &doc) {
        if (!doc.isArray()) return;
        m_goals.clear();
        for (const auto &v : doc.array())
            m_goals.append(v.toObject().toVariantMap());
        emit goalsChanged();
    });
}

void WorkoutStore::fetchAthletes()
{
    const auto doc = httpSync(QStringLiteral("GET"), QStringLiteral("/api/athletes"));
    if (doc.isArray()) {
        m_athletes.clear();
        for (const auto &v : doc.array())
            m_athletes.append(v.toObject().toVariantMap());

        if (!m_athletes.isEmpty() && m_selectedAthleteId.isEmpty())
            m_selectedAthleteId =
                m_athletes.first().toMap().value(QStringLiteral("id")).toString();
    }
    emit athletesChanged();
    emit selectedAthleteChanged();
    fetchDayWorkouts();
    fetchAnalytics();
    fetchGoals();
}

// ─── Properties ───────────────────────────────────────────────────────────────

QString WorkoutStore::monthLabel() const
{
    return QLocale(QLocale::Russian)
        .toString(m_monthStart, QStringLiteral("MMMM yyyy 'года'"));
}

QString WorkoutStore::selectedAthleteName() const
{
    for (const auto &v : m_athletes) {
        const auto m = v.toMap();
        if (m.value(QStringLiteral("id")).toString() == m_selectedAthleteId)
            return m.value(QStringLiteral("name")).toString();
    }
    return {};
}

QString WorkoutStore::selectedDayLabel() const
{
    return QLocale(QLocale::Russian)
        .toString(m_selectedDate, QStringLiteral("d MMMM yyyy"));
}

// ─── Setters ──────────────────────────────────────────────────────────────────

void WorkoutStore::setSelectedAthleteId(const QString &id)
{
    if (id == m_selectedAthleteId) return;
    m_selectedAthleteId = id;
    m_selectedWorkoutId.clear();
    emit selectedAthleteChanged();
    fetchCalendar();
    fetchDayWorkouts();
    fetchAnalytics();
    fetchGoals();
}

void WorkoutStore::setCreateDialogOpen(bool open)
{
    if (open == m_createDialogOpen) return;
    m_createDialogOpen = open;
    emit createDialogOpenChanged();
}

void WorkoutStore::setViewMode(const QString &mode)
{
    if (mode == m_viewMode) return;
    m_viewMode = mode;
    emit viewModeChanged();
}

// ─── Calendar navigation ──────────────────────────────────────────────────────

void WorkoutStore::goToToday()
{
    m_selectedDate = QDate::currentDate();
    m_monthStart   = QDate(m_selectedDate.year(), m_selectedDate.month(), 1);
    emit selectedDateChanged();
    fetchCalendar();
    fetchDayWorkouts();
}

void WorkoutStore::prevMonth()
{
    m_monthStart = m_monthStart.addMonths(-1);
    fetchCalendar();
    emit calendarChanged();
}

void WorkoutStore::nextMonth()
{
    m_monthStart = m_monthStart.addMonths(1);
    fetchCalendar();
    emit calendarChanged();
}

void WorkoutStore::selectDate(const QString &dateIso)
{
    m_selectedDate = QDate::fromString(dateIso, Qt::ISODate);
    m_draftDate    = m_selectedDate;

    for (auto &v : m_dayCells) {
        auto m = v.toMap();
        m[QStringLiteral("isSelected")] =
            (m[QStringLiteral("dateIso")].toString() == dateIso);
        v = m;
    }
    emit selectedDateChanged();
    emit calendarChanged();
    fetchDayWorkouts();
}

void WorkoutStore::openCreateDialogForDate(const QString &dateIso)
{
    m_draftDate        = QDate::fromString(dateIso, Qt::ISODate);
    m_createDialogOpen = true;
    emit draftChanged();
    emit createDialogOpenChanged();
}

void WorkoutStore::cancelCreateDialog()
{
    m_createDialogOpen = false;
    emit createDialogOpenChanged();
}

// ─── Workout CRUD ─────────────────────────────────────────────────────────────

bool WorkoutStore::createWorkout(
    const QString &title, const QString &category,
    double distanceKm, int durationMin,
    const QString &intensity, const QString &notes,
    bool hiddenFromAthlete, const QString &intervalsJson)
{
    if (m_selectedAthleteId.isEmpty()) {
        setError(QStringLiteral("Не выбран атлет."));
        return false;
    }

    QJsonObject body;
    body[QStringLiteral("athlete_id")]     = m_selectedAthleteId;
    body[QStringLiteral("date")]           = m_draftDate.toString(Qt::ISODate);
    body[QStringLiteral("title")]          = title;
    body[QStringLiteral("category")]       = category;
    body[QStringLiteral("distance_km")]    = distanceKm;
    body[QStringLiteral("duration_min")]   = durationMin;
    body[QStringLiteral("intensity")]      = intensity;
    body[QStringLiteral("notes")]          = notes;
    body[QStringLiteral("hidden")]         = hiddenFromAthlete;
    body[QStringLiteral("intervals_json")] = intervalsJson.isEmpty()
                                               ? QStringLiteral("[]") : intervalsJson;

    auto *reply = m_nam->post(makeRequest(QStringLiteral("/api/workouts")),
                              QJsonDocument(body).toJson(QJsonDocument::Compact));
    QEventLoop loop;
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    const int  status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    reply->deleteLater();

    if (status == 401) { handleUnauthorized(); return false; }

    const bool ok = (status == 201);
    if (!ok) setError(QStringLiteral("Не удалось создать тренировку."));
    if (ok) {
        m_createDialogOpen = false;
        emit createDialogOpenChanged();
        emit workoutCreated();
        fetchCalendar();
        fetchDayWorkouts();
    }
    return ok;
}

bool WorkoutStore::updateWorkout(
    const QString &id, const QString &title, const QString &category,
    double distanceKm, int durationMin,
    const QString &intensity, const QString &notes,
    bool hiddenFromAthlete, const QString &intervalsJson)
{
    QJsonObject body;
    body[QStringLiteral("title")]          = title;
    body[QStringLiteral("category")]       = category;
    body[QStringLiteral("distance_km")]    = distanceKm;
    body[QStringLiteral("duration_min")]   = durationMin;
    body[QStringLiteral("intensity")]      = intensity;
    body[QStringLiteral("notes")]          = notes;
    body[QStringLiteral("hidden")]         = hiddenFromAthlete;
    body[QStringLiteral("intervals_json")] = intervalsJson.isEmpty()
                                               ? QStringLiteral("[]") : intervalsJson;

    const auto doc = httpSync(QStringLiteral("PUT"),
                              QStringLiteral("/api/workouts/") + id, body);
    const bool ok = doc.isObject() && !doc.object().isEmpty();
    if (ok) { fetchCalendar(); fetchDayWorkouts(); fetchSelectedWorkout(); }
    return ok;
}

bool WorkoutStore::deleteWorkout(const QString &id)
{
    auto *reply = m_nam->deleteResource(
        makeRequest(QStringLiteral("/api/workouts/") + id));

    QEventLoop loop;
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    const int  status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    reply->deleteLater();

    if (status == 401) { handleUnauthorized(); return false; }

    const bool ok = (status == 204 || status == 200);
    if (!ok) setError(QStringLiteral("Не удалось удалить тренировку."));
    if (ok) {
        if (m_selectedWorkoutId == id) {
            m_selectedWorkoutId.clear();
            m_selectedWorkout.clear();
            emit selectedWorkoutChanged();
        }
        fetchCalendar();
        fetchDayWorkouts();
    }
    return ok;
}

void WorkoutStore::selectWorkout(const QString &id)
{
    m_selectedWorkoutId = id;
    fetchSelectedWorkout();
    fetchComments();
}

bool WorkoutStore::markWorkoutStatus(const QString &workoutId,
                                     const QString &status,
                                     const QString &feedback)
{
    return markWorkoutStatusDetailed(workoutId, status, feedback, {}, 0);
}

bool WorkoutStore::markWorkoutStatusDetailed(
    const QString &workoutId, const QString &status, const QString &feedback,
    const QString &mood, int perceivedExertion)
{
    QJsonObject body;
    body[QStringLiteral("status")]             = status;
    body[QStringLiteral("athlete_feedback")]   = feedback;
    body[QStringLiteral("athlete_mood")]       = mood;
    body[QStringLiteral("perceived_exertion")] = perceivedExertion;

    const auto doc = httpSync(QStringLiteral("PUT"),
                              QStringLiteral("/api/workouts/") + workoutId
                              + QStringLiteral("/status"), body);
    const bool ok = doc.isObject();
    if (ok) { fetchCalendar(); fetchDayWorkouts(); fetchSelectedWorkout(); }
    return ok;
}

// ─── Comments ─────────────────────────────────────────────────────────────────

bool WorkoutStore::addComment(const QString &text)
{
    if (m_selectedWorkoutId.isEmpty()) return false;

    QJsonObject body;
    body[QStringLiteral("text")] = text;   // author derived from JWT on server

    auto *reply = m_nam->post(
        makeRequest(QStringLiteral("/api/workouts/") + m_selectedWorkoutId
                    + QStringLiteral("/comments")),
        QJsonDocument(body).toJson(QJsonDocument::Compact));

    QEventLoop loop;
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    const int  status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    reply->deleteLater();

    if (status == 401) { handleUnauthorized(); return false; }

    const bool ok = (status == 201);
    if (ok) fetchComments();
    return ok;
}

// ─── Templates ────────────────────────────────────────────────────────────────

bool WorkoutStore::saveTemplate(
    const QString &title, const QString &category,
    double distanceKm, int durationMin,
    const QString &intensity, const QString &intervals,
    const QString &notes, const QString &tags)
{
    QJsonObject body;
    body[QStringLiteral("title")]          = title;
    body[QStringLiteral("category")]       = category;
    body[QStringLiteral("distance_km")]    = distanceKm;
    body[QStringLiteral("duration_min")]   = durationMin;
    body[QStringLiteral("intensity")]      = intensity;
    body[QStringLiteral("intervals_json")] = intervals.isEmpty()
                                               ? QStringLiteral("[]") : intervals;
    body[QStringLiteral("notes")]          = notes;
    body[QStringLiteral("tags")]           = tags;

    auto *reply = m_nam->post(makeRequest(QStringLiteral("/api/templates")),
                              QJsonDocument(body).toJson(QJsonDocument::Compact));
    QEventLoop loop;
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    const int  status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    reply->deleteLater();

    if (status == 401) { handleUnauthorized(); return false; }

    const bool ok = (status == 201);
    if (!ok) setError(QStringLiteral("Не удалось сохранить шаблон."));
    if (ok) fetchTemplates();
    return ok;
}

bool WorkoutStore::updateTemplate(
    const QString &id, const QString &title, const QString &category,
    double distanceKm, int durationMin,
    const QString &intensity, const QString &intervals,
    const QString &notes, const QString &tags)
{
    QJsonObject body;
    body[QStringLiteral("title")]          = title;
    body[QStringLiteral("category")]       = category;
    body[QStringLiteral("distance_km")]    = distanceKm;
    body[QStringLiteral("duration_min")]   = durationMin;
    body[QStringLiteral("intensity")]      = intensity;
    body[QStringLiteral("intervals_json")] = intervals.isEmpty()
                                               ? QStringLiteral("[]") : intervals;
    body[QStringLiteral("notes")]          = notes;
    body[QStringLiteral("tags")]           = tags;

    const auto doc = httpSync(QStringLiteral("PUT"),
                              QStringLiteral("/api/templates/") + id, body);
    const bool ok = doc.isObject();
    if (ok) fetchTemplates();
    return ok;
}

bool WorkoutStore::deleteTemplate(const QString &id)
{
    auto *reply = m_nam->deleteResource(
        makeRequest(QStringLiteral("/api/templates/") + id));

    QEventLoop loop;
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    const int  status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    reply->deleteLater();

    if (status == 401) { handleUnauthorized(); return false; }

    const bool ok = (status == 204 || status == 200);
    if (ok) fetchTemplates();
    return ok;
}

bool WorkoutStore::planFromTemplate(const QString &templateId, const QString &dateIso)
{
    QJsonObject body;
    body[QStringLiteral("athlete_id")] = m_selectedAthleteId;
    body[QStringLiteral("date")]       = dateIso;

    auto *reply = m_nam->post(
        makeRequest(QStringLiteral("/api/templates/") + templateId
                    + QStringLiteral("/plan")),
        QJsonDocument(body).toJson(QJsonDocument::Compact));

    QEventLoop loop;
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    const int  status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    reply->deleteLater();

    if (status == 401) { handleUnauthorized(); return false; }

    const bool ok = (status == 201);
    if (!ok) setError(QStringLiteral("Не удалось добавить тренировку из шаблона."));
    if (ok) { fetchCalendar(); fetchDayWorkouts(); }
    return ok;
}

// ─── Misc ─────────────────────────────────────────────────────────────────────

bool WorkoutStore::canCurrentUserEditAthlete(const QString &) const
{
    return canEditWorkouts();
}

void WorkoutStore::clearError()
{
    if (m_errorMessage.isEmpty()) return;
    m_errorMessage.clear();
    emit errorChanged({});
}

void WorkoutStore::refresh()
{
    fetchCalendar();
    fetchDayWorkouts();
    fetchSelectedWorkout();
    fetchComments();
    fetchTemplates();
    fetchAnalytics();
    fetchGoals();
}

void WorkoutStore::setAnalyticsPeriod(const QString &p)
{
    if (p == m_analyticsPeriod) return;
    m_analyticsPeriod = p;
    emit analyticsPeriodChanged();
    fetchAnalytics();
}

// ─── Goals ────────────────────────────────────────────────────────────────────

bool WorkoutStore::createGoal(const QString &title,
                              const QString &targetDate,
                              const QString &type,
                              double targetValue,
                              const QString &targetUnit)
{
    if (m_selectedAthleteId.isEmpty()) {
        setError(QStringLiteral("Не выбран атлет"));
        return false;
    }

    QJsonObject body{
        {QStringLiteral("athlete_id"),  m_selectedAthleteId},
        {QStringLiteral("title"),       title},
        {QStringLiteral("target_date"), targetDate},
        {QStringLiteral("type"),        type},
    };
    if (targetValue > 0)
        body.insert(QStringLiteral("target_value"), targetValue);
    if (!targetUnit.isEmpty())
        body.insert(QStringLiteral("target_unit"), targetUnit);

    const auto doc = httpSync(QStringLiteral("POST"), QStringLiteral("/api/goals"), body);
    if (!doc.isObject() || !doc.object().contains(QStringLiteral("id")))
        return false;
    fetchGoals();
    fetchAnalytics();
    return true;
}

bool WorkoutStore::deleteGoal(const QString &id)
{
    const auto doc = httpSync(QStringLiteral("DELETE"),
                              QStringLiteral("/api/goals/") + id);
    Q_UNUSED(doc);
    fetchGoals();
    fetchAnalytics();
    return true;
}

// ─── Watch import ────────────────────────────────────────────────────────────

bool WorkoutStore::importWatchFile(const QString &workoutId, const QString &localPath)
{
    QString cleaned = localPath;
    if (cleaned.startsWith(QStringLiteral("file://")))
        cleaned = QUrl(cleaned).toLocalFile();

    QFile f(cleaned);
    if (!f.open(QIODevice::ReadOnly)) {
        setError(QStringLiteral("Не удалось открыть файл: ") + cleaned);
        return false;
    }
    const QByteArray fileBytes = f.readAll();
    f.close();

    const QString fileName = QFileInfo(cleaned).fileName();
    const QString boundary = QStringLiteral("----SportCalBoundary%1")
                                .arg(QDateTime::currentMSecsSinceEpoch());

    QByteArray body;
    body.append("--" + boundary.toUtf8() + "\r\n");
    body.append("Content-Disposition: form-data; name=\"file\"; filename=\""
                + fileName.toUtf8() + "\"\r\n");
    body.append("Content-Type: application/octet-stream\r\n\r\n");
    body.append(fileBytes);
    body.append("\r\n--" + boundary.toUtf8() + "--\r\n");

    QNetworkRequest req(QUrl(m_baseUrl + QStringLiteral("/api/workouts/") + workoutId
                              + QStringLiteral("/import")));
    req.setHeader(QNetworkRequest::ContentTypeHeader,
                  QByteArray("multipart/form-data; boundary=") + boundary.toUtf8());
    if (!m_token.isEmpty())
        req.setRawHeader(QByteArray("Authorization"),
                         QByteArray("Bearer ") + m_token.toUtf8());

    setBusy(true);
    QEventLoop loop;
    auto *reply = m_nam->post(req, body);
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray respBody = reply->readAll();
    reply->deleteLater();
    setBusy(false);

    if (status == 401) { handleUnauthorized(); return false; }
    if (status >= 400) {
        QJsonParseError err;
        const auto doc = QJsonDocument::fromJson(respBody, &err);
        QString msg = QStringLiteral("Ошибка импорта (HTTP %1)").arg(status);
        if (doc.isObject() && doc.object().contains(QStringLiteral("detail")))
            msg = doc.object().value(QStringLiteral("detail")).toString();
        setError(msg);
        return false;
    }

    fetchSelectedWorkout();
    fetchDayWorkouts();
    fetchCalendar();
    fetchAnalytics();
    return true;
}

// ─── Routes ──────────────────────────────────────────────────────────────────

void WorkoutStore::fetchRoutes()
{
    httpAsync(QStringLiteral("/api/routes"), [this](const QJsonDocument &doc) {
        if (!doc.isArray()) return;
        const QJsonArray arr = doc.array();
        QVariantList list;
        for (const auto &v : arr) list.append(v.toObject().toVariantMap());
        m_routes = list;
        emit routesChanged();
    });
}

void WorkoutStore::fetchOpenAiKeyStatus()
{
    httpAsync(QStringLiteral("/api/auth/openai-key"), [this](const QJsonDocument &doc) {
        if (!doc.isObject()) return;
        bool hasKey = doc.object().value(QStringLiteral("hasKey")).toBool(false);
        if (hasKey != m_hasOpenAiKey) {
            m_hasOpenAiKey = hasKey;
            emit openAiKeyChanged();
        }
    });
}

void WorkoutStore::setOpenAiKey(const QString &key)
{
    QJsonObject body;
    body[QStringLiteral("key")] = key;
    const auto doc = httpSync(QStringLiteral("PUT"), QStringLiteral("/api/auth/openai-key"), body);
    Q_UNUSED(doc);
    m_hasOpenAiKey = !key.trimmed().isEmpty();
    emit openAiKeyChanged();
}

void WorkoutStore::setServerUrl(const QString &url)
{
    QString trimmed = url.trimmed();
    if (trimmed.isEmpty() || trimmed == m_baseUrl) return;
    // Remove trailing slash for uniformity
    while (trimmed.endsWith(QLatin1Char('/')))
        trimmed.chop(1);
    m_baseUrl = trimmed;
    emit serverUrlChanged();
}

void WorkoutStore::generateRoute(double lat, double lon,
                                  double distanceKm, const QString &preferences)
{
    QJsonObject body;
    body[QStringLiteral("start_lat")]    = lat;
    body[QStringLiteral("start_lon")]    = lon;
    body[QStringLiteral("distance_km")]  = distanceKm;
    body[QStringLiteral("preferences")]  = preferences;

    setBusy(true);
    QTimer::singleShot(0, this, [this, body]() {
        const auto doc = httpSync(QStringLiteral("POST"), QStringLiteral("/api/routes/generate"), body);
        setBusy(false);
        if (doc.isNull()) return;  // error already set
        fetchRoutes();
    });
}

void WorkoutStore::deleteRoute(const QString &routeId)
{
    const auto doc = httpSync(QStringLiteral("DELETE"),
                              QStringLiteral("/api/routes/") + routeId);
    Q_UNUSED(doc);
    fetchRoutes();
}

void WorkoutStore::setError(const QString &message)
{
    m_errorMessage = message;
    emit errorChanged(message);
}

void WorkoutStore::setAuthError(const QString &message)
{
    m_authError = message;
    emit authErrorChanged();
}

void WorkoutStore::setBusy(bool value)
{
    if (value == m_busy) return;
    m_busy = value;
    emit busyChanged();
}

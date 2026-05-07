#pragma once

#include <QObject>
#include <QDate>
#include <QVariantList>
#include <QVariantMap>
#include <QStringList>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

class WorkoutStore : public QObject
{
    Q_OBJECT

    // ── Auth ──────────────────────────────────────────────────────────────────
    Q_PROPERTY(bool    isLoggedIn       READ isLoggedIn       NOTIFY loginStateChanged)
    Q_PROPERTY(QString currentUserName  READ currentUserName  NOTIFY loginStateChanged)
    Q_PROPERTY(QString currentUserRole  READ currentUserRole  NOTIFY loginStateChanged)
    Q_PROPERTY(bool    canEditWorkouts  READ canEditWorkouts  NOTIFY loginStateChanged)
    Q_PROPERTY(QString authError        READ authError        NOTIFY authErrorChanged)

    // ── Calendar / data ───────────────────────────────────────────────────────
    Q_PROPERTY(QString      monthLabel             READ monthLabel             NOTIFY calendarChanged)
    Q_PROPERTY(QVariantList athletes               READ athletes               NOTIFY athletesChanged)
    Q_PROPERTY(QString      selectedAthleteId      READ selectedAthleteId
               WRITE setSelectedAthleteId          NOTIFY selectedAthleteChanged)
    Q_PROPERTY(QString      selectedAthleteName    READ selectedAthleteName    NOTIFY selectedAthleteChanged)
    Q_PROPERTY(QString      selectedDateIso        READ selectedDateIso        NOTIFY selectedDateChanged)
    Q_PROPERTY(QString      selectedDayLabel       READ selectedDayLabel       NOTIFY selectedDateChanged)
    Q_PROPERTY(QVariantList dayCells               READ dayCells               NOTIFY calendarChanged)
    Q_PROPERTY(QVariantList selectedDayWorkouts    READ selectedDayWorkouts    NOTIFY selectedDayChanged)
    Q_PROPERTY(QVariantMap  selectedWorkout        READ selectedWorkout        NOTIFY selectedWorkoutChanged)
    Q_PROPERTY(QVariantList selectedWorkoutComments READ selectedWorkoutComments NOTIFY selectedWorkoutCommentsChanged)
    Q_PROPERTY(QVariantMap  analyticsSummary       READ analyticsSummary       NOTIFY analyticsChanged)
    Q_PROPERTY(QString      analyticsPeriod        READ analyticsPeriod
               WRITE setAnalyticsPeriod            NOTIFY analyticsPeriodChanged)
    Q_PROPERTY(QVariantList goals                  READ goals                  NOTIFY goalsChanged)
    Q_PROPERTY(QVariantList routes                 READ routes                 NOTIFY routesChanged)
    Q_PROPERTY(bool         hasOpenAiKey           READ hasOpenAiKey           NOTIFY openAiKeyChanged)
    Q_PROPERTY(QVariantList templateLibrary        READ templateLibrary        NOTIFY templatesChanged)
    Q_PROPERTY(bool         createDialogOpen       READ createDialogOpen
               WRITE setCreateDialogOpen           NOTIFY createDialogOpenChanged)
    Q_PROPERTY(QString      draftDateIso           READ draftDateIso           NOTIFY draftChanged)
    Q_PROPERTY(QString      viewMode               READ viewMode
               WRITE setViewMode                   NOTIFY viewModeChanged)
    Q_PROPERTY(QStringList  categories             READ categories             CONSTANT)
    Q_PROPERTY(QStringList  intensities            READ intensities            CONSTANT)
    Q_PROPERTY(QString      errorMessage           READ errorMessage           NOTIFY errorChanged)
    Q_PROPERTY(bool         busy                   READ busy                   NOTIFY busyChanged)

public:
    explicit WorkoutStore(QObject *parent = nullptr);

    // ── Auth getters ──────────────────────────────────────────────────────────
    bool    isLoggedIn()      const { return !m_token.isEmpty(); }
    QString currentUserName() const { return m_currentUserName; }
    QString currentUserRole() const { return m_currentUserRole; }
    bool    canEditWorkouts() const { return m_currentUserRole == QStringLiteral("coach"); }
    QString authError()       const { return m_authError; }

    // ── Data getters ──────────────────────────────────────────────────────────
    QString      monthLabel()          const;
    QVariantList athletes()            const { return m_athletes; }
    QString      selectedAthleteId()   const { return m_selectedAthleteId; }
    void         setSelectedAthleteId(const QString &id);
    QString      selectedAthleteName() const;
    QString      selectedDateIso()     const { return m_selectedDate.toString(Qt::ISODate); }
    QString      selectedDayLabel()    const;
    QVariantList dayCells()            const { return m_dayCells; }
    QVariantList selectedDayWorkouts() const { return m_selectedDayWorkouts; }
    QVariantMap  selectedWorkout()     const { return m_selectedWorkout; }
    QVariantList selectedWorkoutComments() const { return m_selectedWorkoutComments; }
    QVariantMap  analyticsSummary()    const { return m_analyticsSummary; }
    QString      analyticsPeriod()     const { return m_analyticsPeriod; }
    void         setAnalyticsPeriod(const QString &p);
    QVariantList goals()               const { return m_goals; }
    QVariantList routes()              const { return m_routes; }
    bool         hasOpenAiKey()        const { return m_hasOpenAiKey; }
    QVariantList templateLibrary()     const { return m_templateLibrary; }
    bool         createDialogOpen()    const { return m_createDialogOpen; }
    void         setCreateDialogOpen(bool open);
    QString      draftDateIso()        const { return m_draftDate.toString(Qt::ISODate); }
    QString      viewMode()            const { return m_viewMode; }
    void         setViewMode(const QString &mode);
    QStringList  categories()          const { return {QStringLiteral("run"), QStringLiteral("bike"), QStringLiteral("swim")}; }
    QStringList  intensities()         const { return {QStringLiteral("easy"), QStringLiteral("moderate"), QStringLiteral("hard")}; }
    QString      errorMessage()        const { return m_errorMessage; }
    bool         busy()                const { return m_busy; }

    // ── Auth invokables ───────────────────────────────────────────────────────
    Q_INVOKABLE void loginUser(const QString &email, const QString &password);
    Q_INVOKABLE void registerUser(const QString &email, const QString &name,
                                  const QString &password, const QString &role);
    Q_INVOKABLE void logout();
    Q_INVOKABLE void clearAuthError();

    // ── Athlete management ────────────────────────────────────────────────────
    Q_INVOKABLE void linkAthlete(const QString &athleteEmail);

    // ── Calendar & workout invokables ─────────────────────────────────────────
    Q_INVOKABLE void goToToday();
    Q_INVOKABLE void prevMonth();
    Q_INVOKABLE void nextMonth();
    Q_INVOKABLE void selectDate(const QString &dateIso);
    Q_INVOKABLE void openCreateDialogForDate(const QString &dateIso);
    Q_INVOKABLE void cancelCreateDialog();

    Q_INVOKABLE bool createWorkout(
        const QString &title, const QString &category,
        double distanceKm, int durationMin,
        const QString &intensity, const QString &notes,
        bool hiddenFromAthlete = false,
        const QString &intervalsJson = QString());

    Q_INVOKABLE bool updateWorkout(
        const QString &id, const QString &title, const QString &category,
        double distanceKm, int durationMin,
        const QString &intensity, const QString &notes,
        bool hiddenFromAthlete = false,
        const QString &intervalsJson = QString());

    Q_INVOKABLE bool deleteWorkout(const QString &id);
    Q_INVOKABLE void selectWorkout(const QString &id);

    // author is now taken from the JWT on the server — no longer a parameter
    Q_INVOKABLE bool addComment(const QString &text);

    Q_INVOKABLE bool markWorkoutStatus(const QString &workoutId,
                                       const QString &status,
                                       const QString &feedback);
    Q_INVOKABLE bool markWorkoutStatusDetailed(
        const QString &workoutId, const QString &status, const QString &feedback,
        const QString &mood, int perceivedExertion);

    Q_INVOKABLE bool saveTemplate(
        const QString &title, const QString &category,
        double distanceKm, int durationMin,
        const QString &intensity, const QString &intervals,
        const QString &notes, const QString &tags);

    Q_INVOKABLE bool updateTemplate(
        const QString &id, const QString &title, const QString &category,
        double distanceKm, int durationMin,
        const QString &intensity, const QString &intervals,
        const QString &notes, const QString &tags);

    Q_INVOKABLE bool deleteTemplate(const QString &id);
    Q_INVOKABLE bool planFromTemplate(const QString &templateId, const QString &dateIso);

    Q_INVOKABLE bool canCurrentUserEditAthlete(const QString &athleteId) const;
    Q_INVOKABLE void clearError();
    Q_INVOKABLE void refresh();

    // ── Goals ─────────────────────────────────────────────────────────────────
    Q_INVOKABLE bool createGoal(const QString &title,
                                const QString &targetDate,
                                const QString &type,
                                double targetValue,
                                const QString &targetUnit);
    Q_INVOKABLE bool deleteGoal(const QString &id);

    // ── Watch import ──────────────────────────────────────────────────────────
    Q_INVOKABLE bool importWatchFile(const QString &workoutId,
                                     const QString &localPath);

    // ── Routes ────────────────────────────────────────────────────────────────
    Q_INVOKABLE void generateRoute(double lat, double lon,
                                   double distanceKm, const QString &preferences);
    Q_INVOKABLE void deleteRoute(const QString &routeId);
    Q_INVOKABLE void setOpenAiKey(const QString &key);

signals:
    // Auth
    void loginStateChanged();
    void loginSucceeded();
    void loginFailed(const QString &error);
    void loggedOut();
    void sessionExpired();
    void authErrorChanged();
    void athleteLinked(const QString &athleteName);
    void athleteLinkFailed(const QString &error);

    // Data
    void calendarChanged();
    void athletesChanged();
    void selectedAthleteChanged();
    void selectedDateChanged();
    void selectedDayChanged();
    void selectedWorkoutChanged();
    void selectedWorkoutCommentsChanged();
    void analyticsChanged();
    void analyticsPeriodChanged();
    void goalsChanged();
    void routesChanged();
    void openAiKeyChanged();
    void templatesChanged();
    void createDialogOpenChanged();
    void draftChanged();
    void viewModeChanged();
    void errorChanged(const QString &message);
    void busyChanged();
    void workoutCreated();

private slots:
    void initialLoad();

private:
    // ── HTTP layer ────────────────────────────────────────────────────────────
    QNetworkRequest makeRequest(const QString &path) const;
    QJsonDocument   httpSync(const QString &method, const QString &path,
                             const QJsonObject &body = {});
    void            httpAsync(const QString &path,
                              std::function<void(const QJsonDocument &)> callback);
    void            handleUnauthorized();

    // ── Async fetchers ────────────────────────────────────────────────────────
    void buildLocalCalendar();
    void fetchCalendar();
    void fetchDayWorkouts();
    void fetchSelectedWorkout();
    void fetchComments();
    void fetchTemplates();
    void fetchAnalytics();
    void fetchAthletes();
    void fetchGoals();
    void fetchRoutes();
    void fetchOpenAiKeyStatus();

    // ── Helpers ───────────────────────────────────────────────────────────────
    void setError(const QString &message);
    void setAuthError(const QString &message);
    void setBusy(bool value);
    void applyAuthResponse(const QJsonObject &obj);
    void saveSession();
    void clearSession();
    bool tryRestoreSession();

    // ── Network ───────────────────────────────────────────────────────────────
    QNetworkAccessManager *m_nam     = nullptr;
    QString                m_baseUrl = QStringLiteral("http://localhost:8000");

    // ── Auth ──────────────────────────────────────────────────────────────────
    QString m_token;
    QString m_currentUserName;
    QString m_currentUserRole;
    QString m_currentAthleteId;
    QString m_authError;

    // ── Cached data ───────────────────────────────────────────────────────────
    QVariantList m_athletes;
    QVariantList m_dayCells;
    QVariantList m_selectedDayWorkouts;
    QVariantMap  m_selectedWorkout;
    QVariantList m_selectedWorkoutComments;
    QVariantMap  m_analyticsSummary;
    QString      m_analyticsPeriod = QStringLiteral("all");
    QVariantList m_goals;
    QVariantList m_routes;
    bool         m_hasOpenAiKey = false;
    QString      m_routeGenerating; // id of currently generating route ("" when idle)
    QVariantList m_templateLibrary;

    // ── UI state ──────────────────────────────────────────────────────────────
    QDate   m_monthStart;
    QDate   m_selectedDate;
    QDate   m_draftDate;
    bool    m_createDialogOpen  = false;
    QString m_viewMode          = QStringLiteral("month");
    QString m_selectedWorkoutId;
    QString m_selectedAthleteId;
    QString m_errorMessage;
    bool    m_busy              = false;
};

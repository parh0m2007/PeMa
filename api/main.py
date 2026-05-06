"""
Sport Calendar API v2 — FastAPI + SQLAlchemy (SQLite)
Auth: JWT Bearer tokens, bcrypt passwords
Run: uvicorn api.main:app --reload --port 8000
"""
from __future__ import annotations

import calendar as cal_module
import json
import os
import uuid
from datetime import date as Date, datetime, timedelta
from typing import Optional

from fastapi import Depends, FastAPI, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel, field_validator
from sqlalchemy import (
    Boolean, Column, Float, ForeignKey, Integer, String, Text, create_engine,
)
from sqlalchemy.orm import Session, declarative_base, sessionmaker

# ─── Config ──────────────────────────────────────────────────────────────────

SECRET_KEY = os.getenv("SECRET_KEY", "CHANGE_ME_IN_PRODUCTION_PLEASE_SET_ENV_VAR")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24  # 24 hours

DATABASE_URL = "sqlite:///./sport_calendar.db"

# ─── Database ────────────────────────────────────────────────────────────────

engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

pwd_ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def new_id() -> str:
    return str(uuid.uuid4())


# ─── Models ──────────────────────────────────────────────────────────────────

class UserDB(Base):
    __tablename__ = "users"
    id = Column(String, primary_key=True)
    email = Column(String, unique=True, nullable=False, index=True)
    name = Column(String, nullable=False)
    role = Column(String, nullable=False)          # "coach" | "athlete"
    password_hash = Column(String, nullable=False)
    athlete_id = Column(String, ForeignKey("athletes.id"), nullable=True)
    created_at = Column(String, nullable=False)


class AthleteDB(Base):
    __tablename__ = "athletes"
    id = Column(String, primary_key=True)
    name = Column(String, nullable=False)


class CoachAthleteLinkDB(Base):
    __tablename__ = "coach_athlete_links"
    coach_user_id = Column(String, ForeignKey("users.id"), primary_key=True)
    athlete_id = Column(String, ForeignKey("athletes.id"), primary_key=True)


class WorkoutDB(Base):
    __tablename__ = "workouts"
    id = Column(String, primary_key=True)
    athlete_id = Column(String, ForeignKey("athletes.id"), nullable=False)
    date = Column(String, nullable=False)          # YYYY-MM-DD
    title = Column(String, nullable=False)
    category = Column(String, nullable=False, default="run")
    distance_km = Column(Float, default=0.0)
    duration_min = Column(Integer, default=0)
    intensity = Column(String, default="moderate")
    notes = Column(Text, default="")
    hidden = Column(Boolean, default=False)
    intervals_json = Column(Text, default="[]")
    status = Column(String, default="planned")     # planned | done | skipped
    athlete_feedback = Column(Text, default="")
    athlete_mood = Column(String, default="")
    perceived_exertion = Column(Integer, default=0)


class CommentDB(Base):
    __tablename__ = "comments"
    id = Column(String, primary_key=True)
    workout_id = Column(String, ForeignKey("workouts.id"), nullable=False)
    author = Column(String, nullable=False)
    text = Column(Text, nullable=False)
    created_at = Column(String, nullable=False)


class TemplateDB(Base):
    __tablename__ = "templates"
    id = Column(String, primary_key=True)
    title = Column(String, nullable=False)
    category = Column(String, nullable=False, default="run")
    distance_km = Column(Float, default=0.0)
    duration_min = Column(Integer, default=0)
    intensity = Column(String, default="moderate")
    intervals_json = Column(Text, default="[]")
    notes = Column(Text, default="")
    tags = Column(String, default="")


# ─── Auth schemas ─────────────────────────────────────────────────────────────

VALID_ROLES = {"coach", "athlete"}


class RegisterRequest(BaseModel):
    email: str
    name: str
    password: str
    role: str

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: str) -> str:
        v = v.strip().lower()
        parts = v.split("@")
        if len(parts) != 2 or not parts[0] or "." not in parts[1] or not parts[1].split(".")[-1]:
            raise ValueError("Некорректный формат email")
        return v

    @field_validator("name")
    @classmethod
    def validate_name(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Имя не может быть пустым")
        if len(v) > 100:
            raise ValueError("Имя слишком длинное")
        return v

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Пароль должен содержать минимум 8 символов")
        return v

    @field_validator("role")
    @classmethod
    def validate_role(cls, v: str) -> str:
        if v not in VALID_ROLES:
            raise ValueError(f"Роль должна быть одной из: {', '.join(VALID_ROLES)}")
        return v


class LoginRequest(BaseModel):
    email: str
    password: str

    @field_validator("email")
    @classmethod
    def normalize_email(cls, v: str) -> str:
        return v.strip().lower()


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    name: str
    role: str
    athlete_id: Optional[str] = None


# ─── Workout / template schemas ───────────────────────────────────────────────

class WorkoutCreate(BaseModel):
    athlete_id: str
    date: str
    title: str
    category: str = "run"
    distance_km: float = 0.0
    duration_min: int = 0
    intensity: str = "moderate"
    notes: str = ""
    hidden: bool = False
    intervals_json: str = "[]"


class WorkoutUpdate(BaseModel):
    title: Optional[str] = None
    category: Optional[str] = None
    distance_km: Optional[float] = None
    duration_min: Optional[int] = None
    intensity: Optional[str] = None
    notes: Optional[str] = None
    hidden: Optional[bool] = None
    intervals_json: Optional[str] = None


class WorkoutStatusUpdate(BaseModel):
    status: str
    athlete_feedback: str = ""
    athlete_mood: str = ""
    perceived_exertion: int = 0


class CommentCreate(BaseModel):
    text: str

    @field_validator("text")
    @classmethod
    def text_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Комментарий не может быть пустым")
        return v.strip()


class TemplateCreate(BaseModel):
    title: str
    category: str = "run"
    distance_km: float = 0.0
    duration_min: int = 0
    intensity: str = "moderate"
    intervals_json: str = "[]"
    notes: str = ""
    tags: str = ""


class TemplateUpdate(BaseModel):
    title: Optional[str] = None
    category: Optional[str] = None
    distance_km: Optional[float] = None
    duration_min: Optional[int] = None
    intensity: Optional[str] = None
    intervals_json: Optional[str] = None
    notes: Optional[str] = None
    tags: Optional[str] = None


class PlanFromTemplate(BaseModel):
    athlete_id: str
    date: str


class AddAthleteRequest(BaseModel):
    athlete_email: str

    @field_validator("athlete_email")
    @classmethod
    def normalize(cls, v: str) -> str:
        return v.strip().lower()


# ─── JWT helpers ──────────────────────────────────────────────────────────────

def create_access_token(user_id: str, role: str) -> str:
    payload = {
        "sub": user_id,
        "role": role,
        "exp": datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES),
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> UserDB:
    exc = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Неверный или просроченный токен",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if not user_id:
            raise exc
    except JWTError:
        raise exc

    user = db.query(UserDB).filter(UserDB.id == user_id).first()
    if not user:
        raise exc
    return user


def require_coach(current_user: UserDB = Depends(get_current_user)) -> UserDB:
    if current_user.role != "coach":
        raise HTTPException(status_code=403, detail="Только для тренеров")
    return current_user


# ─── Formatters ──────────────────────────────────────────────────────────────

def category_icon(cat: str) -> str:
    return {"run": "🏃", "bike": "🚴", "swim": "🏊"}.get(cat, "⚡")


def intensity_label(i: str) -> str:
    return {"easy": "Легко", "moderate": "Умеренно", "hard": "Тяжело"}.get(i, i)


def intensity_color(i: str) -> str:
    return {"easy": "#10b981", "moderate": "#f59e0b", "hard": "#ef4444"}.get(i, "#6b7280")


def status_label(s: str) -> str:
    return {"planned": "Запланировано", "done": "Выполнено", "skipped": "Пропущено"}.get(s, s)


def workout_to_card(w: WorkoutDB) -> dict:
    return {
        "id": w.id,
        "title": w.title,
        "category": w.category,
        "typeIcon": category_icon(w.category),
        "distance": f"{w.distance_km:.1f} км",
        "duration": f"{w.duration_min} мин",
        "distanceKm": w.distance_km,
        "durationMin": w.duration_min,
        "intensity": w.intensity,
        "intensityLabel": intensity_label(w.intensity),
        "intensityColor": intensity_color(w.intensity),
        "status": w.status,
        "statusLabel": status_label(w.status),
        "hidden": w.hidden,
        "dateIso": w.date,
        "notes": w.notes,
        "intervalsJson": w.intervals_json,
        "athleteFeedback": w.athlete_feedback or "",
        "athleteMood": w.athlete_mood or "",
        "perceivedExertion": w.perceived_exertion or 0,
        "athleteId": w.athlete_id,
    }


def tpl_to_dict(t: TemplateDB) -> dict:
    return {
        "id": t.id,
        "title": t.title,
        "category": t.category,
        "distanceKm": t.distance_km,
        "durationMin": t.duration_min,
        "intensity": t.intensity,
        "intervals": t.intervals_json,
        "notes": t.notes,
        "tags": t.tags,
    }


# ─── App ─────────────────────────────────────────────────────────────────────

app = FastAPI(title="Sport Calendar API", version="2.0.0", docs_url="/docs")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def startup():
    Base.metadata.create_all(bind=engine)


# ─── Auth ─────────────────────────────────────────────────────────────────────

@app.post("/api/auth/register", response_model=TokenResponse, status_code=201)
def register(data: RegisterRequest, db: Session = Depends(get_db)):
    if db.query(UserDB).filter(UserDB.email == data.email).first():
        raise HTTPException(400, "Email уже зарегистрирован")

    athlete_id = None
    if data.role == "athlete":
        athlete = AthleteDB(id=new_id(), name=data.name)
        db.add(athlete)
        db.flush()
        athlete_id = athlete.id

    user = UserDB(
        id=new_id(),
        email=data.email,
        name=data.name,
        role=data.role,
        password_hash=pwd_ctx.hash(data.password),
        athlete_id=athlete_id,
        created_at=datetime.utcnow().isoformat(),
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    return TokenResponse(
        access_token=create_access_token(user.id, user.role),
        user_id=user.id,
        name=user.name,
        role=user.role,
        athlete_id=user.athlete_id,
    )


@app.post("/api/auth/login", response_model=TokenResponse)
def login(data: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(UserDB).filter(UserDB.email == data.email).first()
    if not user or not pwd_ctx.verify(data.password, user.password_hash):
        # Same error for both to prevent email enumeration
        raise HTTPException(401, "Неверный email или пароль")

    return TokenResponse(
        access_token=create_access_token(user.id, user.role),
        user_id=user.id,
        name=user.name,
        role=user.role,
        athlete_id=user.athlete_id,
    )


@app.get("/api/auth/me")
def get_me(current_user: UserDB = Depends(get_current_user)):
    return {
        "id": current_user.id,
        "email": current_user.email,
        "name": current_user.name,
        "role": current_user.role,
        "athleteId": current_user.athlete_id,
    }


# ─── Athletes ────────────────────────────────────────────────────────────────

@app.get("/api/athletes")
def list_athletes(
    current_user: UserDB = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role == "coach":
        links = db.query(CoachAthleteLinkDB).filter(
            CoachAthleteLinkDB.coach_user_id == current_user.id
        ).all()
        ids = [lnk.athlete_id for lnk in links]
        athletes = db.query(AthleteDB).filter(AthleteDB.id.in_(ids)).order_by(AthleteDB.name).all()
    else:
        athletes = (
            db.query(AthleteDB).filter(AthleteDB.id == current_user.athlete_id).all()
            if current_user.athlete_id else []
        )
    return [{"id": a.id, "name": a.name} for a in athletes]


@app.post("/api/athletes/link", status_code=201)
def link_athlete(
    data: AddAthleteRequest,
    current_user: UserDB = Depends(require_coach),
    db: Session = Depends(get_db),
):
    athlete_user = db.query(UserDB).filter(
        UserDB.email == data.athlete_email,
        UserDB.role == "athlete",
    ).first()
    if not athlete_user or not athlete_user.athlete_id:
        raise HTTPException(404, "Атлет с таким email не найден")

    existing = db.query(CoachAthleteLinkDB).filter(
        CoachAthleteLinkDB.coach_user_id == current_user.id,
        CoachAthleteLinkDB.athlete_id == athlete_user.athlete_id,
    ).first()
    if existing:
        raise HTTPException(409, "Атлет уже добавлен")

    db.add(CoachAthleteLinkDB(
        coach_user_id=current_user.id,
        athlete_id=athlete_user.athlete_id,
    ))
    db.commit()
    return {"athleteId": athlete_user.athlete_id, "name": athlete_user.name}


@app.delete("/api/athletes/{athlete_id}/link", status_code=204)
def unlink_athlete(
    athlete_id: str,
    current_user: UserDB = Depends(require_coach),
    db: Session = Depends(get_db),
):
    link = db.query(CoachAthleteLinkDB).filter(
        CoachAthleteLinkDB.coach_user_id == current_user.id,
        CoachAthleteLinkDB.athlete_id == athlete_id,
    ).first()
    if not link:
        raise HTTPException(404, "Связь не найдена")
    db.delete(link)
    db.commit()


# ─── Calendar ────────────────────────────────────────────────────────────────

@app.get("/api/calendar/{year}/{month}")
def get_calendar(
    year: int,
    month: int,
    athlete_id: str,
    current_user: UserDB = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _assert_athlete_access(current_user, athlete_id, db)

    first_day = Date(year, month, 1)
    last_day = Date(year, month, cal_module.monthrange(year, month)[1])
    grid_start = first_day - timedelta(days=first_day.weekday())

    start_fetch = grid_start - timedelta(days=1)
    end_fetch = last_day + timedelta(days=14)
    show_hidden = current_user.role == "coach"

    workouts_q = db.query(WorkoutDB).filter(
        WorkoutDB.athlete_id == athlete_id,
        WorkoutDB.date >= start_fetch.strftime("%Y-%m-%d"),
        WorkoutDB.date <= end_fetch.strftime("%Y-%m-%d"),
    ).all()

    by_date: dict[str, list] = {}
    for w in workouts_q:
        if w.hidden and not show_hidden:
            continue
        by_date.setdefault(w.date, []).append(workout_to_card(w))

    today_iso = Date.today().strftime("%Y-%m-%d")
    cells = []
    for i in range(42):
        d = grid_start + timedelta(days=i)
        d_iso = d.strftime("%Y-%m-%d")
        in_month = d.month == month
        cells.append({
            "dateIso": d_iso,
            "dayNumber": str(d.day),
            "inCurrentMonth": in_month,
            "isToday": d_iso == today_iso,
            "background": "#dbeafe" if d_iso == today_iso else ("#ffffff" if in_month else "#f8fafc"),
            "workouts": by_date.get(d_iso, []),
        })
    return cells


# ─── Workouts ────────────────────────────────────────────────────────────────

@app.get("/api/workouts")
def list_workouts(
    athlete_id: str,
    date: Optional[str] = Query(None),
    current_user: UserDB = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _assert_athlete_access(current_user, athlete_id, db)
    q = db.query(WorkoutDB).filter(WorkoutDB.athlete_id == athlete_id)
    if date:
        q = q.filter(WorkoutDB.date == date)
    show_hidden = current_user.role == "coach"
    return [
        workout_to_card(w) for w in q.order_by(WorkoutDB.date).all()
        if not (w.hidden and not show_hidden)
    ]


@app.post("/api/workouts", status_code=201)
def create_workout(
    workout: WorkoutCreate,
    current_user: UserDB = Depends(require_coach),
    db: Session = Depends(get_db),
):
    _assert_coach_athlete_link(current_user.id, workout.athlete_id, db)
    try:
        json.loads(workout.intervals_json)
    except Exception:
        raise HTTPException(400, "Некорректный JSON интервалов")

    w = WorkoutDB(
        id=new_id(), athlete_id=workout.athlete_id, date=workout.date,
        title=workout.title, category=workout.category,
        distance_km=workout.distance_km, duration_min=workout.duration_min,
        intensity=workout.intensity, notes=workout.notes,
        hidden=workout.hidden, intervals_json=workout.intervals_json,
        status="planned",
    )
    db.add(w)
    db.commit()
    db.refresh(w)
    return workout_to_card(w)


@app.get("/api/workouts/{workout_id}")
def get_workout(
    workout_id: str,
    current_user: UserDB = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    w = _get_workout_or_404(workout_id, db)
    _assert_athlete_access(current_user, w.athlete_id, db)
    if w.hidden and current_user.role != "coach":
        raise HTTPException(403, "Нет доступа")
    return workout_to_card(w)


@app.put("/api/workouts/{workout_id}")
def update_workout(
    workout_id: str,
    update: WorkoutUpdate,
    current_user: UserDB = Depends(require_coach),
    db: Session = Depends(get_db),
):
    w = _get_workout_or_404(workout_id, db)
    _assert_coach_athlete_link(current_user.id, w.athlete_id, db)

    if update.title is not None:         w.title = update.title
    if update.category is not None:      w.category = update.category
    if update.distance_km is not None:   w.distance_km = update.distance_km
    if update.duration_min is not None:  w.duration_min = update.duration_min
    if update.intensity is not None:     w.intensity = update.intensity
    if update.notes is not None:         w.notes = update.notes
    if update.hidden is not None:        w.hidden = update.hidden
    if update.intervals_json is not None:
        try:
            json.loads(update.intervals_json)
        except Exception:
            raise HTTPException(400, "Некорректный JSON интервалов")
        w.intervals_json = update.intervals_json

    db.commit()
    db.refresh(w)
    return workout_to_card(w)


@app.delete("/api/workouts/{workout_id}", status_code=204)
def delete_workout(
    workout_id: str,
    current_user: UserDB = Depends(require_coach),
    db: Session = Depends(get_db),
):
    w = _get_workout_or_404(workout_id, db)
    _assert_coach_athlete_link(current_user.id, w.athlete_id, db)
    db.query(CommentDB).filter(CommentDB.workout_id == workout_id).delete()
    db.delete(w)
    db.commit()


@app.put("/api/workouts/{workout_id}/status")
def update_workout_status(
    workout_id: str,
    update: WorkoutStatusUpdate,
    current_user: UserDB = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    w = _get_workout_or_404(workout_id, db)
    _assert_athlete_access(current_user, w.athlete_id, db)
    if update.status not in {"planned", "done", "skipped"}:
        raise HTTPException(400, "Недопустимый статус")

    w.status = update.status
    w.athlete_feedback = update.athlete_feedback
    w.athlete_mood = update.athlete_mood
    w.perceived_exertion = update.perceived_exertion
    db.commit()
    db.refresh(w)
    return workout_to_card(w)


@app.get("/api/workouts/{workout_id}/comments")
def list_comments(
    workout_id: str,
    current_user: UserDB = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    w = _get_workout_or_404(workout_id, db)
    _assert_athlete_access(current_user, w.athlete_id, db)
    comments = db.query(CommentDB).filter(
        CommentDB.workout_id == workout_id
    ).order_by(CommentDB.created_at).all()
    return [
        {"id": c.id, "workoutId": c.workout_id, "author": c.author,
         "text": c.text, "createdAt": c.created_at}
        for c in comments
    ]


@app.post("/api/workouts/{workout_id}/comments", status_code=201)
def add_comment(
    workout_id: str,
    comment: CommentCreate,
    current_user: UserDB = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    w = _get_workout_or_404(workout_id, db)
    _assert_athlete_access(current_user, w.athlete_id, db)
    c = CommentDB(
        id=new_id(), workout_id=workout_id,
        author=current_user.name,
        text=comment.text,
        created_at=datetime.utcnow().isoformat(),
    )
    db.add(c)
    db.commit()
    db.refresh(c)
    return {"id": c.id, "workoutId": c.workout_id, "author": c.author,
            "text": c.text, "createdAt": c.created_at}


# ─── Templates ───────────────────────────────────────────────────────────────

@app.get("/api/templates")
def list_templates(
    current_user: UserDB = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return [tpl_to_dict(t) for t in db.query(TemplateDB).order_by(TemplateDB.title).all()]


@app.post("/api/templates", status_code=201)
def create_template(
    tpl: TemplateCreate,
    current_user: UserDB = Depends(require_coach),
    db: Session = Depends(get_db),
):
    t = TemplateDB(
        id=new_id(), title=tpl.title, category=tpl.category,
        distance_km=tpl.distance_km, duration_min=tpl.duration_min,
        intensity=tpl.intensity, intervals_json=tpl.intervals_json,
        notes=tpl.notes, tags=tpl.tags,
    )
    db.add(t)
    db.commit()
    db.refresh(t)
    return tpl_to_dict(t)


@app.put("/api/templates/{template_id}")
def update_template(
    template_id: str,
    update: TemplateUpdate,
    current_user: UserDB = Depends(require_coach),
    db: Session = Depends(get_db),
):
    t = db.query(TemplateDB).filter(TemplateDB.id == template_id).first()
    if not t:
        raise HTTPException(404, "Шаблон не найден")
    for key, val in update.model_dump(exclude_none=True).items():
        if hasattr(t, key):
            setattr(t, key, val)
    db.commit()
    db.refresh(t)
    return tpl_to_dict(t)


@app.delete("/api/templates/{template_id}", status_code=204)
def delete_template(
    template_id: str,
    current_user: UserDB = Depends(require_coach),
    db: Session = Depends(get_db),
):
    t = db.query(TemplateDB).filter(TemplateDB.id == template_id).first()
    if not t:
        raise HTTPException(404, "Шаблон не найден")
    db.delete(t)
    db.commit()


@app.post("/api/templates/{template_id}/plan", status_code=201)
def plan_from_template(
    template_id: str,
    plan: PlanFromTemplate,
    current_user: UserDB = Depends(require_coach),
    db: Session = Depends(get_db),
):
    _assert_coach_athlete_link(current_user.id, plan.athlete_id, db)
    t = db.query(TemplateDB).filter(TemplateDB.id == template_id).first()
    if not t:
        raise HTTPException(404, "Шаблон не найден")
    w = WorkoutDB(
        id=new_id(), athlete_id=plan.athlete_id, date=plan.date,
        title=t.title, category=t.category,
        distance_km=t.distance_km, duration_min=t.duration_min,
        intensity=t.intensity, notes=t.notes,
        intervals_json=t.intervals_json, status="planned",
    )
    db.add(w)
    db.commit()
    db.refresh(w)
    return workout_to_card(w)


# ─── Analytics ───────────────────────────────────────────────────────────────

@app.get("/api/analytics")
def get_analytics(
    athlete_id: str,
    current_user: UserDB = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _assert_athlete_access(current_user, athlete_id, db)
    workouts = db.query(WorkoutDB).filter(WorkoutDB.athlete_id == athlete_id).all()

    by_intensity = {"easy": 0, "moderate": 0, "hard": 0}
    by_category = {"run": 0, "bike": 0, "swim": 0}
    by_status = {"planned": 0, "done": 0, "skipped": 0}
    for w in workouts:
        by_intensity[w.intensity] = by_intensity.get(w.intensity, 0) + 1
        by_category[w.category] = by_category.get(w.category, 0) + 1
        by_status[w.status] = by_status.get(w.status, 0) + 1

    return {
        "workoutsCount": len(workouts),
        "durationTotal": sum(w.duration_min for w in workouts),
        "distanceTotal": round(sum(w.distance_km for w in workouts), 1),
        "byIntensity": by_intensity,
        "byCategory": by_category,
        "byStatus": by_status,
    }


# ─── Access helpers ───────────────────────────────────────────────────────────

def _assert_athlete_access(user: UserDB, athlete_id: str, db: Session) -> None:
    if user.role == "athlete":
        if user.athlete_id != athlete_id:
            raise HTTPException(403, "Нет доступа")
    else:
        _assert_coach_athlete_link(user.id, athlete_id, db)


def _assert_coach_athlete_link(coach_user_id: str, athlete_id: str, db: Session) -> None:
    link = db.query(CoachAthleteLinkDB).filter(
        CoachAthleteLinkDB.coach_user_id == coach_user_id,
        CoachAthleteLinkDB.athlete_id == athlete_id,
    ).first()
    if not link:
        raise HTTPException(403, "Нет доступа к этому атлету")


def _get_workout_or_404(workout_id: str, db: Session) -> WorkoutDB:
    w = db.query(WorkoutDB).filter(WorkoutDB.id == workout_id).first()
    if not w:
        raise HTTPException(404, "Тренировка не найдена")
    return w

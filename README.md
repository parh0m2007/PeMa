# PeMa - Personal Training Manager

Desktop app for planning and tracking workouts. Coach creates plans, athlete executes and reports back. Built with Qt 6 + FastAPI.

## Features

- **Calendar** - monthly grid with workout cards, click any day to plan
- **Roles** — coach creates/edits workouts, athlete marks them done/skipped with feedback
- **Analytics** - distance, duration, pace, streak, weekly/monthly charts, completion rate
- **Routes** — generate circular routes by distance, draw custom routes on an OSM map, sync activities from Strava
- **Watch import** - upload `.gpx` or `.fit` files to fill in actual distance, HR, elevation
- **Templates / Builder** — save reusable workout templates and schedule them in one click
- **Pain map** - clickable body silhouette to tag sore spots in post-workout feedback
- **Goals** - set race/volume targets with progress tracking
- **Dark mode** - full light/dark/system theme support

## Tech stack

| Layer | Technology |
|---|---|
| UI | Qt 6 / QML / QuickControls 2 |
| Backend | Python · FastAPI · SQLAlchemy · SQLite |
| Maps | OpenStreetMap tiles (proxied) · OSRM routing |
| Auth | JWT · bcrypt |
| Sync | Strava API OAuth2 · GPX/FIT parsing |

## Requirements

**Qt app (C++)**
- Qt 6.5+ (Core, Gui, Qml, Quick, QuickControls2, Network)
- CMake 3.21+
- C++17 compiler (AppleClang / MSVC / GCC)

**Backend (Python)**
- Python 3.10+
- Dependencies listed in `api/requirements.txt`

## Quick start (macOS)

```bash
# Clone
git clone https://github.com/yourname/pema.git
cd pema

# Launch everything (builds Qt app, starts backend, opens app)
bash PeMa.command
```

The script automatically:
- Configures and builds the Qt app (first run ~1 min)
- Creates a Python venv and installs dependencies
- Starts the FastAPI backend on `http://localhost:8000`
- Opens the app; kills the backend when you close the window

## Manual build

```bash
# Backend
cd api
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --port 8000

# Qt app (new terminal)
mkdir build && cd build
cmake -DCMAKE_PREFIX_PATH="~/Qt/6.11.0/macos" ..
cmake --build . --parallel
open PeMa.app
```

**Windows:**
```powershell
cmake -S . -B build -DCMAKE_PREFIX_PATH="C:\Qt\6.x.x\msvc2022_64"
cmake --build build
```

## Project structure

```
├── api/
│   ├── main.py              # FastAPI app (auth, workouts, routes, Strava)
│   └── requirements.txt
├── src/
│   ├── app/main.cpp
│   ├── backend/
│   │   ├── WorkoutStore.h
│   │   └── WorkoutStore.cpp # Qt ↔ backend bridge
│   └── ui/qml/
│       ├── main.qml
│       ├── RouteTab.qml
│       └── components/      # AuthScreen, TileMap, BodyPainMap, …
├── resources/
├── CMakeLists.txt
└── PeMa.command             # macOS one-click launcher
```

## Strava integration

1. Create a free app at [strava.com/settings/api](https://www.strava.com/settings/api)
2. In PeMa → Routes → enter your Client ID & Secret
3. Click **Connect Strava** — browser opens for OAuth
4. Click **Sync** to import recent activities

## License




```mermaid

classDiagram
    %% Стилизация для разделения слоев
    class UserDB {
        +int id
        +string email
        +string password_hash
        +string name
        +datetime created_at
        +get_profile()
        +update_settings()
    }

    class AthleteDB {
        +int user_id
        +float weight
        +float height
        +int ftp
        +string zone_config
        +calc_zones()
        +update_metrics()
    }

    class CoachAthleteLinkDB {
        +int coach_id
        +int athlete_id
        +string status
        +datetime linked_at
        +grant_access()
        +revoke_access()
    }

    class WorkoutDB {
        +int id
        +int user_id
        +datetime start_time
        +string type
        +float duration
        +json data_points
        +string strava_id
        +save_activity()
        +get_details()
    }

    class GoalDB {
        +int id
        +int user_id
        +string target_type
        +float target_value
        +datetime deadline
        +check_progress()
        +update_status()
    }

    class RouteDB {
        +int id
        +int user_id
        +string name
        +geojson path
        +float distance
        +export_gpx()
    }

    class AuthRouter {
        +register()
        +login()
        +refresh_token()
        +logout()
        +validate_user()
    }

    class WorkoutRouter {
        +list_workouts()
        +get_workout()
        +upload_workout()
        +delete_workout()
        +sync_strava()
    }

    class AnalyticsRouter {
        +get_stats()
        +get_form_chart()
        +compare_goals()
        +calculate_fitness()
    }

    class StravaRouter {
        +oauth_callback()
        +fetch_activities()
        +push_activity()
        +handle_webhook()
    }

    class AIRouter {
        +generate_plan()
        +analyze_performance()
        +get_recommendation()
        +chat_with_coach()
    }

    class RouteRouter {
        +create_route()
        +search_routes()
        +get_route_map()
        +export_route()
    }

    class WorkoutStore {
        <<C++ / Qt6>>
        -QList<Workout> cache
        -NetworkManager net
        +loadWorkouts()
        +syncWithServer()
        +selectDate()
        +notifyUI()
    }

    class CalendarView {
        <<QML>>
        +model: WorkoutStore
        +renderMonth()
        +onDayClicked()
        +highlightIntensity()
    }

    class WorkoutDetailPanel {
        <<QML>>
        +currentWorkout: object
        +showMap()
        +renderCharts()
        +displayMetrics()
    }

    class AnalyticsTab {
        <<QML>>
        +fetchStats()
        +renderGraphs()
        +showGoalProgress()
    }

    class AiCoachTab {
        <<QML>>
        +displayPlan()
        +sendQuery()
        +showRecommendations()
    }

    class RouteTab {
        <<QML>>
        +mapComponent
        +drawRoute()
        +loadSavedRoutes()
    }

    class SettingsPanel {
        <<QML>>
        +editProfile()
        +connectStrava()
        +appPreferences()
    }

    class AuthScreen {
        <<QML>>
        +loginForm
        +registerForm
        +submitCredentials()
        +handleError()
    }

    class BuilderTab {
        <<QML>>
        +intervalEditor
        +planBuilder
        +saveTemplate()
    }

    %% Отношения БД
    UserDB "1" -- "1" AthleteDB : extends/profile
    UserDB "1" -- "0..*" CoachAthleteLinkDB : links
    UserDB "1" -- "0..*" WorkoutDB : owns
    UserDB "1" -- "0..*" GoalDB : sets
    UserDB "1" -- "0..*" RouteDB : creates

    %% Отношения Бэкенд -> БД (Использование)
    AuthRouter ..> UserDB : manages
    WorkoutRouter ..> WorkoutDB : CRUD
    WorkoutRouter ..> StravaRouter : triggers
    AnalyticsRouter ..> WorkoutDB : reads
    AnalyticsRouter ..> GoalDB : compares
    AIRouter ..> WorkoutDB : analyzes
    AIRouter ..> AthleteDB : personalizes
    RouteRouter ..> RouteDB : manages

    %% Отношения Фронтенд <-> Логика
    WorkoutStore ..> AuthRouter : auth
    WorkoutStore ..> WorkoutRouter : fetch data
    WorkoutStore ..> AnalyticsRouter : fetch stats
    WorkoutStore ..> RouteRouter : fetch routes
    
    %% Отношения QML -> Store
    CalendarView --> WorkoutStore : observes
    WorkoutDetailPanel --> WorkoutStore : selects
    AnalyticsTab --> WorkoutStore : requests data
    AiCoachTab --> WorkoutStore : interacts
    RouteTab --> WorkoutStore : loads maps
    SettingsPanel --> WorkoutStore : updates config
    AuthScreen --> WorkoutStore : submits creds
    BuilderTab --> WorkoutStore : saves plans

    %% Группировка по пакетам (визуально)
    subgraph Database_Layer ["🗄️ Database Models (SQLAlchemy)"]
        UserDB
        AthleteDB
        CoachAthleteLinkDB
        WorkoutDB
        GoalDB
        RouteDB
    end

    subgraph Backend_Layer ["🐍 FastAPI Backend"]
        AuthRouter
        WorkoutRouter
        AnalyticsRouter
        StravaRouter
        AIRouter
        RouteRouter
    end

    subgraph Desktop_Core ["⚙️ C++ Core (Qt6)"]
        WorkoutStore
    end

    subgraph Frontend_Layer ["🎨 QML Frontend"]
        CalendarView
        WorkoutDetailPanel
        AnalyticsTab
        AiCoachTab
        RouteTab
        SettingsPanel
        AuthScreen
        BuilderTab
    end

```

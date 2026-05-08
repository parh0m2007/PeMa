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

MIT

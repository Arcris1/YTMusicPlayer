# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

YouTube Music Player — a Spotify-like music/video streaming app powered by YouTube. Python FastAPI backend + Flutter frontend.

## Common Commands

### Backend (from `backend/`)

```bash
# Run with Docker (recommended) — API on :8001, PostgreSQL on :5433, Redis on :6379
docker-compose up -d

# Run manually (requires PostgreSQL + Redis running, venv activated)
uvicorn app.main:app --reload    # serves on :8000

# Install dependencies
pip install -r requirements.txt

# API docs available at /docs (Swagger) and /redoc
```

### Frontend (from `frontend/`)

```bash
flutter pub get                        # install dependencies
flutter run -d windows                 # run on Windows desktop
flutter analyze                        # static analysis (flutter_lints)
dart run build_runner build            # one-time code generation (Freezed, Riverpod, JSON)
dart run build_runner watch            # watch mode code generation
```

## Architecture

### Backend (FastAPI, async)

Layered: **Router → Endpoint → Service → DB/yt-dlp**

- `app/main.py` — App factory with lifespan; creates all DB tables on startup via `Base.metadata.create_all`
- `app/api/v1/` — Versioned routers: `auth.py`, `search.py`, `playback.py`, `playlists.py`
- `app/services/youtube.py` — Singleton `YouTubeService`; wraps yt-dlp in `ThreadPoolExecutor(max_workers=4)` via `run_in_executor()` since yt-dlp is blocking
- `app/models/` — SQLAlchemy async ORM: `User`, `Playlist`, `Track`, `LikedTrack`, `playlist_tracks` (association table with `position`)
- `app/schemas/` — Pydantic v2 request/response models
- `app/core/security.py` — JWT (access 30min / refresh 7d), `pbkdf2_sha256` password hashing, `OAuth2PasswordBearer`
- `app/db/database.py` — `AsyncSession` via `asyncpg`
- `app/config.py` — Pydantic `Settings` loaded from `.env`, cached with `@lru_cache`

### Frontend (Flutter + Riverpod)

Feature-based structure under `lib/features/` (auth, home, search, player, library).

- **State management**: Manual `StateNotifier` + `StateNotifierProvider` (Riverpod). Key providers:
  - `mediaPlayerControllerProvider` — primary player using MediaKit (libmpv)
  - `authProvider` — login/register/logout with secure token storage
  - `playlistProvider` — playlist CRUD + liked tracks
  - `searchProvider` — YouTube search (defined inline in `search_screen.dart`)
- **API client** (`core/api/api_client.dart`): Dio with interceptor that attaches Bearer token and handles 401 refresh
- **Navigation**: `IndexedStack` inside `AppShell` with 3 tabs (Home, Search, Library); `NowPlayingScreen` slides up via `AnimatedSlide`
- **Media playback flow**: User taps track → controller calls backend `/playback/audio|video/{id}` → backend extracts stream URL via yt-dlp → controller opens URL in MediaKit player → on queue end, auto-fetches related videos via `/playback/related/{id}`
- **Tokens**: Stored in `flutter_secure_storage`
- **Theme** (`config/theme.dart`): Spotify-inspired dark theme, Material 3, Inter font
- **API base URL** (`config/constants.dart`): Hardcoded to `http://localhost:8001`

### Key Infrastructure

- Docker Compose: 3 services (api, postgres, redis) — API port-mapped 8001→8000, PostgreSQL 5433→5432
- Backend `.env` config: `SECRET_KEY`, `DATABASE_URL`, `REDIS_URL`, preferred YouTube audio/video format IDs
- No tests, CI/CD, or migration scripts exist yet
- Redis is configured in settings but not actively used in application code

# YouTube Music Player

A Spotify-like music and video streaming application powered by YouTube, featuring a Python FastAPI backend and Flutter frontend.

## 🎵 Features

- **YouTube Search**: Search for songs, artists, and videos directly from YouTube
- **Audio Streaming**: Stream high-quality audio from YouTube videos
- **Background Playback**: Continue listening while using other apps
- **Playlists**: Create and manage personal playlists
- **Dark Theme**: Beautiful Spotify-inspired dark UI
- **Queue Management**: Build and control your playback queue

## 📁 Project Structure

```
MusicPlayer/
├── backend/                 # Python FastAPI backend
│   ├── app/
│   │   ├── api/v1/         # API endpoints
│   │   ├── core/           # Security & dependencies
│   │   ├── models/         # SQLAlchemy models
│   │   ├── schemas/        # Pydantic schemas
│   │   ├── services/       # Business logic (YouTube, etc.)
│   │   └── db/             # Database configuration
│   ├── tests/              # Backend tests
│   ├── docker-compose.yml  # Docker setup
│   └── requirements.txt    # Python dependencies
│
└── frontend/               # Flutter mobile app
    └── lib/
        ├── config/         # Theme & constants
        ├── core/           # API client & services
        ├── features/       # Feature modules
        │   ├── auth/       # Authentication
        │   ├── home/       # Home screen
        │   ├── search/     # Search functionality
        │   ├── player/     # Audio/video player
        │   └── library/    # User library
        └── shared/         # Shared widgets & models
```

## 🚀 Getting Started

### Prerequisites

- Python 3.11+
- Flutter 3.10+
- Docker & Docker Compose (optional, for backend)
- PostgreSQL (or use Docker)
- Redis (or use Docker)

### Backend Setup

1. **Navigate to backend directory:**
   ```bash
   cd backend
   ```

2. **Create virtual environment:**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

4. **Set up environment variables:**
   ```bash
   cp .env.example .env
   # Edit .env with your settings
   ```

5. **Using Docker (recommended):**
   ```bash
   docker-compose up -d
   ```
   
   Or **run manually:**
   ```bash
   # Start PostgreSQL and Redis first, then:
   uvicorn app.main:app --reload
   ```

6. **Access API docs:**
   - Swagger UI: http://localhost:8000/docs
   - ReDoc: http://localhost:8000/redoc

### Frontend Setup

1. **Navigate to frontend directory:**
   ```bash
   cd frontend
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

## 📱 Screenshots

*Coming soon...*

## 🛠️ Tech Stack

### Backend
- **FastAPI** - High-performance async Python API
- **SQLAlchemy** - Async ORM
- **PostgreSQL** - Database
- **Redis** - Caching
- **yt-dlp** - YouTube integration
- **JWT** - Authentication

### Frontend
- **Flutter** - Cross-platform mobile framework
- **Riverpod** - State management
- **just_audio** - Audio playback
- **Dio** - HTTP client
- **Hive** - Local storage

## 📝 API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/auth/register` | POST | Register new user |
| `/api/v1/auth/login` | POST | Login user |
| `/api/v1/search` | GET | Search YouTube |
| `/api/v1/playback/audio/{id}` | GET | Get audio stream URL |
| `/api/v1/playback/video/{id}` | GET | Get video stream URL |
| `/api/v1/playlists` | GET/POST | List/Create playlists |
| `/api/v1/playlists/{id}` | GET/PUT/DELETE | Manage playlist |

## ⚠️ Legal Notice

This application is for educational and personal use only. Using YouTube content may violate YouTube's Terms of Service. Please respect copyright laws and content creators.

## 📄 License

MIT License - See LICENSE file for details.

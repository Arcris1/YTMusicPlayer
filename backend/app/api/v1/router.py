from fastapi import APIRouter

from app.api.v1.auth import router as auth_router
from app.api.v1.search import router as search_router
from app.api.v1.playback import router as playback_router
from app.api.v1.playlists import router as playlists_router

api_router = APIRouter()

api_router.include_router(auth_router)
api_router.include_router(search_router)
api_router.include_router(playback_router)
api_router.include_router(playlists_router)

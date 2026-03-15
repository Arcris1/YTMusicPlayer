from fastapi import APIRouter, Depends, Query

from app.services.youtube import get_youtube_service, YouTubeService
from app.schemas.user import SearchResponse, TrackSearchResult, PlaylistSearchResponse, PlaylistTracksResponse
from app.core.security import get_current_user_id

router = APIRouter(prefix="/search", tags=["Search"])


@router.get("", response_model=SearchResponse)
async def search_tracks(
    query: str = Query(..., min_length=1, max_length=200, description="Search query"),
    limit: int = Query(default=20, ge=1, le=50, description="Number of results"),
    youtube: YouTubeService = Depends(get_youtube_service),
):
    """Search for tracks on YouTube."""
    results = await youtube.search(query, limit)
    
    return SearchResponse(
        query=query,
        results=results,
        total=len(results),
    )


@router.get("/playlists", response_model=PlaylistSearchResponse)
async def search_playlists(
    query: str = Query(..., min_length=1, max_length=200, description="Search query"),
    limit: int = Query(default=20, ge=1, le=50, description="Number of results"),
    youtube: YouTubeService = Depends(get_youtube_service),
):
    """Search for playlists on YouTube."""
    results = await youtube.search_playlists(query, limit)

    return PlaylistSearchResponse(
        query=query,
        results=results,
        total=len(results),
    )


@router.get("/playlists/{playlist_id}", response_model=PlaylistTracksResponse)
async def get_playlist_tracks(
    playlist_id: str,
    youtube: YouTubeService = Depends(get_youtube_service),
):
    """Get tracks from a YouTube playlist."""
    data = await youtube.get_playlist_tracks(playlist_id)

    return PlaylistTracksResponse(**data)


@router.get("/suggestions")
async def get_search_suggestions(
    query: str = Query(..., min_length=1, max_length=100),
    youtube: YouTubeService = Depends(get_youtube_service),
):
    """Get search suggestions (autocomplete)."""
    # For now, just return a limited search
    results = await youtube.search(query, limit=5)
    
    return {
        "suggestions": [r.title for r in results]
    }

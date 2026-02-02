from fastapi import APIRouter, Depends, Query

from app.services.youtube import get_youtube_service, YouTubeService
from app.schemas.user import SearchResponse, TrackSearchResult
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

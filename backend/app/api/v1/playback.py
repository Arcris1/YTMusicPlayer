from fastapi import APIRouter, Depends, HTTPException, status, Query

from app.services.youtube import get_youtube_service, YouTubeService
from app.schemas.user import StreamInfo
from app.core.security import get_current_user_id

router = APIRouter(prefix="/playback", tags=["Playback"])


@router.get("/audio/{video_id}", response_model=StreamInfo)
async def get_audio_stream(
    video_id: str,
    youtube: YouTubeService = Depends(get_youtube_service),
):
    """Get audio stream URL for a video."""
    try:
        stream_info = await youtube.get_audio_stream_url(video_id)
        return stream_info
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Could not get audio stream: {str(e)}"
        )


@router.get("/video/{video_id}", response_model=StreamInfo)
async def get_video_stream(
    video_id: str,
    quality: str = Query(default="best", regex="^(best|1080|720|480|360)$"),
    youtube: YouTubeService = Depends(get_youtube_service),
):
    """Get video stream URL for a video."""
    try:
        stream_info = await youtube.get_video_stream_url(video_id, quality)
        return stream_info
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Could not get video stream: {str(e)}"
        )


@router.get("/info/{video_id}")
async def get_track_info(
    video_id: str,
    youtube: YouTubeService = Depends(get_youtube_service),
):
    """Get detailed track/video information."""
    try:
        info = await youtube.get_video_info(video_id)
        return info
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Could not get track info: {str(e)}"
        )

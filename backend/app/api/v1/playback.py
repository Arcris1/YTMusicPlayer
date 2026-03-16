import asyncio
import logging

from fastapi import APIRouter, Depends, HTTPException, status, Query

from app.services.youtube import get_youtube_service, YouTubeService
from app.schemas.user import StreamInfo
from app.core.security import get_current_user_id, validate_video_id

router = APIRouter(prefix="/playback", tags=["Playback"])
logger = logging.getLogger(__name__)


@router.get("/audio/{video_id}", response_model=StreamInfo)
async def get_audio_stream(
    video_id: str,
    youtube: YouTubeService = Depends(get_youtube_service),
    _user_id: str = Depends(get_current_user_id),
):
    """Get audio stream URL for a video."""
    validate_video_id(video_id)
    try:
        return await youtube.get_audio_stream_url(video_id)
    except asyncio.TimeoutError:
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail="YouTube extraction timed out — please try again",
        )
    except Exception as e:
        logger.warning(f"Audio stream failed for {video_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Could not get audio stream",
        )


@router.get("/video/{video_id}", response_model=StreamInfo)
async def get_video_stream(
    video_id: str,
    quality: str = Query(default="best", pattern="^(best|1080|720|480|360)$"),
    youtube: YouTubeService = Depends(get_youtube_service),
    _user_id: str = Depends(get_current_user_id),
):
    """Get video stream URL for a video."""
    validate_video_id(video_id)
    try:
        return await youtube.get_video_stream_url(video_id, quality)
    except asyncio.TimeoutError:
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail="YouTube extraction timed out — please try again",
        )
    except Exception as e:
        logger.warning(f"Video stream failed for {video_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Could not get video stream",
        )


@router.get("/info/{video_id}")
async def get_track_info(
    video_id: str,
    youtube: YouTubeService = Depends(get_youtube_service),
    _user_id: str = Depends(get_current_user_id),
):
    """Get detailed track/video information."""
    validate_video_id(video_id)
    try:
        return await youtube.get_video_info(video_id)
    except asyncio.TimeoutError:
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail="YouTube extraction timed out — please try again",
        )
    except Exception as e:
        logger.warning(f"Track info failed for {video_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Could not get track info",
        )


@router.get("/related/{video_id}")
async def get_related_tracks(
    video_id: str,
    limit: int = Query(default=20, ge=1, le=50),
    youtube: YouTubeService = Depends(get_youtube_service),
    _user_id: str = Depends(get_current_user_id),
):
    """Get related videos for autoplay functionality."""
    validate_video_id(video_id)
    try:
        related = await youtube.get_related_videos(video_id, limit)
        return {"results": [track.model_dump() for track in related]}
    except asyncio.TimeoutError:
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail="Related videos lookup timed out — please try again",
        )
    except Exception as e:
        logger.warning(f"Related tracks failed for {video_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Could not get related tracks",
        )

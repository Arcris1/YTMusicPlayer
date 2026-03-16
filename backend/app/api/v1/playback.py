import asyncio
import logging

import httpx
from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from fastapi.responses import StreamingResponse

from app.services.youtube import get_youtube_service, YouTubeService
from app.schemas.user import StreamInfo
from app.core.security import get_current_user_id, validate_video_id

router = APIRouter(prefix="/playback", tags=["Playback"])
logger = logging.getLogger(__name__)

# Shared httpx client for proxying streams
_http_client: httpx.AsyncClient | None = None


def _get_http_client() -> httpx.AsyncClient:
    global _http_client
    if _http_client is None or _http_client.is_closed:
        _http_client = httpx.AsyncClient(
            timeout=httpx.Timeout(connect=10, read=30, write=10, pool=10),
            follow_redirects=True,
            limits=httpx.Limits(max_connections=20, max_keepalive_connections=10),
        )
    return _http_client


async def _proxy_stream(
    video_id: str,
    youtube: YouTubeService,
    stream_getter,
    request: Request,
):
    """Proxy a YouTube stream through the backend so clients don't need
    direct access to the IP-locked YouTube URL."""
    try:
        stream_info = await stream_getter
    except asyncio.TimeoutError:
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail="YouTube extraction timed out — please try again",
        )
    except Exception as e:
        logger.warning(f"Stream extraction failed for {video_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Could not get stream",
        )

    if not stream_info.url:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="No stream URL available",
        )

    # Build headers for the upstream YouTube request
    upstream_headers = dict(stream_info.headers) if stream_info.headers else {}

    # Support range requests from client (seeking)
    range_header = request.headers.get("range")
    if range_header:
        upstream_headers["Range"] = range_header

    client = _get_http_client()

    try:
        upstream_resp = await client.send(
            client.build_request("GET", stream_info.url, headers=upstream_headers),
            stream=True,
        )
    except httpx.RequestError as e:
        logger.warning(f"Proxy request failed for {video_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Could not connect to stream",
        )

    # Forward relevant response headers
    response_headers = {}
    for key in ("content-type", "content-length", "accept-ranges", "content-range"):
        val = upstream_resp.headers.get(key)
        if val:
            response_headers[key] = val

    # Allow clients to seek
    response_headers["Accept-Ranges"] = "bytes"

    status_code = upstream_resp.status_code  # 200 or 206 for range

    async def stream_generator():
        try:
            async for chunk in upstream_resp.aiter_bytes(chunk_size=64 * 1024):
                yield chunk
        finally:
            await upstream_resp.aclose()

    return StreamingResponse(
        stream_generator(),
        status_code=status_code,
        headers=response_headers,
    )


# ─── Proxy streaming endpoints ───────────────────────────────────────────────
# These pipe the actual audio/video bytes through the backend so the client
# doesn't need to hit YouTube's IP-locked URLs directly.


@router.get("/stream/audio/{video_id}")
async def stream_audio(
    video_id: str,
    request: Request,
    youtube: YouTubeService = Depends(get_youtube_service),
    _user_id: str = Depends(get_current_user_id),
):
    """Proxy audio stream through backend."""
    validate_video_id(video_id)
    return await _proxy_stream(
        video_id,
        youtube,
        youtube.get_audio_stream_url(video_id),
        request,
    )


@router.get("/stream/video/{video_id}")
async def stream_video(
    video_id: str,
    request: Request,
    quality: str = Query(default="best", pattern="^(best|1080|720|480|360)$"),
    youtube: YouTubeService = Depends(get_youtube_service),
    _user_id: str = Depends(get_current_user_id),
):
    """Proxy video stream through backend."""
    validate_video_id(video_id)
    return await _proxy_stream(
        video_id,
        youtube,
        youtube.get_video_stream_url(video_id, quality),
        request,
    )


# ─── Metadata endpoints (kept as-is) ─────────────────────────────────────────


@router.get("/audio/{video_id}", response_model=StreamInfo)
async def get_audio_stream(
    video_id: str,
    youtube: YouTubeService = Depends(get_youtube_service),
    _user_id: str = Depends(get_current_user_id),
):
    """Get audio stream URL for a video (direct YouTube URL — may not work cross-IP)."""
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
    """Get video stream URL for a video (direct YouTube URL — may not work cross-IP)."""
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

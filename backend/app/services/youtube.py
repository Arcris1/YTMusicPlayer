import yt_dlp
from typing import Optional, List, Dict, Any
import asyncio
from concurrent.futures import ThreadPoolExecutor

from app.config import get_settings
from app.schemas.user import TrackSearchResult, StreamInfo

settings = get_settings()

# Thread pool for yt-dlp operations (blocking I/O)
executor = ThreadPoolExecutor(max_workers=4)


class YouTubeService:
    """Service for interacting with YouTube via yt-dlp."""

    def __init__(self):
        self.base_opts = {
            'quiet': True,
            'no_warnings': True,
            'extract_flat': False,
        }

    def _extract_info(self, url: str, opts: dict) -> dict:
        """Extract video info (blocking operation)."""
        with yt_dlp.YoutubeDL({**self.base_opts, **opts}) as ydl:
            return ydl.extract_info(url, download=False)

    async def search(self, query: str, limit: int = 20) -> List[TrackSearchResult]:
        """Search YouTube for videos matching the query."""
        search_opts = {
            'extract_flat': True,
            'default_search': 'ytsearch',
        }
        
        search_url = f"ytsearch{limit}:{query}"
        
        loop = asyncio.get_event_loop()
        result = await loop.run_in_executor(
            executor, 
            self._extract_info, 
            search_url, 
            search_opts
        )

        tracks = []
        for entry in result.get('entries', []):
            if entry:
                tracks.append(TrackSearchResult(
                    id=entry.get('id', ''),
                    title=entry.get('title', 'Unknown'),
                    artist=entry.get('uploader') or entry.get('channel'),
                    duration=entry.get('duration'),
                    thumbnail=entry.get('thumbnail') or self._get_thumbnail(entry.get('id')),
                    view_count=entry.get('view_count'),
                ))
        
        return tracks

    async def get_video_info(self, video_id: str) -> Dict[str, Any]:
        """Get detailed video information."""
        url = f"https://www.youtube.com/watch?v={video_id}"
        
        loop = asyncio.get_event_loop()
        info = await loop.run_in_executor(
            executor,
            self._extract_info,
            url,
            {}
        )
        
        return {
            'id': info.get('id'),
            'title': info.get('title'),
            'artist': info.get('uploader') or info.get('channel'),
            'duration': info.get('duration'),
            'thumbnail': info.get('thumbnail'),
            'description': info.get('description'),
            'view_count': info.get('view_count'),
        }

    async def get_audio_stream_url(self, video_id: str) -> StreamInfo:
        """Get the best audio stream URL for a video."""
        url = f"https://www.youtube.com/watch?v={video_id}"
        
        audio_opts = {
            'format': settings.YOUTUBE_AUDIO_FORMAT,
        }
        
        loop = asyncio.get_event_loop()
        info = await loop.run_in_executor(
            executor,
            self._extract_info,
            url,
            audio_opts
        )
        
        return StreamInfo(
            url=info.get('url', ''),
            title=info.get('title', 'Unknown'),
            duration=info.get('duration', 0),
            thumbnail=info.get('thumbnail'),
        )

    async def get_video_stream_url(self, video_id: str, quality: str = "best") -> StreamInfo:
        """Get video stream URL (for video playback)."""
        url = f"https://www.youtube.com/watch?v={video_id}"
        
        video_opts = {
            'format': 'best[ext=mp4]/best' if quality == "best" else f'best[height<={quality}][ext=mp4]/best',
        }
        
        loop = asyncio.get_event_loop()
        info = await loop.run_in_executor(
            executor,
            self._extract_info,
            url,
            video_opts
        )
        
        return StreamInfo(
            url=info.get('url', ''),
            title=info.get('title', 'Unknown'),
            duration=info.get('duration', 0),
            thumbnail=info.get('thumbnail'),
            headers=info.get('http_headers'),
        )

    def _get_thumbnail(self, video_id: str) -> str:
        """Get thumbnail URL from video ID."""
        return f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg"


# Singleton instance
youtube_service = YouTubeService()


def get_youtube_service() -> YouTubeService:
    """Get the YouTube service instance."""
    return youtube_service

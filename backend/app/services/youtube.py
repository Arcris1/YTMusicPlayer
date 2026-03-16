import os
import yt_dlp
from typing import Optional, List, Dict, Any
from urllib.parse import quote_plus
import asyncio
import time
import logging
from concurrent.futures import ThreadPoolExecutor

from app.config import get_settings
from app.schemas.user import TrackSearchResult, StreamInfo, YouTubePlaylistResult

settings = get_settings()
logger = logging.getLogger(__name__)

# Thread pool for yt-dlp operations (blocking I/O)
executor = ThreadPoolExecutor(max_workers=8)

# In-memory stream URL cache: { "audio:{video_id}": (StreamInfo, expiry_time), ... }
_stream_cache: Dict[str, tuple] = {}
_CACHE_TTL = 3600  # 1 hour — YouTube URLs expire in ~6h


def _get_cached_stream(key: str) -> Optional[StreamInfo]:
    """Return cached StreamInfo if still valid, else None."""
    entry = _stream_cache.get(key)
    if entry is None:
        return None
    info, expiry = entry
    if time.monotonic() > expiry:
        del _stream_cache[key]
        return None
    return info


def _set_cached_stream(key: str, info: StreamInfo) -> None:
    """Store a StreamInfo in the cache with TTL."""
    _stream_cache[key] = (info, time.monotonic() + _CACHE_TTL)
    # Evict old entries when cache grows too large
    if len(_stream_cache) > 200:
        now = time.monotonic()
        expired = [k for k, (_, exp) in _stream_cache.items() if now > exp]
        for k in expired:
            del _stream_cache[k]


class YouTubeService:
    """Service for interacting with YouTube via yt-dlp."""

    # Path to Netscape-format cookies.txt (exported from a logged-in browser).
    # Set via YOUTUBE_COOKIES_FILE env var or place at /app/cookies.txt in Docker.
    COOKIES_FILE = os.environ.get('YOUTUBE_COOKIES_FILE', '/app/cookies.txt')

    def __init__(self):
        self.base_opts = {
            'quiet': True,
            'no_warnings': True,
            'extract_flat': False,
            'socket_timeout': 10,
            'retries': 3,
            'extractor_retries': 2,
            'geo_bypass': True,
            # Required for yt-dlp to use deno for YouTube JS signature solving
            'remote_components': ['ejs:github'],
        }
        # Use cookies file if it exists (needed for VPS IPs flagged by YouTube)
        if os.path.isfile(self.COOKIES_FILE):
            self.base_opts['cookiefile'] = self.COOKIES_FILE
            logger.info(f"Using YouTube cookies from {self.COOKIES_FILE}")
        else:
            logger.warning(
                f"No cookies file at {self.COOKIES_FILE} — YouTube may block requests. "
                "Export cookies.txt from a logged-in browser and place it there."
            )

    def _extract_info(self, url: str, opts: dict) -> dict:
        """Extract video info (blocking operation)."""
        with yt_dlp.YoutubeDL({**self.base_opts, **opts}) as ydl:
            return ydl.extract_info(url, download=False)

    async def _run_extraction(self, url: str, opts: dict, timeout: float = 15.0) -> dict:
        """Run yt-dlp extraction in executor with timeout."""
        loop = asyncio.get_event_loop()
        return await asyncio.wait_for(
            loop.run_in_executor(executor, self._extract_info, url, opts),
            timeout=timeout,
        )

    async def search(self, query: str, limit: int = 20) -> List[TrackSearchResult]:
        """Search YouTube for videos matching the query."""
        search_opts = {
            'extract_flat': True,
            'default_search': 'ytsearch',
        }

        search_url = f"ytsearch{limit}:{query}"
        result = await self._run_extraction(search_url, search_opts, timeout=15.0)

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

    async def search_playlists(self, query: str, limit: int = 20) -> List[YouTubePlaylistResult]:
        """Search YouTube for playlists matching the query."""
        search_opts = {
            'extract_flat': True,
            'default_search': 'ytsearch',
        }

        # sp=EgIQAw%3D%3D filters YouTube results to playlists only
        search_url = f"https://www.youtube.com/results?search_query={quote_plus(query)}&sp=EgIQAw%3D%3D"
        result = await self._run_extraction(search_url, search_opts, timeout=30.0)

        playlists = []
        for entry in result.get('entries', [])[:limit]:
            if not entry:
                continue
            playlists.append(YouTubePlaylistResult(
                id=entry.get('id', ''),
                title=entry.get('title', 'Unknown Playlist'),
                channel=entry.get('uploader') or entry.get('channel'),
                video_count=entry.get('playlist_count') or entry.get('n_entries'),
                thumbnail=entry.get('thumbnails', [{}])[-1].get('url') if entry.get('thumbnails') else None,
                url=entry.get('url') or entry.get('webpage_url'),
            ))

        return playlists

    async def get_playlist_tracks(self, playlist_id: str) -> Dict[str, Any]:
        """Fetch tracks from a YouTube playlist."""
        url = f"https://www.youtube.com/playlist?list={playlist_id}"

        playlist_opts = {
            'extract_flat': 'in_playlist',
            'quiet': True,
            'no_warnings': True,
        }

        info = await self._run_extraction(url, playlist_opts, timeout=20.0)

        tracks = []
        for entry in info.get('entries', []):
            if not entry:
                continue
            tracks.append(TrackSearchResult(
                id=entry.get('id', ''),
                title=entry.get('title', 'Unknown'),
                artist=entry.get('uploader') or entry.get('channel'),
                duration=entry.get('duration'),
                thumbnail=entry.get('thumbnails', [{}])[-1].get('url') if entry.get('thumbnails') else self._get_thumbnail(entry.get('id', '')),
                view_count=entry.get('view_count'),
            ))

        return {
            'playlist_id': playlist_id,
            'title': info.get('title', 'Unknown Playlist'),
            'channel': info.get('uploader') or info.get('channel'),
            'thumbnail': info.get('thumbnails', [{}])[-1].get('url') if info.get('thumbnails') else None,
            'video_count': len(tracks),
            'tracks': tracks,
        }

    async def get_video_info(self, video_id: str) -> Dict[str, Any]:
        """Get detailed video information."""
        url = f"https://www.youtube.com/watch?v={video_id}"

        info = await self._run_extraction(url, {}, timeout=12.0)

        return {
            'id': info.get('id'),
            'title': info.get('title'),
            'artist': info.get('uploader') or info.get('channel'),
            'duration': info.get('duration'),
            'thumbnail': info.get('thumbnail'),
            'description': info.get('description'),
            'view_count': info.get('view_count'),
        }

    async def get_related_videos(self, video_id: str, limit: int = 20) -> List[TrackSearchResult]:
        """Get related videos with smart variety - focuses on genre/artist, not song title repeats."""
        import random

        url = f"https://www.youtube.com/watch?v={video_id}"

        # Extract video info using flat extraction (faster)
        opts = {
            'extract_flat': 'in_playlist',
        }

        info = await self._run_extraction(url, opts, timeout=12.0)

        title = info.get('title', '')
        artist = info.get('uploader', '') or info.get('channel', '')

        # Clean up artist name (remove "- Topic", "VEVO", etc.)
        artist_clean = artist.replace(' - Topic', '').replace('VEVO', '').strip()

        # Build variety-focused search queries
        variety_queries = []

        # 1. Artist's other songs (high priority)
        if artist_clean:
            variety_queries.append(f"{artist_clean} songs")
            variety_queries.append(f"{artist_clean} playlist")
            variety_queries.append(f"best of {artist_clean}")

        # 2. Similar artists/genre (extract genre hints from title)
        genre_hints = []
        genre_keywords = ['love', 'ballad', 'rock', 'pop', 'acoustic', 'chill', 'sad',
                         'happy', 'dance', 'romantic', 'opm', 'indie', 'jazz', 'rnb',
                         'hiphop', 'rap', 'country', 'folk', 'edm', 'kpop', 'jpop']

        title_lower = title.lower()
        for keyword in genre_keywords:
            if keyword in title_lower:
                genre_hints.append(keyword)

        if 'love' in title_lower or 'heart' in title_lower:
            variety_queries.append("love songs playlist")
            variety_queries.append("romantic songs")

        if genre_hints:
            variety_queries.append(f"{genre_hints[0]} music playlist")

        # 3. "Similar to" / mix queries
        variety_queries.append(f"songs like {artist_clean}")
        variety_queries.append(f"{artist_clean} mix")
        variety_queries.append("trending songs")

        # Fetch tracks from 2 random queries (down from 5) for speed
        all_tracks = []
        seen_ids = {video_id}  # Don't include original
        seen_titles = set()  # Avoid same song different versions

        # Extract core title words to avoid repeats
        title_words = set(title.lower().split()[:4])

        # Shuffle queries for randomness
        random.shuffle(variety_queries)

        for query in variety_queries[:2]:  # Use top 2 random queries (was 5)
            try:
                results = await self.search(query, limit=15)
                for track in results:
                    if track.id in seen_ids:
                        continue

                    # Check if this is basically the same song (cover/remix)
                    track_title_lower = track.title.lower()
                    track_words = set(track_title_lower.split()[:4])

                    # If too many words overlap with original title, skip
                    overlap = len(title_words & track_words)
                    if overlap >= 3:
                        continue

                    # Also check for exact title matches (normalized)
                    if any(existing.lower() == track_title_lower for existing in seen_titles):
                        continue

                    seen_ids.add(track.id)
                    seen_titles.add(track.title)
                    all_tracks.append(track)

            except Exception as e:
                logger.warning(f"Related query '{query}' failed: {e}")
                continue

        # Shuffle results for variety
        random.shuffle(all_tracks)

        result = all_tracks[:limit]
        logger.debug(f"Generated {len(result)} varied tracks for '{title}' by '{artist_clean}'")

        return result

    async def get_audio_stream_url(self, video_id: str) -> StreamInfo:
        """Get the best audio stream URL for a video (cached)."""
        cache_key = f"audio:{video_id}"
        cached = _get_cached_stream(cache_key)
        if cached is not None:
            return cached

        url = f"https://www.youtube.com/watch?v={video_id}"

        audio_opts = {
            'format': settings.YOUTUBE_AUDIO_FORMAT,
        }

        info = await self._run_extraction(url, audio_opts, timeout=15.0)

        stream_info = StreamInfo(
            url=info.get('url', ''),
            title=info.get('title', 'Unknown'),
            duration=info.get('duration', 0),
            thumbnail=info.get('thumbnail'),
            headers=info.get('http_headers'),
        )
        _set_cached_stream(cache_key, stream_info)
        return stream_info

    async def get_video_stream_url(self, video_id: str, quality: str = "best") -> StreamInfo:
        """Get video stream URL (for video playback) (cached)."""
        cache_key = f"video:{quality}:{video_id}"
        cached = _get_cached_stream(cache_key)
        if cached is not None:
            return cached

        url = f"https://www.youtube.com/watch?v={video_id}"

        # Use a progressive (combined audio+video) format to ensure sound.
        # YouTube is deprecating progressive formats; fallback chains ensure we
        # always get audio: mp4 progressive → any progressive → best single URL.
        if quality == "best":
            fmt = 'best[ext=mp4][acodec!=none]/best[acodec!=none]/best'
        else:
            fmt = f'best[height<={quality}][ext=mp4][acodec!=none]/best[height<={quality}][acodec!=none]/best[acodec!=none]/best'

        video_opts = {
            'format': fmt,
        }

        info = await self._run_extraction(url, video_opts, timeout=15.0)

        stream_info = StreamInfo(
            url=info.get('url', ''),
            title=info.get('title', 'Unknown'),
            duration=info.get('duration', 0),
            thumbnail=info.get('thumbnail'),
            headers=info.get('http_headers'),
        )
        _set_cached_stream(cache_key, stream_info)
        return stream_info

    def _get_thumbnail(self, video_id: str) -> str:
        """Get thumbnail URL from video ID."""
        return f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg"


# Singleton instance
youtube_service = YouTubeService()


def get_youtube_service() -> YouTubeService:
    """Get the YouTube service instance."""
    return youtube_service

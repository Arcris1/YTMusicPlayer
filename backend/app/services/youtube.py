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

    async def get_related_videos(self, video_id: str, limit: int = 20) -> List[TrackSearchResult]:
        """Get related videos with smart variety - focuses on genre/artist, not song title repeats."""
        import random
        
        url = f"https://www.youtube.com/watch?v={video_id}"
        
        # Extract video info
        opts = {
            'extract_flat': 'in_playlist',
        }
        
        loop = asyncio.get_event_loop()
        info = await loop.run_in_executor(
            executor,
            self._extract_info,
            url,
            opts
        )
        
        title = info.get('title', '')
        artist = info.get('uploader', '') or info.get('channel', '')
        
        # Clean up artist name (remove "- Topic", "VEVO", etc.)
        artist_clean = artist.replace(' - Topic', '').replace('VEVO', '').strip()
        
        # Build variety-focused search queries
        # The key is to NOT search for the exact song title repeatedly
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
        
        # Add generic genre queries
        if 'love' in title_lower or 'heart' in title_lower:
            variety_queries.append("love songs playlist")
            variety_queries.append("romantic songs")
        
        if genre_hints:
            variety_queries.append(f"{genre_hints[0]} music playlist")
        
        # 3. "Similar to" searches
        variety_queries.append(f"songs like {artist_clean}")
        variety_queries.append(f"{artist_clean} similar artists")
        
        # 4. Mix/radio style
        variety_queries.append(f"{artist_clean} mix")
        variety_queries.append("trending songs")
        
        # Fetch tracks from multiple queries for variety
        all_tracks = []
        seen_ids = {video_id}  # Don't include original
        seen_titles = set()  # Avoid same song different versions
        
        # Extract core title words to avoid repeats (e.g., "close to you" variants)
        title_words = set(title.lower().split()[:4])  # First 4 words of title
        
        # Shuffle queries for randomness
        random.shuffle(variety_queries)
        
        for query in variety_queries[:5]:  # Use top 5 random queries
            try:
                results = await self.search(query, limit=8)
                for track in results:
                    if track.id in seen_ids:
                        continue
                    
                    # Check if this is basically the same song (cover/remix)
                    track_title_lower = track.title.lower()
                    track_words = set(track_title_lower.split()[:4])
                    
                    # If too many words overlap with original title, skip (likely same song)
                    overlap = len(title_words & track_words)
                    if overlap >= 3:  # 3+ matching words = probably same song
                        continue
                    
                    # Also check for exact title matches (normalized)
                    if any(existing.lower() == track_title_lower for existing in seen_titles):
                        continue
                    
                    seen_ids.add(track.id)
                    seen_titles.add(track.title)
                    all_tracks.append(track)
                    
            except Exception as e:
                print(f"DEBUG: Query '{query}' failed: {e}")
                continue
        
        # Shuffle results for variety
        random.shuffle(all_tracks)
        
        # Limit results
        result = all_tracks[:limit]
        
        print(f"DEBUG: Generated {len(result)} varied tracks for '{title}' by '{artist_clean}'")
        
        return result

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

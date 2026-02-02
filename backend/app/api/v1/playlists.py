from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import List

import logging
from app.db.database import get_db
from app.models.user import Playlist, Track, playlist_tracks
from app.schemas.user import (
    PlaylistCreate,
    PlaylistUpdate,
    PlaylistResponse,
    PlaylistDetailResponse,
    AddTrackToPlaylist,
    TrackResponse,
)
from app.core.security import get_current_user_id
from app.services.youtube import get_youtube_service, YouTubeService

router = APIRouter(prefix="/playlists", tags=["Playlists"])


@router.get("", response_model=List[PlaylistResponse])
async def get_user_playlists(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Get all playlists for the current user."""
    result = await db.execute(
        select(Playlist).where(Playlist.owner_id == user_id)
    )
    playlists = result.scalars().all()
    
    # Add track count to each playlist
    playlist_responses = []
    for playlist in playlists:
        count_result = await db.execute(
            select(func.count()).select_from(playlist_tracks).where(
                playlist_tracks.c.playlist_id == playlist.id
            )
        )
        track_count = count_result.scalar() or 0
        
        playlist_responses.append(PlaylistResponse(
            id=playlist.id,
            name=playlist.name,
            description=playlist.description,
            cover_image=playlist.cover_image,
            is_public=playlist.is_public,
            owner_id=playlist.owner_id,
            created_at=playlist.created_at,
            track_count=track_count,
        ))
    
    return playlist_responses


@router.post("", response_model=PlaylistResponse, status_code=status.HTTP_201_CREATED)
async def create_playlist(
    playlist_data: PlaylistCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Create a new playlist."""
    playlist = Playlist(
        name=playlist_data.name,
        description=playlist_data.description,
        is_public=playlist_data.is_public,
        owner_id=user_id,
    )
    db.add(playlist)
    await db.commit()
    await db.refresh(playlist)
    
    return PlaylistResponse(
        id=playlist.id,
        name=playlist.name,
        description=playlist.description,
        cover_image=playlist.cover_image,
        is_public=playlist.is_public,
        owner_id=playlist.owner_id,
        created_at=playlist.created_at,
        track_count=0,
    )


@router.get("/{playlist_id}", response_model=PlaylistDetailResponse)
async def get_playlist(
    playlist_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Get a playlist with its tracks."""
    result = await db.execute(
        select(Playlist).where(Playlist.id == playlist_id)
    )
    playlist = result.scalar_one_or_none()
    
    if not playlist:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Playlist not found"
        )
    
    if playlist.owner_id != user_id and not playlist.is_public:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to view this playlist"
        )
    
    # Get tracks in playlist
    tracks_result = await db.execute(
        select(Track)
        .join(playlist_tracks)
        .where(playlist_tracks.c.playlist_id == playlist_id)
        .order_by(playlist_tracks.c.position)
    )
    tracks = tracks_result.scalars().all()
    
    return PlaylistDetailResponse(
        id=playlist.id,
        name=playlist.name,
        description=playlist.description,
        cover_image=playlist.cover_image,
        is_public=playlist.is_public,
        owner_id=playlist.owner_id,
        created_at=playlist.created_at,
        track_count=len(tracks),
        tracks=[TrackResponse.model_validate(t) for t in tracks],
    )


@router.put("/{playlist_id}", response_model=PlaylistResponse)
async def update_playlist(
    playlist_id: str,
    playlist_data: PlaylistUpdate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Update a playlist."""
    result = await db.execute(
        select(Playlist).where(Playlist.id == playlist_id, Playlist.owner_id == user_id)
    )
    playlist = result.scalar_one_or_none()
    
    if not playlist:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Playlist not found"
        )
    
    if playlist_data.name is not None:
        playlist.name = playlist_data.name
    if playlist_data.description is not None:
        playlist.description = playlist_data.description
    if playlist_data.is_public is not None:
        playlist.is_public = playlist_data.is_public
    
    await db.commit()
    await db.refresh(playlist)
    
    return playlist


@router.delete("/{playlist_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_playlist(
    playlist_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Delete a playlist."""
    result = await db.execute(
        select(Playlist).where(Playlist.id == playlist_id, Playlist.owner_id == user_id)
    )
    playlist = result.scalar_one_or_none()
    
    if not playlist:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Playlist not found"
        )
    
    await db.delete(playlist)
    await db.commit()


@router.post("/{playlist_id}/tracks", status_code=status.HTTP_201_CREATED)
async def add_track_to_playlist(
    playlist_id: str,
    track_data: AddTrackToPlaylist,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
    youtube: YouTubeService = Depends(get_youtube_service),
):
    """Add a track to a playlist."""
    try:
        # Check playlist exists and user owns it
        result = await db.execute(
            select(Playlist).where(Playlist.id == playlist_id, Playlist.owner_id == user_id)
        )
        playlist = result.scalar_one_or_none()
        
        if not playlist:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Playlist not found"
            )
        
        # Check if track exists in database, if not fetch from YouTube
        track_result = await db.execute(select(Track).where(Track.id == track_data.track_id))
        track = track_result.scalar_one_or_none()
        
        if not track:
            # Fetch track info from YouTube
            info = await youtube.get_video_info(track_data.track_id)
            track = Track(
                id=info['id'],
                title=info['title'],
                artist=info.get('artist'),
                duration=info.get('duration'),
                thumbnail=info.get('thumbnail'),
            )
            db.add(track)
            db.add(track)
            await db.flush()
        
        # Check if track is already in playlist
        exists_result = await db.execute(
            select(playlist_tracks).where(
                playlist_tracks.c.playlist_id == playlist_id,
                playlist_tracks.c.track_id == track.id
            )
        )
        if exists_result.first():
            return {"message": "Track already in playlist"}

        # Get current max position
        pos_result = await db.execute(
            select(func.max(playlist_tracks.c.position))
            .where(playlist_tracks.c.playlist_id == playlist_id)
        )
        max_pos = pos_result.scalar() or -1
        position = track_data.position if track_data.position is not None else max_pos + 1
        
        # Add track to playlist
        await db.execute(
            playlist_tracks.insert().values(
                playlist_id=playlist_id,
                track_id=track.id,
                position=position,
            )
        )
        await db.commit()
        
        return {"message": "Track added to playlist"}

    except HTTPException:
        raise
    except Exception as e:
        import traceback
        logging.getLogger(__name__).error(f"Error adding track: {str(e)}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to add track: {str(e)}"
        )


@router.delete("/{playlist_id}/tracks/{track_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_track_from_playlist(
    playlist_id: str,
    track_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Remove a track from a playlist."""
    # Check playlist exists and user owns it
    result = await db.execute(
        select(Playlist).where(Playlist.id == playlist_id, Playlist.owner_id == user_id)
    )
    playlist = result.scalar_one_or_none()
    
    if not playlist:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Playlist not found"
        )
    
    await db.execute(
        playlist_tracks.delete().where(
            playlist_tracks.c.playlist_id == playlist_id,
            playlist_tracks.c.track_id == track_id,
        )
    )
    await db.commit()

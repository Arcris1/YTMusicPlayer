from sqlalchemy import Column, String, DateTime, Boolean, ForeignKey, Table, Integer
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import uuid

from app.db.database import Base


# Association table for playlist tracks
playlist_tracks = Table(
    "playlist_tracks",
    Base.metadata,
    Column("playlist_id", String, ForeignKey("playlists.id"), primary_key=True),
    Column("track_id", String, ForeignKey("tracks.id"), primary_key=True),
    Column("position", Integer, nullable=False, default=0),
    Column("added_at", DateTime(timezone=True), server_default=func.now()),
)


class User(Base):
    """User model for authentication and personalization."""
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    email = Column(String, unique=True, index=True, nullable=False)
    username = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    playlists = relationship("Playlist", back_populates="owner", cascade="all, delete-orphan")
    liked_tracks = relationship("LikedTrack", back_populates="user", cascade="all, delete-orphan")


class Playlist(Base):
    """User-created playlist."""
    __tablename__ = "playlists"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String, nullable=False)
    description = Column(String, nullable=True)
    cover_image = Column(String, nullable=True)
    is_public = Column(Boolean, default=False)
    owner_id = Column(String, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    owner = relationship("User", back_populates="playlists")
    tracks = relationship("Track", secondary=playlist_tracks, back_populates="playlists")


class Track(Base):
    """Cached track metadata from YouTube."""
    __tablename__ = "tracks"

    id = Column(String, primary_key=True)  # YouTube video ID
    title = Column(String, nullable=False)
    artist = Column(String, nullable=True)
    duration = Column(Integer, nullable=True)  # Duration in seconds
    thumbnail = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    playlists = relationship("Playlist", secondary=playlist_tracks, back_populates="tracks")


class LikedTrack(Base):
    """User's liked tracks."""
    __tablename__ = "liked_tracks"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    track_id = Column(String, ForeignKey("tracks.id"), nullable=False)
    liked_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    user = relationship("User", back_populates="liked_tracks")

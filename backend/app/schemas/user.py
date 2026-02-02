from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List
from datetime import datetime


# User Schemas
class UserCreate(BaseModel):
    email: EmailStr
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=8)


class UserResponse(BaseModel):
    id: str
    email: str
    username: str
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class UserLogin(BaseModel):
    email: EmailStr
    password: str


# Token Schemas
class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class TokenRefresh(BaseModel):
    refresh_token: str


# Track Schemas
class TrackBase(BaseModel):
    id: str  # YouTube video ID
    title: str
    artist: Optional[str] = None
    duration: Optional[int] = None
    thumbnail: Optional[str] = None


class TrackResponse(TrackBase):
    class Config:
        from_attributes = True


class TrackSearchResult(BaseModel):
    id: str
    title: str
    artist: Optional[str] = None
    duration: Optional[int] = None
    thumbnail: Optional[str] = None
    view_count: Optional[int] = None


# Playlist Schemas
class PlaylistCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = None
    is_public: bool = False


class PlaylistUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = None
    is_public: Optional[bool] = None


class PlaylistResponse(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    cover_image: Optional[str] = None
    is_public: bool
    owner_id: str
    created_at: datetime
    track_count: int = 0

    class Config:
        from_attributes = True


class PlaylistDetailResponse(PlaylistResponse):
    tracks: List[TrackResponse] = []


class AddTrackToPlaylist(BaseModel):
    track_id: str
    position: Optional[int] = None


# Search Schemas
class SearchQuery(BaseModel):
    query: str = Field(..., min_length=1, max_length=200)
    limit: int = Field(default=20, ge=1, le=50)


class SearchResponse(BaseModel):
    query: str
    results: List[TrackSearchResult]
    total: int


# Stream Schemas
class StreamInfo(BaseModel):
    url: str
    title: str
    duration: int
    thumbnail: Optional[str] = None
    expires_at: Optional[datetime] = None
    headers: Optional[dict] = None

import 'track.dart';

/// Playlist model
class Playlist {
  final String id;
  final String name;
  final String? description;
  final String? coverImage;
  final bool isPublic;
  final String ownerId;
  final DateTime createdAt;
  final int trackCount;
  final List<Track>? tracks;

  const Playlist({
    required this.id,
    required this.name,
    this.description,
    this.coverImage,
    required this.isPublic,
    required this.ownerId,
    required this.createdAt,
    this.trackCount = 0,
    this.tracks,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      coverImage: json['cover_image'] as String?,
      isPublic: json['is_public'] as bool? ?? false,
      ownerId: json['owner_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      trackCount: json['track_count'] as int? ?? 0,
      tracks: json['tracks'] != null
          ? (json['tracks'] as List)
              .map((t) => Track.fromJson(t))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'cover_image': coverImage,
      'is_public': isPublic,
      'owner_id': ownerId,
      'created_at': createdAt.toIso8601String(),
      'track_count': trackCount,
    };
  }
}

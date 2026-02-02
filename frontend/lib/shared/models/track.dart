/// Track model representing a YouTube video/audio track
class Track {
  final String id;
  final String title;
  final String? artist;
  final int? duration;
  final String? thumbnail;
  final int? viewCount;

  const Track({
    required this.id,
    required this.title,
    this.artist,
    this.duration,
    this.thumbnail,
    this.viewCount,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String?,
      duration: json['duration'] as int?,
      thumbnail: json['thumbnail'] as String?,
      viewCount: json['view_count'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'duration': duration,
      'thumbnail': thumbnail,
      'view_count': viewCount,
    };
  }

  /// Get formatted duration string (e.g., "3:45")
  String get durationFormatted {
    if (duration == null) return '--:--';
    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get thumbnail URL (fallback to YouTube default)
  String get thumbnailUrl {
    return thumbnail ?? 'https://img.youtube.com/vi/$id/hqdefault.jpg';
  }

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    int? duration,
    String? thumbnail,
    int? viewCount,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      duration: duration ?? this.duration,
      thumbnail: thumbnail ?? this.thumbnail,
      viewCount: viewCount ?? this.viewCount,
    );
  }
}

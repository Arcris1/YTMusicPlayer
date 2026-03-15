/// Model representing a YouTube playlist from search results
class YouTubePlaylist {
  final String id;
  final String title;
  final String? channel;
  final int? videoCount;
  final String? thumbnail;
  final String? url;

  const YouTubePlaylist({
    required this.id,
    required this.title,
    this.channel,
    this.videoCount,
    this.thumbnail,
    this.url,
  });

  factory YouTubePlaylist.fromJson(Map<String, dynamic> json) {
    return YouTubePlaylist(
      id: json['id'] as String,
      title: json['title'] as String,
      channel: json['channel'] as String?,
      videoCount: json['video_count'] as int?,
      thumbnail: json['thumbnail'] as String?,
      url: json['url'] as String?,
    );
  }
}

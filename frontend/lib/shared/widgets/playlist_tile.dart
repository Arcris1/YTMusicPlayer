import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../config/theme.dart';
import '../models/youtube_playlist.dart';

/// Reusable playlist tile widget for YouTube playlist search results
class PlaylistTile extends StatelessWidget {
  final YouTubePlaylist playlist;
  final VoidCallback? onTap;

  const PlaylistTile({
    super.key,
    required this.playlist,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Thumbnail with playlist badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: playlist.thumbnail != null
                      ? CachedNetworkImage(
                          imageUrl: playlist.thumbnail!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: AppTheme.cardDark,
                            highlightColor: AppTheme.cardHover,
                            child: Container(
                              width: 56,
                              height: 56,
                              color: AppTheme.cardDark,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 56,
                            height: 56,
                            color: AppTheme.cardDark,
                            child: const Icon(Icons.queue_music,
                                color: AppTheme.textSecondary),
                          ),
                        )
                      : Container(
                          width: 56,
                          height: 56,
                          color: AppTheme.cardDark,
                          child: const Icon(Icons.queue_music,
                              color: AppTheme.textSecondary),
                        ),
                ),
                // Playlist icon badge
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Icon(
                      Icons.playlist_play,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Playlist info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (playlist.channel != null) playlist.channel!,
                      if (playlist.videoCount != null)
                        '${playlist.videoCount} videos',
                    ].join(' \u2022 '),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppTheme.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

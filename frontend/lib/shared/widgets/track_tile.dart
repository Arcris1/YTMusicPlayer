import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../config/theme.dart';
import '../models/track.dart';

/// Reusable track tile widget
class TrackTile extends StatelessWidget {
  final Track track;
  final VoidCallback? onTap;
  final VoidCallback? onMorePressed;
  final bool isPlaying;
  final bool showDuration;

  const TrackTile({
    super.key,
    required this.track,
    this.onTap,
    this.onMorePressed,
    this.isPlaying = false,
    this.showDuration = true,
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
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: track.thumbnailUrl,
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
                  child: const Icon(Icons.music_note, color: AppTheme.textSecondary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Track info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: TextStyle(
                      color: isPlaying ? AppTheme.primaryGreen : AppTheme.textPrimary,
                      fontWeight: isPlaying ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artist ?? 'Unknown Artist',
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
            // Duration
            if (showDuration) ...[
              const SizedBox(width: 8),
              Text(
                track.durationFormatted,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
            // More button
            if (onMorePressed != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
                onPressed: onMorePressed,
                iconSize: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

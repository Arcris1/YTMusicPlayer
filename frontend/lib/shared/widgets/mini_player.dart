import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../core/providers/media_player_provider.dart';
import '../../features/library/providers/playlist_provider.dart';
import '../../shared/models/track.dart';

/// Mini player bar that appears at bottom of screen
class MiniPlayer extends ConsumerStatefulWidget {
  final VoidCallback onTap;
  
  const MiniPlayer({
    super.key,
    required this.onTap,
  });

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer> {
  bool _showVolume = false;

  void _showAddToPlaylistSheet(BuildContext parentContext, Track track) {
    showModalBottomSheet(
      context: parentContext,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final playlistState = ref.watch(playlistProvider);

            // Force load if empty
            if (!playlistState.isLoading && playlistState.playlists.isEmpty) {
              Future.microtask(() {
                ref.read(playlistProvider.notifier).loadPlaylists();
              });
            }

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Add to Playlist',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  if (playlistState.isLoading)
                     const Padding(
                       padding: EdgeInsets.all(32),
                       child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                     )
                  else if (playlistState.playlists.isEmpty)
                     Padding(
                       padding: const EdgeInsets.all(32),
                       child: Column(
                         children: [
                           const Text(
                             'No playlists yet',
                             style: TextStyle(color: Colors.white54),
                           ),
                           TextButton(
                             onPressed: () {
                               Navigator.pop(sheetContext);
                             },
                             child: const Text('Cancel'),
                           )
                         ],
                       ),
                     )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: playlistState.playlists.length,
                        itemBuilder: (context, index) {
                          final playlist = playlistState.playlists[index];
                          return Material(
                            color: Colors.transparent,
                            child: ListTile(
                              leading: Container(
                                width: 48,
                                height: 48,
                                color: Colors.grey.shade800,
                                child: const Icon(Icons.music_note, color: Colors.white54),
                              ),
                              title: Text(
                                playlist.name,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                '${playlist.trackCount} songs',
                                style: const TextStyle(color: Colors.white54),
                              ),
                              onTap: () async {
                                try {
                                  Navigator.pop(sheetContext);
                                  final result = await ref.read(playlistProvider.notifier)
                                      .addTrackToPlaylist(playlist.id, track.id);
                                  
                                  if (parentContext.mounted) {
                                    ScaffoldMessenger.of(parentContext).hideCurrentSnackBar();
                                    ScaffoldMessenger.of(parentContext).showSnackBar(
                                      SnackBar(
                                        content: Text(result ?? 'Failed to add to playlist'),
                                        backgroundColor: result != null ? AppTheme.spotifyBlack : Colors.red,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  print('Error adding to playlist: $e');
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(mediaPlayerControllerProvider);
    
    // Don't show if no track
    if (!playerState.hasTrack) {
      return const SizedBox.shrink();
    }

    final track = playerState.currentTrack!;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          border: Border(
            top: BorderSide(
              color: Colors.grey.shade800,
              width: 0.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: playerState.progress,
              backgroundColor: Colors.grey.shade800,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
              minHeight: 2,
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: track.thumbnailUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 48,
                          height: 48,
                          color: AppTheme.cardHover,
                          child: const Icon(
                            Icons.music_note,
                            color: AppTheme.textSecondary,
                            size: 24,
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 48,
                          height: 48,
                          color: AppTheme.cardHover,
                          child: const Icon(
                            Icons.music_note,
                            color: AppTheme.textSecondary,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Track info
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artist ?? '',
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
                    // Loading indicator or controls
                    if (playerState.isLoading)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryGreen,
                        ),
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Volume Controls (Animated)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: _showVolume ? 80 : 0, // Smaller width for MiniPlayer
                                margin: EdgeInsets.only(right: _showVolume ? 8 : 0),
                                child: _showVolume 
                                  ? SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor: AppTheme.primaryGreen,
                                        inactiveTrackColor: Colors.grey,
                                        thumbColor: Colors.white,
                                        trackHeight: 2,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5), // Smaller thumb
                                        overlayShape: SliderComponentShape.noOverlay,
                                      ),
                                      child: Slider(
                                        value: playerState.volume.clamp(0.0, 100.0),
                                        min: 0.0,
                                        max: 100.0,
                                        onChanged: (value) {
                                          ref.read(mediaPlayerControllerProvider.notifier)
                                              .setVolume(value);
                                        },
                                      ),
                                    )
                                  : null,
                              ),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                                icon: Icon(
                                  playerState.volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                  color: _showVolume ? AppTheme.primaryGreen : AppTheme.textSecondary,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showVolume = !_showVolume;
                                  });
                                },
                              ),
                            ],
                          ),

                          // Add to Playlist Button
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                            icon: const Icon(
                              Icons.playlist_add_rounded,
                              color: AppTheme.textSecondary,
                              size: 24,
                            ),
                            onPressed: () {
                              _showAddToPlaylistSheet(context, track);
                            },
                          ),

                          // Play/Pause button
                          IconButton(
                            icon: Icon(
                              playerState.isPlaying 
                                  ? Icons.pause_rounded 
                                  : Icons.play_arrow_rounded,
                              color: AppTheme.textPrimary,
                              size: 32,
                            ),
                            onPressed: () {
                              ref.read(mediaPlayerControllerProvider.notifier)
                                  .togglePlayPause();
                            },
                          ),
                          // Skip Next button
                          IconButton(
                            icon: Icon(
                              Icons.skip_next_rounded,
                              color: playerState.hasNext 
                                  ? AppTheme.textPrimary 
                                  : AppTheme.textSecondary.withOpacity(0.3),
                              size: 32,
                            ),
                            onPressed: playerState.hasNext 
                                ? () => ref.read(mediaPlayerControllerProvider.notifier).skipToNext()
                                : null,
                          ),
                          // Close button
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppTheme.textSecondary,
                              size: 24,
                            ),
                            onPressed: () {
                              ref.read(mediaPlayerControllerProvider.notifier)
                                  .stop();
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

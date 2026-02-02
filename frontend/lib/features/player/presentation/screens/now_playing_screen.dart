import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../config/theme.dart';
import '../../../../core/providers/media_player_provider.dart';
import '../../../../shared/models/track.dart';
import '../../../library/providers/playlist_provider.dart';

/// Full-screen Now Playing screen with video and controls
class NowPlayingScreen extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const NowPlayingScreen({
    super.key,
    required this.onClose,
  });

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  bool _isFullscreen = false;
  bool _showVolume = false;

  @override
  void initState() {
    super.initState();
    
    // Slide up animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  void _handleClose() {
    _animationController.reverse().then((_) {
      widget.onClose();
    });
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

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
            
            // Debug print
            print('Playlist Sheet: isLoading=${playlistState.isLoading}, count=${playlistState.playlists.length}');

            // Force load if empty
            if (!playlistState.isLoading && playlistState.playlists.isEmpty) {
              Future.microtask(() {
                print('Playlist list empty, triggering loadPlaylists()...');
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
                               // TODO: Show create dialog
                               Navigator.pop(sheetContext);
                             },
                             child: const Text('Create Playlist'),
                           )
                         ],
                       ),
                     )
                  else
                    // Use Flexible instead of Expanded for MainAxisSize.min
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: playlistState.playlists.length,
                        itemBuilder: (context, index) {
                          final playlist = playlistState.playlists[index];
                          return Material( // Ensure hit test works
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
                                  debugPrint('User tapped playlist: ${playlist.name} (${playlist.id})');
                                  Navigator.pop(sheetContext);
                                  
                                  debugPrint('Adding track ${track.id} to playlist ${playlist.id}...');
                                  final result = await ref.read(playlistProvider.notifier)
                                      .addTrackToPlaylist(playlist.id, track.id);
                                  debugPrint('Add result: $result');
                                  
                                  if (parentContext.mounted) {
                                    ScaffoldMessenger.of(parentContext).hideCurrentSnackBar();
                                    ScaffoldMessenger.of(parentContext).showSnackBar(
                                      SnackBar(
                                        content: Text(result ?? 'Failed to add to playlist'),
                                        backgroundColor: result != null ? AppTheme.spotifyBlack : Colors.red,
                                      ),
                                    );
                                  }
                                } catch (e, stack) {
                                  debugPrint('CRASH in onTap: $e');
                                  debugPrint(stack.toString());
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

  void _showQualitySelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final playerState = ref.watch(mediaPlayerControllerProvider);
            final currentQuality = playerState.quality;
            
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Quality for Current Video',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...['best', '1080', '720', '480', '360'].map((quality) {
                    final label = quality == 'best' ? 'Auto (Best)' : '${quality}p';
                    final isSelected = currentQuality == quality;
                    
                    return ListTile(
                      title: Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? AppTheme.primaryGreen : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected 
                          ? const Icon(Icons.check, color: AppTheme.primaryGreen) 
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        ref.read(mediaPlayerControllerProvider.notifier)
                            .changeQuality(quality);
                      },
                    );
                  }),
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
    final track = playerState.currentTrack;

    if (track == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, MediaQuery.of(context).size.height * _slideAnimation.value),
          child: child,
        );
      },
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 500) {
            _handleClose();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(
              children: [
                // Header with close button
                if (!_isFullscreen)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, 
                            color: Colors.white, size: 32),
                          onPressed: _handleClose,
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'NOW PLAYING',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 11,
                                  letterSpacing: 1,
                                ),
                              ),
                              Text(
                                track.artist ?? 'Unknown Artist',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onPressed: () {
                            if (track != null) {
                              _showAddToPlaylistSheet(context, track);
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                // Video player area
                Expanded(
                  flex: _isFullscreen ? 1 : 2,
                  child: GestureDetector(
                    onDoubleTap: _toggleFullscreen,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Video Layer
                        if (playerState.isVideoMode)
                          SizedBox(
                            width: MediaQuery.of(context).size.width,
                            height: MediaQuery.of(context).size.width * 
                                (playerState.videoWidth > 0 && playerState.videoHeight > 0 
                                    ? playerState.videoHeight / playerState.videoWidth 
                                    : 9.0 / 16.0),
                            child: Video(
                              key: ValueKey(track.id), 
                              controller: ref.watch(videoControllerProvider),
                              controls: NoVideoControls,
                              fit: BoxFit.contain,
                              fill: Colors.black,
                            ),
                          ),
                          
                        // Thumbnail Layer (Overlay if video not ready or audio mode)
                        if (!playerState.isVideoMode || playerState.videoWidth == 0 || playerState.videoHeight == 0)
                          CachedNetworkImage(
                            imageUrl: track.thumbnailUrl,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => Container(
                              color: Colors.black,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade900,
                              child: const Icon(
                                Icons.music_note,
                                size: 80,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        
                        // Controls overlay (Fullscreen & Quality)
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Volume Control
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: _showVolume ? 100 : 0,
                                    margin: EdgeInsets.only(right: _showVolume ? 8 : 0),
                                    child: _showVolume 
                                      ? SliderTheme(
                                          data: SliderTheme.of(context).copyWith(
                                            activeTrackColor: AppTheme.primaryGreen,
                                            inactiveTrackColor: Colors.grey,
                                            thumbColor: Colors.white,
                                            trackHeight: 2,
                                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
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
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black54,
                                    ),
                                    icon: Icon(
                                      playerState.volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                      color: _showVolume ? AppTheme.primaryGreen : Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _showVolume = !_showVolume;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ),

                              // Quality button
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                ),
                                icon: const Icon(
                                  Icons.settings_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () => _showQualitySelector(context),
                              ),
                              const SizedBox(width: 8),
                              // Fullscreen toggle
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                ),
                                icon: Icon(
                                  _isFullscreen 
                                      ? Icons.fullscreen_exit_rounded 
                                      : Icons.fullscreen_rounded,
                                  color: Colors.white,
                                ),
                                onPressed: _toggleFullscreen,
                              ),
                            ],
                          ),
                        ),

                        // Loading overlay
                        if (playerState.isLoading)
                          Container(
                            color: Colors.black54,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Track info and controls (hidden in fullscreen)
                if (!_isFullscreen) ...[
                  // Track info
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(
                      children: [
                        Text(
                          track.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          track.artist ?? '',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Progress slider
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppTheme.primaryGreen,
                            inactiveTrackColor: Colors.grey.shade800,
                            thumbColor: AppTheme.primaryGreen,
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                          ),
                          child: Slider(
                            value: playerState.progress.clamp(0.0, 1.0),
                            onChanged: (value) {
                              ref.read(mediaPlayerControllerProvider.notifier)
                                  .seekToPercent(value);
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(playerState.position),
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                _formatDuration(playerState.duration),
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Main controls
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.shuffle_rounded, 
                            color: playerState.isShuffle ? AppTheme.primaryGreen : Colors.white54, 
                            size: 24
                          ),
                          onPressed: () {
                            ref.read(mediaPlayerControllerProvider.notifier).toggleShuffle();
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.skip_previous_rounded, 
                            color: playerState.hasPrevious || playerState.position.inSeconds > 3 ? Colors.white : Colors.white24, 
                            size: 40
                          ),
                          onPressed: () {
                            ref.read(mediaPlayerControllerProvider.notifier).skipToPrevious();
                          },
                        ),
                        // Play/Pause button
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryGreen,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              playerState.isPlaying 
                                  ? Icons.pause_rounded 
                                  : Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: 36,
                            ),
                            onPressed: () {
                              ref.read(mediaPlayerControllerProvider.notifier)
                                  .togglePlayPause();
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.skip_next_rounded, 
                            color: playerState.hasNext ? Colors.white : Colors.white24, 
                            size: 40
                          ),
                          onPressed: () {
                            ref.read(mediaPlayerControllerProvider.notifier).skipToNext();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.repeat_rounded, 
                            color: Colors.white54, size: 24),
                          onPressed: () {
                            // TODO: Implement repeat
                          },
                        ),
                      ],
                    ),
                  ),

                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

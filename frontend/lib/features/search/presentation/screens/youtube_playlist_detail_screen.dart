import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../config/theme.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/providers/media_player_provider.dart';
import '../../../../shared/models/track.dart';
import '../../../../shared/widgets/track_tile.dart';
import '../../../../shared/widgets/mini_player.dart';
import '../../../../features/player/presentation/screens/now_playing_screen.dart';

class YouTubePlaylistDetailScreen extends ConsumerStatefulWidget {
  final String playlistId;
  final String playlistTitle;
  final String? thumbnail;
  final String? channel;

  const YouTubePlaylistDetailScreen({
    super.key,
    required this.playlistId,
    required this.playlistTitle,
    this.thumbnail,
    this.channel,
  });

  @override
  ConsumerState<YouTubePlaylistDetailScreen> createState() =>
      _YouTubePlaylistDetailScreenState();
}

class _YouTubePlaylistDetailScreenState
    extends ConsumerState<YouTubePlaylistDetailScreen> {
  bool _isLoading = true;
  String? _error;
  String _title = '';
  String? _channel;
  String? _thumbnail;
  int _videoCount = 0;
  List<Track> _tracks = [];

  bool _isNowPlayingExpanded = false;
  bool _isPlayerVisible = false;

  @override
  void initState() {
    super.initState();
    _title = widget.playlistTitle;
    _channel = widget.channel;
    _thumbnail = widget.thumbnail;
    _loadPlaylistTracks();
  }

  Future<void> _loadPlaylistTracks() async {
    try {
      final youtubeService = ref.read(youtubeServiceProvider);
      final data = await youtubeService.getPlaylistTracks(widget.playlistId);
      final tracks = data['tracks'] as List<Track>;

      if (mounted) {
        setState(() {
          _title = data['title'] as String? ?? widget.playlistTitle;
          _channel = data['channel'] as String? ?? widget.channel;
          _thumbnail = data['thumbnail'] as String? ?? widget.thumbnail;
          _videoCount = data['video_count'] as int? ?? tracks.length;
          _tracks = tracks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  PlaylistSource get _source => PlaylistSource(
        id: widget.playlistId,
        title: _title,
        thumbnail: _thumbnail,
        channel: _channel,
      );

  bool _isPlayingFromThisPlaylist(MediaPlayerState playerState) {
    if (playerState.currentTrack == null || _tracks.isEmpty) return false;
    return _tracks.any((t) => t.id == playerState.currentTrack!.id);
  }

  String get _totalDuration {
    int totalSeconds = 0;
    for (final t in _tracks) {
      totalSeconds += t.duration ?? 0;
    }
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) return '$hours hr $minutes min';
    return '$minutes min';
  }

  void _expandNowPlaying() {
    setState(() => _isPlayerVisible = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _isNowPlayingExpanded = true);
    });
  }

  void _collapseNowPlaying() {
    setState(() => _isNowPlayingExpanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(mediaPlayerControllerProvider);
    final controller = ref.read(mediaPlayerControllerProvider.notifier);
    final isFromThisPlaylist = _isPlayingFromThisPlaylist(playerState);
    final isPlayingHere = isFromThisPlaylist && playerState.isPlaying;
    final hasTrack = playerState.hasTrack;
    final hasSource = playerState.playlistSource != null;
    final miniPlayerHeight = hasTrack ? (64.0 + (hasSource ? 28.0 : 0.0)) : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.spotifyBlack,
      body: Stack(
        children: [
          // --- Main scrollable content ---
          Positioned.fill(
            bottom: miniPlayerHeight,
            child: CustomScrollView(
              slivers: [
                // Header
                SliverAppBar(
                  backgroundColor: AppTheme.spotifyBlack,
                  expandedHeight: 300,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      _title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_thumbnail != null)
                          CachedNetworkImage(
                            imageUrl: _thumbnail!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                Container(color: Colors.grey.shade800),
                          )
                        else
                          Container(color: Colors.grey.shade800),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.transparent,
                                AppTheme.spotifyBlack.withValues(alpha: 0.7),
                                AppTheme.spotifyBlack,
                              ],
                              stops: const [0.0, 0.4, 0.75, 1.0],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Playlist info + controls
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_channel != null)
                          Text(
                            _channel!,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '$_videoCount songs${_tracks.isNotEmpty ? ' \u2022 $_totalDuration' : ''}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Controls row
                        Row(
                          children: [
                            // Shuffle
                            _ControlButton(
                              icon: Icons.shuffle_rounded,
                              isActive: playerState.isShuffle,
                              onTap: () {
                                controller.toggleShuffle();
                                if (!isFromThisPlaylist && _tracks.isNotEmpty) {
                                  controller.playPlaylist(_tracks,
                                      initialIndex: 0, source: _source);
                                }
                              },
                            ),
                            const Spacer(),
                            // Play/Pause FAB
                            if (_tracks.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  if (isFromThisPlaylist) {
                                    controller.togglePlayPause();
                                  } else {
                                    controller.playPlaylist(_tracks,
                                        initialIndex: 0, source: _source);
                                  }
                                },
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryGreen,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isPlayingHere
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.black,
                                    size: 32,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // Track list
                if (_isLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryGreen),
                    ),
                  )
                else if (_error != null)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 64, color: AppTheme.textSecondary),
                          const SizedBox(height: 16),
                          Text('Failed to load playlist',
                              style: TextStyle(color: Colors.red.shade300)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _isLoading = true;
                                _error = null;
                              });
                              _loadPlaylistTracks();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_tracks.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Text('No tracks in this playlist',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final track = _tracks[index];
                        final isPlaying =
                            playerState.currentTrack?.id == track.id;

                        return TrackTile(
                          track: track,
                          isPlaying: isPlaying,
                          onTap: () {
                            if (isPlaying) {
                              controller.togglePlayPause();
                            } else {
                              controller.playPlaylist(_tracks,
                                  initialIndex: index, source: _source);
                            }
                          },
                        );
                      },
                      childCount: _tracks.length,
                    ),
                  ),

                // Bottom padding for mini player
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ),
          ),

          // --- Mini player at bottom ---
          if (hasTrack)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MiniPlayer(onTap: _expandNowPlaying),
            ),

          // --- Full Now Playing screen (slides up) ---
          if (_isPlayerVisible)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_isNowPlayingExpanded,
                child: AnimatedSlide(
                  offset: _isNowPlayingExpanded
                      ? Offset.zero
                      : const Offset(0, 1),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  onEnd: () {
                    if (!_isNowPlayingExpanded) {
                      setState(() => _isPlayerVisible = false);
                    }
                  },
                  child: NowPlayingScreen(onClose: _collapseNowPlaying),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive
              ? AppTheme.primaryGreen.withValues(alpha: 0.15)
              : Colors.transparent,
        ),
        child: Icon(
          icon,
          color: isActive ? AppTheme.primaryGreen : AppTheme.textSecondary,
          size: 24,
        ),
      ),
    );
  }
}

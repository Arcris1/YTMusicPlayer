import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../config/theme.dart';
import '../../../../config/constants.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/providers/media_player_provider.dart';
import '../../../../shared/models/track.dart';
import '../../../../shared/widgets/track_tile.dart';

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
      final client = ref.read(apiClientProvider);
      final response = await client.dio.get(
        '${ApiConstants.searchPlaylists}/${widget.playlistId}',
      );

      final data = response.data;
      final tracks = (data['tracks'] as List)
          .map((json) => Track.fromJson(json))
          .toList();

      if (mounted) {
        setState(() {
          _title = data['title'] ?? widget.playlistTitle;
          _channel = data['channel'] ?? widget.channel;
          _thumbnail = data['thumbnail'] ?? widget.thumbnail;
          _videoCount = data['video_count'] ?? tracks.length;
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

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(mediaPlayerControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.spotifyBlack,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppTheme.spotifyBlack,
            expandedHeight: 250,
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
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey.shade800,
                      ),
                    )
                  else
                    Container(color: Colors.grey.shade800),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppTheme.spotifyBlack.withOpacity(0.8),
                          AppTheme.spotifyBlack,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Playlist info + play button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_channel != null)
                          Text(
                            _channel!,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        Text(
                          '$_videoCount videos',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Play all button
                  if (_tracks.isNotEmpty)
                    FloatingActionButton(
                      onPressed: () {
                        ref
                            .read(mediaPlayerControllerProvider.notifier)
                            .playPlaylist(_tracks, initialIndex: 0);
                      },
                      backgroundColor: AppTheme.primaryGreen,
                      child:
                          const Icon(Icons.play_arrow, color: Colors.black),
                    ),
                ],
              ),
            ),
          ),

          // Content
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child:
                    CircularProgressIndicator(color: AppTheme.primaryGreen),
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
                    Text(
                      'Failed to load playlist',
                      style: TextStyle(color: Colors.red.shade300),
                    ),
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
                child: Text(
                  'No tracks in this playlist',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
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
                      ref
                          .read(mediaPlayerControllerProvider.notifier)
                          .playPlaylist(_tracks, initialIndex: index);
                    },
                  );
                },
                childCount: _tracks.length,
              ),
            ),
        ],
      ),
    );
  }
}

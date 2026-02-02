import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/providers/media_player_provider.dart';
import '../../../../shared/models/playlist.dart';
import '../../../../shared/models/track.dart';
import '../../providers/playlist_provider.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final String playlistId;
  final String playlistName; // Preliminary name for AppBar before loading

  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
    required this.playlistName,
  });

  @override
  ConsumerState<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  bool _isLoading = true;
  Playlist? _playlist;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final client = ref.read(apiClientProvider);
      final playlist = await client.getPlaylistDetails(widget.playlistId);
      if (mounted) {
        setState(() {
          _playlist = playlist;
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
    final playlistState = ref.watch(playlistProvider);

    return Scaffold(
      backgroundColor: AppTheme.spotifyBlack,
      body: CustomScrollView(
        slivers: [
          // AppBar with flexible space
          SliverAppBar(
            backgroundColor: AppTheme.spotifyBlack,
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _playlist?.name ?? widget.playlistName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.grey.shade800,
                      AppTheme.spotifyBlack,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.music_note,
                    size: 80,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
            ),
          ),

          // Content
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryGreen),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  'Error loading playlist',
                  style: TextStyle(color: Colors.red.shade300),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final tracks = _playlist?.tracks ?? [];
                  if (tracks.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No songs yet',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    );
                  }
                  
                  if (index >= tracks.length) return null;
                  
                  final track = tracks[index];
                  final isLiked = playlistState.likedTrackIds.contains(track.id);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: track.thumbnailUrl != null
                          ? Image.network(
                              track.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.music_note,
                                color: Colors.white54,
                              ),
                            )
                          : const Icon(Icons.music_note, color: Colors.white54),
                    ),
                    title: Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      track.artist ?? 'Unknown Artist',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Like Button
                        IconButton(
                          icon: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? AppTheme.primaryGreen : Colors.white54,
                            size: 20,
                          ),
                          onPressed: () {
                             final likedPlaylist = playlistState.playlists
                                 .where((p) => p.name == 'Liked Songs')
                                 .firstOrNull;
                             
                             if (likedPlaylist != null) {
                               ref.read(playlistProvider.notifier)
                                   .toggleLike(likedPlaylist.id, track.id);
                             } else {
                               ScaffoldMessenger.of(context).showSnackBar(
                                 const SnackBar(content: Text('Liked Songs playlist not found')),
                               );
                             }
                          },
                        ),
                        // More Options
                        IconButton(
                          icon: const Icon(Icons.more_vert, color: Colors.white54),
                          onPressed: () {
                            // TODO: Show options (remove from playlist)
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      if (_playlist?.tracks != null) {
                        ref.read(mediaPlayerControllerProvider.notifier)
                            .playPlaylist(_playlist!.tracks!, initialIndex: index);
                      }
                    },
                  );
                },
                childCount: (_playlist?.tracks?.isEmpty ?? true) ? 1 : _playlist!.tracks!.length,
              ),
            ),
        ],
      ),
    );
  }
}

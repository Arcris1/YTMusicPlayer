import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme.dart';
import '../../providers/playlist_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../shared/models/playlist.dart';
import 'playlist_detail_screen.dart';

/// Library screen for playlists and liked songs
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistState = ref.watch(playlistProvider);

    return Scaffold(
      backgroundColor: AppTheme.spotifyBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.spotifyBlack,
        title: const Text('Your Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _showCreatePlaylistDialog(context, ref);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(playlistProvider.notifier).loadPlaylists(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Liked Songs
            const _LibraryItem(
              icon: Icons.favorite,
              iconColor: AppTheme.primaryGreen,
              title: 'Liked Songs',
              subtitle: 'Playlist • 0 songs', // TODO: Fetch real count
              onTap: null, 
            ),
            const SizedBox(height: 16),
            
            // Your Playlists header
            const Text(
              'Your Playlists',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Playlists List
            if (playlistState.isLoading && playlistState.playlists.isEmpty)
              const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
            else if (playlistState.playlists.isEmpty)
              _buildEmptyState(context, ref)
            else
              ...playlistState.playlists.map((playlist) => _LibraryItem(
                icon: Icons.music_note,
                iconColor: Colors.grey,
                title: playlist.name,
                subtitle: 'Playlist • ${playlist.trackCount} songs',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlaylistDetailScreen(
                        playlistId: playlist.id,
                        playlistName: playlist.name,
                      ),
                    ),
                  );
                },
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.library_music,
            size: 80,
            color: AppTheme.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Create your first playlist',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "It's easy, we'll help you",
            style: TextStyle(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _showCreatePlaylistDialog(context, ref),
            child: const Text('Create Playlist'),
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text(
          'Create Playlist',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context);
                final success = await ref.read(playlistProvider.notifier)
                    .createPlaylist(name);
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Playlist created')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

/// Library item widget
class _LibraryItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _LibraryItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    iconColor.withOpacity(0.8),
                    iconColor.withOpacity(0.4),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

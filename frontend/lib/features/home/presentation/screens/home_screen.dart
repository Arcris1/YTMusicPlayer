import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_music_player/config/theme.dart';
import 'package:youtube_music_player/shared/models/track.dart';
import 'package:youtube_music_player/shared/widgets/app_shell.dart';
import 'package:youtube_music_player/core/providers/media_player_provider.dart';
import 'package:youtube_music_player/features/search/presentation/screens/search_screen.dart';
import 'package:youtube_music_player/features/library/presentation/screens/library_screen.dart';

/// Home screen with bottom navigation and persistent mini player
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Content screens (without navigation - that's in AppShell)
    final screens = [
      const _HomeContent(),
      const SearchScreen(),
      const LibraryScreen(),
    ];

    return AppShell(
      currentIndex: _currentIndex,
      onNavigationChanged: (index) => setState(() => _currentIndex = index),
      child: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
    );
  }
}

/// Home content with sections
class _HomeContent extends ConsumerWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sample tracks for demonstration
    final sampleTracks = [
      const Track(
        id: 'dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        artist: 'Rick Astley',
        duration: 213,
      ),
      const Track(
        id: 'fJ9rUzIMcZQ',
        title: 'Bohemian Rhapsody',
        artist: 'Queen',
        duration: 354,
      ),
      const Track(
        id: '9bZkp7q19f0',
        title: 'Gangnam Style',
        artist: 'PSY',
        duration: 252,
      ),
      const Track(
        id: 'kJQP7kiw5Fk',
        title: 'Despacito',
        artist: 'Luis Fonsi ft. Daddy Yankee',
        duration: 282,
      ),
      const Track(
        id: 'CevxZvSJLk8',
        title: 'Roar',
        artist: 'Katy Perry',
        duration: 269,
      ),
      const Track(
        id: 'YQHsXMglC9A',
        title: 'Hello',
        artist: 'Adele',
        duration: 295,
      ),
    ];

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            backgroundColor: AppTheme.spotifyBlack,
            floating: true,
            title: _getGreeting(),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.history),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {},
              ),
            ],
          ),
          // Quick picks section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Picks',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 3.0,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: sampleTracks.length,
                    itemBuilder: (context, index) {
                      final track = sampleTracks[index];
                      return _QuickPickCard(
                        track: track,
                        onTap: () {
                          // Play using global player
                          ref.read(mediaPlayerControllerProvider.notifier)
                              .playTrack(track, videoMode: true);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // Recently played section
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Recently Played',
              onSeeAll: () {},
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: sampleTracks.length,
                itemBuilder: (context, index) {
                  final track = sampleTracks[index];
                  return _MediaCard(
                    title: track.title,
                    subtitle: track.artist ?? '',
                    imageUrl: track.thumbnailUrl,
                    onTap: () {
                      ref.read(mediaPlayerControllerProvider.notifier)
                          .playTrack(track, videoMode: true);
                    },
                  );
                },
              ),
            ),
          ),
          // Recommended section
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Recommended for You',
              onSeeAll: () {},
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: sampleTracks.length,
                itemBuilder: (context, index) {
                  final track = sampleTracks[sampleTracks.length - 1 - index];
                  return _MediaCard(
                    title: track.title,
                    subtitle: track.artist ?? '',
                    imageUrl: track.thumbnailUrl,
                    onTap: () {
                      ref.read(mediaPlayerControllerProvider.notifier)
                          .playTrack(track, videoMode: true);
                    },
                  );
                },
              ),
            ),
          ),
          // Extra padding at bottom for mini player
          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
        ],
      ),
    );
  }

  Widget _getGreeting() {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }
    return Text(
      greeting,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

/// Quick pick card
class _QuickPickCard extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;

  const _QuickPickCard({
    required this.track,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.cardDark,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  bottomLeft: Radius.circular(4),
                ),
                child: Image.network(
                  track.thumbnailUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => Container(
                    width: 56,
                    height: 56,
                    color: AppTheme.cardHover,
                    child: const Icon(Icons.music_note, size: 20, color: AppTheme.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  track.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section header
class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;

  const _SectionHeader({
    required this.title,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(
            onPressed: onSeeAll,
            child: const Text(
              'See all',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Media card for horizontal lists
class _MediaCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final VoidCallback onTap;

  const _MediaCard({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                width: 140,
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(
                  width: 140,
                  height: 140,
                  color: AppTheme.cardDark,
                  child: const Icon(
                    Icons.music_note,
                    size: 40,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
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
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../core/providers/media_player_provider.dart';
import '../../features/player/presentation/screens/now_playing_screen.dart';
import 'mini_player.dart';

/// App shell that provides persistent mini player across all screens
class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  final int currentIndex;
  final ValueChanged<int> onNavigationChanged;

  const AppShell({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onNavigationChanged,
  });

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _isNowPlayingExpanded = false;
  bool _isPlayerVisible = false;

  void _expandNowPlaying() {
    setState(() {
      _isPlayerVisible = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isNowPlayingExpanded = true;
        });
      }
    });
  }

  void _collapseNowPlaying() {
    setState(() {
      _isNowPlayingExpanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(mediaPlayerControllerProvider);
    final hasTrack = playerState.hasTrack;

    return Scaffold(
      backgroundColor: AppTheme.spotifyBlack,
      body: Stack(
        children: [
          // Main content with padding for mini player and nav bar
          Positioned.fill(
            bottom: hasTrack ? 64 + 60 : 60, // mini player + nav bar height
            child: widget.child,
          ),
          
          // Mini player (above nav bar)
          if (hasTrack)
            Positioned(
              left: 0,
              right: 0,
              bottom: 60, // above nav bar
              child: MiniPlayer(
                onTap: _expandNowPlaying,
              ),
            ),

          // Bottom navigation bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomNavBar(),
          ),

          // Expanded Now Playing Screen (slides up)
          if (_isPlayerVisible)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_isNowPlayingExpanded,
                child: AnimatedSlide(
                  offset: _isNowPlayingExpanded ? Offset.zero : const Offset(0, 1),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  onEnd: () {
                    if (!_isNowPlayingExpanded) {
                      setState(() {
                        _isPlayerVisible = false;
                      });
                    }
                  },
                  child: NowPlayingScreen(
                    onClose: _collapseNowPlaying,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: AppTheme.spotifyBlack,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade800,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
          _buildNavItem(1, Icons.search_rounded, Icons.search_outlined, 'Search'),
          _buildNavItem(2, Icons.library_music_rounded, Icons.library_music_outlined, 'Library'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = widget.currentIndex == index;
    
    return Expanded(
      child: InkWell(
        onTap: () => widget.onNavigationChanged(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

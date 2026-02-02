import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../config/theme.dart';
import '../../../../config/constants.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/providers/media_player_provider.dart';
import '../../../../shared/models/track.dart';
import '../../../../shared/widgets/track_tile.dart';
import '../../../library/providers/playlist_provider.dart';

/// Search state
class SearchState {
  final bool isLoading;
  final List<Track> results;
  final String query;
  final String? error;

  const SearchState({
    this.isLoading = false,
    this.results = const [],
    this.query = '',
    this.error,
  });

  SearchState copyWith({
    bool? isLoading,
    List<Track>? results,
    String? query,
    String? error,
  }) {
    return SearchState(
      isLoading: isLoading ?? this.isLoading,
      results: results ?? this.results,
      query: query ?? this.query,
      error: error,
    );
  }
}

/// Search notifier
class SearchNotifier extends StateNotifier<SearchState> {
  final ApiClient _apiClient;

  SearchNotifier(this._apiClient) : super(const SearchState());

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = const SearchState();
      return;
    }

    state = state.copyWith(isLoading: true, query: query, error: null);

    try {
      final response = await _apiClient.dio.get(
        ApiConstants.search,
        queryParameters: {'query': query, 'limit': 30},
      );

      final results = (response.data['results'] as List)
          .map((json) => Track.fromJson(json))
          .toList();

      state = state.copyWith(isLoading: false, results: results);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? 'Search failed',
      );
    }
  }

  void clear() {
    state = const SearchState();
  }
}

final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref.read(apiClientProvider));
});

/// Search screen
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    ref.read(searchProvider.notifier).search(query);
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final playerState = ref.watch(mediaPlayerControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.spotifyBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.spotifyBlack,
        title: const Text('Search'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'What do you want to listen to?',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(searchProvider.notifier).clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.textPrimary,
                hintStyle: const TextStyle(color: AppTheme.spotifyBlack),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: AppTheme.spotifyBlack),
              onSubmitted: _onSearch,
              onChanged: (value) {
                setState(() {}); // Rebuild for suffix icon
                // Debounce could be added here
              },
            ),
          ),
          // Results
          Expanded(
            child: searchState.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryGreen,
                    ),
                  )
                : searchState.error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              searchState.error!,
                              style: const TextStyle(color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _onSearch(searchState.query),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : searchState.results.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  searchState.query.isEmpty
                                      ? Icons.search
                                      : Icons.music_off,
                                  size: 64,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  searchState.query.isEmpty
                                      ? 'Search for songs, artists, or albums'
                                      : 'No results found',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: searchState.results.length,
                            itemBuilder: (context, index) {
                              final track = searchState.results[index];
                              final isPlaying = playerState.currentTrack?.id == track.id;
                              
                              return TrackTile(
                                track: track,
                                isPlaying: isPlaying,
                                onTap: () {
                                  // Play using global player
                                  ref.read(mediaPlayerControllerProvider.notifier)
                                      .playTrack(track, videoMode: true);
                                },
                                onMorePressed: () {
                                  _showTrackOptions(context, track);
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  void _showTrackOptions(BuildContext context, Track track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.music_note, color: AppTheme.primaryGreen),
              title: const Text('Play audio only'),
              onTap: () {
                Navigator.pop(context);
                ref.read(mediaPlayerControllerProvider.notifier).playTrack(track, videoMode: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add, color: AppTheme.textPrimary),
              title: const Text('Add to playlist'),
              onTap: () {
                Navigator.pop(context);
                _showAddToPlaylistSheet(context, track);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music, color: AppTheme.textPrimary),
              title: const Text('Add to queue'),
              onTap: () {
                // TODO: Implement queue
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Added to queue')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: AppTheme.textPrimary),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Share functionality
              },
            ),
          ],
        ),
      ),
    );
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
            print('Search Playlist Sheet: count=${playlistState.playlists.length}');
            
            // Force load if empty
            if (!playlistState.isLoading && playlistState.playlists.isEmpty) {
               Future.microtask(() => ref.read(playlistProvider.notifier).loadPlaylists());
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
                          return ListTile(
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
                              Navigator.pop(sheetContext);
                              
                              print('Adding track ${track.id} to playlist ${playlist.id}...');
                              final result = await ref.read(playlistProvider.notifier)
                                  .addTrackToPlaylist(playlist.id, track.id);
                              
                              if (parentContext.mounted) {
                                ScaffoldMessenger.of(parentContext).showSnackBar(
                                  SnackBar(
                                    content: Text(result ?? 'Failed to add to playlist'),
                                    backgroundColor: result != null ? AppTheme.spotifyBlack : Colors.red,
                                  ),
                                );
                              }
                            },
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
}

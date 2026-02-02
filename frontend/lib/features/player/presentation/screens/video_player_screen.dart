import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:dio/dio.dart';
import '../../../../config/theme.dart';
import '../../../../config/constants.dart';
import '../../../../shared/models/track.dart';

/// Video player screen for full video playback using MediaKit
class VideoPlayerScreen extends ConsumerStatefulWidget {
  final Track track;

  const VideoPlayerScreen({
    super.key,
    required this.track,
  });

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  // MediaKit player and controller
  late final Player _player;
  late final VideoController _controller;
  
  bool _isLoading = true;
  String? _error;
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));

  @override
  void initState() {
    super.initState();
    // Create player and controller
    _player = Player();
    _controller = VideoController(_player);
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('Fetching video stream for: ${widget.track.id}');
      final response = await _dio.get(
        '${ApiConstants.videoStream}/${widget.track.id}',
        queryParameters: {'quality': 'best'},
      );

      debugPrint('Video API Response received');
      final streamUrl = response.data['url'] as String?;
      
      if (streamUrl == null || streamUrl.isEmpty) {
        debugPrint('ERROR: Video stream URL is empty or null');
        setState(() {
          _error = 'Could not get video stream URL';
          _isLoading = false;
        });
        return;
      }

      debugPrint('Video stream URL found, length: ${streamUrl.length}');

      // Extract headers if available
      Map<String, String> headers = {};
      if (response.data['headers'] != null) {
        final headersMap = response.data['headers'] as Map;
        headersMap.forEach((key, value) {
          headers[key.toString()] = value.toString();
        });
        debugPrint('Headers extracted: ${headers.keys.join(", ")}');
      }

      // Open media with MediaKit - supports headers natively
      await _player.open(
        Media(streamUrl, httpHeaders: headers),
        play: true,
      );
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Video initialization error: $e');
      setState(() {
        _error = 'Failed to load video: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    // Reset system UI to normal
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.track.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () => _showVideoOptions(context),
          ),
        ],
      ),
      body: Center(
        child: _isLoading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: AppTheme.primaryGreen,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading video...',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                ],
              )
            : _error != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 64),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _initializePlayer,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ],
                  )
                : Video(
                    controller: _controller,
                    controls: MaterialVideoControls,
                  ),
      ),
    );
  }

  void _showVideoOptions(BuildContext context) {
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
              leading: const Icon(Icons.playlist_add, color: Colors.white),
              title: const Text('Add to playlist'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement add to playlist
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.white),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement share
              },
            ),
            ListTile(
              leading: const Icon(Icons.music_note, color: Colors.white),
              title: const Text('Play audio only'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pop(context); // Return to previous screen for audio
              },
            ),
          ],
        ),
      ),
    );
  }
}

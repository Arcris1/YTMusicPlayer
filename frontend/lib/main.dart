import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'config/theme.dart';
import 'core/providers/media_player_provider.dart';
import 'core/services/audio_handler.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/home/presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Request notification permission on Android 13+
  if (Platform.isAndroid) {
    await Permission.notification.request();
  }

  // Initialize AudioService (Android/iOS only — hangs on desktop).
  final audioHandler = AppAudioHandler();
  if (Platform.isAndroid || Platform.isIOS) {
    debugPrint('[main] Starting AudioService.init...');
    try {
      await AudioService.init(
        builder: () => audioHandler,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.musicplayer.youtube_music_player.audio',
          androidNotificationChannelName: 'SpoTube Playback',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      );
      debugPrint('[main] AudioService.init completed successfully');
    } catch (e, st) {
      debugPrint('[main] AudioService.init FAILED: $e');
      debugPrint('[main] Stack trace: $st');
    }
  } else {
    debugPrint('[main] Skipping AudioService.init on desktop');
  }

  // Create Player AFTER AudioService is initialized
  final player = Player();
  audioHandler.attachPlayer(player);
  debugPrint('[main] Player created and attached to handler');

  runApp(ProviderScope(
    overrides: [
      playerProvider.overrideWithValue(player),
      audioHandlerProvider.overrideWithValue(audioHandler),
    ],
    child: const SpoTubeApp(),
  ));
}

class SpoTubeApp extends StatelessWidget {
  const SpoTubeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpoTube',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const _AuthGate(),
    );
  }
}

/// Shows LoginScreen if not authenticated, HomeScreen if authenticated.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    if (authState.isAuthenticated) {
      return const HomeScreen();
    }

    return const LoginScreen();
  }
}

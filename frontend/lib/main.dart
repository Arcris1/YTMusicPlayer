import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'config/theme.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/home/presentation/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const ProviderScope(child: YouTubeMusicApp()));
}

class YouTubeMusicApp extends ConsumerStatefulWidget {
  const YouTubeMusicApp({super.key});

  @override
  ConsumerState<YouTubeMusicApp> createState() => _YouTubeMusicAppState();
}

class _YouTubeMusicAppState extends ConsumerState<YouTubeMusicApp> {
  @override
  void initState() {
    super.initState();
    // Check auth status on startup
    Future.microtask(() => ref.read(authProvider.notifier).checkAuthStatus());
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'YouTube Music Player',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: authState.isAuthenticated 
          ? const HomeScreen() 
          : const LoginScreen(),
    );
  }
}

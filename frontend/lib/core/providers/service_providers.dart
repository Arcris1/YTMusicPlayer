import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/youtube_service.dart';
import '../services/database_service.dart';

/// Provider for YouTubeService singleton
final youtubeServiceProvider = Provider<YouTubeService>((ref) {
  return YouTubeService();
});

/// Provider for DatabaseService singleton
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

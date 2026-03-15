import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme.dart';
import '../../../../core/providers/media_player_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppTheme.spotifyBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.spotifyBlack,
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // User info
          if (authState.isAuthenticated)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryGreen,
                    child: Text(
                      (authState.username ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authState.username ?? 'User',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        authState.email ?? '',
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
          const Divider(color: AppTheme.cardDark),

          // Playback
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Playback',
              style: TextStyle(
                color: AppTheme.primaryGreen,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text(
              'Audio Only Mode (MP3)',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            subtitle: const Text(
              'Stream audio only instead of video. Uses less data and battery.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            value: settings.audioOnlyMode,
            activeTrackColor: AppTheme.primaryGreen,
            activeThumbColor: AppTheme.primaryGreen,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setAudioOnlyMode(value);
              ref
                  .read(mediaPlayerControllerProvider.notifier)
                  .setVideoMode(!value);
            },
          ),
          const Divider(color: AppTheme.cardDark),

          // Account
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Account',
              style: TextStyle(
                color: AppTheme.primaryGreen,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Log Out',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.cardDark,
                  title: const Text(
                    'Log Out',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                  content: const Text(
                    'Are you sure you want to log out?',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Log Out'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

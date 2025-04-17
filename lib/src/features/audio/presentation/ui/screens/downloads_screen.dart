import 'dart:io';
import 'package:auto_route/auto_route.dart';
import 'package:eulaiq/src/common/services/notification_service.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:eulaiq/src/common/widgets/notification_card.dart';
import 'package:eulaiq/src/features/audio/data/models/audio_model.dart';
import 'package:eulaiq/src/features/audio/presentation/providers/audio_download_provider.dart';
import 'package:eulaiq/src/features/audio/presentation/providers/persistent_audio_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:path/path.dart' as path;

@RoutePage()
class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  String? _currentlyPlayingId;
  
  @override
  void initState() {
    super.initState();
    
    // Refresh downloaded files list
    Future.microtask(() {
      ref.read(audioDownloadProvider.notifier).loadDownloadedFiles();
    });
  }
  
  Future<void> _playAudio(String audioId, String filePath, String title) async {
    try {
      // Create a mock Audio object for the downloaded file
      final audio = Audio(
        id: audioId,
        title: title,
        audioUrl: filePath,
        audioDuration: 0, // This will be updated when audio is loaded
        createdAt: DateTime.now(),
        index: 0,
      );
      
      // Create a playlist with just this audio
      final playlist = [audio];
      
      // Use the persistent audio player
      final persistentPlayer = ref.read(persistentAudioProvider.notifier);
      persistentPlayer.loadPlaylist(
        playlist: playlist,
        collectionId: "downloads",
        collectionTitle: "Downloaded Audio",
        startIndex: 0,
      );
      
      setState(() {
        _currentlyPlayingId = audioId;
      });
    } catch (e) {
      ref.read(notificationServiceProvider).showNotification(
        message: 'Failed to play audio: $e',
        type: NotificationType.error,
      );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final downloadState = ref.watch(audioDownloadProvider);
    
    // Extract file information
    final downloadedFiles = downloadState.downloadedFiles;
    final entries = downloadedFiles.entries.toList();
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Downloaded Episodes'),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(MdiIcons.refresh),
            onPressed: () {
              ref.read(audioDownloadProvider.notifier).loadDownloadedFiles();
              ref.read(notificationServiceProvider).showNotification(
                message: 'Downloads refreshed',
                type: NotificationType.info,
              );
            },
          ),
        ],
      ),
      body: downloadState.isLoadingDownloads
        ? Center(
            child: CircularProgressIndicator(
              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            ),
          )
        : entries.isEmpty
          ? _buildEmptyState(isDark)
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final audioId = entry.key;
                final filePath = entry.value;
                
                // Extract filename
                final fileName = path.basename(filePath);
                // Extract title from filename pattern: audioId_title.mp3
                final parts = fileName.split('_');
                final title = parts.length > 1 
                    ? parts.sublist(1).join('_').replaceAll('.mp3', '')
                    : fileName;
                
                // Check if file exists and get its size
                final file = File(filePath);
                final fileExists = file.existsSync();
                final fileSize = fileExists ? file.lengthSync() : 0;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isDark ? Colors.black38 : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: fileExists ? () => _playAudio(audioId, filePath, title) : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Play button
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: fileExists
                                  ? (isDark ? AppColors.neonCyan.withOpacity(0.1) : AppColors.brandDeepGold.withOpacity(0.1))
                                  : Colors.grey.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                _currentlyPlayingId == audioId
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 28,
                              ),
                              color: fileExists
                                  ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                                  : Colors.grey,
                              onPressed: fileExists ? () => _playAudio(audioId, filePath, title) : null,
                            ),
                          ),
                          
                          const SizedBox(width: 16),
                          
                          // Title and info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  fileExists 
                                      ? _formatFileSize(fileSize)
                                      : 'File not found',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: fileExists
                                        ? (isDark ? Colors.white60 : Colors.black54)
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Delete button
                          IconButton(
                            icon: Icon(MdiIcons.deleteOutline),
                            color: isDark ? Colors.white60 : Colors.black45,
                            onPressed: () {
                              _showDeleteConfirmation(isDark, audioId, title);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
  
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              MdiIcons.downloadOff,
              size: 80,
              color: isDark ? Colors.white24 : Colors.black12,
            ),
            const SizedBox(height: 24),
            Text(
              'No Downloaded Episodes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Episodes you download will appear here for offline listening.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showDeleteConfirmation(bool isDark, String audioId, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          'Delete Downloaded Audio',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$title" from your downloads?',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(audioDownloadProvider.notifier).deleteDownloadedAudio(audioId);
              ref.read(notificationServiceProvider).showNotification(
                message: 'Audio deleted from downloads',
                type: NotificationType.info,
              );
            },
            child: Text(
              'Delete',
              style: TextStyle(
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
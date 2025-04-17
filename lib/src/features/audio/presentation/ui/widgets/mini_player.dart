import 'package:auto_route/auto_route.dart';
import 'package:eulaiq/src/common/common.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:eulaiq/src/features/audio/presentation/providers/persistent_audio_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(persistentAudioProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Don't show if not visible or no audio is loaded
    if (!audioState.isVisible || audioState.currentAudio == null) {
      return const SizedBox.shrink();
    }

    final audio = audioState.currentAudio!;
    
    return GestureDetector(
      onTap: () => _expandPlayer(context, ref),
      child: Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.black38 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: isDark 
                ? AppColors.neonCyan.withOpacity(0.3) 
                : AppColors.brandDeepGold.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Album art / icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: audioState.collectionImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: audioState.collectionImageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => Icon(
                          Icons.music_note,
                          color: isDark ? Colors.white30 : Colors.grey,
                        ),
                      )
                    : Icon(
                        Icons.music_note,
                        color: isDark ? Colors.white30 : Colors.grey,
                      ),
              ),
            ),
            
            // Title and progress bar
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      audio.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: audioState.duration.inMilliseconds > 0
                          ? audioState.position.inMilliseconds / 
                            audioState.duration.inMilliseconds
                          : 0.0,
                      backgroundColor: isDark 
                          ? Colors.white10 
                          : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(
                        isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                      ),
                      minHeight: 2,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      audioState.collectionTitle ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            
            // Play/Pause button
            IconButton(
              icon: Icon(
                audioState.isPlaying 
                    ? Icons.pause_rounded 
                    : Icons.play_arrow_rounded,
                color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
              ),
              onPressed: () {
                ref.read(persistentAudioProvider.notifier).togglePlayPause();
              },
            ),
            
            // Close button
            IconButton(
              icon: Icon(
                Icons.close,
                color: isDark ? Colors.white60 : Colors.black45,
                size: 20,
              ),
              onPressed: () {
                ref.read(persistentAudioProvider.notifier).hidePlayer();
                ref.read(persistentAudioProvider).player.stop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _expandPlayer(BuildContext context, WidgetRef ref) {
    final audioState = ref.read(persistentAudioProvider);
    if (audioState.collectionId != null) {
      // Navigate to the full player screen
      context.router.push(
        AudioStreamingRoute(
          collectionId: audioState.collectionId!,
          title: audioState.collectionTitle ?? 'Now Playing',
          imageUrl: audioState.collectionImageUrl,
          fromMiniPlayer: true,
        ),
      );
    }
  }
}
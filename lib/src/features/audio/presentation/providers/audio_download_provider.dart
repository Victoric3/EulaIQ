import 'package:eulaiq/src/features/audio/presentation/providers/audio_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eulaiq/src/features/audio/data/repositories/audio_repository.dart';
import 'package:eulaiq/src/features/audio/data/models/audio_model.dart';

class DownloadState {
  final Map<String, DownloadProgress> downloadProgress;
  final Map<String, String> downloadedFiles; // audioId -> filePath
  final bool isLoadingDownloads;
  final String? errorMessage;
  
  // Download All tracking properties
  final bool isDownloadingAll;
  final double downloadAllProgress;
  final int totalItemsToDownload;
  final int downloadedItemsCount;
  final String? currentDownloadingTitle;
  
  // Streaming indicator properties
  final Set<String> currentlyStreaming;
  
  DownloadState({
    this.downloadProgress = const {},
    this.downloadedFiles = const {},
    this.isLoadingDownloads = false,
    this.errorMessage,
    this.isDownloadingAll = false,
    this.downloadAllProgress = 0.0,
    this.totalItemsToDownload = 0,
    this.downloadedItemsCount = 0,
    this.currentDownloadingTitle,
    this.currentlyStreaming = const {},
  });
  
  DownloadState copyWith({
    Map<String, DownloadProgress>? downloadProgress,
    Map<String, String>? downloadedFiles,
    bool? isLoadingDownloads,
    String? errorMessage,
    bool? isDownloadingAll,
    double? downloadAllProgress,
    int? totalItemsToDownload,
    int? downloadedItemsCount,
    String? currentDownloadingTitle,
    Set<String>? currentlyStreaming,
  }) {
    return DownloadState(
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadedFiles: downloadedFiles ?? this.downloadedFiles,
      isLoadingDownloads: isLoadingDownloads ?? this.isLoadingDownloads,
      errorMessage: errorMessage,
      isDownloadingAll: isDownloadingAll ?? this.isDownloadingAll,
      downloadAllProgress: downloadAllProgress ?? this.downloadAllProgress,
      totalItemsToDownload: totalItemsToDownload ?? this.totalItemsToDownload,
      downloadedItemsCount: downloadedItemsCount ?? this.downloadedItemsCount,
      currentDownloadingTitle: currentDownloadingTitle ?? this.currentDownloadingTitle,
      currentlyStreaming: currentlyStreaming ?? this.currentlyStreaming,
    );
  }
}

class AudioDownloadNotifier extends StateNotifier<DownloadState> {
  final AudioRepository _repository;
  
  AudioDownloadNotifier(this._repository) : super(DownloadState()) {
    // Load downloaded files on initialization
    loadDownloadedFiles();
  }
  
  // Download an audio file
  Future<void> downloadAudio(Audio audio) async {
    try {
      // Extract filename from URL
      final fileName = "${audio.id}_${audio.title.replaceAll(' ', '_')}.mp3";
      String audioId = audio.id ?? '';
      // Start download and track progress
      await _repository.downloadAudio(
        audio.audioUrl,
        fileName,
        audioId,
        audio.title,
        (progress) {
          state = state.copyWith(
            downloadProgress: {
              ...state.downloadProgress,
              audioId: progress,
            },
          );
        },
      );
      
      // Update downloaded files list after successful download
      final filePath = await _repository.getLocalAudioPath(fileName);
      if (filePath != null) {
        state = state.copyWith(
          downloadedFiles: {
            ...state.downloadedFiles,
            audioId: filePath,
          },
          // Clear progress for this file
          downloadProgress: {
            ...state.downloadProgress,
          }..remove(audioId),
        );
      }
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to download audio: $e',
        // Clear progress for this file on error
        downloadProgress: {
          ...state.downloadProgress,
        }..remove(audio.id),
      );
    }
  }
  
  // Load all previously downloaded files
  Future<void> loadDownloadedFiles() async {
    state = state.copyWith(isLoadingDownloads: true);
    
    try {
      final downloadedFiles = await _repository.getDownloadedAudioFiles();
      final newMap = <String, String>{};
      
      for (final file in downloadedFiles) {
        final fileName = file['fileName'] as String;
        // Extract audio ID from filename pattern: audioId_title.mp3
        final audioId = fileName.split('_').first;
        newMap[audioId] = file['path'] as String;
      }
      
      state = state.copyWith(
        downloadedFiles: newMap,
        isLoadingDownloads: false,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to load downloaded files: $e',
        isLoadingDownloads: false,
      );
    }
  }
  
  // Delete a downloaded audio file
  Future<void> deleteDownloadedAudio(String audioId) async {
    try {
      final filePath = state.downloadedFiles[audioId];
      if (filePath == null) return;
      
      final success = await _repository.deleteDownloadedAudio(filePath);
      
      if (success) {
        state = state.copyWith(
          downloadedFiles: {
            ...state.downloadedFiles,
          }..remove(audioId),
        );
      }
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to delete audio: $e',
      );
    }
  }
  
  // Check if an audio is downloaded
  bool isAudioDownloaded(String audioId) {
    return state.downloadedFiles.containsKey(audioId);
  }
  
  // Get local path for a downloaded audio
  String? getLocalAudioPath(String audioId) {
    return state.downloadedFiles[audioId];
  }
  
  // Clear error message
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  bool _isDownloadingAll = false;
  bool _cancelDownloadAll = false;
  String? _currentlyDownloadingId;

  // Method to download all audio segments from a collection
  Future<void> downloadAllAudioInCollection(List<Audio> audioSegments) async {
    if (_isDownloadingAll) return;
    
    try {
      _isDownloadingAll = true;
      _cancelDownloadAll = false;
      
      // Set initial state for download all
      state = state.copyWith(
        isDownloadingAll: true,
        downloadAllProgress: 0.0,
        totalItemsToDownload: audioSegments.length,
        downloadedItemsCount: 0,
      );
      
      // Download each audio one by one
      for (int i = 0; i < audioSegments.length; i++) {
        // Check if operation was cancelled
        if (_cancelDownloadAll) {
          break;
        }
        
        final audio = audioSegments[i];
        final String audioId = audio.id ?? '';
        _currentlyDownloadingId = audioId;
        
        // Skip if already downloaded
        if (state.downloadedFiles.containsKey(audioId)) {
          state = state.copyWith(
            downloadedItemsCount: state.downloadedItemsCount + 1,
            downloadAllProgress: (i + 1) / audioSegments.length,
          );
          continue;
        }
        
        // Extract filename from URL and sanitize it
        final fileName = "${audioId}_${audio.title.replaceAll(' ', '_')}.mp3";
        
        // Download the audio file with progress tracking
        await _repository.downloadAudio(
          audio.audioUrl,
          fileName,
          audioId,
          audio.title,
          (progress) {
            // Update individual file progress
            state = state.copyWith(
              downloadProgress: {
                ...state.downloadProgress,
                audioId: progress,
              },
              // Also update the download all progress
              downloadAllProgress: ((i + (progress.progress)) / audioSegments.length),
              currentDownloadingTitle: audio.title,
            );
          },
        );
        
        // Update downloaded files list after successful download
        final filePath = await _repository.getLocalAudioPath(fileName);
        if (filePath != null) {
          state = state.copyWith(
            downloadedFiles: {
              ...state.downloadedFiles,
              audioId: filePath,
            },
            // Clear progress for this file
            downloadProgress: {
              ...state.downloadProgress,
            }..remove(audioId),
            // Update download all progress
            downloadedItemsCount: state.downloadedItemsCount + 1,
            downloadAllProgress: (i + 1) / audioSegments.length,
          );
        }
      }
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to download all audio: $e',
      );
    } finally {
      _isDownloadingAll = false;
      _cancelDownloadAll = false;
      _currentlyDownloadingId = null;
      
      // Reset download all state
      state = state.copyWith(
        isDownloadingAll: false,
        downloadAllProgress: 0.0,
        totalItemsToDownload: 0,
        downloadedItemsCount: 0,
        currentDownloadingTitle: null,
      );
    }
  }

  // Method to cancel download all operation
  void cancelDownloadAll() {
    if (!_isDownloadingAll) return;
    
    _cancelDownloadAll = true;
    
    // Cancel current download if any
    if (_currentlyDownloadingId != null) {
      final currentProgress = state.downloadProgress[_currentlyDownloadingId];
      if (currentProgress != null) {
        state = state.copyWith(
          downloadProgress: {
            ...state.downloadProgress,
          }..remove(_currentlyDownloadingId),
        );
      }
    }
  }

  // Add tracking methods for streaming indicators
  void setStreamingStatus(String audioId, bool isStreaming) {
    Set<String> newStreamingSet = {...state.currentlyStreaming};
    
    if (isStreaming) {
      newStreamingSet.add(audioId);
    } else {
      newStreamingSet.remove(audioId);
    }
    
    state = state.copyWith(
      currentlyStreaming: newStreamingSet,
    );
  }

  // Add this method to AudioDownloadNotifier in audio_download_provider.dart
  void cancelDownload(String audioId) {
    if (!state.downloadProgress.containsKey(audioId)) return;
    
    // Remove from progress tracking
    state = state.copyWith(
      downloadProgress: {
        ...state.downloadProgress,
      }..remove(audioId),
    );
    
    // Show notification
    // This would require passing the notification service to the provider
    // or creating a way for the UI to listen to cancellation events
  }
}

final audioDownloadProvider = StateNotifierProvider<AudioDownloadNotifier, DownloadState>((ref) {
  return AudioDownloadNotifier(ref.watch(audioRepositoryProvider));
});
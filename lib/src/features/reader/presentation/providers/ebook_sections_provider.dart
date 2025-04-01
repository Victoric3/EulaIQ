import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eulaiq/src/features/reader/data/repositories/ebook_sections_repository.dart';

/// Repository provider
final ebookSectionsRepositoryProvider = Provider<EbookSectionsRepository>((ref) {
  return EbookSectionsRepository(ref);
});

/// State for tracking EPUB download progress
class EpubDownloadState {
  final bool isLoading;
  final double progress;
  final int downloadedBytes;
  final int totalBytes;
  final String? errorMessage;
  final String? epubFilePath;
  final bool isCached;
  final DateTime? lastDownloaded;

  EpubDownloadState({
    this.isLoading = false,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.errorMessage,
    this.epubFilePath,
    this.isCached = false,
    this.lastDownloaded,
  });

  EpubDownloadState copyWith({
    bool? isLoading,
    double? progress, 
    int? downloadedBytes,
    int? totalBytes,
    String? errorMessage,
    String? epubFilePath,
    bool? isCached,
    DateTime? lastDownloaded,
  }) {
    return EpubDownloadState(
      isLoading: isLoading ?? this.isLoading,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      errorMessage: errorMessage,
      epubFilePath: epubFilePath ?? this.epubFilePath,
      isCached: isCached ?? this.isCached,
      lastDownloaded: lastDownloaded ?? this.lastDownloaded,
    );
  }
}

/// Notifier for EPUB download state
class EpubNotifier extends StateNotifier<EpubDownloadState> {
  final EbookSectionsRepository _repository;
  final String storyId;
  final String title;
  
  EpubNotifier(this._repository, this.storyId, this.title) : super(EpubDownloadState()) {
    // Add this debug print to see if the notifier is being created
    print('EpubNotifier created for story: $storyId');
    _initialize();
  }
  
  /// Initialize by checking for cached EPUB
  Future<void> _initialize() async {
    print('Initializing EPUB download for story: $storyId');
    state = state.copyWith(isLoading: true);
    
    try {
      // Check if EPUB exists in cache
      final localPath = await _repository.getLocalEpubPath(storyId);
      print('Local path check result: $localPath');
      final lastDownloaded = await _repository.getLastDownloadDate(storyId);
      
      if (localPath != null) {
        print('Using cached EPUB: $localPath');
        // Use cached EPUB
        state = state.copyWith(
          epubFilePath: localPath,
          isLoading: false,
          isCached: true,
          lastDownloaded: lastDownloaded,
        );
      } else {
        print('No cached EPUB found, downloading...');
        // No cache - need to download EPUB
        await downloadEpub();
      }
    } catch (e) {
      print('Error in EPUB initialization: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  /// Download EPUB file from server
  Future<void> downloadEpub() async {
    print("Downloading EPUB for story: $storyId");
    
    // Start with loading state
    state = state.copyWith(
      isLoading: true,
      progress: 0.0,
      downloadedBytes: 0,
      errorMessage: null,
    );
    
    try {
      final epubPath = await _repository.downloadEpub(
        storyId,
        title,
        onProgress: (progress, bytes, total) {
          state = state.copyWith(
            progress: progress,
            downloadedBytes: bytes,
            totalBytes: total,
          );
        },
      );
      
      // Update state with the downloaded file path
      state = state.copyWith(
        epubFilePath: epubPath,
        isLoading: false,
        progress: 1.0,
        isCached: false,
        lastDownloaded: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }
  
  /// Delete cached EPUB file
  Future<void> deleteEpub() async {
    await _repository.deleteLocalEpub(storyId);
    state = state.copyWith(
      epubFilePath: null,
      isCached: false,
      lastDownloaded: null,
    );
  }
}

/// Provider for EPUB download
final epubProvider = StateNotifierProvider.family<EpubNotifier, EpubDownloadState, ({String id, String title})>(
  (ref, params) {
    final repository = ref.watch(ebookSectionsRepositoryProvider);
    return EpubNotifier(repository, params.id, params.title);
  },
);
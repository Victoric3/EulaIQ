import 'dart:async';
import 'package:eulaiq/src/features/audio/data/models/audio_model.dart';
import 'package:eulaiq/src/features/audio/data/repositories/audio_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioState {
  final bool isLoading;
  final String? errorMessage;
  final List<AudioCollection> audioCollections;
  final bool hasMoreData;
  final int currentPage;
  final Map<String, AudioGenerationStatus>? generationStatus;
  final Map<String, bool> segmentsAvailable; // Make this final for consistency

  AudioState({
    this.isLoading = false,
    this.errorMessage,
    this.audioCollections = const [],
    this.hasMoreData = true,
    this.currentPage = 1,
    this.generationStatus,
    this.segmentsAvailable =
        const {}, // Add it as a constructor parameter with default empty map
  });

  AudioState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<AudioCollection>? audioCollections,
    bool? hasMoreData,
    int? currentPage,
    Map<String, AudioGenerationStatus>? generationStatus,
    Map<String, bool>? segmentsAvailable,
  }) {
    return AudioState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      audioCollections: audioCollections ?? this.audioCollections,
      hasMoreData: hasMoreData ?? this.hasMoreData,
      currentPage: currentPage ?? this.currentPage,
      generationStatus: generationStatus ?? this.generationStatus,
      segmentsAvailable: segmentsAvailable ?? this.segmentsAvailable,
    );
  }
}

class AudioGenerationStatus {
  final String collectionId;
  final String status;
  final double progress;
  final String? processingStatus;
  final int audioCount;
  final String? error;
  final DateTime? lastUpdated;

  AudioGenerationStatus({
    required this.collectionId,
    required this.status,
    this.progress = 0.0,
    this.processingStatus,
    this.audioCount = 0,
    this.error,
    this.lastUpdated,
  });
}

class AudioNotifier extends StateNotifier<AudioState> {
  final AudioRepository _repository;
  final String ebookId;
  Timer? _statusCheckTimer;
  final Map<String, Timer> _collectionTimers = {};

  // Map to keep track of which collections have been checked for audio segments
  final Map<String, bool> _checkedForAudio = {};
  // Map to track last status for each collection
  final Map<String, String> _lastStatus = {};

  AudioNotifier(this._repository, this.ebookId) : super(AudioState());

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    // Cancel all collection timers
    for (var timer in _collectionTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  Future<void> fetchAudioCollections({bool refresh = false}) async {
    if (state.isLoading) return;

    // If refresh, reset page to 1, otherwise use current page
    final page = refresh ? 1 : state.currentPage;

    // Don't attempt to load more if we're not refreshing and there's no more data
    if (!refresh && !state.hasMoreData) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final collections = await _repository.fetchAudioCollections(
        ebookId,
        page: page,
        limit: 10,
      );

      // If refreshing, replace collections, otherwise append
      final updatedCollections =
          refresh ? collections : [...state.audioCollections, ...collections];

      // Check for processing collections and start status polling for them
      for (var collection in collections) {
        if (collection.uiStatus == 'generating') {
          _startStatusPolling(collection.id);
        }
      }

      state = state.copyWith(
        isLoading: false,
        audioCollections: updatedCollections,
        hasMoreData:
            collections.length ==
            10, // If we got fewer than requested, there's no more data
        currentPage: page + 1, // Increment page for next load
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load audio collections: $e',
      );
    }
  }

  Future<void> generateAudio({
    required String title,
    String? description,
    required List<String> voiceActors,
    required String speed,
    required String quality,
    required String module,
    String? chapterId,
    bool useGpt4o = false,
    String tone = 'Calm - Measured pacing with soothing, relaxed delivery',
  }) async {
    try {
      // Extract just the speed value from the string (e.g., "Normal (1.0x)" → "1.0x")
      String speedValue = speed.split('(').last.split(')').first;

      // Create the module description
      String moduleDescription = "Generate audio at ${speedValue} speed.";
      if (description != null && description.isNotEmpty) {
        moduleDescription += " " + description;
      }

      final result = await _repository.generateAudio(
        ebookId: ebookId,
        title: title,
        description: description,
        voiceActors: voiceActors,
        module: module,
        moduleDescription: moduleDescription,
        useGpt4oAudio: useGpt4o,
        tone: tone,
      );

      // Start polling for status immediately
      final collectionId = result['collectionId'];
      if (collectionId != null) {
        _startStatusPolling(collectionId);
      }

      return;
    } catch (e) {
      throw Exception('Failed to generate audio: $e');
    }
  }

  Future<void> continueAudioGeneration({
    required String collectionId,
    bool useGpt4o = false,
  }) async {
    try {

      await _repository.continueAudioGeneration(
        collectionId: collectionId,
        useGpt4oAudio: useGpt4o
      );

      // Start polling for status immediately
      _startStatusPolling(collectionId);

      return;
    } catch (e) {
      throw Exception('Failed to continue audio generation: $e');
    }
  }

  void _startStatusPolling(String collectionId) {
    // Cancel existing timer if there is one
    _collectionTimers[collectionId]?.cancel();

    // Create a new timer that checks status every 5 seconds
    _collectionTimers[collectionId] = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkAudioGenerationStatus(collectionId),
    );

    // Check immediately first time
    _checkAudioGenerationStatus(collectionId);
  }

  Future<void> _checkAudioGenerationStatus(String collectionId) async {
    try {
      final statusData = await _repository.checkAudioGenerationStatus(
        collectionId,
      );

      final currentStatus = statusData['status'] ?? 'processing';
      final lastStatus = _lastStatus[collectionId];

      // Update the generation status in state
      final generationStatusMap = state.generationStatus ?? {};
      final updatedStatus = Map<String, AudioGenerationStatus>.from(
        generationStatusMap,
      );

      updatedStatus[collectionId] = AudioGenerationStatus(
        collectionId: collectionId,
        status: currentStatus,
        progress: statusData['progress']?.toDouble() ?? 0.0,
        processingStatus: statusData['processingStatus'],
        audioCount: statusData['audioCount'] ?? 0,
        error: statusData['error'],
        lastUpdated: DateTime.now(),
      );

      state = state.copyWith(generationStatus: updatedStatus);

      // Check for audio segments if:
      // 1. Status has changed, OR
      // 2. We haven't checked for this collection yet
      if (currentStatus != lastStatus ||
          !_checkedForAudio.containsKey(collectionId)) {
        _lastStatus[collectionId] = currentStatus;
        await checkForAudioSegments(collectionId);
      }

      // If status is complete or error, stop polling
      if (currentStatus == 'complete' || currentStatus == 'error') {
        _collectionTimers[collectionId]?.cancel();
        _collectionTimers.remove(collectionId);

        // Check one last time for audio segments
        await checkForAudioSegments(collectionId);

        // Refresh collections to get the updated status
        fetchAudioCollections(refresh: true);
      }
    } catch (e) {
      print('Error checking audio generation status: $e');
    }
  }

  Future<void> checkForAudioSegments(String collectionId) async {
    try {
      // If we already know this collection has segments, skip the check
      if (state.segmentsAvailable[collectionId] == true) return;

      // Mark that we've checked this collection
      _checkedForAudio[collectionId] = true;

      final hasSegments = await _repository.checkAudioSegmentsAvailable(
        collectionId,
      );
      if (hasSegments) {
        // Update state with this info
        state = state.copyWith(
          segmentsAvailable: {...state.segmentsAvailable, collectionId: true},
        );
      } else {
        // Schedule a retry in 30 seconds
        Timer(const Duration(seconds: 30), () {
          // Safely check if segments are NOT available (value is either false or null)
          if (mounted && state.segmentsAvailable[collectionId] != true) {
            checkForAudioSegments(collectionId);
          }
        });
      }
    } catch (e) {
      print('Error checking audio segments for collection $collectionId: $e');
    }
  }

  Future<void> checkForStreamableSegments() async {
    // Check collections that are either in progress or completed
    final collections =
        state.audioCollections.toList();

    for (final collection in collections) {
      // If we already know segments are available, skip the check
      if (state.segmentsAvailable[collection.id] == true) continue;

      // Check for audio segments
      await checkForAudioSegments(collection.id);
    }
  }
}

// Define providers
final audioRepositoryProvider = Provider<AudioRepository>((ref) {
  return AudioRepository();
});

final audioProvider = StateNotifierProvider.family<
  AudioNotifier,
  AudioState,
  String
>((ref, ebookId) => AudioNotifier(ref.watch(audioRepositoryProvider), ebookId));

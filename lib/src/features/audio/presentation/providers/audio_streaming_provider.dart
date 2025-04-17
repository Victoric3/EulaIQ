import 'package:eulaiq/src/features/audio/data/models/audio_model.dart';
import 'package:eulaiq/src/features/audio/data/repositories/audio_repository.dart';
import 'package:eulaiq/src/features/audio/presentation/providers/audio_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioStreamingState {
  final bool isLoading;
  final String? errorMessage;
  final List<Audio> audioSegments;
  final AudioCollection? collection;

  AudioStreamingState({
    this.isLoading = false,
    this.errorMessage,
    this.audioSegments = const [],
    this.collection,
  });

  AudioStreamingState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<Audio>? audioSegments,
    AudioCollection? collection,
  }) {
    return AudioStreamingState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      audioSegments: audioSegments ?? this.audioSegments,
      collection: collection ?? this.collection,
    );
  }
}

class AudioStreamingNotifier extends StateNotifier<AudioStreamingState> {
  final AudioRepository _repository;
  final String collectionId;
  
  AudioStreamingNotifier(this._repository, this.collectionId)
      : super(AudioStreamingState());

  Future<void> loadAudioSegments() async {
    state = state.copyWith(isLoading: true);
    
    try {
      final audioSegments = await _repository.fetchAudiosByCollectionId(collectionId);
      
      // Test first audio URL to ensure streaming endpoint works
      if (audioSegments.isNotEmpty) {
        final testUrl = audioSegments.first.audioUrl;
        final connectionWorks = await _repository.testStreamingConnection(testUrl);
        
        if (!connectionWorks) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Streaming service is currently unavailable',
          );
          return;
        }
      }
      
      state = state.copyWith(
        isLoading: false,
        audioSegments: audioSegments,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load audio segments: $e',
      );
    }
  }
}

final audioStreamingProvider = StateNotifierProvider.family<AudioStreamingNotifier, AudioStreamingState, String>(
  (ref, collectionId) => AudioStreamingNotifier(ref.watch(audioRepositoryProvider), collectionId),
);
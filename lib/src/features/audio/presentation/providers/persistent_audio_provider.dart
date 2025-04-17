import 'package:eulaiq/src/features/audio/presentation/ui/screens/audio_streaming_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';  // This already imports RepeatMode
import 'package:eulaiq/src/features/audio/data/models/audio_model.dart';

class PersistentAudioState {
  final AudioPlayer player;
  final bool isPlaying;
  final bool isVisible;
  final Duration position;
  final Duration duration;
  final Audio? currentAudio;
  final String? collectionId;
  final String? collectionTitle;
  final String? collectionImageUrl;
  final int currentIndex;
  final List<Audio> playlist;
  final double playbackSpeed;
  final RepeatMode repeatMode;

  PersistentAudioState({
    required this.player,
    this.isPlaying = false,
    this.isVisible = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.currentAudio,
    this.collectionId,
    this.collectionTitle,
    this.collectionImageUrl,
    this.currentIndex = 0,
    this.playlist = const [],
    this.playbackSpeed = 1.0,
    this.repeatMode = RepeatMode.none,
  });

  PersistentAudioState copyWith({
    AudioPlayer? player,
    bool? isPlaying,
    bool? isVisible,
    Duration? position,
    Duration? duration,
    Audio? currentAudio,
    String? collectionId,
    String? collectionTitle,
    String? collectionImageUrl,
    int? currentIndex,
    List<Audio>? playlist,
    double? playbackSpeed,
    RepeatMode? repeatMode,
  }) {
    return PersistentAudioState(
      player: player ?? this.player,
      isPlaying: isPlaying ?? this.isPlaying,
      isVisible: isVisible ?? this.isVisible,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      currentAudio: currentAudio ?? this.currentAudio,
      collectionId: collectionId ?? this.collectionId,
      collectionTitle: collectionTitle ?? this.collectionTitle,
      collectionImageUrl: collectionImageUrl ?? this.collectionImageUrl,
      currentIndex: currentIndex ?? this.currentIndex,
      playlist: playlist ?? this.playlist,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      repeatMode: repeatMode ?? this.repeatMode,
    );
  }
}

class PersistentAudioNotifier extends StateNotifier<PersistentAudioState> {
  PersistentAudioNotifier() 
      : super(PersistentAudioState(player: AudioPlayer())) {
    _initializeListeners();
  }

  void _initializeListeners() {
    state.player.playerStateStream.listen((playerState) {
      state = state.copyWith(
        isPlaying: playerState.playing,
      );
    });

    state.player.positionStream.listen((position) {
      state = state.copyWith(
        position: position,
      );
    });

    state.player.durationStream.listen((duration) {
      if (duration != null) {
        state = state.copyWith(
          duration: duration,
        );
      }
    });

    state.player.processingStateStream.listen((processingState) {
      if (processingState == ProcessingState.completed) {
        _handlePlaybackCompletion();
      }
    });
  }

  void _handlePlaybackCompletion() {
    switch (state.repeatMode) {
      case RepeatMode.none:
        playNext();
        break;
      case RepeatMode.single:
        playAudio(state.currentIndex);
        break;
      case RepeatMode.all:
        if (state.currentIndex >= state.playlist.length - 1) {
          playAudio(0);
        } else {
          playNext();
        }
        break;
    }
  }

  Future<void> playAudio(int index) async {
    if (index < 0 || index >= state.playlist.length) return;

    final audio = state.playlist[index];
    
    try {
      await state.player.stop();
      
      // Setup the new audio (local or streaming)
      // This part would depend on your existing audio download/streaming logic
      
      state = state.copyWith(
        currentAudio: audio,
        currentIndex: index,
        isVisible: true,
      );
      
      await state.player.play();
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  void togglePlayPause() {
    if (state.isPlaying) {
      state.player.pause();
    } else {
      state.player.play();
    }
  }

  void playNext() {
    if (state.currentIndex < state.playlist.length - 1) {
      playAudio(state.currentIndex + 1);
    } else if (state.repeatMode == RepeatMode.all) {
      playAudio(0);
    }
  }

  void playPrevious() {
    if (state.player.position > const Duration(seconds: 3)) {
      // If more than 3 seconds have passed, go to the beginning of the current track
      state.player.seek(Duration.zero);
    } else if (state.currentIndex > 0) {
      // Otherwise go to the previous track
      playAudio(state.currentIndex - 1);
    }
  }

  void setPlaybackSpeed(double speed) {
    state.player.setSpeed(speed);
    state = state.copyWith(playbackSpeed: speed);
  }

  void setRepeatMode(RepeatMode mode) {
    state = state.copyWith(repeatMode: mode);
  }

  void showPlayer() {
    state = state.copyWith(isVisible: true);
  }

  void hidePlayer() {
    state = state.copyWith(isVisible: false);
  }

  void loadPlaylist({
    required List<Audio> playlist, 
    required String collectionId,
    required String collectionTitle,
    String? collectionImageUrl,
    int startIndex = 0,
  }) {
    state = state.copyWith(
      playlist: playlist,
      collectionId: collectionId,
      collectionTitle: collectionTitle,
      collectionImageUrl: collectionImageUrl,
      currentIndex: startIndex,
    );
    
    // Start playing the selected audio
    playAudio(startIndex);
  }

  @override
  void dispose() {
    state.player.dispose();
    super.dispose();
  }
}

final persistentAudioProvider = StateNotifierProvider<PersistentAudioNotifier, PersistentAudioState>((ref) {
  return PersistentAudioNotifier();
});
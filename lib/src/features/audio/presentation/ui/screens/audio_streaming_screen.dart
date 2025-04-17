import 'dart:math';
import 'package:auto_route/auto_route.dart';
import 'package:eulaiq/src/common/common.dart';
import 'package:eulaiq/src/common/services/notification_service.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:eulaiq/src/common/widgets/notification_card.dart';
import 'package:eulaiq/src/features/audio/data/models/audio_model.dart';
import 'package:eulaiq/src/features/audio/presentation/providers/audio_provider.dart';
import 'package:eulaiq/src/features/audio/presentation/providers/audio_streaming_provider.dart';
import 'package:eulaiq/src/features/audio/presentation/providers/persistent_audio_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import 'package:eulaiq/src/features/audio/presentation/providers/audio_download_provider.dart';
import 'dart:io';
import 'dart:async';

enum RepeatMode {
  none,
  all,    
  single, 
}

@RoutePage()
class AudioStreamingScreen extends ConsumerStatefulWidget {
  final String collectionId;
  final String title;
  final String? imageUrl;
  final bool fromMiniPlayer;

  const AudioStreamingScreen({
    Key? key,
    required this.collectionId,
    required this.title,
    this.imageUrl,
    this.fromMiniPlayer = false,
  }) : super(key: key);

  @override
  ConsumerState<AudioStreamingScreen> createState() => _AudioStreamingScreenState();
}

class _AudioStreamingScreenState extends ConsumerState<AudioStreamingScreen> with SingleTickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  int _currentIndex = 0;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackSpeed = 1.0;

  late AnimationController _expansionController;
  late Animation<double> _expansionAnimation;
  bool _isExpanded = false;

  double _startValue = 0.0;
  double _dragStartPosition = 0.0;
  final double threshold = 200.0;

  RepeatMode _repeatMode = RepeatMode.none;

  bool _showTranscript = false;
  ScrollController _transcriptScrollController = ScrollController();

  bool _showMoreOptions = false;
  final GlobalKey _moreActionsKey = GlobalKey();

  int _currentSegmentIndex = 0;
  Timer? _transcriptHighlightTimer;
  Map<String, List<Map<String, dynamic>>> _segmentedTranscripts = {};

  @override
  void initState() {
    super.initState();
    
    if (!widget.fromMiniPlayer) {
      _audioPlayer = AudioPlayer();
      _setupAudioPlayerListeners();
      _loadAudioSegments();
    } else {
      _audioPlayer = ref.read(persistentAudioProvider).player;
      final persistentState = ref.read(persistentAudioProvider);
      _currentIndex = persistentState.currentIndex;
      _playbackSpeed = persistentState.playbackSpeed;
      _repeatMode = persistentState.repeatMode;
      _isPlaying = persistentState.isPlaying;
      _position = persistentState.position;
      _duration = persistentState.duration;
      _loadAudioSegments(skipPreload: true);
    }

    _setupUIAnimations();
  }

  Future<void> _loadAudioSegments({bool skipPreload = false}) async {
    await ref.read(audioStreamingProvider(widget.collectionId).notifier).loadAudioSegments();
    
    if (mounted) {
      final audioState = ref.read(audioStreamingProvider(widget.collectionId));
      if (audioState.audioSegments.isNotEmpty) {
        if (!widget.fromMiniPlayer) {
          setState(() {
            _currentIndex = 0;
          });
          if (!skipPreload) {
            await _preloadAudio(audioState.audioSegments[0]);
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _transcriptHighlightTimer?.cancel();
    _transcriptScrollController.dispose();
    if (!widget.fromMiniPlayer) {
      _audioPlayer.dispose();
    }
    _expansionController.dispose();
    super.dispose();
  }

  void _setupUIAnimations() {
    _expansionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expansionAnimation = CurvedAnimation(
      parent: _expansionController,
      curve: Curves.easeInOut,
    );

    _expansionController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isExpanded = true;
        });
      } else if (status == AnimationStatus.dismissed) {
        setState(() {
          _isExpanded = false;
        });
      }
    });
  }

  void _setupAudioPlayerListeners() {
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });

    _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
          _updateCurrentSegment(position);
        });
      }
    });

    _audioPlayer.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _duration = duration;
        });
      }
    });

    _audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        switch (_repeatMode) {
          case RepeatMode.none:
            _playNext();
            break;
          case RepeatMode.single:
            _playAudio(_currentIndex);
            break;
          case RepeatMode.all:
            final audioState = ref.read(audioStreamingProvider(widget.collectionId));
            if (_currentIndex >= audioState.audioSegments.length - 1) {
              _playAudio(0);
            } else {
              _playNext();
            }
            break;
        }
      }
    });
  }

  Future<void> _playAudio(int index) async {
    final audioState = ref.read(audioStreamingProvider(widget.collectionId));
    if (audioState.isLoading || audioState.audioSegments.isEmpty) return;

    if (index >= 0 && index < audioState.audioSegments.length) {
      final audio = audioState.audioSegments[index];
      final audioId = audio.id ?? '';

      try {
        await _audioPlayer.stop();

        setState(() {
          _currentIndex = index;
          _currentSegmentIndex = 0;
        });
        
        _prepareTranscriptSegments(audio);

        final downloadState = ref.read(audioDownloadProvider);
        final localPath = downloadState.downloadedFiles[audioId];

        if (localPath != null && File(localPath).existsSync()) {
          await _audioPlayer.setFilePath(localPath);
        } else {
          final streamingUrl = ref.read(audioRepositoryProvider).getStreamingUrl(audio.audioUrl);
          await _audioPlayer.setUrl(
            streamingUrl,
            headers: { 
              'Accept': '*/*'
            },
          ).timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('Connection timed out. Please try again.'),
          );
        }

        await _audioPlayer.setSpeed(_playbackSpeed);
        await _audioPlayer.play();
        
        final persistentPlayer = ref.read(persistentAudioProvider.notifier);
        persistentPlayer.loadPlaylist(
          playlist: audioState.audioSegments,
          collectionId: widget.collectionId,
          collectionTitle: widget.title,
          collectionImageUrl: widget.imageUrl,
          startIndex: index,
        );
        
      } catch (e) {
        ref.read(audioDownloadProvider.notifier).setStreamingStatus(audioId, false);
        
        ref.read(notificationServiceProvider).showNotification(
          message: 'Failed to play audio: $e',
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _preloadAudio(Audio audio) async {
    try {
      final downloadState = ref.read(audioDownloadProvider);
      final localPath = downloadState.downloadedFiles[audio.id];

      if (localPath != null && File(localPath).existsSync()) {
        await _audioPlayer.setFilePath(localPath);
      } else {
        final streamingUrl = ref.read(audioRepositoryProvider).getStreamingUrl(audio.audioUrl);
        await _audioPlayer.setUrl(
          streamingUrl,
          headers: {
            'Cache-Control': 'no-cache',
            'Accept': '*/*'
          },
        );
      }
      
      await _audioPlayer.setSpeed(_playbackSpeed);
    } catch (e) {
      print('Error preloading audio: $e');
    }
  }

  void _playNext() {
    final audioState = ref.read(audioStreamingProvider(widget.collectionId));
    if (_currentIndex < audioState.audioSegments.length - 1) {
      _playAudio(_currentIndex + 1);
    } else if (_repeatMode == RepeatMode.all) {
      _playAudio(0);
    }
  }

  void _playPrevious() {
    if (_currentIndex > 0) {
      _playAudio(_currentIndex - 1);
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
  }

  void _toggleTranscript() {
    setState(() {
      _showTranscript = !_showTranscript;
    });
    
    if (_showTranscript) {
      Future.delayed(Duration(milliseconds: 350), () {
        if (mounted) _scrollToCurrentSegment();
      });
      
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _changePlaybackSpeed() async {
    final speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
    final currentIndex = speeds.indexOf(_playbackSpeed);
    final nextIndex = (currentIndex + 1) % speeds.length;

    _playbackSpeed = speeds[nextIndex];
    await _audioPlayer.setSpeed(_playbackSpeed);
    setState(() {});
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  void _toggleExpansion() {
    if (_isExpanded) {
      _expansionController.reverse();
    } else {
      _expansionController.forward();
    }
    
    // Optional: add haptic feedback
    HapticFeedback.lightImpact();
  }

  void _showCollectionDetails(BuildContext context, bool isDark, AudioCollection? collection, List<Audio> episodes) {
    final scrimColor = Colors.black.withOpacity(0.5);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: scrimColor,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.7,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              color: isDark ? AppColors.darkBg : Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white30 : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'About This Collection',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.grey[850] : Colors.grey[200],
                                  ),
                                  child: collection?.imageUrl != null || widget.imageUrl != null
                                      ? CachedNetworkImage(
                                          imageUrl: widget.imageUrl ?? collection!.imageUrl!,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => _buildPlaceholderImage(isDark),
                                          errorWidget: (context, url, error) => _buildPlaceholderImage(isDark),
                                        )
                                      : _buildPlaceholderImage(isDark),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.title,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${episodes.length} Episodes',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Total Duration: ${_formatTotalDuration(episodes)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          if (collection?.description != null && collection!.description!.isNotEmpty) ...[
                            Text(
                              'Description',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              collection.description!,
                              style: TextStyle(
                                fontSize: 15,
                                color: isDark ? Colors.white70 : Colors.black87,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          Text(
                            'Episodes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...episodes.map((episode) {
                            final isCurrentlyPlaying = _isPlaying && episodes.indexOf(episode) == _currentIndex;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isCurrentlyPlaying
                                        ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                                        : (isDark ? Colors.white10 : Colors.grey.shade100),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: isCurrentlyPlaying
                                        ? Icon(
                                            Icons.equalizer_rounded,
                                            color: isDark ? Colors.black : Colors.white,
                                          )
                                        : Text(
                                            '${episodes.indexOf(episode) + 1}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white70 : Colors.grey.shade700,
                                            ),
                                          ),
                                  ),
                                ),
                                title: Text(
                                  episode.title,
                                  style: TextStyle(
                                    fontWeight: isCurrentlyPlaying ? FontWeight.bold : FontWeight.normal,
                                    color: isCurrentlyPlaying
                                        ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                                        : (isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                                subtitle: Text(
                                  _formatDuration(Duration(seconds: episode.audioDuration)),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white54 : Colors.black54,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    isCurrentlyPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    if (isCurrentlyPlaying) {
                                      _togglePlayPause();
                                    } else {
                                      _playAudio(episodes.indexOf(episode));
                                    }
                                  },
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  _playAudio(episodes.indexOf(episode));
                                },
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTotalDuration(List<Audio> episodes) {
    int totalSeconds = episodes.fold(0, (total, episode) => total + episode.audioDuration);
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  void _runDiagnostics() async {
    try {
      final audioState = ref.read(audioStreamingProvider(widget.collectionId));
      if (audioState.audioSegments.isEmpty) {
        ref.read(notificationServiceProvider).showNotification(
          message: 'No audio segments available to test',
          type: NotificationType.warning,
        );
        return;
      }

      final audio = audioState.audioSegments[_currentIndex];
      final audioUrl = audio.audioUrl;

      ref.read(notificationServiceProvider).showNotification(
        message: 'Running connection diagnostics...',
        type: NotificationType.info,
      );

      final results = await ref.read(audioRepositoryProvider).testEndpointConnections(audioUrl);

      if (results['streamStatus'] == 200) {
        ref.read(notificationServiceProvider).showNotification(
            message: 'Streaming endpoint is working properly',
          type: NotificationType.success,
        );
      }

      if (results['streamStatus'] != 200) {
        ref.read(notificationServiceProvider).showNotification(
          message: 'Streaming endpoint issue: Network error',
          type: NotificationType.error,
        );
      }
    } catch (e) {
      ref.read(notificationServiceProvider).showNotification(
        message: 'Diagnostic error: $e',
        type: NotificationType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final audioState = ref.watch(audioStreamingProvider(widget.collectionId));
    final mediaQuery = MediaQuery.of(context);
    final collection = audioState.collection;
    final albumArtSize = mediaQuery.size.width * (0.7 - (_expansionAnimation.value * 0.3));

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.grey[50],
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  widget.fromMiniPlayer ? Icons.keyboard_arrow_down : Icons.arrow_back,
                  color: isDark ? Colors.white : Colors.black87,
                  size: 22,
                ),
                onPressed: () => context.router.pop(),
              ),
            ),
          ),
        ),
        actions: [
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.playlist_add,
                    color: isDark ? Colors.white : Colors.black87,
                    size: 22,
                  ),
                  onPressed: () {
                    _showDownloadAllDialog(isDark, audioState);
                  },
                  tooltip: 'Download All Episodes',
                ),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    MdiIcons.folderDownload,
                    color: isDark ? Colors.white : Colors.black87,
                    size: 22,
                  ),
                  onPressed: () {
                    context.router.push(const DownloadsRoute());
                  },
                  tooltip: 'View Downloads',
                ),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.info,
                    color: isDark ? Colors.white : Colors.black87,
                    size: 22,
                  ),
                  onPressed: () {
                    _showCollectionDetails(context, isDark, collection, audioState.audioSegments);
                  },
                ),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: isDark ? Colors.white : Colors.black87,
                    size: 22,
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (context) => _buildOptionsSheet(isDark),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      body: audioState.isLoading && audioState.audioSegments.isEmpty
          ? _buildLoadingState(isDark)
          : audioState.audioSegments.isEmpty
              ? _buildEmptyState(isDark)
              : Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isDark
                              ? [Colors.black, AppColors.darkBg]
                              : [AppColors.brandDeepGold.withOpacity(0.1), Colors.white],
                          stops: const [0.0, 0.7],
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Column(
                        children: [
                          Expanded(
                            child: AnimatedBuilder(
                              animation: _expansionAnimation,
                              builder: (context, child) {
                                return Column(
                                  children: [
                                    Expanded(
                                      flex: _isExpanded ? 3 : 5,
                                      child: Center(
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Container(
                                              width: albumArtSize,
                                              height: albumArtSize,
                                              decoration: BoxDecoration(
                                                color: isDark ? Colors.grey[900] : Colors.white,
                                                borderRadius: BorderRadius.circular(20),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.2),
                                                    blurRadius: 20,
                                                    offset: const Offset(0, 10),
                                                  ),
                                                ],
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(20),
                                                child: widget.imageUrl != null
                                                    ? CachedNetworkImage(
                                                        imageUrl: widget.imageUrl!,
                                                        fit: BoxFit.cover,
                                                        placeholder: (context, url) => _buildPlaceholderImage(isDark),
                                                        errorWidget: (context, url, error) => _buildPlaceholderImage(isDark),
                                                      )
                                                    : collection?.imageUrl != null
                                                        ? CachedNetworkImage(
                                                            imageUrl: collection!.imageUrl!,
                                                            fit: BoxFit.cover,
                                                            placeholder: (context, url) => _buildPlaceholderImage(isDark),
                                                            errorWidget: (context, url, error) => _buildPlaceholderImage(isDark),
                                                          )
                                                        : _buildPlaceholderImage(isDark),
                                              ),
                                            ),
                                            if (!_isExpanded)
                                              Positioned.fill(
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    borderRadius: BorderRadius.circular(20),
                                                    onTap: _togglePlayPause,
                                                    child: AnimatedOpacity(
                                                      opacity: _isPlaying ? 0.0 : 0.8,
                                                      duration: const Duration(milliseconds: 200),
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          color: Colors.black26,
                                                          borderRadius: BorderRadius.circular(20),
                                                        ),
                                                        child: Center(
                                                          child: Icon(
                                                            Icons.play_arrow_rounded,
                                                            size: albumArtSize * 0.3,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (audioState.audioSegments.isNotEmpty && _currentIndex < audioState.audioSegments.length && !_isExpanded)
                                      Container(
                                        height: 40,
                                        padding: const EdgeInsets.symmetric(horizontal: 24),
                                        child: Center(
                                          child: Text(
                                            audioState.audioSegments[_currentIndex].title,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    Container(
                                      height: 40,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Row(
                                        children: [
                                          Text(
                                            _formatDuration(_position),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? Colors.white60 : Colors.black54,
                                            ),
                                          ),
                                          Expanded(
                                            child: SliderTheme(
                                              data: SliderThemeData(
                                                trackHeight: 4,
                                                thumbShape: RoundSliderThumbShape(enabledThumbRadius: _isExpanded ? 4 : 6),
                                                overlayShape: RoundSliderOverlayShape(overlayRadius: _isExpanded ? 8 : 14),
                                                activeTrackColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                                                inactiveTrackColor: isDark ? Colors.white12 : Colors.grey.shade200,
                                                thumbColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                                                overlayColor: (isDark ? AppColors.neonCyan : AppColors.brandDeepGold).withOpacity(0.2),
                                              ),
                                              child: Slider(
                                                value: _position.inSeconds.toDouble(),
                                                min: 0,
                                                max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                                                onChanged: (value) {
                                                  _audioPlayer.seek(Duration(seconds: value.toInt()));
                                                },
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _formatDuration(_duration),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? Colors.white60 : Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      height: _isExpanded ? 60 : 80,
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(horizontal: _isExpanded ? 16 : 24),
                                        child: _isExpanded ? _buildCompactControls(isDark) : _buildFullControls(isDark, audioState),
                                      ),
                                    ),
                                    Container(
                                    height: _isExpanded ? 400 : 130,
                                    child: _buildEpisodesList(isDark, audioState),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (audioState.audioSegments.isNotEmpty && _currentIndex < audioState.audioSegments.length)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _buildTranscriptPanel(isDark, audioState.audioSegments[_currentIndex]),
                      ),
                  ],
                ),
    );
  }

  Widget _buildOptionsSheet(bool isDark) {
    final audioState = ref.read(audioStreamingProvider(widget.collectionId));
    if (audioState.audioSegments.isEmpty || _currentIndex >= audioState.audioSegments.length) {
      return const SizedBox();
    }

    final audio = audioState.audioSegments[_currentIndex];
    final downloadState = ref.watch(audioDownloadProvider);
    final isDownloaded = downloadState.downloadedFiles.containsKey(audio.id);
    final isDownloading = downloadState.downloadProgress.containsKey(audio.id);
    final downloadProgress = downloadState.downloadProgress[audio.id]?.progress ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              audio.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.share,
              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            ),
            title: Text(
              'Share audio',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              ref.read(notificationServiceProvider).showNotification(
                message: 'Sharing not implemented yet',
                type: NotificationType.info,
              );
            },
          ),
          ListTile(
            leading: Icon(
              isDownloaded ? Icons.delete : MdiIcons.download,
              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            ),
            title: Text(
              isDownloaded ? 'Delete downloaded audio' : 'Download for offline',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: isDownloading
                ? LinearProgressIndicator(
                    value: downloadProgress,
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(isDark ? AppColors.neonCyan : AppColors.brandDeepGold),
                  )
                : null,
            onTap: isDownloading
                ? null
                : () {
                    Navigator.pop(context);
                    if (isDownloaded) {
                      _showDeleteConfirmation(isDark, audio.id ?? '', audio.title);
                    } else {
                      _downloadAudio(audio);
                    }
                  },
          ),
          ListTile(
            leading: Icon(
              Icons.info,
              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            ),
            title: Text(
              'About this collection',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _showCollectionDetails(context, isDark, audioState.collection, audioState.audioSegments);
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.bug_report,
              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            ),
            title: Text(
              'Run connection diagnostics',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _runDiagnostics();
            },
          ),
          ListTile(
            leading: Icon(
              Icons.download_for_offline,
              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            ),
            title: Text(
              'Download All Audio',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _showDownloadAllDialog(isDark, audioState);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage(bool isDark) {
    return Container(
      color: isDark ? Colors.grey[850] : Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.music_note,
          size: 64,
          color: isDark ? Colors.white24 : Colors.black26,
        ),
      ),
    );
  }

  Widget _buildCompactControls(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: _playbackSpeed != 1.0
                ? (isDark
                    ? AppColors.neonCyan.withOpacity(0.15)
                    : AppColors.brandDeepGold.withOpacity(0.1))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _playbackSpeed != 1.0
                  ? (isDark
                      ? AppColors.neonCyan.withOpacity(0.5)
                      : AppColors.brandDeepGold.withOpacity(0.3))
                  : Colors.transparent,
            ),
          ),
          child: InkWell(
            onTap: _changePlaybackSpeed,
            borderRadius: BorderRadius.circular(16),
            child: Text(
              '${_playbackSpeed}x',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _playbackSpeed != 1.0
                    ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous),
              onPressed: _currentIndex > 0 ? _playPrevious : null,
              iconSize: 24,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              color: _currentIndex > 0
                  ? (isDark ? Colors.white : Colors.black87)
                  : (isDark ? Colors.white30 : Colors.grey.shade300),
            ),
            Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isDark
                      ? [AppColors.neonCyan, const Color(0xFF00BFA5)]
                      : [AppColors.brandDeepGold, const Color(0xFFD4AF37)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                        .withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 24,
                ),
                padding: EdgeInsets.zero,
                color: isDark ? Colors.black : Colors.white,
                onPressed: _togglePlayPause,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.skip_next),
              onPressed: _currentIndex < (ref.read(audioStreamingProvider(widget.collectionId)).audioSegments.length - 1)
                  ? _playNext
                  : null,
              iconSize: 24,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              color: _currentIndex < (ref.read(audioStreamingProvider(widget.collectionId)).audioSegments.length - 1)
                  ? (isDark ? Colors.white : Colors.black87)
                  : (isDark ? Colors.white30 : Colors.grey.shade300),
            ),
          ],
        ),
        Container(
          key: _moreActionsKey,
          padding: const EdgeInsets.all(4),
          child: IconButton(
            icon: Icon(
              MdiIcons.dotsVertical,
              color: (_showMoreOptions || _repeatMode != RepeatMode.none || _showTranscript)
                  ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            onPressed: _showMoreActionsMenu,
          ),
        ),
      ],
    );
  }

  void _showMoreActionsMenu() {
    final RenderBox renderBox = _moreActionsKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    setState(() {
      _showMoreOptions = true;
    });
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + renderBox.size.height,
        position.dx + renderBox.size.width,
        position.dy + renderBox.size.height + 200,
      ),
      color: isDark ? Colors.grey[850] : Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(
          padding: const EdgeInsets.all(6),
          child: ListTile(
            leading: Icon(
              _repeatMode == RepeatMode.single 
                  ? Icons.repeat_one
                  : Icons.repeat,
              color: _repeatMode != RepeatMode.none
                  ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
            title: Text(
              'Repeat Mode',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              _repeatMode == RepeatMode.none 
                  ? 'Off' 
                  : _repeatMode == RepeatMode.all 
                      ? 'All Episodes' 
                      : 'Current Episode',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _showRepeatModeOptions();
            },
          ),
        ),
        PopupMenuItem(
          padding: const EdgeInsets.all(6),
          child: ListTile(
            leading: Icon(
              Icons.subtitles,
              color: _showTranscript
                  ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
            title: Text(
              'Transcript',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              _showTranscript ? 'Visible' : 'Hidden',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _toggleTranscript();
            },
          ),
        ),
        PopupMenuItem(
          padding: const EdgeInsets.all(6),
          child: ListTile(
            leading: Icon(
              Icons.alarm,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            title: Text(
              'Sleep Timer',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _showSleepTimerOptions();
            },
          ),
        ),
      ],
    ).then((_) {
      setState(() {
        _showMoreOptions = false;
      });
    });
  }

  void _showRepeatModeOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[850] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              'Repeat Mode',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.repeat,
              color: _repeatMode == RepeatMode.none 
                  ? Colors.grey
                  : Colors.transparent,
            ),
            title: const Text('No Repeat'),
            trailing: _repeatMode == RepeatMode.none ? Icon(
              Icons.check,
              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            ) : null,
            onTap: () {
              setState(() {
                _repeatMode = RepeatMode.none;
              });
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.repeat,
              color: _repeatMode == RepeatMode.all 
                  ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold) 
                  : Colors.grey,
            ),
            title: const Text('Repeat All'),
            trailing: _repeatMode == RepeatMode.all ? Icon(
              Icons.check,
              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            ) : null,
            onTap: () {
              setState(() {
                _repeatMode = RepeatMode.all;
              });
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.repeat_one,
              color: _repeatMode == RepeatMode.single 
                  ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold) 
                  : Colors.grey,
            ),
            title: const Text('Repeat One'),
            trailing: _repeatMode == RepeatMode.single ? Icon(
              Icons.check,
              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            ) : null,
            onTap: () {
              setState(() {
                _repeatMode = RepeatMode.single;
              });
              Navigator.pop(context);
            },
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  void _showSleepTimerOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = [
      'None',
      '5 minutes',
      '15 minutes',
      '30 minutes',
      '45 minutes',
      '1 hour',
    ];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[850] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              'Sleep Timer',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const Divider(),
          ...options.map((option) => ListTile(
            title: Text(option),
            onTap: () {
              Navigator.pop(context);
              if (option != 'None') {
                ref.read(notificationServiceProvider).showNotification(
                  message: 'Sleep timer set for $option',
                  type: NotificationType.info,
                );
              }
            },
          )),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildFullControls(bool isDark, AudioStreamingState audioState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _playbackSpeed != 1.0
                  ? (isDark
                      ? AppColors.neonCyan.withOpacity(0.2)
                      : AppColors.brandDeepGold.withOpacity(0.1))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_playbackSpeed}x',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _playbackSpeed != 1.0
                    ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ),
          onPressed: _changePlaybackSpeed,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
        ),
        IconButton(
          icon: const Icon(Icons.skip_previous),
          onPressed: _currentIndex > 0 ? _playPrevious : null,
          iconSize: 36,
          visualDensity: VisualDensity.compact,
          color: _currentIndex > 0
              ? (isDark ? Colors.white : Colors.black87)
              : (isDark ? Colors.white30 : Colors.grey.shade300),
        ),
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: isDark
                  ? [AppColors.neonCyan, const Color(0xFF00BFA5)]
                  : [AppColors.brandDeepGold, const Color(0xFFD4AF37)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    (isDark ? AppColors.neonCyan : AppColors.brandDeepGold).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              size: 36,
            ),
            color: isDark ? Colors.black : Colors.white,
            onPressed: _togglePlayPause,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next),
          onPressed: _playNext,
          iconSize: 36,
          visualDensity: VisualDensity.compact,
          color: _currentIndex < audioState.audioSegments.length - 1
              ? (isDark ? Colors.white : Colors.black87)
              : (isDark ? Colors.white30 : Colors.grey.shade300),
        ),
        Container(
          key: _moreActionsKey,
          padding: const EdgeInsets.all(4),
          child: IconButton(
            icon: Icon(
              MdiIcons.dotsVertical,
              color: (_showMoreOptions || _repeatMode != RepeatMode.none || _showTranscript)
                  ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            onPressed: _showMoreActionsMenu,
          ),
        ),
      ],
    );
  }

  Widget _buildEpisodesList(bool isDark, AudioStreamingState audioState) {
    final downloadState = ref.watch(audioDownloadProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onVerticalDragStart: (details) {
            _dragStartPosition = details.globalPosition.dy;
            _startValue = _expansionController.value;
            _expansionController.stop();
            HapticFeedback.lightImpact();
          },
          onVerticalDragUpdate: (details) {
            double currentPosition = details.globalPosition.dy;
            double delta = _dragStartPosition - currentPosition;
            if (delta > 0 && _expansionController.value < 1) {
              double progress = delta / threshold;
              _expansionController.value = min(1, _startValue + progress);
            } else if (delta < 0 && _expansionController.value > 0) {
              double progress = -delta / threshold;
              _expansionController.value = max(0, _startValue - progress);
            }
          },
          onVerticalDragEnd: (details) {
            if (_expansionController.value > 0.5 || details.velocity.pixelsPerSecond.dy < -500) {
              _expansionController.forward();
            } else {
              _expansionController.reverse();
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withOpacity(0.5) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 30,
                  alignment: Alignment.center,
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                SizedBox(
                  height: 36,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Text(
                          'Episodes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.neonCyan.withOpacity(0.1) : AppColors.brandDeepGold.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${audioState.audioSegments.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            _isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          onPressed: _toggleExpansion,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ),
                Flexible(
                  child: _isExpanded
                    ? ListView.builder(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
                        itemCount: audioState.audioSegments.length,
                        itemBuilder: (context, index) {
                          final audio = audioState.audioSegments[index];
                          final isPlaying = _isPlaying && index == _currentIndex;
                          final isDownloaded = downloadState.downloadedFiles.containsKey(audio.id);
                          final isDownloading = downloadState.downloadProgress.containsKey(audio.id);
                          final downloadProgress = downloadState.downloadProgress[audio.id]?.progress ?? 0.0;

                          return _buildEpisodeCard(
                            isDark,
                            audio,
                            index,
                            isPlaying,
                            isDownloaded,
                            isDownloading,
                            downloadProgress,
                          );
                        },
                      )
                    : audioState.audioSegments.isNotEmpty 
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(0, 2, 0, 2),
                          child: _buildEpisodeCard(
                            isDark,
                            audioState.audioSegments[_currentIndex],
                            _currentIndex,
                            _isPlaying,
                            downloadState.downloadedFiles.containsKey(audioState.audioSegments[_currentIndex].id),
                            downloadState.downloadProgress.containsKey(audioState.audioSegments[_currentIndex].id),
                            downloadState.downloadProgress[audioState.audioSegments[_currentIndex].id]?.progress ?? 0.0,
                          ),
                        )
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEpisodeCard(
  bool isDark,
  Audio audio,
  int index,
  bool isPlaying,
  bool isDownloaded,
  bool isDownloading,
  double downloadProgress,
) {
  final String audioId = audio.id ?? '';
  final isStreaming = ref.watch(audioDownloadProvider).currentlyStreaming.contains(audioId);
  
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    color: isPlaying 
        ? (isDark ? AppColors.neonCyan.withOpacity(0.1) : AppColors.brandDeepGold.withOpacity(0.05)) 
        : isDark ? Colors.black38 : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        width: isPlaying ? 1 : 0,
        color: isPlaying 
            ? (isDark ? AppColors.neonCyan.withOpacity(0.5) : AppColors.brandDeepGold.withOpacity(0.5)) 
            : Colors.transparent,
      ),
    ),
    elevation: 0,
    child: InkWell(
      onTap: isStreaming ? null : () => _playAudio(index),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white10 : Colors.grey.shade100),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isStreaming
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                              ),
                            ),
                          )
                        : isPlaying
                            ? const Icon(
                                Icons.pause,
                                color: Colors.white,
                                size: 18,
                              )
                            : Text(
                                (index + 1).toString(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isPlaying
                                      ? Colors.white
                                      : (isDark ? AppColors.neonCyan : AppColors.brandDeepGold),
                                ),
                              ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        audio.title.length > 28 ? audio.title.substring(0, min(audio.title.length, 28)) + '...' : audio.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                          color: isPlaying
                              ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDuration(Duration(seconds: audio.audioDuration)),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: isDownloaded
                      ? BoxDecoration(
                          color: isDark
                              ? AppColors.neonCyan.withOpacity(0.1)
                              : AppColors.brandDeepGold.withOpacity(0.1),
                          shape: BoxShape.circle,
                        )
                      : null,
                  child: isDownloading
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: downloadProgress,
                              backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation(
                                isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                              ),
                              strokeWidth: 2,
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 12),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                ref.read(audioDownloadProvider.notifier).cancelDownload(audio.id ?? '');
                              },
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ],
                        )
                      : IconButton(
                          icon: Icon(
                            isDownloaded ? Icons.check : MdiIcons.download,
                            size: isDownloaded ? 18 : 20,
                          ),
                          onPressed: isDownloaded ? null : () => _downloadAudio(audio),
                          color: isDownloaded
                              ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                              : (isDark ? Colors.white60 : Colors.black54),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                ),
              ],
            ),
          ),
          if (isDownloading)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: LinearProgressIndicator(
                value: downloadProgress,
                minHeight: 2,
                backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation(
                  isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
          ),
          const SizedBox(height: 24),
          Text(
            'Loading audio...',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white70 : Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
              Icons.music_off,
              size: 80,
              color: isDark ? Colors.white24 : Colors.black12,
            ),
            const SizedBox(height: 24),
            Text(
              'No Episodes Available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Audio episodes for this content are not yet available. Please check back later.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 40),
            TextButton.icon(
              icon: Icon(
                Icons.refresh,
                color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
              ),
              label: Text(
                'Refresh',
                style: TextStyle(
                  color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                ref.read(audioStreamingProvider(widget.collectionId).notifier).loadAudioSegments();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _downloadAudio(Audio audio) {
    final String audioId = audio.id ?? '';
    
    ref.read(audioDownloadProvider.notifier).setStreamingStatus(audioId, false);
    
    ref.read(notificationServiceProvider).showNotification(
      message: 'Downloading "${audio.title}"...',
      type: NotificationType.info,
    );

    ref.read(audioDownloadProvider.notifier).downloadAudio(audio);
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
            child: const Text(
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

  Widget _buildTranscriptPanel(bool isDark, Audio audio) {
    final segments = _segmentedTranscripts[audio.id ?? "unknown"] ?? [];
    final String fallbackText = audio.text ?? 'No transcript available for this audio.';
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _showTranscript ? MediaQuery.of(context).size.height * 0.4 : 0,
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.9) : Colors.white.withOpacity(0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.subtitles,
                  size: 18,
                  color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                ),
                const SizedBox(width: 8),
                Text(
                  'Transcript',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  color: isDark ? Colors.white70 : Colors.black54,
                  onPressed: () => setState(() => _showTranscript = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: segments.isNotEmpty 
              ? _buildSegmentedTranscript(segments, isDark)
              : _buildSimpleTranscript(fallbackText, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTranscript(List<Map<String, dynamic>> segments, bool isDark) {
    return Scrollbar(
      controller: _transcriptScrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _transcriptScrollController,
        padding: const EdgeInsets.all(16),
        itemCount: segments.length,
        itemBuilder: (context, index) {
          final isCurrentSegment = index == _currentSegmentIndex && _isPlaying;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCurrentSegment 
                  ? (isDark 
                      ? AppColors.neonCyan.withOpacity(0.15) 
                      : AppColors.brandDeepGold.withOpacity(0.1))
                  : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCurrentSegment
                      ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Text(
                segments[index]["text"] as String,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: isCurrentSegment
                      ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                      : (isDark ? Colors.white : Colors.black87),
                  fontWeight: isCurrentSegment ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSimpleTranscript(String text, bool isDark) {
    return Scrollbar(
      controller: _transcriptScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _transcriptScrollController,
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  void _prepareTranscriptSegments(Audio audio) {
    _segmentedTranscripts.clear();

    if (audio.segments.isEmpty) {
      if (audio.text != null && audio.text!.isNotEmpty) {
        _segmentedTranscripts[audio.id ?? "unknown"] = [
          {
            "text": audio.text!,
            "start": 0,
            "end": audio.audioDuration,
          }
        ];
      }
      return;
    }

    List<Map<String, dynamic>> processedSegments = [];
    
    double startTime = 0;
    for (int i = 0; i < audio.segments.length; i++) {
      final segment = audio.segments[i];
      
      if (segment.text != null && segment.text!.isNotEmpty) {
        processedSegments.add({
          "text": segment.text!,
          "start": startTime,
          "end": startTime + segment.duration,
          "index": i,
        });
      }
      
      startTime += segment.duration;
    }
    
    _segmentedTranscripts[audio.id ?? "unknown"] = processedSegments;
  }

  void _updateCurrentSegment(Duration position) {
    final audioState = ref.read(audioStreamingProvider(widget.collectionId));
    if (audioState.audioSegments.isEmpty || _currentIndex >= audioState.audioSegments.length) {
      return;
    }
    
    final audio = audioState.audioSegments[_currentIndex];
    final segments = _segmentedTranscripts[audio.id ?? "unknown"] ?? [];
    
    if (segments.isEmpty) return;
    
    final positionSeconds = position.inMilliseconds / 1000;
    
    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final start = segment["start"] as double;
      final end = segment["end"] as double;
      
      if (positionSeconds >= start && positionSeconds < end) {
        if (_currentSegmentIndex != i) {
          setState(() {
            _currentSegmentIndex = i;
          });
          
          if (_showTranscript) {
            _scrollToCurrentSegment();
          }
        }
        break;
      }
    }
  }

  void _scrollToCurrentSegment() {
    if (!_showTranscript || _transcriptScrollController.positions.isEmpty) return;
    
    final itemHeight = 70.0;
    final viewportHeight = MediaQuery.of(context).size.height * 0.4 - 80;
    final scrollPosition = (_currentSegmentIndex * itemHeight) - (viewportHeight / 2) + (itemHeight / 2);
    
    _transcriptScrollController.animateTo(
      max(0, scrollPosition),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _showDownloadAllDialog(bool isDark, AudioStreamingState audioState) {
    final segmentsCount = audioState.audioSegments.length;
    final downloadState = ref.read(audioDownloadProvider);
    
    final downloadedCount = audioState.audioSegments
        .where((audio) => downloadState.downloadedFiles.containsKey(audio.id))
        .length;
    
    final remainingCount = segmentsCount - downloadedCount;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          'Download All Audio',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              remainingCount > 0
                  ? 'Download all $remainingCount remaining audio segments in this collection?'
                  : 'All audio segments in this collection are already downloaded.',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            if (downloadedCount > 0)
              Text(
                '$downloadedCount segments already downloaded.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black45,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
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
          if (remainingCount > 0)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _downloadAllAudio(audioState.audioSegments);
              },
              child: Text(
                'Download All',
                style: TextStyle(
                  color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _downloadAllAudio(List<Audio> audios) {
    ref.read(notificationServiceProvider).showNotification(
      message: 'Starting download of ${audios.length} audio segments...',
      type: NotificationType.info,
    );
    
    ref.read(audioDownloadProvider.notifier).downloadAllAudioInCollection(audios);
    
    _showDownloadAllProgressDialog();
  }

  void _showDownloadAllProgressDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final downloadState = ref.watch(audioDownloadProvider);
          
          if (!downloadState.isDownloadingAll && context.mounted) {
            Future.delayed(Duration.zero, () {
              Navigator.of(context).pop();
            });
          }
          
          return AlertDialog(
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            title: Text(
              'Downloading Audio Collection',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (downloadState.currentDownloadingTitle != null)
                  Text(
                    'Downloading: ${downloadState.currentDownloadingTitle}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: downloadState.downloadAllProgress,
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation(isDark ? AppColors.neonCyan : AppColors.brandDeepGold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Progress: ${downloadState.downloadedItemsCount}/${downloadState.totalItemsToDownload} segments',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  ref.read(audioDownloadProvider.notifier).cancelDownloadAll();
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
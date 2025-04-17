import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:eulaiq/src/common/common.dart';
import 'package:eulaiq/src/common/services/notification_service.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:eulaiq/src/common/widgets/notification_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:eulaiq/src/features/audio/data/models/audio_model.dart';
import 'package:eulaiq/src/features/audio/presentation/providers/audio_provider.dart';
import 'package:shared_preferences/shared_preferences.dart' as prefs;


@RoutePage()
class AudioScreen extends ConsumerStatefulWidget {
  final String ebookId;
  final String? title;
  final String? imageUrl;

  const AudioScreen({
    Key? key, 
    required this.ebookId,
    this.title,
    this.imageUrl,
  }) : super(key: key);

  @override
  ConsumerState<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends ConsumerState<AudioScreen> {
  // Audio player
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // UI state variables
  bool _isGenerating = false;
  bool _showCompleted = true;
  bool _showGenerating = true;
  bool _showFailed = false;
  
  // Generation options
  // Replace the existing voice options list with these generic names
  final List<String> _voiceOptions = [
    'Professional', 'Casual', 'Narrator', 'Reporter', 'Friendly', 
    'Storyteller', 'Deep', 'Clear', 'Gentle', 'Crisp'
  ];
  String _primaryVoice = 'Clear'; // Default primary voice
  String _secondaryVoice = 'Deep'; // Default secondary voice
  bool _useSecondaryVoice = false; // Toggle for using secondary voice

  // Add this method to map friendly voice names to API voice identifiers
  String _mapVoiceToApiName(String friendlyVoiceName) {
    switch (friendlyVoiceName) {
      case 'Professional': return 'alloy';
      case 'Casual': return 'ash';
      case 'Narrator': return 'ballad';
      case 'Reporter': return 'coral';
      case 'Friendly': return 'echo';
      case 'Storyteller': return 'fable';
      case 'Deep': return 'onyx';
      case 'Clear': return 'nova';
      case 'Gentle': return 'sage';
      case 'Crisp': return 'shimmer';
      default: return 'nova';
    }
  }
  
  final List<String> _speedOptions = [
    'Very Slow (0.75x)',
    'Slow (0.9x)',
    'Normal (1.0x)',
    'Fast (1.1x)',
    'Very Fast (1.25x)'
  ];
  String _selectedSpeed = 'Normal (1.0x)';
  
  // Audio collections (placeholders)
  Timer? _refreshTimer;
  
  // Text controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Add this field to _AudioScreenState class
  final List<String> _moduleOptions = [
    'Direct_Reading_Style',
    'Simply_Explained_Style',
    'Conversational_Podcast_Style',
    'Narrative_Storytelling_Style',
    'Lecture_Explanation_Style',
    'Interview_Style',
    'Socratic_Dialogue_Style',
  ];

  // Add a user-friendly display name mapping
  final Map<String, String> _moduleDisplayNames = {
    'Direct_Reading_Style': 'None',
    'Simply_Explained_Style': 'Simply Explained',
    'Conversational_Podcast_Style': 'Conversational Podcast',
    'Narrative_Storytelling_Style': 'Narrative Storytelling',
    'Lecture_Explanation_Style': 'Lecture Style',
    'Interview_Style': 'Interview Format',
    'Socratic_Dialogue_Style': 'Socratic Dialogue',
  };

  String _selectedModule = 'Simply_Explained_Style';

  late prefs.SharedPreferences _prefs;

  // In _AudioScreenState class, add this field to track expanded descriptions
  final Map<String, bool> _expandedDescriptions = {};

  // Add these properties to your _AudioScreenState class
  final Map<String, String> _tonePrompts = {
    'Calm': 'Calm - Measured pacing with soothing, relaxed delivery. Use gentle intonation and natural pauses.',
    'Enthusiastic': 'Enthusiastic - Energetic and passionate delivery with dynamic vocal range. Express excitement about concepts.',
    'Professional': 'Professional - Clear, authoritative, and formal tone. Maintain consistent pacing with precise articulation.',
    'Educational': 'Educational - Explanatory tone that breaks down complex topics. Use thoughtful pacing with emphasis on key terms.',
    'Engaging': 'Engaging - Captivating style that maintains listener attention. Vary tone to highlight important points.',
    'Clear': 'Clear - Highly articulate and straightforward delivery. Focus on clarity and comprehension above all else.',
    'Instructional': 'Instructional - Step-by-step explanatory style. Use clear transitions between concepts with guiding language.',
    'Authoritative': 'Authoritative - Confident, expert-level delivery. Present information with conviction and deep knowledge.',
    'Conversational': 'Conversational - Natural, friendly with casual inflections. Speak as if explaining to a friend.',
    'Motivational': 'Motivational - Inspiring and encouraging tone. Use positive language with an emphasis on possibilities.'
  };

  final List<String> _toneOptions = [
    'Calm',
    'Enthusiastic',
    'Professional',
    'Educational',
    'Engaging',
    'Clear',
    'Instructional',
    'Authoritative',
    'Conversational',
    'Motivational'
  ];
  String _selectedTone = 'Calm';

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.title ?? 'New Audio Generation';
    
    // Load saved preferences
    _loadSavedPreferences();
    
    // Schedule data fetching for after the build is complete
    Future.microtask(() {
      // Load existing audio collections
      _loadAudioCollections();
    });
    
    // Start a refresh timer to check generation status
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_showGenerating) {
        _loadAudioCollections();
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  // Replace the current _loadAudioCollections method with this:
Future<void> _loadAudioCollections({bool refresh = false}) async {
  try {
    await ref.read(audioProvider(widget.ebookId).notifier).fetchAudioCollections(refresh: refresh);
    
    // After fetching collections, also check for streamable segments
    await ref.read(audioProvider(widget.ebookId).notifier).checkForStreamableSegments();
  } catch (e) {
    // Show error notification
    ref.read(notificationServiceProvider).showNotification(
      message: 'Failed to load audio collections: $e',
      type: NotificationType.error,
    );
  }
}

// Add this method in the _AudioScreenState class to handle retry functionality
Future<void> _retryAudioGeneration(String collectionId) async {
  setState(() {
    _isGenerating = true;
  });
  
  try {
    // Show notification
    ref.read(notificationServiceProvider).showNotification(
      message: 'Restarting audio generation...',
      type: NotificationType.info,
    );
    
    // Call the provider to continue audio generation
    await ref.read(audioProvider(widget.ebookId).notifier).continueAudioGeneration(
      collectionId: collectionId,
      useGpt4o: true,
    );
    
    // Make sure "Generating" filter is enabled so user can see the restarted item
    setState(() {
      _showGenerating = true;
    });
    
    // Refresh immediately to update status
    await _loadAudioCollections(refresh: true);
    
    ref.read(notificationServiceProvider).showNotification(
      message: 'Audio generation restarted successfully',
      type: NotificationType.success,
    );
    
  } catch (e) {
    ref.read(notificationServiceProvider).showNotification(
      message: 'Failed to restart audio generation: $e',
      type: NotificationType.error,
    );
  } finally {
    setState(() {
      _isGenerating = false;
    });
  }
}

// Update the _generateAudio method to map the UI tone to the API tone
Future<void> _generateAudio() async {
  if (_isGenerating) return;
  
  final title = _titleController.text.trim();
  if (title.isEmpty) {
    ref.read(notificationServiceProvider).showNotification(
      message: 'Please enter a title for the audio',
      type: NotificationType.warning,
    );
    return;
  }
  
  setState(() {
    _isGenerating = true;
  });
  
  try {
    // Show notification
    ref.read(notificationServiceProvider).showNotification(
      message: 'Starting advanced audio generation...',
      type: NotificationType.info,
    );
    
    // Map the friendly voice names to API voice names
    final primaryApiVoice = _mapVoiceToApiName(_primaryVoice);
    
    // Create voice array - include secondary voice if enabled
    final List<String> voiceActors = _useSecondaryVoice 
      ? [primaryApiVoice, _mapVoiceToApiName(_secondaryVoice)]
      : [primaryApiVoice];
    
    // For Direct Reading Style, pass null as description
    String? description = _selectedModule == 'Direct_Reading_Style' 
        ? null 
        : _descriptionController.text;
    
    // Map the selected tone to its full API prompt
    final String fullTonePrompt = _tonePrompts[_selectedTone] ?? 
        'Calm - Measured pacing with soothing, relaxed delivery';
    
    // Call the provider to generate audio
    await ref.read(audioProvider(widget.ebookId).notifier).generateAudio(
      title: title,
      description: description,
      voiceActors: voiceActors,
      speed: _selectedSpeed,
      quality: 'Premium',
      module: _selectedModule,
      useGpt4o: true,
      tone: fullTonePrompt,  // Use the full prompt here
    );
    
    setState(() {
      _showGenerating = true;
      _titleController.text = '';
      _descriptionController.text = '';
    });
    
    // Refresh immediately to show the new generating item
    await _loadAudioCollections(refresh: true);
    
    ref.read(notificationServiceProvider).showNotification(
      message: 'Audio generation started successfully',
      type: NotificationType.success,
    );
    
  } catch (e) {
    ref.read(notificationServiceProvider).showNotification(
      message: 'Failed to start audio generation: $e',
      type: NotificationType.error,
    );
  } finally {
    setState(() {
      _isGenerating = false;
    });
  }
}
  // Update the build method to use the provider data
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Watch the audio provider
    final audioState = ref.watch(audioProvider(widget.ebookId));
    final audioCollections = audioState.audioCollections;

    // Check if there are any streamable segments in ANY collection
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Audio Generation'),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(MdiIcons.refresh),
            onPressed: () => _loadAudioCollections(refresh: true),
            tooltip: 'Refresh Audio Collections',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with eBook title - existing code
          if (widget.title != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: isDark 
                ? Colors.black.withOpacity(0.3) 
                : AppColors.brandDeepGold.withOpacity(0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'eBook:',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.title!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          
          // Main content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadAudioCollections(refresh: true),
              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
              child: audioState.isLoading && audioCollections.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Filters row
                      _buildFiltersRow(isDark),
                      
                      const SizedBox(height: 16),
                      
                      // Audio collections
                      ..._buildAudioCollections(isDark, audioCollections, widget.imageUrl),
                      
                      // Loading indicator for pagination
                      if (audioState.isLoading && audioCollections.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                              ),
                            ),
                          ),
                        ),
                      
                      // Empty state
                      if (audioCollections.isEmpty && !audioState.isLoading)
                        _buildEmptyState(isDark),
                      
                      // Load more button if there's more data
                      if (audioState.hasMoreData && audioCollections.isNotEmpty && !audioState.isLoading)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0, bottom: 32.0),
                          child: Center(
                            child: TextButton.icon(
                              onPressed: () => _loadAudioCollections(),
                              icon: Icon(
                                Icons.more_horiz,
                                color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                              ),
                              label: Text(
                                'Load More',
                                style: TextStyle(
                                  color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      
                      // Bottom padding
                      const SizedBox(height: 100),
                    ],
                  ),
            ),
          ),
        ],
      ),
      // FAB to generate audio - existing code
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isGenerating ? null : _showGenerateAudioBottomSheet,
        backgroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
        foregroundColor: isDark ? Colors.black : Colors.white,
        icon: _isGenerating 
            ? const SizedBox(
                width: 18, 
                height: 18, 
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Icon(MdiIcons.waveform),
        label: Text(_isGenerating ? 'Generating...' : 'Generate Audio'),
      ),
    );
  }

  Widget _buildFiltersRow(bool isDark) {
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    physics: const BouncingScrollPhysics(),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          FilterChip(
            selected: _showCompleted,
            label: const Text('Completed'),
            avatar: Icon(
              MdiIcons.checkCircleOutline,
              size: 16,
              color: _showCompleted ? Colors.white : Colors.green,
            ),
            onSelected: (value) {
              setState(() {
                _showCompleted = value;
              });
            },
            backgroundColor: isDark ? Colors.black26 : Colors.grey.shade100,
            selectedColor: Colors.green,
            labelStyle: TextStyle(
              color: _showCompleted ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: _showCompleted ? FontWeight.bold : FontWeight.normal,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: _showCompleted ? Colors.transparent : Colors.green.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            selected: _showGenerating,
            label: const Text('Generating'),
            avatar: Icon(
              MdiIcons.progressClock,
              size: 16,
              color: _showGenerating ? Colors.white : Colors.blue,
            ),
            onSelected: (value) {
              setState(() {
                _showGenerating = value;
              });
            },
            backgroundColor: isDark ? Colors.black26 : Colors.grey.shade100,
            selectedColor: Colors.blue,
            labelStyle: TextStyle(
              color: _showGenerating ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: _showGenerating ? FontWeight.bold : FontWeight.normal,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: _showGenerating ? Colors.transparent : Colors.blue.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            selected: _showFailed,
            label: const Text('Failed'),
            avatar: Icon(
              MdiIcons.alertCircleOutline,
              size: 16,
              color: _showFailed ? Colors.white : Colors.red,
            ),
            onSelected: (value) {
              setState(() {
                _showFailed = value;
              });
            },
            backgroundColor: isDark ? Colors.black26 : Colors.grey.shade100,
            selectedColor: Colors.red,
            labelStyle: TextStyle(
              color: _showFailed ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: _showFailed ? FontWeight.bold : FontWeight.normal,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: _showFailed ? Colors.transparent : Colors.red.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  // Update the _buildAudioCollections method to include a streaming button on each card

List<Widget> _buildAudioCollections(bool isDark, List<AudioCollection> audioCollections, String? imageUrl) {
  final filteredCollections = audioCollections.where((audio) {
    final status = audio.uiStatus;
    if (status == 'completed') return _showCompleted;
    if (status == 'generating') return _showGenerating;
    if (status == 'failed') return _showFailed;
    return false;
  }).toList();
  
  if (filteredCollections.isEmpty) {
    return [];
  }
  
  return [
    ...filteredCollections.map((audio) {
      final status = audio.uiStatus;
      final id = audio.id;
      
      // Get real-time status updates if available
      final generationStatus = ref.watch(audioProvider(widget.ebookId)).generationStatus;
      final realtimeStatus = generationStatus != null ? generationStatus[id] : null;
      
      // Check if this collection has available audio segments
      final hasAudioSegments = ref.watch(audioProvider(widget.ebookId)).segmentsAvailable[id] == true;
      
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.black38 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: status == 'failed'
              ? Colors.red.withOpacity(0.3)
              : status == 'generating'
                ? Colors.blue.withOpacity(0.3)
                : isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.all(12),
              title: Text(
                audio.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (audio.description != null && audio.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedCrossFade(
                            firstChild: Text(
                              audio.description!,
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            secondChild: Text(
                              audio.description!,
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            crossFadeState: _expandedDescriptions[audio.id] == true 
                                ? CrossFadeState.showSecond 
                                : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 200),
                          ),
                          if (audio.description!.length > 80) // Only show toggle for longer descriptions
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _expandedDescriptions[audio.id] = !(_expandedDescriptions[audio.id] ?? false);
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _expandedDescriptions[audio.id] == true ? 'Show less' : 'Show more',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                                      ),
                                    ),
                                    Icon(
                                      _expandedDescriptions[audio.id] == true 
                                          ? Icons.keyboard_arrow_up 
                                          : Icons.keyboard_arrow_down,
                                      size: 14,
                                      color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                  // Status row
                  Row(
                    children: [
                      Icon(
                        status == 'completed' 
                          ? MdiIcons.checkCircleOutline
                          : status == 'generating'
                            ? MdiIcons.progressClock
                            : MdiIcons.alertCircleOutline,
                        size: 16,
                        color: status == 'completed'
                          ? Colors.green
                          : status == 'generating'
                            ? Colors.blue
                            : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status.capitalize(),
                        style: TextStyle(
                          fontSize: 12,
                          color: status == 'completed'
                            ? Colors.green
                            : status == 'generating'
                              ? Colors.blue
                              : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Creation date
                      Icon(
                        MdiIcons.clockOutline,
                        size: 14,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(audio.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                      
                      // Duration for completed audios - use totalDuration helper
                      if (status == 'completed' && audio.totalDuration > 0) ...[
                        const SizedBox(width: 12),
                        Icon(
                          MdiIcons.timerOutline,
                          size: 14,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(audio.totalDuration),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  // Processing status display for generating items
                  if (status == 'generating' && realtimeStatus?.processingStatus != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Text(
                        realtimeStatus!.processingStatus!,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  
                  // Progress bar for generating status
                  if (status == 'generating')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(
                        value: realtimeStatus?.progress != null && realtimeStatus!.progress > 0
                          ? realtimeStatus.progress / 100 // Convert percentage to 0-1 range
                          : null, // Indeterminate if no progress data
                        backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                        ),
                      ),
                    ),
                      
                  // Error message for failed status
                  if (status == 'failed')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Error: ${audio.error ?? realtimeStatus?.error ?? 'Audio generation failed'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
              // Always show streaming button but with appropriate state
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: hasAudioSegments 
                        ? Icon(MdiIcons.playCircleOutline, size: 18)
                        : const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                    label: Text(hasAudioSegments ? 'Stream Audio' : 'Preparing Audio...'),
                    onPressed: hasAudioSegments ? () => _navigateToAudioStreaming(id, audio.title, imageUrl) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark 
                          ? (hasAudioSegments ? AppColors.neonCyan : Colors.grey.shade700)
                          : (hasAudioSegments ? AppColors.brandDeepGold : Colors.grey.shade400),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: hasAudioSegments ? 1 : 0,
                    ),
                  ),
                ),
              ),
              
            // Retry button for failed items - more prominent than just the icon
            if (status == 'failed')
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(MdiIcons.refresh, size: 18),
                    label: const Text('Retry Generation'),
                    onPressed: () => _retryAudioGeneration(id),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: isDark ? Colors.red.shade700 : Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }),
  ];
}

// Update _showGenerateAudioBottomSheet to include tone selection
void _showGenerateAudioBottomSheet() {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  
  // Create local variables for the bottom sheet
  String primaryVoice = _primaryVoice;
  String secondaryVoice = _secondaryVoice;
  bool useSecondaryVoice = _useSecondaryVoice;
  String selectedSpeed = _selectedSpeed;
  String selectedModule = _selectedModule;
  String selectedTone = _selectedTone;  // Add this line
  
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBg : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Generate Audio',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create high-quality audio for your eBook',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ],
                  ),
                ),
                
                const Divider(),
                
                // Form content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title field
                        Text(
                          'Title',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            hintText: 'Enter a title for the audio',
                            fillColor: isDark ? Colors.black38 : Colors.grey.shade100,
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white12 : Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                          ),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Description field - conditional based on selected module
                        if (_selectedModule != 'Direct_Reading_Style') ...[
                          Text(
                            'Description (Optional)',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: InputDecoration(
                              hintText: 'Add a description',
                              fillColor: isDark ? Colors.black38 : Colors.grey.shade100,
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                            ),
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 3,
                          ),
                          
                          const SizedBox(height: 24),
                        ],

                        // Advanced audio info card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark 
                              ? Colors.indigo.shade900.withOpacity(0.2)
                              : Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.indigo.shade800 : Colors.indigo.shade200,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                MdiIcons.informationOutline,
                                color: Colors.indigo,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'About Advanced Audio Generation',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: isDark ? Colors.indigo.shade300 : Colors.indigo.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Your audio will be generated using our premium AI system for highest quality results. This provides natural intonation, realistic pauses, and better handling of complex text.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.white70 : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Speed selection
                        Text(
                          'Speed',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black38 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedSpeed,
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                              isExpanded: true,
                              dropdownColor: isDark ? Colors.grey.shade900 : Colors.white,
                              items: _speedOptions.map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setModalState(() {
                                    selectedSpeed = newValue;
                                  });
                                  setState(() {
                                    _selectedSpeed = newValue;
                                  });
                                  _savePreferences();
                                }
                              },
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),

                        // Module Style selection
                        Text(
                          'Audio Style',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black38 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedModule,
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                              isExpanded: true,
                              dropdownColor: isDark ? Colors.grey.shade900 : Colors.white,
                              items: _moduleOptions.map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    _moduleDisplayNames[value] ?? value,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setModalState(() {
                                    selectedModule = newValue;
                                  });
                                  setState(() {
                                    _selectedModule = newValue;
                                  });
                                  _savePreferences();
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          selectedModule == 'Direct_Reading_Style' 
                            ? 'Direct reading without styling or modifications'
                            : selectedModule,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),

                        // Primary voice selection
                        Text(
                          'Voice Actor',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black38 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: primaryVoice,
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                              isExpanded: true,
                              dropdownColor: isDark ? Colors.grey.shade900 : Colors.white,
                              items: _voiceOptions.map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setModalState(() {
                                    primaryVoice = newValue;
                                  });
                                  setState(() {
                                    _primaryVoice = newValue;
                                  });
                                  _savePreferences();
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Main voice for your audio narration',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Secondary voice section with toggle
                        Row(
                          children: [
                            Text(
                              'Secondary Voice Actor',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const Spacer(),
                            Switch(
                              value: useSecondaryVoice,
                              onChanged: (value) {
                                setModalState(() {
                                  useSecondaryVoice = value;
                                });
                                setState(() {
                                  _useSecondaryVoice = value;
                                });
                                _savePreferences();
                              },
                              activeColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Opacity(
                          opacity: useSecondaryVoice ? 1.0 : 0.5,
                          child: IgnorePointer(
                            ignoring: !useSecondaryVoice,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black38 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: secondaryVoice,
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: isDark ? Colors.white54 : Colors.black54,
                                  ),
                                  isExpanded: true,
                                  dropdownColor: isDark ? Colors.grey.shade900 : Colors.white,
                                  items: _voiceOptions.map<DropdownMenuItem<String>>((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(
                                        value,
                                        style: TextStyle(
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setModalState(() {
                                        secondaryVoice = newValue;
                                      });
                                      setState(() {
                                        _secondaryVoice = newValue;
                                      });
                                      _savePreferences();
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (useSecondaryVoice) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Used for dialogue and secondary content',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],

                        // Tone selection
                        const SizedBox(height: 20),
                        Text(
                          'Tone Style',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black38 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedTone,
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                              isExpanded: true,
                              dropdownColor: isDark ? Colors.grey.shade900 : Colors.white,
                              items: _toneOptions.map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setModalState(() {
                                    selectedTone = newValue;
                                  });
                                  setState(() {
                                    _selectedTone = newValue;
                                  });
                                  _savePreferences();
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Select the emotional style of the narration',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                        
                      ],
                    ),
                  ),
                ),
                
                // Bottom button
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).viewPadding.bottom),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black38 : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _generateAudio();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _isGenerating ? 'Generating...' : 'Generate Audio',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(
              MdiIcons.musicNoteOff,
              size: 80,
              color: isDark ? Colors.white24 : Colors.black12,
            ),
            const SizedBox(height: 16),
            Text(
              'No Audio Collections',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate your first audio by clicking the button below',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} min ago';
      }
      return '${difference.inHours} hrs ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatDuration(int seconds) {
    final Duration duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes;
    final remainingSeconds = duration.inSeconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // Add method to load saved preferences
  Future<void> _loadSavedPreferences() async {
  try {
    _prefs = await prefs.SharedPreferences.getInstance();

    setState(() {
      // Load voice preferences
      _primaryVoice = _prefs.getString('primary_voice') ?? 'Clear';
      _secondaryVoice = _prefs.getString('secondary_voice') ?? 'Deep';
      _useSecondaryVoice = _prefs.getBool('use_secondary_voice') ?? false;
      
      // Load speed preference
      _selectedSpeed = _prefs.getString('selected_speed') ?? 'Normal (1.0x)';
      
      // Load module/style preference
      _selectedModule = _prefs.getString('selected_module') ?? 'Simply_Explained_Style';
      
      // Load tone preference
      _selectedTone = _prefs.getString('selected_tone') ?? 'Calm';
    });
  } catch (e) {
    // Fail silently - just use defaults
    print('Failed to load preferences: $e');
  }
}

  // Update _savePreferences method
  Future<void> _savePreferences() async {
    try {
      await _prefs.setString('primary_voice', _primaryVoice);
      await _prefs.setString('secondary_voice', _secondaryVoice);
      await _prefs.setBool('use_secondary_voice', _useSecondaryVoice);
      await _prefs.setString('selected_speed', _selectedSpeed);
      await _prefs.setString('selected_module', _selectedModule);
      await _prefs.setString('selected_tone', _selectedTone);  // Add this line
    } catch (e) {
      // Fail silently
      print('Failed to save preferences: $e');
    }
  }

  // Add this method to navigate to the streaming UI for a specific collection

Future<void> _navigateToAudioStreaming(String collectionId, String title, String? imageUrl) async {
  try {
    // First check if there are actually audio segments available
    final hasAudio = await ref.read(audioRepositoryProvider).checkAudioSegmentsAvailable(collectionId);
    
    if (!hasAudio) {
      ref.read(notificationServiceProvider).showNotification(
        message: 'No audio segments available yet. Please wait...',
        type: NotificationType.info,
      );
      
      // Update the segmentsAvailable state to reflect this
      ref.read(audioProvider(widget.ebookId).notifier).checkForAudioSegments(collectionId);
      return;
    }
    
    // Navigate to audio streaming screen
    await context.router.push(
      AudioStreamingRoute(
        collectionId: collectionId,
        title: title,
        imageUrl: imageUrl,
      ),
    );
  } catch (e) {
    ref.read(notificationServiceProvider).showNotification(
      message: 'Failed to start audio streaming: $e',
      type: NotificationType.error,
    );
  }
}
}

// Extension to capitalize the first letter of a string
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
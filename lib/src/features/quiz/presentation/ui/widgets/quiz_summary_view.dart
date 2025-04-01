import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:eulaiq/src/common/constants/dio_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:eulaiq/src/features/quiz/presentation/providers/quiz_summary_provider.dart';
import 'package:lottie/lottie.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:eulaiq/src/common/services/notification_service.dart';

import '../../../../../common/widgets/notification_card.dart';

class QuizSummaryView extends ConsumerStatefulWidget {
  final String ebookId;

  const QuizSummaryView({Key? key, required this.ebookId}) : super(key: key);

  @override
  ConsumerState<QuizSummaryView> createState() => _QuizSummaryViewState();
}

class _QuizSummaryViewState extends ConsumerState<QuizSummaryView> {
  bool _isGeneratingQuestions = false;
  CancelToken? _generationCancelToken;
  String? _generatingExamId;
  Timer? _statusCheckTimer;
  bool _isProcessingDialogMinimized = false;
  String _processingStatus = "Starting generation...";
  int _processingProgress = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(quizSummaryProvider(widget.ebookId).notifier)
          .fetchQuizSummary(widget.ebookId);
    });
  }

  @override
  void dispose() {
    _generationCancelToken?.cancel('Widget disposed');
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(quizSummaryProvider(widget.ebookId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Quiz Summary',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.auto_awesome,
              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            ),
            onPressed: () => _showGenerateConfirmDialog(context, isDark),
          ),
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            onPressed: () {
              ref
                  .read(quizSummaryProvider(widget.ebookId).notifier)
                  .fetchQuizSummary(widget.ebookId);
            },
          ),
        ],
      ),
      body: _buildBody(state, isDark),
      floatingActionButton:
          _isGeneratingQuestions && _isProcessingDialogMinimized
              ? FloatingActionButton(
                onPressed: () {
                  setState(() {
                    _isProcessingDialogMinimized = false;
                  });
                  _showProcessingDialog(context, isDark);
                },
                backgroundColor:
                    isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                child: Stack(
                  children: [
                    const Icon(Icons.auto_awesome),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                        child: const Text(
                          '',
                          style: TextStyle(fontSize: 8),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              )
              : null,
    );
  }

  void _showGenerateConfirmDialog(BuildContext context, bool isDark) {
    final state = ref.read(quizSummaryProvider(widget.ebookId));
    final String ebookTitle = state.data?['ebookTitle'] ?? 'Unknown Book';
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final nameController = TextEditingController(
      text: 'Questions for $ebookTitle ($timestamp)',
    );

    String difficulty = 'Medium';
    String questionType = 'mcq';
    int duration = 60; // Added missing variable declaration
    bool useAdvancedOptions = false; // Added missing variable declaration
    const String defaultDescription =
        'Generate multiple-choice questions that thoroughly cover all key concepts, nuances, and intricate details of the content. The questions should be structured to be difficult, with tempting but incorrect answer choices that challenge deep understanding. Ensure all aspects of the material are addressed, leaving no major concept untouched.'; // Added missing constant
    final additionalQueryController =
        TextEditingController(); // Added missing controller

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  backgroundColor: isDark ? AppColors.darkBg : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color:
                          isDark
                              ? AppColors.neonCyan.withOpacity(0.3)
                              : AppColors.brandDeepGold.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  title: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color:
                            isDark
                                ? AppColors.neonCyan
                                : AppColors.brandDeepGold,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'Generate New Questions',
                          style: TextStyle(overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Exam Name',
                            hintText: 'Enter a name for this question set',
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Difficulty',
                          ),
                          value: difficulty,
                          items: const [
                            DropdownMenuItem(
                              value: 'Easy',
                              child: Text('Easy'),
                            ),
                            DropdownMenuItem(
                              value: 'Medium',
                              child: Text('Medium'),
                            ),
                            DropdownMenuItem(
                              value: 'Hard',
                              child: Text('Hard'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                difficulty = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Question Type',
                          ),
                          value: questionType,
                          items: const [
                            DropdownMenuItem(
                              value: 'mcq',
                              child: Text('Multiple Choice'),
                            ),
                            DropdownMenuItem(
                              value: 'tf',
                              child: Text('True/False'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                questionType = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Time Per Question (seconds): $duration',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        Slider(
                          value: duration.toDouble(),
                          min: 15,
                          max: 180,
                          divisions: 11,
                          label: duration.toString(),
                          activeColor:
                              isDark
                                  ? AppColors.neonCyan
                                  : AppColors.brandDeepGold,
                          onChanged: (value) {
                            setState(() {
                              duration = value.round();
                            });
                          },
                        ),
                        Text(
                          'Recommended time students should spend on each question',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: Text(
                            'Advanced Generation Options',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          value: useAdvancedOptions,
                          activeColor:
                              isDark
                                  ? AppColors.neonCyan
                                  : AppColors.brandDeepGold,
                          onChanged: (value) {
                            setState(() {
                              useAdvancedOptions = value;
                            });
                          },
                        ),
                        if (useAdvancedOptions) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black12 : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    isDark
                                        ? AppColors.neonCyan.withOpacity(0.2)
                                        : AppColors.brandDeepGold.withOpacity(
                                          0.2,
                                        ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Default Generation Prompt:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isDark
                                            ? Colors.white70
                                            : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  defaultDescription,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        isDark
                                            ? Colors.white60
                                            : Colors.black54,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Additional Instructions (Optional):',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isDark
                                            ? Colors.white70
                                            : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: additionalQueryController,
                                  decoration: InputDecoration(
                                    hintText:
                                        'E.g., Focus on clinical applications, emphasize diagrams...',
                                    hintStyle: TextStyle(
                                      fontSize: 12,
                                      color:
                                          isDark
                                              ? Colors.white38
                                              : Colors.black38,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  minLines: 2,
                                  maxLines: 4,
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          'This will create new AI-generated quiz questions for this eBook. The process may take a few minutes and will continue in the background.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed:
                          _isGeneratingQuestions
                              ? null
                              : () {
                                Navigator.pop(context);
                                _generateNewQuestions(
                                  nameController.text,
                                  difficulty,
                                  questionType,
                                  duration,
                                  defaultDescription,
                                  additionalQueryController.text,
                                );
                              },
                      icon:
                          _isGeneratingQuestions
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Icon(Icons.auto_awesome),
                      label: Text(
                        _isGeneratingQuestions ? 'Generating...' : 'Generate',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isDark
                                ? AppColors.neonCyan
                                : AppColors.brandDeepGold,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            isDark ? Colors.white24 : Colors.grey[300],
                      ),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _generateNewQuestions(
    String name,
    String difficulty,
    String questionType,
    int duration,
    String defaultDescription,
    String additionalQuery,
  ) async {
    final notificationService = ref.read(notificationServiceProvider);

    setState(() {
      _isGeneratingQuestions = true;
      _isProcessingDialogMinimized = false;
      _processingStatus = "Starting generation...";
      _processingProgress = 0;
    });

    _generationCancelToken = CancelToken();

    try {
      notificationService.showNotification(
        message: 'Starting question generation...',
        type: NotificationType.info,
        duration: const Duration(seconds: 5),
      );

      final questionDescription =
          additionalQuery.isNotEmpty
              ? "$defaultDescription\n\nAdditional Instructions: $additionalQuery"
              : defaultDescription;

      final requestData = {
        'ebookId': widget.ebookId,
        'name': name,
        'difficulty': difficulty,
        'questionType': questionType,
        'duration': duration,
        'category': 'Medical',
        'grade': 'Professional',
        'questionDescription': questionDescription,
      };

      final response = await DioConfig.dio?.post(
        '/question/generateQuestion',
        data: requestData,
        cancelToken: _generationCancelToken,
      );

      if (response?.statusCode == 202 && response?.data['success']) {
        _generatingExamId = response?.data['examId'];

        notificationService.showNotification(
          message: 'Question generation started! This may take a few minutes.',
          type: NotificationType.success,
          duration: const Duration(seconds: 5),
        );

        _showProcessingDialog(
          context,
          Theme.of(context).brightness == Brightness.dark,
        );
        _startStatusPolling();
      } else {
        throw Exception(
          response?.data?['message'] ?? 'Failed to start question generation',
        );
      }
    } catch (e) {
      if (_generationCancelToken == null ||
          !_generationCancelToken!.isCancelled) {
        notificationService.showNotification(
          message: 'Failed to generate questions: ${e.toString()}',
          type: NotificationType.error,
          duration: const Duration(seconds: 5),
        );
      }

      setState(() {
        _isGeneratingQuestions = false;
      });
    }
  }

  void _startStatusPolling() {
    if (_generatingExamId == null) return;

    _statusCheckTimer = Timer.periodic(const Duration(seconds: 5), (
      timer,
    ) async {
      try {
        final response = await DioConfig.dio?.get(
          '/question/status/$_generatingExamId',
        );

        if (response?.statusCode == 200 && response?.data['success']) {
          final data = response?.data['data'];
          final status = data['status'];
          final progress = data['progress'] ?? 0;
          final processingStatus = data['processingStatus'] ?? 'Processing...';

          if (mounted) {
            setState(() {
              _processingStatus = processingStatus;
              _processingProgress = progress;
            });
          }

          if (status == 'complete' || status == 'error') {
            _statusCheckTimer?.cancel();

            final notificationService = ref.read(notificationServiceProvider);

            if (status == 'complete') {
              notificationService.showNotification(
                message:
                    'Question generation complete! ${data['questionCount']} questions created.',
                type: NotificationType.success,
                duration: const Duration(seconds: 5),
              );

              ref
                  .read(quizSummaryProvider(widget.ebookId).notifier)
                  .fetchQuizSummary(widget.ebookId);
            } else {
              notificationService.showNotification(
                message:
                    'Question generation failed: ${data['error'] ?? 'Unknown error'}',
                type: NotificationType.error,
                duration: const Duration(seconds: 5),
              );
            }

            setState(() {
              _isGeneratingQuestions = false;
              _generatingExamId = null;
            });
          }
        }
      } catch (e) {
        print('Error checking question generation status: $e');
      }
    });
  }

  void _showProcessingDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => WillPopScope(
                  onWillPop: () async {
                    Navigator.pop(context);
                    setState(() {
                      _isProcessingDialogMinimized = true;
                    });
                    return true;
                  },
                  child: AlertDialog(
                    backgroundColor: isDark ? AppColors.darkBg : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color:
                            isDark
                                ? AppColors.neonCyan.withOpacity(0.3)
                                : AppColors.brandDeepGold.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    title: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark
                                  ? AppColors.neonCyan
                                  : AppColors.brandDeepGold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('Generating Questions'),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.minimize, size: 20),
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {
                              _isProcessingDialogMinimized = true;
                            });
                          },
                          tooltip: 'Minimize',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 150,
                          width: 150,
                          child: LottieBuilder.asset(
                            isDark
                                ? 'assets/animations/processing-darkmode.json'
                                : 'assets/animations/processing.json',
                            fit: BoxFit.contain,
                            repeat: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _processingStatus,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        if (_processingProgress > 0) ...[
                          LinearProgressIndicator(
                            value: _processingProgress / 100,
                            backgroundColor:
                                isDark ? Colors.white10 : Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark
                                  ? AppColors.neonCyan
                                  : AppColors.brandDeepGold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_processingProgress%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color:
                                  isDark
                                      ? AppColors.neonCyan
                                      : AppColors.brandDeepGold,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ] else
                          const SizedBox(height: 16),
                        const Text(
                          'AI is analyzing your eBook content and creating high-quality questions. This may take several minutes depending on the content length.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _isProcessingDialogMinimized = true;
                          });
                        },
                        child: const Text('Minimize'),
                      ),
                      TextButton(
                        onPressed: () {
                          if (_generationCancelToken != null &&
                              !_generationCancelToken!.isCancelled) {
                            _generationCancelToken!.cancel('User cancelled');
                            _statusCheckTimer?.cancel();

                            setState(() {
                              _isGeneratingQuestions = false;
                              _generatingExamId = null;
                              _isProcessingDialogMinimized = false;
                            });

                            ref
                                .read(notificationServiceProvider)
                                .showNotification(
                                  message: 'Question generation cancelled',
                                  type: NotificationType.warning,
                                  duration: const Duration(seconds: 3),
                                );
                          }

                          Navigator.pop(context);
                        },
                        child: const Text('Cancel Generation'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Widget _buildBody(QuizSummaryState state, bool isDark) {
    if (state.isLoading) {
      return _buildLoadingView(isDark);
    }

    if (state.errorMessage != null) {
      return _buildErrorView(isDark, state.errorMessage!);
    }

    if (state.data == null) {
      return _buildEmptyView(isDark);
    }

    return _buildQuizSummaryContent(state.data!, isDark);
  }

  Widget _buildLoadingView(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading quiz data...',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(bool isDark, String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              MdiIcons.alertCircleOutline,
              size: 64,
              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load quiz data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(quizSummaryProvider(widget.ebookId).notifier)
                    .fetchQuizSummary(widget.ebookId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              MdiIcons.checkboxMarkedCircleOutline,
              size: 64,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
            const SizedBox(height: 16),
            Text(
              'No quizzes available yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This eBook doesn\'t have any quizzes generated yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showGenerateConfirmDialog(context, isDark),
              icon: Icon(MdiIcons.robot),
              label: const Text('Generate Questions'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizSummaryContent(Map<String, dynamic> data, bool isDark) {
    final String ebookTitle = data['ebookTitle'] ?? 'Unknown Book';
    final int totalQuestions = data['totalQuestions'] ?? 0;
    final int totalExams = data['totalExams'] ?? 0;
    final List<dynamic> exams = data['exams'] ?? [];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildSummaryHeader(
            isDark,
            ebookTitle,
            totalQuestions,
            totalExams,
          ),
        ),
        if (exams.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'No exam data available for this eBook',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ),
          ),
        if (exams.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              return _buildExamCard(exams[index], isDark, index);
            }, childCount: exams.length),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildSummaryHeader(
    bool isDark,
    String title,
    int totalQuestions,
    int totalExams,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  isDark,
                  MdiIcons.helpCircleOutline,
                  'Questions',
                  totalQuestions.toString(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  isDark,
                  MdiIcons.formatListChecks,
                  'Exams',
                  totalExams.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    bool isDark,
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            isDark
                ? AppColors.neonCyan.withOpacity(0.1)
                : AppColors.brandDeepGold.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isDark
                  ? AppColors.neonCyan.withOpacity(0.3)
                  : AppColors.brandDeepGold.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamCard(Map<String, dynamic> exam, bool isDark, int index) {
    final String examName = exam['name'] ?? 'Exam ${index + 1}';
    final String difficulty = exam['difficulty'] ?? 'Medium';
    final String status = exam['status'] ?? 'Ready';
    final int questionCount = exam['questionCount'] ?? 0;
    final List<dynamic> topics = exam['topics'] ?? [];
    final Map<String, dynamic> priorityBreakdown =
        exam['priorityBreakdown'] ?? {};
    final double averageRelevance = (exam['averageRelevance'] ?? 0).toDouble();
    final String examId = exam['id'] ?? '';

    List<Color> gradientColors;
    if (difficulty.toLowerCase() == 'hard') {
      gradientColors =
          isDark
              ? [
                Colors.red[900]!.withOpacity(0.4),
                Colors.red[700]!.withOpacity(0.2),
              ]
              : [Colors.red[50]!, Colors.red[100]!];
    } else if (difficulty.toLowerCase() == 'medium') {
      gradientColors =
          isDark
              ? [
                Colors.amber[900]!.withOpacity(0.4),
                Colors.amber[700]!.withOpacity(0.2),
              ]
              : [Colors.amber[50]!, Colors.amber[100]!];
    } else {
      gradientColors =
          isDark
              ? [
                Colors.green[900]!.withOpacity(0.4),
                Colors.green[700]!.withOpacity(0.2),
              ]
              : [Colors.green[50]!, Colors.green[100]!];
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? Colors.black26 : Colors.white,
            isDark ? Colors.black38.withOpacity(0.5) : Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ExpansionTile(
          collapsedBackgroundColor: Colors.transparent,
          backgroundColor: Colors.transparent,
          title: Row(
            children: [
              Container(
                width: 6,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: gradientColors,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? AppColors.neonCyan.withOpacity(0.1)
                          : AppColors.brandDeepGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    MdiIcons.fileDocumentOutline,
                    color:
                        isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      examName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? gradientColors[0].withOpacity(0.6)
                                    : gradientColors[1],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            difficulty,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$questionCount Questions',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.picture_as_pdf,
                  color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                  size: 20,
                ),
                tooltip: 'Download PDF',
                onPressed:
                    () => _showPdfDownloadDialog(
                      context,
                      examName,
                      examId,
                      isDark,
                    ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8, left: 18),
            child: _buildStatusChip(status, isDark),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (topics.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          MdiIcons.tagOutline,
                          size: 16,
                          color:
                              isDark
                                  ? AppColors.neonCyan
                                  : AppColors.brandDeepGold,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Topic Distribution',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTopicsList(topics, isDark),
                    const Divider(height: 32),
                  ],
                  Row(
                    children: [
                      Icon(
                        MdiIcons.priorityHigh,
                        size: 16,
                        color:
                            isDark
                                ? AppColors.neonCyan
                                : AppColors.brandDeepGold,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Question Priority',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildPriorityBreakdown(priorityBreakdown, isDark),
                  const Divider(height: 32),
                  _buildRelevanceScore(averageRelevance, isDark),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          status.toLowerCase() == 'ready'
                              ? () {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Quiz feature coming soon!',
                                    ),
                                    backgroundColor:
                                        isDark
                                            ? AppColors.neonCyan
                                            : AppColors.brandDeepGold,
                                  ),
                                );
                              }
                              : null,
                      icon: Icon(MdiIcons.playCircleOutline),
                      label: const Text('Take Quiz'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isDark
                                ? AppColors.neonCyan
                                : AppColors.brandDeepGold,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            isDark ? Colors.white24 : Colors.grey[300],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        shadowColor:
                            isDark
                                ? AppColors.neonCyan.withOpacity(0.3)
                                : AppColors.brandDeepGold.withOpacity(0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPdfDownloadDialog(
    BuildContext context,
    String examName,
    String examId,
    bool isDark,
  ) {
    final examNameController = TextEditingController(text: examName);

    bool includeAnswers = true;
    String groupByOption = 'default';
    String colorThemeOption = 'medical';
    bool includeMetadata = true;
    bool isGenerating = false;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  backgroundColor:
                      isDark ? const Color(0xFF121212) : Colors.white,
                  title: Row(
                    children: [
                      Icon(
                        Icons.picture_as_pdf,
                        color:
                            isDark
                                ? AppColors.neonCyan
                                : AppColors.brandDeepGold,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      const Text('Generate PDF'),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: examNameController,
                          decoration: const InputDecoration(
                            labelText: 'Exam Name',
                            hintText: 'Enter a name for this exam',
                          ),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Include Answers'),
                          subtitle: const Text(
                            'Show correct answers and explanations',
                          ),
                          value: includeAnswers,
                          onChanged: (value) {
                            setState(() {
                              includeAnswers = value;
                            });
                          },
                        ),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Group Questions By',
                          ),
                          value: groupByOption,
                          items: const [
                            DropdownMenuItem(
                              value: 'default',
                              child: Text('Default Sections'),
                            ),
                            DropdownMenuItem(
                              value: 'priority',
                              child: Text('Priority Level'),
                            ),
                            DropdownMenuItem(
                              value: 'conceptCategory',
                              child: Text('Concept Category'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                groupByOption = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Color Theme',
                          ),
                          value: colorThemeOption,
                          items: const [
                            DropdownMenuItem(
                              value: 'warm',
                              child: Text('Warm'),
                            ),
                            DropdownMenuItem(
                              value: 'cool',
                              child: Text('Cool'),
                            ),
                            DropdownMenuItem(
                              value: 'professional',
                              child: Text('Professional'),
                            ),
                            DropdownMenuItem(
                              value: 'medical',
                              child: Text('Medical'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                colorThemeOption = value;
                              });
                            }
                          },
                        ),
                        SwitchListTile(
                          title: const Text('Include Metadata'),
                          subtitle: const Text(
                            'Show priority and relevance info',
                          ),
                          value: includeMetadata,
                          onChanged: (value) {
                            setState(() {
                              includeMetadata = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed:
                          isGenerating
                              ? null
                              : () {
                                setState(() {
                                  isGenerating = true;
                                });

                                Navigator.pop(context);
                                _generatePdf(
                                  examId,
                                  examNameController.text,
                                  includeAnswers,
                                  groupByOption,
                                  colorThemeOption,
                                  includeMetadata,
                                );
                              },
                      icon:
                          isGenerating
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Icon(Icons.picture_as_pdf),
                      label: Text(isGenerating ? 'Generating...' : 'Generate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isDark
                                ? AppColors.neonCyan
                                : AppColors.brandDeepGold,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
          ),
    );
  }

  void _generatePdf(
    String examId,
    String examName,
    bool includeAnswers,
    String groupBy,
    String colorTheme,
    bool includeMetadata,
  ) async {
    final notificationService = ref.read(notificationServiceProvider);
    final cancelToken = CancelToken();

    try {
      notificationService.showNotification(
        message: 'Starting PDF generation...',
        type: NotificationType.info,
        duration: const Duration(seconds: 5),
      );

      final requestData = {
        'name': examName,
        'QandA': includeAnswers,
        'groupBy': groupBy,
        'colorTheme': colorTheme,
        'includeMetadata': includeMetadata,
      };

      final response = await DioConfig.dio?.post(
        '/question/fetchExamData',
        data: requestData,
      );

      if (response?.statusCode == 200 && response?.data['success']) {
        final pdfPath = response!.data['data']['pdfPath'];
        print('PDF Path returned from server: $pdfPath');

        final appDir = await getApplicationDocumentsDirectory();
        final localPath =
            '${appDir.path}/${examName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';

        notificationService.showNotification(
          message: 'PDF ready. Starting download...',
          type: NotificationType.info,
          duration: const Duration(seconds: 30),
        );

        String downloadUrl = '/download/$pdfPath';
        print('Attempting to download from: $downloadUrl');

        int lastReportedProgress = 0;

        final downloadResponse = await DioConfig.dio?.get(
          downloadUrl,
          cancelToken: cancelToken,
          options: Options(responseType: ResponseType.bytes),
          onReceiveProgress: (received, total) {
            if (total != -1) {
              final progress = (received / total * 100).round();
              if (progress >= lastReportedProgress + 20) {
                lastReportedProgress = progress;
                notificationService.showNotification(
                  message: 'Downloading PDF: $progress%',
                  type: NotificationType.info,
                  duration: const Duration(seconds: 2),
                );
              }
            }
          },
        );

        if (downloadResponse?.statusCode == 200) {
          final file = File(localPath);
          await file.writeAsBytes(downloadResponse!.data);

          notificationService.showNotification(
            message: 'PDF downloaded successfully!',
            type: NotificationType.success,
            duration: const Duration(seconds: 4),
          );

          await Future.delayed(const Duration(milliseconds: 500));
          OpenFile.open(localPath);
        } else {
          throw Exception(
            'Download failed with status: ${downloadResponse?.statusCode}',
          );
        }
      } else {
        throw Exception(response?.data['message'] ?? 'Failed to generate PDF');
      }
    } on DioException catch (e) {
      notificationService.showNotification(
        message: e.response?.data?['message'] ?? 'Error: ${e.message}',
        type: NotificationType.error,
        duration: const Duration(seconds: 5),
      );
      print('Dio error: ${e.message}, Response: ${e.response}');
    } catch (e) {
      notificationService.showNotification(
        message: 'Error generating PDF: $e',
        type: NotificationType.error,
        duration: const Duration(seconds: 5),
      );
      print('Error in PDF generation: $e');
    }
  }

  Widget _buildStatusChip(String status, bool isDark) {
    Color bgColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'ready':
        bgColor = isDark ? Colors.green[900]! : Colors.green[100]!;
        textColor = isDark ? Colors.green[300]! : Colors.green[800]!;
        break;
      case 'processing':
        bgColor = isDark ? Colors.blue[900]! : Colors.blue[100]!;
        textColor = isDark ? Colors.blue[300]! : Colors.blue[800]!;
        break;
      case 'error':
        bgColor = isDark ? Colors.red[900]! : Colors.red[100]!;
        textColor = isDark ? Colors.red[300]! : Colors.red[800]!;
        break;
      default:
        bgColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
        textColor = isDark ? Colors.grey[300]! : Colors.grey[800]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildTopicsList(List<dynamic> topics, bool isDark) {
    if (topics.isEmpty) {
      return Text(
        'No topics available',
        style: TextStyle(
          fontSize: 14,
          fontStyle: FontStyle.italic,
          color: isDark ? Colors.white54 : Colors.black45,
        ),
      );
    }

    topics.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    return Column(
      children:
          topics.take(5).map((topic) {
            final String topicName = topic['topic'] ?? 'Unknown';
            final int count = topic['count'] ?? 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      topicName,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? AppColors.neonCyan.withOpacity(0.1)
                              : AppColors.brandDeepGold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color:
                            isDark
                                ? AppColors.neonCyan
                                : AppColors.brandDeepGold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _buildPriorityBreakdown(
    Map<String, dynamic> priorityBreakdown,
    bool isDark,
  ) {
    final int highCount = priorityBreakdown['high'] ?? 0;
    final int mediumCount = priorityBreakdown['medium'] ?? 0;
    final int lowCount = priorityBreakdown['low'] ?? 0;
    final int total = highCount + mediumCount + lowCount;

    if (total == 0) {
      return Text(
        'No priority data available',
        style: TextStyle(
          fontSize: 14,
          fontStyle: FontStyle.italic,
          color: isDark ? Colors.white54 : Colors.black45,
        ),
      );
    }

    return Column(
      children: [
        _buildPriorityBar(highCount, mediumCount, lowCount, total, isDark),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildPriorityLegend('High', Colors.red, highCount, isDark),
            _buildPriorityLegend('Medium', Colors.amber, mediumCount, isDark),
            _buildPriorityLegend('Low', Colors.green, lowCount, isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildPriorityBar(
    int high,
    int medium,
    int low,
    int total,
    bool isDark,
  ) {
    final double highRatio = total > 0 ? high / total : 0;
    final double mediumRatio = total > 0 ? medium / total : 0;
    final double lowRatio = total > 0 ? low / total : 0;

    return Container(
      height: 12,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            flex: (highRatio * 100).round(),
            child: Container(color: isDark ? Colors.red[700] : Colors.red[400]),
          ),
          Expanded(
            flex: (mediumRatio * 100).round(),
            child: Container(
              color: isDark ? Colors.amber[700] : Colors.amber[400],
            ),
          ),
          Expanded(
            flex: (lowRatio * 100).round(),
            child: Container(
              color: isDark ? Colors.green[700] : Colors.green[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityLegend(
    String label,
    MaterialColor color,
    int count,
    bool isDark,
  ) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isDark ? color[700] : color[400],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildRelevanceScore(double score, bool isDark) {
    MaterialColor barColor;

    if (score >= 80) {
      barColor = Colors.green;
    } else if (score >= 60) {
      barColor = Colors.amber;
    } else {
      barColor = Colors.red;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Content Relevance',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              '${score.round()}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? barColor[300]! : barColor[700]!,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: score / 100,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? barColor[700] : barColor[400],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'How relevant the questions are to the eBook content',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }
}

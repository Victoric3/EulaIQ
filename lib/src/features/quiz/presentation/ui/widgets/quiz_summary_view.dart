import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:dio/dio.dart';
import 'package:eulaiq/src/common/common.dart';
import 'package:eulaiq/src/common/constants/dio_config.dart';
import 'package:eulaiq/src/features/quiz/presentation/ui/screens/quiz_options_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:eulaiq/src/features/quiz/presentation/providers/quiz_summary_provider.dart';
import 'package:lottie/lottie.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:eulaiq/src/common/services/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

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

  List<String> _availableSections = [];
  String? _selectedSection;

  // Map to track retry states per exam ID
  final Map<String, DateTime> _retryTimeouts = {};
  final Map<String, bool> _isRetrying =
      {}; // Track if a specific exam is retrying

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(quizSummaryProvider(widget.ebookId).notifier)
          .fetchQuizSummary(widget.ebookId);
      _fetchSections();
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
              : Container(
                margin: const EdgeInsets.only(right: 8, bottom: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color:
                          isDark
                              ? AppColors.neonCyan.withOpacity(0.4)
                              : AppColors.brandDeepGold.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      try {
                        final validEbookId = widget.ebookId;
                        print(
                          'Navigating to quiz options with ebookId: $validEbookId',
                        );

                        context.router.push(
                          QuizOptionsRoute(
                            ebookId: validEbookId,
                            preSelectedExamId: null,
                          ),
                        );
                      } catch (e) {
                        print('Navigation error: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Error navigating to quiz options: $e',
                            ),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(32),
                    splashColor:
                        isDark
                            ? AppColors.neonCyan.withOpacity(0.2)
                            : AppColors.brandDeepGold.withOpacity(0.2),
                    highlightColor:
                        isDark
                            ? AppColors.neonCyan.withOpacity(0.1)
                            : AppColors.brandDeepGold.withOpacity(0.1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors:
                              isDark
                                  ? [
                                    AppColors.neonCyan,
                                    Color.lerp(
                                      AppColors.neonCyan,
                                      Colors.blue,
                                      0.3,
                                    )!,
                                  ]
                                  : [
                                    AppColors.brandDeepGold,
                                    Color.lerp(
                                      AppColors.brandDeepGold,
                                      Colors.orange,
                                      0.3,
                                    )!,
                                  ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Take Quiz',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
    );
  }

  void _showGenerateConfirmDialog(BuildContext context, bool isDark) {
    final state = ref.read(quizSummaryProvider(widget.ebookId));
    final String ebookTitle = state.data?['ebookTitle'] ?? 'Unknown Book';
    final timestamp = DateTime.now().millisecondsSinceEpoch
        .toString()
        .substring(9);
    final nameController = TextEditingController(
      text: 'Questions for $ebookTitle ($timestamp)',
    );

    String difficulty = 'Medium';
    String questionType = 'mcq';
    int duration = 60;

    bool generateForSpecificSection = false;
    String? selectedSection = _selectedSection;

    const String defaultDescription =
        'Generate multiple-choice questions that thoroughly cover all key concepts, nuances, and intricate details of the content. The questions should be structured to be difficult, with tempting but incorrect answer choices that challenge deep understanding. The material contains delicate educational content, Ensure all aspects of the material are addressed, leaving no concept untouched.';
    final additionalQueryController = TextEditingController();

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
                    mainAxisSize: MainAxisSize.min,
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
                      Flexible(
                        child: Text(
                          'Generate New Questions',
                          style: const TextStyle(
                            overflow: TextOverflow.ellipsis,
                          ),
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
                        SwitchListTile(
                          title: Text(
                            'Generate for Specific Section',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            'Focus on a single chapter/section',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          value: generateForSpecificSection,
                          activeColor:
                              isDark
                                  ? AppColors.neonCyan
                                  : AppColors.brandDeepGold,
                          onChanged: (value) {
                            setState(() {
                              generateForSpecificSection = value;
                              if (!value) selectedSection = null;
                            });
                          },
                        ),
                        if (generateForSpecificSection) ...[
                          const SizedBox(height: 8),
                          _availableSections.isEmpty
                              ? Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      isDark
                                          ? Colors.black12
                                          : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                        isDark
                                            ? AppColors.neonCyan.withOpacity(
                                              0.2,
                                            )
                                            : AppColors.brandDeepGold
                                                .withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              isDark
                                                  ? AppColors.neonCyan
                                                  : AppColors.brandDeepGold,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Loading available sections...',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color:
                                            isDark
                                                ? Colors.white70
                                                : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Select Section',
                                  hintText:
                                      'Choose a section to generate questions from',
                                ),
                                value: selectedSection,
                                isExpanded: true,
                                items:
                                    _availableSections.map((section) {
                                      return DropdownMenuItem(
                                        value: section,
                                        child: Text(
                                          section,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      );
                                    }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedSection = value;
                                  });
                                  this.setState(() {
                                    _selectedSection = value;
                                  });
                                },
                              ),
                          const SizedBox(height: 8),
                          Text(
                            'Generate questions only from the selected section and its subsections.',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
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
                            if (value != null)
                              setState(() => difficulty = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Question Type',
                                      style: TextStyle(
                                        color: isDark ? Colors.white70 : Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          size: 16,
                                          color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Multiple Choice Questions',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: additionalQueryController,
                          decoration: const InputDecoration(
                            labelText: 'Additional Instructions (Optional)',
                            hintText: 'Enter any specific requirements...',
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed:
                              _isGeneratingQuestions
                                  ? null
                                  : () {
                                    Navigator.pop(context);
                                    if (generateForSpecificSection &&
                                        selectedSection != null) {
                                      _generateQuestionsForSection(
                                        nameController.text,
                                        difficulty,
                                        questionType,
                                        duration,
                                        defaultDescription,
                                        additionalQueryController.text,
                                        selectedSection!,
                                        retryCount: 0,
                                      );
                                    } else {
                                      _generateNewQuestions(
                                        nameController.text,
                                        difficulty,
                                        questionType,
                                        duration,
                                        defaultDescription,
                                        additionalQueryController.text,
                                      );
                                    }
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
                            _isGeneratingQuestions
                                ? 'Generating...'
                                : 'Generate',
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

  Future<void> _generateQuestionsForSection(
    String name,
    String difficulty,
    String questionType,
    int duration,
    String defaultDescription,
    String additionalQuery,
    String sectionTitle, {
    int retryCount = 0,
    CancelToken? existingCancelToken,
  }) async {
    final notificationService = ref.read(notificationServiceProvider);

    final originalSectionTitle =
        sectionTitle.contains(' (')
            ? sectionTitle.substring(0, sectionTitle.lastIndexOf(' ('))
            : sectionTitle;

    setState(() {
      _isGeneratingQuestions = true;
      _isProcessingDialogMinimized = false;
      _processingStatus =
          retryCount > 0
              ? "Retrying section-specific generation (attempt #${retryCount + 1})..."
              : "Starting section-specific generation...";
      _processingProgress = 0;
    });

    _generationCancelToken = existingCancelToken ?? CancelToken();

    try {
      final questionDescription =
          additionalQuery.isNotEmpty
              ? "$defaultDescription\n\nAdditional Instructions: $additionalQuery"
              : defaultDescription;

      final requestData = {
        'ebookId': widget.ebookId,
        'name': name,
        'sectionTitle': originalSectionTitle,
        'difficulty': difficulty,
        'questionType': questionType,
        'duration': duration,
        'category': 'Medical',
        'grade': 'Professional',
        'questionDescription': questionDescription,
      };

      final response = await DioConfig.dio?.post(
        '/question/section/generateQuestion',
        data: requestData,
        cancelToken: _generationCancelToken,
      );

      if (response?.statusCode == 202 && response?.data['success']) {
        _generatingExamId = response?.data['examId'];

        notificationService.showNotification(
          message:
              retryCount > 0
                  ? 'Question generation restarted for section: $originalSectionTitle!'
                  : 'Question generation started for section: $originalSectionTitle!',
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
          response?.data?['message'] ??
              'Failed to start section question generation',
        );
      }
    } catch (e) {
      print('Error in section generation: $e');

      if (retryCount < 2 &&
          (_generationCancelToken == null ||
              !_generationCancelToken!.isCancelled)) {
        notificationService.showNotification(
          message:
              'Error generating questions. Retrying automatically in 3 seconds...',
          type: NotificationType.warning,
          duration: const Duration(seconds: 3),
        );

        await Future.delayed(const Duration(seconds: 3));

        return _generateQuestionsForSection(
          name,
          difficulty,
          questionType,
          duration,
          defaultDescription,
          additionalQuery,
          sectionTitle,
          retryCount: retryCount + 1,
          existingCancelToken: _generationCancelToken,
        );
      }

      if (_generationCancelToken == null ||
          !_generationCancelToken!.isCancelled) {
        notificationService.showNotification(
          message:
              'Failed to generate questions after ${retryCount + 1} attempts: ${e.toString()}',
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
    final dialogUpdateController = StreamController<void>.broadcast();
    Timer? updateTimer;

    updateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (dialogUpdateController.hasListener) {
        dialogUpdateController.add(null);
      } else {
        updateTimer?.cancel();
      }
    });

    bool isCompleted = false;

    Widget buildDialogContent() {
      isCompleted =
          _processingProgress >= 100 ||
          _processingStatus.toLowerCase().contains('complete');
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            width: 150,
            child:
                isCompleted
                    ? LottieBuilder.asset(
                      isDark
                          ? 'assets/animations/success-darkmode.json'
                          : 'assets/animations/success-lightmode.json',
                      fit: BoxFit.contain,
                      repeat: false,
                    )
                    : LottieBuilder.asset(
                      isDark
                          ? 'assets/animations/processing-darkmode.json'
                          : 'assets/animations/processing.json',
                      fit: BoxFit.contain,
                      repeat: true,
                    ),
          ),
          const SizedBox(height: 16),
          Text(
            isCompleted ? 'Question Generation Complete!' : _processingStatus,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color:
                  isCompleted
                      ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                      : (isDark ? Colors.white : Colors.black87),
            ),
          ),
          const SizedBox(height: 12),
          if (_processingProgress > 0) ...[
            LinearProgressIndicator(
              value: _processingProgress / 100,
              backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_processingProgress%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
              ),
            ),
            const SizedBox(height: 16),
          ] else
            const SizedBox(height: 16),
          Text(
            isCompleted
                ? 'Your questions are ready! You can now take the quiz or generate more questions.'
                : 'AI is analyzing your eBook content and creating high-quality questions. This may take several minutes depending on the content length.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return WillPopScope(
          onWillPop: () async {
            updateTimer?.cancel();
            dialogUpdateController.close();
            Navigator.pop(dialogContext);
            setState(() {
              _isProcessingDialogMinimized = true;
            });
            return true;
          },
          child: StreamBuilder<void>(
            stream: dialogUpdateController.stream,
            builder: (context, _) {
              return AlertDialog(
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child:
                          isCompleted
                              ? Icon(
                                Icons.check_circle,
                                color:
                                    isDark
                                        ? AppColors.neonCyan
                                        : AppColors.brandDeepGold,
                                size: 24,
                              )
                              : CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isDark
                                      ? AppColors.neonCyan
                                      : AppColors.brandDeepGold,
                                ),
                              ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        isCompleted
                            ? 'Generation Complete'
                            : 'Generating Questions',
                        style: TextStyle(
                          overflow: TextOverflow.ellipsis,
                          color:
                              isCompleted
                                  ? (isDark
                                      ? AppColors.neonCyan
                                      : AppColors.brandDeepGold)
                                  : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                    ),
                    if (!isCompleted)
                      IconButton(
                        icon: const Icon(Icons.minimize, size: 20),
                        onPressed: () {
                          updateTimer?.cancel();
                          dialogUpdateController.close();
                          Navigator.pop(dialogContext);
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
                content: buildDialogContent(),
                actions: [
                  if (isCompleted)
                    TextButton.icon(
                      icon: Icon(
                        Icons.check_circle_outline,
                        color:
                            isDark
                                ? AppColors.neonCyan
                                : AppColors.brandDeepGold,
                      ),
                      onPressed: () {
                        updateTimer?.cancel();
                        dialogUpdateController.close();
                        Navigator.pop(dialogContext);
                        setState(() {
                          _isProcessingDialogMinimized = false;
                        });
                      },
                      label: const Text('Close'),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            isDark
                                ? AppColors.neonCyan
                                : AppColors.brandDeepGold,
                      ),
                    )
                  else ...[
                    TextButton(
                      onPressed: () {
                        updateTimer?.cancel();
                        dialogUpdateController.close();
                        Navigator.pop(dialogContext);
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
                        updateTimer?.cancel();
                        dialogUpdateController.close();
                        Navigator.pop(dialogContext);
                      },
                      child: const Text('Cancel Generation'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    ).then((_) {
      updateTimer?.cancel();
      dialogUpdateController.close();
    });
  }

  Widget _buildBody(QuizSummaryState state, bool isDark) {
    if (state.isLoading) return _buildLoadingView(isDark);
    if (state.errorMessage != null)
      return _buildErrorView(isDark, state.errorMessage!);
    if (state.data == null) return _buildEmptyView(isDark);
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
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildExamCard(exams[index], isDark, index),
              childCount: exams.length,
            ),
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
    final List<dynamic> topics = exam['topics'] ?? [];
    final Map<String, dynamic> priorityBreakdown =
        exam['priorityBreakdown'] ?? {};
    final double averageRelevance = (exam['averageRelevance'] ?? 0).toDouble();
    final String examId = exam['examId'];

    final bool canRetry = [
      'processing',
      'error',
    ].contains(status.toLowerCase());
    final bool inCooldown =
        canRetry &&
        _retryTimeouts.containsKey(examId) &&
        DateTime.now().difference(_retryTimeouts[examId]!).inSeconds < 30;
    final bool isRetrying = _isRetrying[examId] ?? false;

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
                  mainAxisSize: MainAxisSize.min, // Ensure minimum height
                  children: [
                    Text(
                      examName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis, // Ensure text truncates
                    ),
                    // Other children...
                  ],
                ),
              ),
              // Make sure action buttons are wrapped in a flexible container with constraints
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min, // Take minimum space needed
                  children: [
                    if (canRetry)
                      IconButton(
                        icon: Stack(
                          children: [
                            Icon(
                              Icons.refresh,
                              color:
                                  inCooldown || isRetrying
                                      ? (isDark
                                          ? Colors.grey[600]
                                          : Colors.grey[400])
                                      : (isDark
                                          ? AppColors.neonCyan
                                          : AppColors.brandDeepGold),
                              size: 20,
                            ),
                            if (inCooldown || isRetrying)
                              Positioned.fill(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isDark ? Colors.white24 : Colors.black12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        tooltip:
                            inCooldown
                                ? 'Please wait before retrying'
                                : 'Retry generation',
                        onPressed:
                            (inCooldown || isRetrying)
                                ? null
                                : () => _retryQuestionGeneration(
                                  examId,
                                  status,
                                  isDark,
                                ),
                        constraints: BoxConstraints.tightFor(
                          width: 40,
                          height: 40,
                        ), // Fixed size
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.picture_as_pdf,
                        color:
                            isDark
                                ? AppColors.neonCyan
                                : AppColors.brandDeepGold,
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
                      constraints: const BoxConstraints.tightFor(
                        width: 40,
                        height: 40,
                      ), // Fixed size
                    ),
                  ],
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
                        'Key Topics',
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
                          status.toLowerCase() == 'complete'
                              ? () {
                                // Navigate to Quiz Options Screen with this exam pre-selected
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => QuizOptionsScreen(
                                          ebookId: widget.ebookId,
                                          preSelectedExamId: examId,
                                        ),
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

  Future<void> _retryQuestionGeneration(
    String examId,
    String status,
    bool isDark,
  ) async {
    final notificationService = ref.read(notificationServiceProvider);

    print(
      'Starting retry question generation for exam ID: $examId with status: $status',
    );

    setState(() {
      _retryTimeouts[examId] = DateTime.now();
      _isRetrying[examId] = true;
      _isGeneratingQuestions = true;
      _isProcessingDialogMinimized = false;
      _processingStatus = "Resuming question generation...";
      _processingProgress = 0;
      _generatingExamId = examId; // Set the exam ID for status polling
    });

    try {
      print('Sending retry notification');
      notificationService.showNotification(
        message: 'Resuming question generation...',
        type: NotificationType.info,
        duration: const Duration(seconds: 3),
      );

      final requestData = {
        'examId': examId,
        'questionType': 'mcq',
        'questionDescription':
            'Generate multiple-choice questions that thoroughly cover key concepts from the content.',
      };

      print('Sending retry request with data: $requestData');

      final response = await DioConfig.dio?.post(
        '/question/continueQuestionGeneration',
        data: requestData,
      );

      print(
        'Received retry response: statusCode=${response?.statusCode}, success=${response?.data['success']}',
      );

      if (response?.statusCode == 202 && response?.data['success'] == true) {
        print('Question generation retry successful for exam ID: $examId');
        notificationService.showNotification(
          message: 'Question generation resumed successfully!',
          type: NotificationType.success,
          duration: const Duration(seconds: 3),
        );

        // Show processing dialog and start status polling
        _showProcessingDialog(context, isDark);
        _startStatusPolling();

        // Don't refresh summary here - let the polling handle it when complete
      } else {
        throw Exception(
          response?.data['message'] ?? 'Failed to resume question generation',
        );
      }
    } catch (e) {
      print('Error retrying question generation: $e');
      notificationService.showNotification(
        message: 'Failed to retry question generation: ${e.toString()}',
        type: NotificationType.error,
        duration: const Duration(seconds: 5),
      );

      // Reset generation state
      setState(() {
        _isGeneratingQuestions = false;
        _generatingExamId = null;
      });
    } finally {
      // Only reset the retry state, but keep generation state for polling
      setState(() {
        _isRetrying[examId] = false;
      });
    }
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

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Generate PDF',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setState) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Center(
              child: Material(  // Add this Material widget
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black87.withOpacity(0.9)
                        : Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? AppColors.neonCyan.withOpacity(0.3)
                            : AppColors.brandDeepGold.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                    border: Border.all(
                      color: isDark
                          ? AppColors.neonCyan.withOpacity(0.3)
                          : AppColors.brandDeepGold.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.picture_as_pdf,
                              color:
                                  isDark
                                      ? AppColors.neonCyan
                                      : AppColors.brandDeepGold,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Generate PDF',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: examNameController,
                          decoration: InputDecoration(
                            labelText: 'Exam Name',
                            hintText: 'Enter a name for this exam',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color:
                                    isDark
                                        ? AppColors.neonCyan
                                        : AppColors.brandDeepGold,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Options with more visual appeal
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? Colors.black38
                                    : Colors.black.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isDark
                                      ? Colors.white10
                                      : Colors.black.withOpacity(0.05),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PDF Options',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SwitchListTile(
                                title: Text(
                                  'Include Answers',
                                  style: TextStyle(
                                    color:
                                        isDark
                                            ? Colors.white
                                            : Colors.black87,
                                  ),
                                ),
                                subtitle: Text(
                                  'Show correct answers and explanations',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        isDark
                                            ? Colors.white70
                                            : Colors.black54,
                                  ),
                                ),
                                value: includeAnswers,
                                onChanged:
                                    (value) => setState(
                                      () => includeAnswers = value,
                                    ),
                                activeColor:
                                    isDark
                                        ? AppColors.neonCyan
                                        : AppColors.brandDeepGold,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Group Questions By:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor:
                                      isDark ? Colors.black45 : Colors.white,
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
                                onChanged:
                                    (value) => setState(
                                      () => groupByOption = value!,
                                    ),
                                dropdownColor:
                                    isDark ? Colors.black87 : Colors.white,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Color Theme:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor:
                                      isDark ? Colors.black45 : Colors.white,
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
                                onChanged:
                                    (value) => setState(
                                      () => colorThemeOption = value!,
                                    ),
                                dropdownColor:
                                    isDark ? Colors.black87 : Colors.white,
                              ),
                              const SizedBox(height: 12),
                              SwitchListTile(
                                title: Text(
                                  'Include Metadata',
                                  style: TextStyle(
                                    color:
                                        isDark
                                            ? Colors.white
                                            : Colors.black87,
                                  ),
                                ),
                                subtitle: Text(
                                  'Show priority and relevance info',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        isDark
                                            ? Colors.white70
                                            : Colors.black54,
                                  ),
                                ),
                                value: includeMetadata,
                                onChanged:
                                    (value) => setState(
                                      () => includeMetadata = value,
                                    ),
                                activeColor:
                                    isDark
                                        ? AppColors.neonCyan
                                        : AppColors.brandDeepGold,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color:
                                      isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed:
                                  isGenerating
                                      ? null
                                      : () {
                                        setState(() => isGenerating = true);
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
                                      ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                      : Icon(Icons.picture_as_pdf),
                              label: Text(
                                isGenerating
                                    ? 'Generating...'
                                    : 'Generate PDF',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isDark
                                        ? AppColors.neonCyan
                                        : AppColors.brandDeepGold,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notificationService = ref.read(notificationServiceProvider);

    try {
      // Show initial notification
      notificationService.showNotification(
        message: 'Preparing PDF...',
        type: NotificationType.info,
        duration: const Duration(seconds: 3),
      );

      // Prepare the request data
      final requestData = {
        'examId': examId,
        'name': examName,
        'QandA': includeAnswers,
        'groupBy': groupBy,
        'colorTheme': colorTheme,
        'includeMetadata': includeMetadata,
      };

      // Generate a filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${examName.replaceAll(' ', '_')}_$timestamp.pdf';

      // Show generation notification
      notificationService.showNotification(
        message: 'Generating PDF...',
        type: NotificationType.info,
        duration: const Duration(seconds: 3),
      );

      // Download PDF data from server
      final response = await DioConfig.dio?.post(
        '/question/fetchExamData',
        data: requestData,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: false,
        ),
      );

      if (response?.statusCode == 200) {
        // Get PDF data
        final pdfBytes = response!.data;

        // Handle based on platform
        if (Platform.isAndroid) {
          // For Android: Try to save directly to Downloads folder first
          try {
            // Check if we have storage permissions
            if (await Permission.storage.request().isGranted) {
              // Get the Downloads directory
              final downloadsDir = await getExternalStorageDirectory();
              final downloadPath = '${downloadsDir?.path}/Download/$fileName';
              final downloadFile = File(downloadPath);

              // Create parent directories if they don't exist
              if (!await downloadFile.parent.exists()) {
                await downloadFile.parent.create(recursive: true);
              }

              // Write PDF to Downloads folder
              await downloadFile.writeAsBytes(pdfBytes);

              // Notify user of successful save
              notificationService.showNotification(
                message: 'PDF saved to Downloads folder',
                type: NotificationType.success,
                duration: const Duration(seconds: 4),
              );

              await OpenFile.open(downloadPath);

              // Also offer to share if needed
              // Use a short delay to avoid notification overlap
              await Future.delayed(const Duration(seconds: 1));
              final shouldShare =
                  await showDialog<bool>(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('PDF Saved'),
                          content: const Text(
                            'Would you also like to share this PDF?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('No'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Yes'),
                            ),
                          ],
                        ),
                  ) ??
                  false;

              if (shouldShare) {
                await _showBlurredShareDialog(
                  context,
                  downloadPath,
                  examName,
                  isDark,
                );
              } else {
                // Auto-open the file after saving
                OpenFile.open(downloadPath);
              }

              return; // Exit early as we've handled the file
            }
          } catch (e) {
            print('Error saving to Downloads folder: $e');
            // Continue to fallback method if direct save fails
          }
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          // For desktop platforms: Use file_picker to get save location
          try {
            // Save to temp first
            final tempDir = await getTemporaryDirectory();
            final tempPath = '${tempDir.path}/$fileName';
            final tempFile = File(tempPath);
            await tempFile.writeAsBytes(pdfBytes);

            // Use file_picker to show save dialog (requires file_picker package)
            final result = await FilePicker.platform.saveFile(
              dialogTitle: 'Save PDF File',
              fileName: fileName,
              type: FileType.custom,
              allowedExtensions: ['pdf'],
            );

            if (result != null) {
              // Copy from temp to chosen location
              await File(tempPath).copy(result);

              notificationService.showNotification(
                message: 'PDF saved successfully!',
                type: NotificationType.success,
                duration: const Duration(seconds: 4),
              );

              // Open the file
              OpenFile.open(result);
              return; // Exit early as we've handled the file
            }
          } catch (e) {
            print('Error saving with file picker: $e');
            // Continue to fallback method
          }
        }

        // Fallback for all platforms if direct save methods fail

        // Save to temporary file
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/$fileName';
        final tempFile = File(tempPath);
        await tempFile.writeAsBytes(pdfBytes);

        // Notify user
        notificationService.showNotification(
          message: 'PDF generated! Choose where to save...',
          type: NotificationType.success,
          duration: const Duration(seconds: 3),
        );

        // Use share sheet as fallback (works on all platforms)
        await Share.shareXFiles(
          [XFile(tempPath)],
          text: 'Quiz PDF: $examName',
          subject: fileName,
        );
      } else {
        throw Exception('Failed to download PDF: ${response?.statusMessage}');
      }
    } catch (e) {
      print('Error generating PDF: $e');
      notificationService.showNotification(
        message: 'Error generating PDF: ${e.toString()}',
        type: NotificationType.error,
        duration: const Duration(seconds: 5),
      );
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

  // Add this new method
  Future _showBlurredShareDialog(
    BuildContext context,
    String filePath,
    String examName,
    bool isDark,
  ) async {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Share PDF',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Center(
            child: Material(  // Add this Material widget
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? Colors.black87.withOpacity(0.9)
                          : Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color:
                          isDark
                              ? AppColors.neonCyan.withOpacity(0.3)
                              : AppColors.brandDeepGold.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(
                    color:
                        isDark
                            ? AppColors.neonCyan.withOpacity(0.3)
                            : AppColors.brandDeepGold.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.picture_as_pdf,
                      color:
                          isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'PDF Created Successfully!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your PDF has been saved. What would you like to do now?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            context,
                            MdiIcons.fileDocument,
                            'Open PDF',
                            () {
                              OpenFile.open(filePath);
                              Navigator.pop(context);
                            },
                            isDark,
                            primary: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            context,
                            MdiIcons.share,
                            'Share PDF',
                            () async {
                              await Share.shareXFiles([
                                XFile(filePath),
                              ], text: 'Quiz PDF: $examName');
                              Navigator.pop(context);
                            },
                            isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onPressed,
    bool isDark, {
    bool primary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient:
                primary
                    ? LinearGradient(
                      colors:
                          isDark
                              ? [
                                AppColors.neonCyan,
                                Color.lerp(
                                  AppColors.neonCyan,
                                  Colors.blue,
                                  0.3,
                                )!,
                              ]
                              : [
                                AppColors.brandDeepGold,
                                Color.lerp(
                                  AppColors.brandDeepGold,
                                  Colors.orange,
                                  0.3,
                                )!,
                              ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                    : null,
            color:
                primary
                    ? null
                    : (isDark
                        ? Colors.white10
                        : Colors.black.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  primary
                      ? Colors.transparent
                      : (isDark ? Colors.white24 : Colors.black12),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color:
                    primary
                        ? Colors.white
                        : (isDark
                            ? AppColors.neonCyan
                            : AppColors.brandDeepGold),
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color:
                      primary
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
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
    MaterialColor barColor =
        score >= 80
            ? Colors.green
            : score >= 60
            ? Colors.amber
            : Colors.red;

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

  Future<void> _fetchSections() async {
    try {
      final response = await DioConfig.dio?.get(
        '/ebook/${widget.ebookId}/sectionTitles',
      );

      if (response?.statusCode == 200 && response?.data['success'] == true) {
        if (response?.data['data'] != null &&
            response?.data['data']['sections'] is List) {
          final structuredSections = response!.data['data']['sections'] as List;
          final headSectionTitles = <String>[];
          final seenTitles = <String, int>{};

          for (var section in structuredSections) {
            if (section is Map<String, dynamic> &&
                section['type'] == 'head' &&
                section['title'] != null) {
              final title = section['title'].toString();
              if (seenTitles.containsKey(title)) {
                seenTitles[title] = seenTitles[title]! + 1;
                headSectionTitles.add('$title (${seenTitles[title]})');
              } else {
                seenTitles[title] = 1;
                headSectionTitles.add(title);
              }
            }
          }

          setState(() => _availableSections = headSectionTitles);
        } else {
          setState(() => _availableSections = []);
        }
      } else {
        setState(() => _availableSections = []);
      }
    } catch (e) {
      setState(() => _availableSections = []);
    }
  }
}

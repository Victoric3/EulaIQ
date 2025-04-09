import 'dart:convert';
import 'package:auto_route/auto_route.dart';
import 'package:eulaiq/src/common/common.dart';
import 'package:eulaiq/src/common/constants/dio_config.dart';
import 'package:eulaiq/src/common/services/notification_service.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:eulaiq/src/common/widgets/notification_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:eulaiq/src/features/quiz/presentation/providers/quiz_summary_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

@RoutePage()
class QuizOptionsScreen extends ConsumerStatefulWidget {
  final String ebookId;
  final String? preSelectedExamId;

  const QuizOptionsScreen({
    Key? key,
    required this.ebookId,
    this.preSelectedExamId,
  }) : super(key: key);

  @override
  ConsumerState<QuizOptionsScreen> createState() => _QuizOptionsScreenState();
}

class _QuizOptionsScreenState extends ConsumerState<QuizOptionsScreen> {
  bool _isLoading = true;
  bool _isStartingQuiz = false;
  List<Map<String, dynamic>> _availableExams = [];

  // Selected options
  final Set<String> _selectedExamIds = {};
  String? _selectedDifficulty;
  String? _selectedPriority;
  String? _selectedTopic;
  String? _selectedExamFrequency;
  int _questionLimit = 10;
  bool _isCustomQuestionLimit = false;
  final TextEditingController _customQuestionLimitController =
      TextEditingController(text: '10');
  bool _randomizeQuestions = true;
  double _minRelevanceScore = 0;
  int _durationPerQuestion = 60; // Default 60 seconds per question
  final List<int> _durationOptions = [5, 10, 15, 30, 45, 60, 90, 120, 180]; // Options in seconds

  // Available filter options
  final List<String> _difficulties = ['Any', 'Easy', 'Medium', 'Hard'];
  final List<String> _priorities = ['Any', 'High', 'Medium', 'Low'];
  final List<String> _examFrequencies = [
    'Any',
    'Very Common',
    'Common',
    'Uncommon',
    'Rare',
  ];
  final List<int> _questionLimits = [5, 10, 15, 20, 30, 50, 100];

  // Dynamic filter options from exams
  List<String> _availableTopics = ['Any'];

  // UI control
  bool _isExamSectionExpanded = true;

  // Pagination state
  Map<String, dynamic>? _previousQuizState;
  bool _hasPreviousQuiz = false;
  int _currentQuizPage = 1;
  int _totalQuizPages = 1;
  int _totalAvailableQuestions = 0;

  String _customQuestionPrompt =
      'Generate multiple-choice questions that thoroughly cover all key concepts, nuances, and intricate details of the content. The questions should be structured to be difficult, with tempting but incorrect answer choices that challenge deep understanding. The material contains delicate educational content, Ensure all aspects of the material are addressed, leaving no concept untouched.';
  bool _isCustomPromptExpanded = false;

  String _examName = 'Practice Quiz';
  final TextEditingController _examNameController =
      TextEditingController(text: 'Practice Quiz');

  @override
  void initState() {
    super.initState();
    _examNameController.text = _examName;
    if (widget.preSelectedExamId != null) {
      _selectedExamIds.add(widget.preSelectedExamId!);
    }
    _loadPreviousQuizState();
  }

  @override
  void dispose() {
    _customQuestionLimitController.dispose();
    _examNameController.dispose();
    super.dispose();
  }

  Future<void> _loadPreviousQuizState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedQuizStateJson = prefs.getString('last_quiz_state_${widget.ebookId}');
      if (savedQuizStateJson != null) {
        final savedState = jsonDecode(savedQuizStateJson) as Map<String, dynamic>;
        final int currentPage = _safeParseInt(savedState['pagination']?['page'], 1);
        final int totalPages = _safeParseInt(savedState['pagination']?['pages'], 1);
        final int totalQuestions = _safeParseInt(savedState['pagination']?['total'], 0);
        setState(() {
          _previousQuizState = savedState;
          _currentQuizPage = currentPage;
          _totalQuizPages = totalPages;
          _totalAvailableQuestions = totalQuestions;
          _hasPreviousQuiz = totalPages > 1 && currentPage < totalPages;
        });
        if (_hasPreviousQuiz) {
          _promptForPreviousQuiz();
        }
      }
    } catch (e) {
      print('Error loading previous quiz state: $e');
    }
  }

  int _safeParseInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  void _promptForPreviousQuiz() {
    if (_previousQuizState == null) return;
    Future.microtask(() {
      final int limitValue = _safeParseInt(_previousQuizState!['queryParams']?['limit'], 10);
      final int remainingQuestions = _totalAvailableQuestions - (_currentQuizPage * limitValue);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Continue Previous Quiz?'),
          content: Text(
            'You have more questions from your previous session.\n\n'
            'There are $remainingQuestions '
            'more questions available (page ${_currentQuizPage + 1} of $_totalQuizPages).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Start New Quiz'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _continuePreviousQuiz();
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    });
  }

  void _continuePreviousQuiz() {
    if (_previousQuizState == null) return;
    final savedQueryParams = _previousQuizState!['queryParams'] as Map<String, dynamic>;
    setState(() {
      if (savedQueryParams['examName'] != null) {
        _examName = savedQueryParams['examName'];
        _examNameController.text = _examName;
      }
      if (savedQueryParams['examIds'] != null) {
        _selectedExamIds.clear();
        for (var id in savedQueryParams['examIds']) {
          _selectedExamIds.add(id.toString());
        }
      }
      _selectedDifficulty = savedQueryParams['difficulty'] ?? 'Any';
      _selectedPriority = savedQueryParams['priority'] != null
          ? _capitalizeFirstLetter(savedQueryParams['priority'])
          : 'Any';
      _selectedTopic = savedQueryParams['topic'] ?? 'Any';
      _selectedExamFrequency = savedQueryParams['examFrequency'] != null
          ? _formatExamFrequency(savedQueryParams['examFrequency'])
          : 'Any';
      _questionLimit = _safeParseInt(savedQueryParams['limit'], 10);
      _customQuestionLimitController.text = _questionLimit.toString();
      _randomizeQuestions = savedQueryParams['random'] == 'true';
      _minRelevanceScore = _safeParseDouble(savedQueryParams['minRelevance'], 0.0);
      if (savedQueryParams['questionDescription'] != null) {
        _customQuestionPrompt = savedQueryParams['questionDescription'];
      }
    });
    _startQuiz(continuePrevious: true);
  }

  double _safeParseDouble(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  String _formatExamFrequency(String frequency) {
    final words = frequency.split(' ');
    return words.map((word) => _capitalizeFirstLetter(word)).join(' ');
  }

  void _processExamsFromProvider(Map<String, dynamic>? data) {
    if (data != null && data['exams'] != null) {
      final List<dynamic> exams = data['exams'];
      _availableExams = exams
          .where((exam) => ['ready', 'complete'].contains((exam['status'] ?? '').toLowerCase()))
          .map((exam) => exam as Map<String, dynamic>)
          .toList();
      final Set<String> topics = {'Any'};
      for (final exam in _availableExams) {
        if (exam['topics'] != null) {
          for (final topic in exam['topics']) {
            if (topic['topic'] != null) topics.add(topic['topic']);
          }
        }
      }
      _availableTopics = topics.toList();
    }
  }

  Future<void> _startQuiz({bool continuePrevious = false}) async {
    if (_selectedExamIds.isEmpty) {
      ref.read(notificationServiceProvider).showNotification(
            message: 'Please select at least one exam',
            type: NotificationType.warning,
            duration: const Duration(seconds: 3),
          );
      return;
    }
    final notificationService = ref.read(notificationServiceProvider);
    try {
      setState(() => _isStartingQuiz = true);
      final actualQuestionLimit = _isCustomQuestionLimit
          ? int.tryParse(_customQuestionLimitController.text) ?? 10
          : _questionLimit;
      final cappedQuestionLimit = actualQuestionLimit > 500 ? 500 : actualQuestionLimit;
      final Map<String, dynamic> queryParams = {
        'examIds': _selectedExamIds.toList(),
        'limit': cappedQuestionLimit.toString(),
        'random': _randomizeQuestions.toString(),
        'minRelevance': _minRelevanceScore.toInt().toString(),
        'questionDescription': _customQuestionPrompt,
        'page': continuePrevious && _previousQuizState != null
            ? ((_previousQuizState!['pagination']['page'] ?? 1) + 1).toString()
            : '1',
      };
      if (_selectedDifficulty != null && _selectedDifficulty != 'Any') {
        queryParams['difficulty'] = _selectedDifficulty;
      }
      if (_selectedPriority != null && _selectedPriority != 'Any') {
        queryParams['priority'] = _selectedPriority?.toLowerCase();
      }
      if (_selectedTopic != null && _selectedTopic != 'Any') {
        queryParams['topic'] = _selectedTopic;
      }
      if (_selectedExamFrequency != null && _selectedExamFrequency != 'Any') {
        queryParams['examFrequency'] = _selectedExamFrequency?.toLowerCase();
      }
      final response = await DioConfig.dio?.get('/question/getQuestion', queryParameters: queryParams);
      if (response?.statusCode == 200 && response?.data['success'] == true) {
        final quizData = response?.data['data'];
        final questions = quizData['questions'];
        final pagination = quizData['pagination'];
        final quizState = {
          'queryParams': queryParams,
          'pagination': pagination,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_quiz_state_${widget.ebookId}', jsonEncode(quizState));
        if (questions.isEmpty) {
          throw Exception('No questions match your criteria. Try different filters.');
        }
        if (questions.length < cappedQuestionLimit) {
          notificationService.showNotification(
            message: 'Only ${questions.length} questions available with these filters.',
            type: NotificationType.info,
            duration: const Duration(seconds: 3),
          );
        }
        final totalDuration = _durationPerQuestion * questions.length;
        context.router.push(
          QuizRoute(
            questions: List<Map<String, dynamic>>.from(questions),
            durationPerQuestion: _durationPerQuestion,
            totalDuration: totalDuration.toInt(),
            examOptions: {
              'difficulty': _selectedDifficulty ?? 'Any',
              'randomized': _randomizeQuestions,
              'questionCount': questions.length,
              'page': int.parse(queryParams['page']),
              'totalPages': pagination['pages'] ?? 1,
              'totalQuestions': pagination['total'] ?? questions.length,
              'examName': _examNameController.text.isEmpty ? 'Practice Quiz' : _examNameController.text,
            },
          ),
        );
      } else {
        throw Exception(response?.data['message'] ?? 'Failed to fetch questions');
      }
    } catch (e) {
      notificationService.showNotification(
        message: e.toString(),
        type: NotificationType.error,
        duration: const Duration(seconds: 4),
      );
    } finally {
      setState(() => _isStartingQuiz = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final quizSummaryState = ref.watch(quizSummaryProvider(widget.ebookId));
    final isProviderLoading = quizSummaryState.isLoading;
    final providerError = quizSummaryState.errorMessage;
    if (!isProviderLoading && quizSummaryState.data != null && _availableExams.isEmpty) {
      _processExamsFromProvider(quizSummaryState.data);
      _isLoading = false;
    } else if (!isProviderLoading && providerError != null) {
      _isLoading = false;
    }
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Quiz Options'),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        elevation: 0,
        actions: [
          if (_hasPreviousQuiz)
            IconButton(
              icon: Badge(
                label: const Text('1'),
                child: Icon(
                  MdiIcons.playCircleOutline,
                  color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                ),
              ),
              onPressed: _promptForPreviousQuiz,
              tooltip: 'Continue Previous Quiz',
            ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                  ),
                )
              : _buildOptionsContent(isDark),
          if (_isStartingQuiz) _buildQuizStartingOverlay(isDark),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(isDark),
    );
  }

  Widget _buildOptionsContent(bool isDark) {
    return ListView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
      children: [
        if (_hasPreviousQuiz) _buildPreviousQuizBanner(isDark),
        _buildCollapsibleSection(
          title: 'Select Exams',
          isExpanded: _isExamSectionExpanded,
          onToggle: () => setState(() => _isExamSectionExpanded = !_isExamSectionExpanded),
          content: _buildExamsSelection(isDark),
          isDark: isDark,
          leading: Icon(
            MdiIcons.fileDocumentOutline,
            color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            size: 20,
          ),
        ),
        const SizedBox(height: 16),
        _buildSettingsCard(
          isDark: isDark,
          icon: MdiIcons.tune,
          title: 'Quiz Filters',
          content: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      'Difficulty',
                      _selectedDifficulty ?? 'Any',
                      _difficulties,
                      isDark,
                      (value) => setState(() => _selectedDifficulty = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      'Priority',
                      _selectedPriority ?? 'Any',
                      _priorities,
                      isDark,
                      (value) => setState(() => _selectedPriority = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      'Topic',
                      _selectedTopic ?? 'Any',
                      _availableTopics,
                      isDark,
                      (value) => setState(() => _selectedTopic = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      'Exam Frequency',
                      _selectedExamFrequency ?? 'Any',
                      _examFrequencies,
                      isDark,
                      (value) => setState(() => _selectedExamFrequency = value),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSettingsCard(
          isDark: isDark,
          icon: MdiIcons.cog,
          title: 'Quiz Settings',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Exam Name',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white24 : Colors.black12,
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _examNameController,
                  onChanged: (value) => setState(() => _examName = value),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Name your quiz/exam',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _isCustomQuestionLimit
                        ? _buildCustomQuestionInput(isDark)
                        : _buildDropdown(
                            'Number of Questions',
                            _questionLimit.toString(),
                            [..._questionLimits.map((e) => e.toString()), 'Custom...'],
                            isDark,
                            (value) {
                              if (value == 'Custom...') {
                                setState(() {
                                  _isCustomQuestionLimit = true;
                                  _customQuestionLimitController.text = _questionLimit.toString();
                                });
                              } else {
                                setState(() => _questionLimit = int.parse(value));
                              }
                            },
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown(
                      'Seconds per Question',
                      _durationPerQuestion.toString(),
                      _durationOptions.map((e) => e.toString()).toList(),
                      isDark,
                      (value) => setState(() => _durationPerQuestion = int.parse(value)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSwitchTile(
                'Randomize Questions',
                _randomizeQuestions,
                isDark,
                (value) => setState(() => _randomizeQuestions = value),
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Minimum Relevance Score',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _minRelevanceScore,
                          min: 0,
                          max: 100,
                          divisions: 10,
                          label: '${_minRelevanceScore.toInt()}%',
                          activeColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                          inactiveColor: isDark ? Colors.white24 : Colors.black12,
                          onChanged: (value) => setState(() => _minRelevanceScore = value),
                        ),
                      ),
                      Container(
                        width: 50,
                        alignment: Alignment.center,
                        child: Text(
                          '${_minRelevanceScore.toInt()}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildCustomPromptCard(isDark),
        const SizedBox(height: 16),
        _buildSettingsCard(
          isDark: isDark,
          icon: MdiIcons.checkboxMarkedCircleOutline,
          title: 'Quiz Summary',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryItem(
                isDark,
                'Selected Exams:',
                '${_selectedExamIds.length} exam${_selectedExamIds.length != 1 ? 's' : ''}',
                MdiIcons.bookOpenVariant,
              ),
              const SizedBox(height: 8),
              _buildSummaryItem(
                isDark,
                'Expected Questions:',
                _isCustomQuestionLimit
                    ? '${_customQuestionLimitController.text} questions (max)'
                    : '$_questionLimit questions',
                MdiIcons.formatListNumbered,
              ),
              const SizedBox(height: 8),
              _buildSummaryItem(
                isDark,
                'Time Limit:',
                '${(_durationPerQuestion * (_isCustomQuestionLimit ? int.tryParse(_customQuestionLimitController.text) ?? 10 : _questionLimit) / 60).toStringAsFixed(1)} minutes',
                MdiIcons.clockOutline,
              ),
              const SizedBox(height: 8),
              _buildSummaryItem(
                isDark,
                'Difficulty:',
                _selectedDifficulty ?? 'Any',
                MdiIcons.speedometer,
              ),
              if (_selectedTopic != null && _selectedTopic != 'Any') ...[
                const SizedBox(height: 8),
                _buildSummaryItem(
                  isDark,
                  'Topic Focus:',
                  _selectedTopic!,
                  MdiIcons.tagOutline,
                ),
              ],
              const SizedBox(height: 8),
              _buildSummaryItem(
                isDark,
                'Exam Name:',
                _examNameController.text.isEmpty ? 'Practice Quiz' : _examNameController.text,
                MdiIcons.clipboardTextOutline,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviousQuizBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16), // Fixed: Changed 'custom' to 'bottom'
      decoration: BoxDecoration(
        color: isDark ? AppColors.neonCyan.withOpacity(0.1) : AppColors.brandDeepGold.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.neonCyan.withOpacity(0.3) : AppColors.brandDeepGold.withOpacity(0.3),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            MdiIcons.history,
            color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Previous Quiz Available',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  'You have more questions from your previous session',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _continuePreviousQuiz,
            child: Text(
              'Continue',
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

  Widget _buildCustomQuestionInput(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Number of Questions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                maxLines: 2,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isCustomQuestionLimit = false;
                  _questionLimit = int.tryParse(_customQuestionLimitController.text) ?? 10;
                  if (!_questionLimits.contains(_questionLimit)) {
                    int nearestValue = _questionLimits
                        .reduce((a, b) => (a - _questionLimit).abs() < (b - _questionLimit).abs() ? a : b);
                    _questionLimit = nearestValue;
                  }
                });
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Use Preset',
                style: TextStyle(
                  color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: isDark ? Colors.black26 : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.black12,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _customQuestionLimitController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              TextInputFormatter.withFunction((oldValue, newValue) {
                if (newValue.text.isEmpty) return newValue;
                final intValue = int.tryParse(newValue.text) ?? 0;
                if (intValue > 500) {
                  return const TextEditingValue(
                    text: '500',
                    selection: TextSelection.collapsed(offset: 3),
                  );
                }
                return newValue;
              }),
            ],
            onChanged: (value) {
              if (value.isEmpty) {
                _customQuestionLimitController.text = '';
                _customQuestionLimitController.selection =
                    TextSelection.collapsed(offset: _customQuestionLimitController.text.length);
              }
            },
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: '1-500',
              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              suffixText: 'questions',
              suffixStyle: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard({
    required bool isDark,
    required IconData icon,
    required String title,
    required Widget content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black38 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold, size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(bool isDark, String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: isDark ? Colors.white60 : Colors.black54),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsibleSection({
    required String title,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget content,
    required bool isDark,
    Widget? leading,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isDark ? Colors.black38 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          ListTile(
            onTap: onToggle,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: leading,
            title: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: content,
            ),
            secondChild: const SizedBox(height: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildExamsSelection(bool isDark) {
    if (_availableExams.isEmpty) {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          color: isDark ? Colors.black26 : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'No exams available. Generate questions first.',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Available Exams (${_availableExams.length})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selectedExamIds.length == _availableExams.length) {
                    _selectedExamIds.clear();
                  } else {
                    _selectedExamIds.clear();
                    for (final exam in _availableExams) {
                      if (exam['examId'] != null) {
                        _selectedExamIds.add(exam['examId'].toString());
                      }
                    }
                  }
                });
              },
              child: Text(
                _selectedExamIds.length == _availableExams.length ? 'Deselect All' : 'Select All',
                style: TextStyle(
                  color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _availableExams.length,
          itemBuilder: (context, index) {
            final exam = _availableExams[index];
            final examId = exam['examId']?.toString() ?? '';
            final examName = exam['name'] ?? 'Exam ${index + 1}';
            final questionCount = exam['questionCount'] ?? 0;
            final difficulty = exam['difficulty'] ?? 'Medium';
            final isSelected = _selectedExamIds.contains(examId);
            return CheckboxListTile(
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedExamIds.add(examId);
                  } else {
                    _selectedExamIds.remove(examId);
                  }
                });
              },
              title: Text(
                examName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Row(
                children: [
                  Icon(MdiIcons.fileDocumentOutline, size: 14, color: isDark ? Colors.white60 : Colors.black45),
                  const SizedBox(width: 4),
                  Text('$questionCount questions',
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black45)),
                  const SizedBox(width: 8),
                  Icon(MdiIcons.speedometer, size: 14, color: isDark ? Colors.white60 : Colors.black45),
                  const SizedBox(width: 4),
                  Text(difficulty, style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black45)),
                ],
              ),
              activeColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
              checkColor: Colors.white,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              tileColor: isSelected
                  ? (isDark ? AppColors.neonCyan.withOpacity(0.1) : AppColors.brandDeepGold.withOpacity(0.05))
                  : Colors.transparent,
            );
          },
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, bool isDark, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black87),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.black26 : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white24 : Colors.black12, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold),
              iconSize: 24,
              elevation: 8,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
              dropdownColor: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              items: items.map<DropdownMenuItem<String>>((String item) {
                return DropdownMenuItem<String>(value: item, child: Text(item));
              }).toList(),
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, bool value, bool isDark, Function(bool) onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white24 : Colors.black12, width: 1),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    final int displayQuestionCount =
        _isCustomQuestionLimit ? int.tryParse(_customQuestionLimitController.text) ?? 10 : _questionLimit;
    final int totalSeconds = displayQuestionCount * _durationPerQuestion;
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    final String timeDisplay = minutes > 0
        ? "$minutes ${minutes == 1 ? 'minute' : 'minutes'} ${seconds > 0 ? '$seconds seconds' : ''}"
        : "$seconds seconds";
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(MdiIcons.clockOutline, size: 18, color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold),
                const SizedBox(width: 8),
                Text('Time: $timeDisplay',
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54)),
                const SizedBox(width: 16),
                Icon(MdiIcons.fileDocumentOutline, size: 18, color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold),
                const SizedBox(width: 8),
                Text('Questions: $displayQuestionCount',
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: (_isLoading || _isStartingQuiz) ? null : _startQuiz,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 2,
                  shadowColor: isDark ? AppColors.neonCyan.withOpacity(0.3) : AppColors.brandDeepGold.withOpacity(0.3),
                  disabledBackgroundColor:
                      isDark ? AppColors.neonCyan.withOpacity(0.4) : AppColors.brandDeepGold.withOpacity(0.4),
                  disabledForegroundColor: Colors.white70,
                ),
                child: _isStartingQuiz
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(MdiIcons.playCircleOutline, size: 24),
                          const SizedBox(width: 8),
                          const Text(
                            'Start Quiz',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizStartingOverlay(bool isDark) {
    return Container(
      color: isDark ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.8),
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? Colors.black54 : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 150,
                width: 150,
                child: LottieBuilder.asset(
                  isDark ? 'assets/animations/processing-darkmode.json' : 'assets/animations/processing.json',
                  fit: BoxFit.contain,
                  repeat: true,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Fetching Questions',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 12),
              Text(
                _getLoadingMessage(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getLoadingMessage() {
    final messages = [
      'Creating your personalized quiz experience...',
      'Selecting the best questions for you...',
      'Preparing your knowledge challenge...',
      'Tailoring questions to your selected criteria...',
      'Building your quiz session...',
    ];
    return messages[DateTime.now().millisecond % messages.length];
  }

  Widget _buildCustomPromptCard(bool isDark) {
    return _buildCollapsibleSection(
      title: 'Custom Question Prompt',
      isExpanded: _isCustomPromptExpanded,
      onToggle: () => setState(() => _isCustomPromptExpanded = !_isCustomPromptExpanded),
      isDark: isDark,
      leading: Icon(
        MdiIcons.chatQuestionOutline,
        color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
        size: 20,
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customize how questions are generated',
            style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white24 : Colors.black12, width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: TextEditingController(text: _customQuestionPrompt),
              onChanged: (value) => setState(() => _customQuestionPrompt = value),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Describe how you want questions to be generated...',
                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: Icon(
                  MdiIcons.refresh,
                  size: 16,
                  color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                ),
                label: Text(
                  'Reset to Default',
                  style: TextStyle(
                    color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                    fontSize: 13,
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _customQuestionPrompt =
                        'Generate multiple-choice questions that thoroughly cover key concepts from the content.';
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
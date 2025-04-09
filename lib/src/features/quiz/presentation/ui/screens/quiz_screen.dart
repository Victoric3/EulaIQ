import 'dart:async';
import 'package:eulaiq/src/common/common.dart';
import 'package:eulaiq/src/common/constants/dio_config.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:eulaiq/src/features/auth/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:auto_route/auto_route.dart';

@RoutePage()
class QuizScreen extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> questions;
  final int durationPerQuestion;
  final int totalDuration;
  final Map<String, dynamic> examOptions;

  const QuizScreen({
    Key? key,
    required this.questions,
    required this.durationPerQuestion,
    required this.totalDuration,
    required this.examOptions,
  }) : super(key: key);

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  int _currentQuestionIndex = 0;
  List<String?> _selectedAnswers = [];
  List<bool> _isBookmarked = [];
  Timer? _timer;
  int _remainingSeconds = 0;
  int _startTime = 0;
  Map<int, int> _timeSpentPerQuestion = {};
  int _activeQuestionStartTime = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Initialize answer array with nulls (no answer selected)
    _selectedAnswers = List.filled(widget.questions.length, null);
    // Initialize bookmark array
    _isBookmarked = List.filled(widget.questions.length, false);
    // Set initial timer value
    _remainingSeconds = widget.totalDuration;
    // Record start time
    _startTime = DateTime.now().millisecondsSinceEpoch;
    _activeQuestionStartTime = _startTime;
    // Start the timer
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _submitQuiz();
        }
      });
    });
  }

  void _recordQuestionTime() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final timeSpent = now - _activeQuestionStartTime;
    _timeSpentPerQuestion[_currentQuestionIndex] = 
        (_timeSpentPerQuestion[_currentQuestionIndex] ?? 0) + timeSpent;
    _activeQuestionStartTime = now;
  }

  void _goToQuestion(int index) {
    // Record time spent on current question before moving
    _recordQuestionTime();
    
    setState(() {
      _currentQuestionIndex = index;
    });
  }

  void _submitQuiz() async {
    _timer?.cancel();
    
    // Record time for the last question
    _recordQuestionTime();
    
    setState(() {
      _isSubmitting = true;
    });
    
    // Save exam history
    final examHistoryId = await _saveExamHistory(completed: true);
    context.router.push(QuizResultsRoute(examHistoryId: examHistoryId));
  }

  Future<String> _saveExamHistory({bool completed = true}) async {
    try {
      // Calculate total time spent
      final totalTimeSpent = DateTime.now().millisecondsSinceEpoch - _startTime;
      
      // Calculate score
      int correctAnswers = 0;
      
      // Prepare questions with user answers and analytics
      final List<Map<String, dynamic>> enhancedQuestions = [];
      
      // Process questions ONCE - you currently have two loops adding the same questions twice!
      for (int i = 0; i < widget.questions.length; i++) {
        final question = Map<String, dynamic>.from(widget.questions[i]);
        final List<String> options = List<String>.from(question['options'] ?? []);
        
        // Get selected answer (might be the text or index)
        var selectedAnswer = _selectedAnswers[i];
        
        // Get correct option (might be the text or index)
        var correctOption = question['correctOption'];
        int correctIndex = -1;
        
        // If correctOption is a number/index
        if (correctOption is int || (correctOption is String && int.tryParse(correctOption) != null)) {
          correctIndex = int.tryParse(correctOption.toString()) ?? -1;
        } 
        // If correctOption is the actual option text
        else if (correctOption is String) {
          correctIndex = options.indexOf(correctOption);
        }
        
        // Determine selected index
        int selectedIndex = -1;
        if (selectedAnswer != null) {
          selectedIndex = options.indexOf(selectedAnswer);
        }
        
        // Check if answer is correct
        bool isCorrect = (selectedIndex >= 0 && selectedIndex == correctIndex);
        if (isCorrect) {
          correctAnswers++;
        }
        
        // CRITICAL FIX: Add the userAnswer field that the backend expects
        question['userAnswer'] = selectedAnswer;
        
        // Store both the index and the letter for better display
        question['userAnswerIndex'] = selectedIndex;
        question['correctOptionIndex'] = correctIndex;
        question['userAnswerLetter'] = selectedIndex >= 0 ? String.fromCharCode(65 + selectedIndex) : '';
        question['correctOptionLetter'] = correctIndex >= 0 ? String.fromCharCode(65 + correctIndex) : '';
        question['isCorrect'] = isCorrect;
        
        // Keep the explanation field which is important for the review screen
        // Make sure we're preserving the explanation from the original question
        question['explanation'] = question['explanation'] ?? "No explanation is available for this question";
        
        // Add time spent analytics
        question['timeSpentOnQuestion'] = _timeSpentPerQuestion[i] ?? 0;
        question['isHighlighted'] = _isBookmarked[i];
        
        // Add default values for fields that might be missing
        question['topic'] = question['topic'] ?? 'General';
        question['difficulty'] = question['difficulty'] ?? 'Medium';
        question['priority'] = question['priority'] ?? 'medium';
        question['relevanceScore'] = question['relevanceScore'] ?? 50;
        question['examFrequency'] = question['examFrequency'] ?? 'common';
        question['conceptCategory'] = question['conceptCategory'] ?? 'general';
        
        enhancedQuestions.add(question);
      }
      
      final double scorePercentage = widget.questions.isEmpty ? 0 : 
    (correctAnswers / widget.questions.length) * 100;
      
      // Calculate topic-wise performance
      final Map<String, Map<String, dynamic>> topicPerformance = {};

      for (int i = 0; i < widget.questions.length; i++) {
        final question = widget.questions[i];
        final String topic = question['topic'] ?? 'General';
        final correctAnswer = question['correctOption'];
        final userAnswer = _selectedAnswers[i];
        
        // Check if the topic exists in our tracking map
        if (!topicPerformance.containsKey(topic)) {
          topicPerformance[topic] = {
            'correct': 0,
            'total': 0,
            'score': 0.0,
            'totalTimeSpent': 0,
          };
        }
        
        // Increment the total count for this topic
        topicPerformance[topic]!['total'] = (topicPerformance[topic]!['total'] as int) + 1;
        
        // Check if the answer is correct (handle both index and text comparison)
        bool isCorrect = false;
        
        if (correctAnswer != null && userAnswer != null) {
          if (correctAnswer is int || (correctAnswer is String && int.tryParse(correctAnswer) != null)) {
            // It's an index
            int correctIndex = int.tryParse(correctAnswer.toString()) ?? -1;
            if (correctIndex >= 0 && correctIndex < question['options'].length) {
              isCorrect = question['options'][correctIndex] == userAnswer;
            }
          } else {
            // Direct comparison
            isCorrect = correctAnswer == userAnswer;
          }
          
          if (isCorrect) {
            topicPerformance[topic]!['correct'] = (topicPerformance[topic]!['correct'] as int) + 1;
          }
        }
        
        // Add time spent
        topicPerformance[topic]!['totalTimeSpent'] = 
            (topicPerformance[topic]!['totalTimeSpent'] as int) + (_timeSpentPerQuestion[i] ?? 0);
      }

      // Calculate final scores for each topic
      topicPerformance.forEach((topic, data) {
        final int total = data['total'] as int;
        final int correct = data['correct'] as int;
        
        if (total > 0) {
          data['score'] = (correct / total) * 100;
          data['averageTimeSpent'] = (data['totalTimeSpent'] as int) ~/ total;
        }
      });
      
      // Build request payload with updated fields
      final user = ref.read(userProvider).value;
      final username = user?.username ?? 'anonymous';

      final payload = {
        'username': username, // Use actual username from provider
        'exam': widget.examOptions['examName'] ?? 'Practice Quiz',
        'totalScore': scorePercentage,
        'totalQuestions': widget.questions.length,
        'topicPerformance': topicPerformance,
        'questions': enhancedQuestions,
        'timeSpent': totalTimeSpent ~/ 1000, // Convert to seconds
        'deviceInfo': {
          'platform': 'mobile', // Or detect actual platform
          'completed': completed,
        },
      };
      
      // Make API request
      final response = await DioConfig.dio?.post(
        '/examHistory',
        data: payload,
      );
      
      if (response?.statusCode != 201) {
        throw Exception('Failed to save exam history');
      }
      
      // Store exam history ID for results screen
      final examHistoryId = response?.data['_id'];
      
      // Return so we can navigate to results screen
      return examHistoryId;
    } catch (e) {
      print('Error saving exam history: $e');
      // Rethrow to handle in calling method
      rethrow;
    }
  }

  String _formatTime(int seconds) {
    final int hours = seconds ~/ 3600;
    final int minutes = (seconds % 3600) ~/ 60;
    final int remainingSeconds = seconds % 60;
    
    String hoursStr = hours > 0 ? '${hours.toString().padLeft(2, '0')}:' : '';
    return '$hoursStr${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentQuestion = widget.questions[_currentQuestionIndex];
    final String questionText = currentQuestion['question'] ?? '';
    final List<String> options = List<String>.from(currentQuestion['options'] ?? []);
    final String? topic = currentQuestion['topic'];
    final String? difficulty = currentQuestion['difficulty'];


    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        elevation: 0,
        title: Text(
          'Quiz',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton.icon(
            icon: Icon(
              MdiIcons.clockOutline,
              color: _remainingSeconds < 60 
                 ? Colors.red
                 : (isDark ? AppColors.neonCyan : AppColors.brandDeepGold),
              size: 20,
            ),
            label: Text(
              _formatTime(_remainingSeconds),
              style: TextStyle(
                color: _remainingSeconds < 60
                    ? Colors.red
                    : (isDark ? AppColors.neonCyan : AppColors.brandDeepGold),
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: null,
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            onPressed: () {
              _showExitConfirmation();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Question progress indicator
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / widget.questions.length,
            backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            ),
            minHeight: 4,
          ),
          
          // Question navigation and info bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question ${_currentQuestionIndex + 1}/${widget.questions.length}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Row(
                  children: [
                    if (difficulty != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getDifficultyColor(difficulty, isDark),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          difficulty,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        _isBookmarked[_currentQuestionIndex] 
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        color: _isBookmarked[_currentQuestionIndex]
                            ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                            : (isDark ? Colors.white54 : Colors.black45),
                      ),
                      onPressed: () {
                        setState(() {
                          _isBookmarked[_currentQuestionIndex] = !_isBookmarked[_currentQuestionIndex];
                        });
                      },
                      tooltip: 'Bookmark',
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Question content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Topic label if available
                  if (topic != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        topic,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Question text
                  Text(
                    questionText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  
                  // Image if available
                  if (currentQuestion['image'] != null) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          currentQuestion['image'],
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: double.infinity,
                              height: 200,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / 
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Options
                  ...List.generate(options.length, (index) {
                    final String option = options[index];
                    final String optionLabel = String.fromCharCode(65 + index); // A, B, C, D...
                    final bool isSelected = _selectedAnswers[_currentQuestionIndex] == option;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedAnswers[_currentQuestionIndex] = option;
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark 
                                    ? AppColors.neonCyan.withOpacity(0.2)
                                    : AppColors.brandDeepGold.withOpacity(0.1))
                                : (isDark ? Colors.black45 : Colors.white),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                                  : (isDark ? Colors.white24 : Colors.black12),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected 
                                      ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                                      : (isDark ? Colors.white12 : Colors.grey[200]),
                                ),
                                child: Center(
                                  child: Text(
                                    optionLabel,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? (isDark ? Colors.black : Colors.white)
                                          : (isDark ? Colors.white70 : Colors.black54),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          
          // New navigation area
          _buildNavigationArea(isDark),
        ],
      ),
    );
  }

  Color _getDifficultyColor(String difficulty, bool isDark) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return isDark ? Colors.green.withOpacity(0.3) : Colors.green.withOpacity(0.1);
      case 'medium':
        return isDark ? Colors.amber.withOpacity(0.3) : Colors.amber.withOpacity(0.1);
      case 'hard':
        return isDark ? Colors.red.withOpacity(0.3) : Colors.red.withOpacity(0.1);
      default:
        return isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.withOpacity(0.1);
    }
  }

  void _showExitConfirmation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        title: const Text('Exit Quiz?'),
        content: const Text('Your progress will be saved before exiting.'),
        actions: [
          TextButton(
            onPressed: () => context.router.pop(), // Close dialog using AutoRoute
            child: Text(
              'Continue Quiz',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              context.router.pop(); // Close dialog
              
              // Show loading indicator
              setState(() {
                _isSubmitting = true;
              });
              
              try {
                // Save partial progress and capture the ID
                final examHistoryId = await _saveExamHistory(completed: false);
                
                setState(() {
                  _isSubmitting = false;
                });
                
                // Navigate back to options
                context.router.pop();
                
                // Optional: Navigate to results screen
                context.router.push(QuizResultsRoute(examHistoryId: examHistoryId));
                            } catch (e) {
                setState(() {
                  _isSubmitting = false;
                });
                
                // Just go back if saving fails
                context.router.pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
            ),
            child: const Text('Save & Exit'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationArea(bool isDark) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.black26 : Colors.white,
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
            // Jump to question row
            Row(
              children: [
                Text(
                  'Jump to question:',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black45 : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<int>(
                        value: _currentQuestionIndex,
                        isExpanded: true,
                        isDense: true,
                        dropdownColor: isDark ? Colors.grey[900] : Colors.white,
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                        ),
                        items: List.generate(widget.questions.length, (index) {
                          return DropdownMenuItem<int>(
                            value: index,
                            child: Text(
                              'Question ${index + 1}',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 13,
                              ),
                            ),
                          );
                        }),
                        onChanged: (index) {
                          if (index != null) {
                            _goToQuestion(index);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Navigation buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Previous button
                if (_currentQuestionIndex > 0)
                  ElevatedButton.icon(
                    onPressed: () {
                      _goToQuestion(_currentQuestionIndex - 1);
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Previous'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.black45 : Colors.grey[200],
                      foregroundColor: isDark ? Colors.white70 : Colors.black87,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  )
                else
                  const SizedBox(width: 100), // placeholder
                
                // Submit or Next button
                ElevatedButton.icon(
                  onPressed: () {
                    if (_currentQuestionIndex == widget.questions.length - 1) {
                      _submitQuiz();
                    } else {
                      _goToQuestion(_currentQuestionIndex + 1);
                    }
                  },
                  icon: _isSubmitting 
                      ? const SizedBox(
                          width: 20, 
                          height: 20, 
                          child: CircularProgressIndicator(
                            strokeWidth: 2, 
                            color: Colors.white,
                          ),
                        ) 
                      : Icon(_currentQuestionIndex < widget.questions.length - 1 
                          ? Icons.arrow_forward
                          : Icons.check_circle),
                  label: Text(_isSubmitting 
                      ? 'Saving...' 
                      : (_currentQuestionIndex < widget.questions.length - 1 
                          ? 'Next' 
                          : 'Submit')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
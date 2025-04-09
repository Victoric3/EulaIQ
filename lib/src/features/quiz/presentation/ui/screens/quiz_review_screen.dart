import 'package:auto_route/auto_route.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

@RoutePage()
class QuizReviewScreen extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> questions;
  
  const QuizReviewScreen({
    Key? key,
    required this.questions,
  }) : super(key: key);
  
  @override
  ConsumerState<QuizReviewScreen> createState() => _QuizReviewScreenState();
}

class _QuizReviewScreenState extends ConsumerState<QuizReviewScreen> {
  int _currentQuestionIndex = 0;
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Debug questions - check how many questions are received
    print('Questions received in Review: ${widget.questions.length}');
    
    final currentQuestion = widget.questions[_currentQuestionIndex];
    final String questionText = currentQuestion['question'] ?? '';
    final List<String> options = List<String>.from(currentQuestion['options'] ?? []);
    final String? topic = currentQuestion['topic'];
    final String? difficulty = currentQuestion['difficulty'];
    
    // Extract the explanation - make sure we're getting it
    final String explanation = currentQuestion['explanation'] ?? 'No explanation available';
    print('Question ${_currentQuestionIndex + 1} explanation: $explanation');
    
    // Convert numeric indices to actual options
    var userAnswerIndex = -1;
    var correctOptionIndex = -1;

    // Handle user answer - could be an index or the actual answer text
    if (currentQuestion['userAnswerIndex'] != null) {
      userAnswerIndex = currentQuestion['userAnswerIndex'];
    } else if (currentQuestion['userAnswer'] != null) {
      if (currentQuestion['userAnswer'] is int || 
          (currentQuestion['userAnswer'] is String && 
           int.tryParse(currentQuestion['userAnswer'].toString()) != null)) {
        // It's a numeric index
        userAnswerIndex = int.tryParse(currentQuestion['userAnswer'].toString()) ?? -1;
      } else {
        // It's the answer text
        userAnswerIndex = options.indexOf(currentQuestion['userAnswer'].toString());
      }
    }

    // Handle user answer - could be undefined in the API response
    if (currentQuestion.containsKey('userAnswer') && currentQuestion['userAnswer'] != null) {
    } else if (currentQuestion.containsKey('userAnswerIndex') && 
               currentQuestion['userAnswerIndex'] != null && 
               currentQuestion['userAnswerIndex'] is int) {
      final idx = currentQuestion['userAnswerIndex'] as int;
      if (idx >= 0 && idx < options.length) {
      }
    }

    // Handle correct option - could be an index or the actual answer text
    if (currentQuestion['correctOptionIndex'] != null) {
      correctOptionIndex = currentQuestion['correctOptionIndex'];
    } else if (currentQuestion['correctOption'] != null) {
      if (currentQuestion['correctOption'] is int || 
          (currentQuestion['correctOption'] is String && 
           int.tryParse(currentQuestion['correctOption'].toString()) != null)) {
        // It's a numeric index
        correctOptionIndex = int.tryParse(currentQuestion['correctOption'].toString()) ?? -1;
      } else {
        // It's the answer text
        correctOptionIndex = options.indexOf(currentQuestion['correctOption'].toString());
      }
    }

    // Determine if the answer was correct
    final bool isCorrect = userAnswerIndex == correctOptionIndex && userAnswerIndex >= 0;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        elevation: 0,
        title: Text(
          'Review Questions',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Question counter
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.black45 : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_currentQuestionIndex + 1}/${widget.questions.length}',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
              isCorrect ? Colors.green : Colors.red,
            ),
            minHeight: 4,
          ),
          
          // Question info bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Correctness indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCorrect 
                        ? Colors.green.withOpacity(0.2) 
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isCorrect ? Icons.check_circle : Icons.cancel,
                        color: isCorrect ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isCorrect ? 'Correct' : 'Incorrect',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isCorrect ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Difficulty tag
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
                    final bool isSelected = index == userAnswerIndex;
                    final bool isCorrectOption = index == correctOptionIndex;
                    
                    // Determine colors based on correctness
                    Color backgroundColor;
                    Color borderColor;
                    
                    if (isSelected && isCorrectOption) {
                      // User selected correct answer
                      backgroundColor = isDark ? Colors.green.withOpacity(0.2) : Colors.green.withOpacity(0.1);
                      borderColor = Colors.green;
                    } else if (isSelected && !isCorrectOption) {
                      // User selected wrong answer
                      backgroundColor = isDark ? Colors.red.withOpacity(0.2) : Colors.red.withOpacity(0.1);
                      borderColor = Colors.red;
                    } else if (isCorrectOption) {
                      // The correct answer (not selected)
                      backgroundColor = isDark ? Colors.green.withOpacity(0.1) : Colors.green.withOpacity(0.05);
                      borderColor = Colors.green.withOpacity(0.5);
                    } else {
                      // Other options
                      backgroundColor = isDark ? Colors.black45 : Colors.white;
                      borderColor = isDark ? Colors.white24 : Colors.black12;
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: borderColor,
                            width: isSelected || isCorrectOption ? 2 : 1,
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
                                    ? (isCorrectOption ? Colors.green : Colors.red)
                                    : (isCorrectOption ? Colors.green.withOpacity(0.3) : (isDark ? Colors.white12 : Colors.grey[200])),
                              ),
                              child: Center(
                                child: Text(
                                  optionLabel,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : (isCorrectOption 
                                            ? (isDark ? Colors.white : Colors.green)
                                            : (isDark ? Colors.white70 : Colors.black54)),
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
                            
                            // Indicator icons for correct/wrong
                            if (isSelected || isCorrectOption)
                              Icon(
                                isCorrectOption ? Icons.check_circle : Icons.cancel,
                                color: isCorrectOption ? Colors.green : Colors.red,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  
                  // Explanation section
                  if (explanation.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black38 : Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.blue.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                MdiIcons.informationOutline,
                                color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Explanation',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            explanation,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black87,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Navigation buttons
          SafeArea(
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Previous button
                  if (_currentQuestionIndex > 0)
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _currentQuestionIndex--;
                        });
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
                  
                  // Next or Finish button
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_currentQuestionIndex < widget.questions.length - 1) {
                        setState(() {
                          _currentQuestionIndex++;
                        });
                      } else {
                        context.router.pop(); // Return to results screen
                      }
                    },
                    icon: Icon(_currentQuestionIndex < widget.questions.length - 1 
                        ? Icons.arrow_forward
                        : Icons.check_circle),
                    label: Text(_currentQuestionIndex < widget.questions.length - 1 
                        ? 'Next' 
                        : 'Finish'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
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

  String getOptionLabel(int index) {
    if (index < 0) return '';
    return String.fromCharCode(65 + index); // A, B, C, D...
  }
}
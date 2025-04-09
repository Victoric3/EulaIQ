import 'package:auto_route/auto_route.dart';
import 'package:eulaiq/src/common/common.dart';
import 'package:eulaiq/src/common/constants/dio_config.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'dart:convert';

@RoutePage()
class QuizResultsScreen extends ConsumerStatefulWidget {
  final String examHistoryId;
  
  const QuizResultsScreen({
    Key? key,
    required this.examHistoryId,
  }) : super(key: key);
  
  @override
  ConsumerState<QuizResultsScreen> createState() => _QuizResultsScreenState();
}

class _QuizResultsScreenState extends ConsumerState<QuizResultsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _resultData;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadResults();
  }
  
  Future<void> _loadResults() async {
    try {
      final response = await DioConfig.dio?.get(
        '/examHistory/${widget.examHistoryId}',
      );
      
      // Debug the API response
      print('API Response type: ${response?.data.runtimeType}');
      print('API Response status: ${response?.statusCode}');
      
      if (response?.statusCode == 200) {
        dynamic resultData;
        
        // Safely handle different response formats
        if (response?.data is Map) {
          // Handle Map response
          resultData = response?.data['success'] == true && response?.data['data'] != null
              ? response?.data['data']
              : response?.data;
        } else if (response?.data is String) {
          // Try to parse string as JSON
          try {
            resultData = jsonDecode(response?.data);
            if (resultData is Map && resultData['data'] != null) {
              resultData = resultData['data'];
            }
          } catch (e) {
            print('Failed to parse response string as JSON: $e');
            throw Exception('Unexpected API response format');
          }
        } else {
          resultData = response?.data;
        }
        
        // Ensure we have a Map before proceeding
        if (resultData is! Map) {
          throw Exception('API response is not in the expected format');
        }
        
        // Convert to a proper Map<String, dynamic>
        final dataMap = Map<String, dynamic>.from(resultData);
        
        // Process performance summary safely
        if (dataMap['performanceSummary'] is String) {
          try {
            dataMap['performanceSummary'] = jsonDecode(dataMap['performanceSummary']);
          } catch (e) {
            print('Failed to parse performanceSummary: $e');
            dataMap['performanceSummary'] = {};
          }
        } else if (dataMap['performanceSummary'] is! Map) {
          dataMap['performanceSummary'] = {};
        }
        
        // Handle topic performance safely
        if (dataMap['topicPerformance'] is String) {
          try {
            dataMap['topicPerformance'] = jsonDecode(dataMap['topicPerformance']);
          } catch (e) {
            print('Failed to parse topicPerformance: $e');
            dataMap['topicPerformance'] = {};
          }
        }
        
        // Handle difficulty breakdown safely
        if (dataMap['difficultyBreakdown'] is String) {
          try {
            dataMap['difficultyBreakdown'] = jsonDecode(dataMap['difficultyBreakdown']);
          } catch (e) {
            print('Failed to parse difficultyBreakdown: $e');
            dataMap['difficultyBreakdown'] = {};
          }
        }
        
        // Handle concept category breakdown safely
        if (dataMap['conceptCategoryBreakdown'] is String) {
          try {
            dataMap['conceptCategoryBreakdown'] = jsonDecode(dataMap['conceptCategoryBreakdown']);
          } catch (e) {
            print('Failed to parse conceptCategoryBreakdown: $e');
            dataMap['conceptCategoryBreakdown'] = {};
          }
        }
        
        setState(() {
          _resultData = dataMap;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load results: ${response?.statusCode}');
      }
    } catch (e) {
      print('Error loading quiz results: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Quiz Results'),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Text(
                    'Error: $_errorMessage',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                )
              : _buildResultsContent(isDark),
    );
  }
  
  Widget _buildResultsContent(bool isDark) {
    // Ensure totalScore is a double
    double totalScore = 0.0;
    if (_resultData?['totalScore'] is int) {
      totalScore = (_resultData?['totalScore'] as int).toDouble();
    } else if (_resultData?['totalScore'] is double) {
      totalScore = _resultData?['totalScore'] as double;
    } else if (_resultData?['totalScore'] is String) {
      totalScore = double.tryParse(_resultData?['totalScore'] as String) ?? 0.0;
    }
    
    final totalQuestions = _resultData?['totalQuestions'] ?? 0;
    final correctAnswers = (totalScore * totalQuestions / 100).round();
    final timeSpent = _resultData?['timeSpent'] ?? 0;
    final examName = _resultData?['examName'] ?? 'Practice Quiz';
    
    // Get performance summary if available
    final performanceSummary = _getMapSafely(_resultData?['performanceSummary']);
    final strengths = _getListSafely(performanceSummary['strengths'])
        .map((item) => item.toString())
        .toList();
    final weaknesses = _getListSafely(performanceSummary['weaknesses'])
        .map((item) => item.toString())
        .toList();
    final recommendations = _getListSafely(performanceSummary['recommendations'])
        .map((item) => item.toString())
        .toList();
    final summaryText = performanceSummary['summary']?.toString() ?? '';
    
    // Get concept and difficulty breakdowns
    final difficultyBreakdown = _getMapSafely(_resultData?['difficultyBreakdown']);
    final conceptBreakdown = _getMapSafely(_resultData?['conceptCategoryBreakdown']);
    
    // Get the questions
    final questions = _getListSafely(_resultData?['questions']);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Score summary card
              Card(
                elevation: 2,
                color: isDark ? Colors.black38 : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Exam name
                      Text(
                        examName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      
                      // Score display
                      Icon(
                        totalScore >= 70 ? MdiIcons.trophy : MdiIcons.information,
                        size: 64,
                        color: totalScore >= 70 
                            ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                            : Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your Score',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${totalScore.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _getScoreColor(totalScore, isDark),
                        ),
                      ),
                      Text(
                        '$correctAnswers/$totalQuestions correct answers',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Stats
                      _buildStatRow(
                        isDark, 
                        'Time Spent', 
                        _formatDuration(timeSpent), 
                        MdiIcons.clockOutline,
                      ),
                      const SizedBox(height: 8),
                      _buildStatRow(
                        isDark, 
                        'Average Time per Question', 
                        _formatDuration(totalQuestions > 0 ? timeSpent ~/ totalQuestions : 0), 
                        MdiIcons.timerOutline,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Performance Summary (if available)
              if (summaryText.isNotEmpty) 
                _buildSummaryCard(isDark, summaryText),
                
              const SizedBox(height: 24),
              
              // Topic Performance
              _buildSectionTitle(isDark, 'Performance by Topic'),
              const SizedBox(height: 12),
              _buildTopicPerformance(isDark),
              
              const SizedBox(height: 24),
              
              // Difficulty Breakdown (if available)
              if (difficultyBreakdown.isNotEmpty) ...[
                _buildSectionTitle(isDark, 'Performance by Difficulty'),
                const SizedBox(height: 12),
                _buildBreakdownSection(isDark, difficultyBreakdown),
                const SizedBox(height: 24),
              ],
              
              // Concept Category Breakdown (if available)
              if (conceptBreakdown.isNotEmpty) ...[
                _buildSectionTitle(isDark, 'Performance by Concept'),
                const SizedBox(height: 12),
                _buildBreakdownSection(isDark, conceptBreakdown),
                const SizedBox(height: 24),
              ],
              
              // Strengths & Weaknesses
              if (strengths.isNotEmpty || weaknesses.isNotEmpty) ...[
                _buildStrengthsWeaknesses(isDark, strengths, weaknesses),
                const SizedBox(height: 24),
              ],
              
              // Recommendations
              if (recommendations.isNotEmpty) ...[
                _buildRecommendations(isDark, recommendations),
                const SizedBox(height: 24),
              ],
              
              // Review Questions Button
              if (questions.isNotEmpty)
                _buildReviewButton(isDark, questions),
                
              // Add extra padding to ensure bottom action buttons don't cover content
              const SizedBox(height: 50),
            ],
          ),
        ),
        
        // Action buttons at bottom
        _buildBottomActions(isDark),
      ],
    );
  }

  Widget _buildSummaryCard(bool isDark, String summary) {
    return Card(
      color: isDark ? Colors.black38 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  MdiIcons.clipboardTextOutline,
                  color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Performance Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              summary,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Update the _buildBreakdownSection method to merge case variations
  Widget _buildBreakdownSection(bool isDark, Map<String, dynamic> breakdown) {
    // Normalize and merge difficulty data (e.g., "Easy" and "easy")
    final normalizedBreakdown = <String, Map<String, dynamic>>{};
    
    breakdown.forEach((key, value) {
      // Skip entries with 0 total questions
      if (value is Map && value['total'] != null && value['total'] > 0) {
        // Normalize key (convert to title case)
        final normalizedKey = key.toLowerCase() == 'easy' ? 'Easy' :
                             key.toLowerCase() == 'medium' ? 'Medium' :
                             key.toLowerCase() == 'hard' ? 'Hard' : key;
        
        // If we already have this key, merge the data
        if (normalizedBreakdown.containsKey(normalizedKey)) {
          final existingData = normalizedBreakdown[normalizedKey]!;
          existingData['correct'] = (existingData['correct'] ?? 0) + (value['correct'] ?? 0);
          existingData['total'] = (existingData['total'] ?? 0) + (value['total'] ?? 0);
          
          // Recalculate percentage
          if (existingData['total'] > 0) {
            existingData['percentage'] = (existingData['correct'] / existingData['total']) * 100;
          }
        } else {
          // Add new entry
          normalizedBreakdown[normalizedKey] = Map<String, dynamic>.from(value);
        }
      }
    });
    
    if (normalizedBreakdown.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.black26 : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'No breakdown data available',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ),
      );
    }
    
    return Column(
      children: normalizedBreakdown.entries.map((entry) {
        final category = entry.key;
        final data = entry.value;
        
        // Ensure percentage is a double
        double percentage = 0.0;
        if (data['percentage'] is int) {
          percentage = (data['percentage'] as int).toDouble();
        } else if (data['percentage'] is double) {
          percentage = data['percentage'] as double;
        }
        
        final correct = data['correct'] ?? 0;
        final total = data['total'] ?? 0;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isDark ? Colors.black26 : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getScoreColor(percentage, isDark).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getScoreColor(percentage, isDark),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Correct: $correct/$total',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(percentage, isDark)),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStrengthsWeaknesses(bool isDark, List<String> strengths, List<String> weaknesses) {
    return Card(
      color: isDark ? Colors.black38 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Strengths & Areas to Improve',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            
            // Strengths
            if (strengths.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    Icons.thumb_up_outlined,
                    color: Colors.green,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Strengths',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...strengths.map((strength) => Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 26),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '•',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        strength,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
              if (weaknesses.isNotEmpty) 
                const SizedBox(height: 16),
            ],
            
            // Weaknesses
            if (weaknesses.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    Icons.thumb_down_outlined,
                    color: Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Areas to Improve',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...weaknesses.map((weakness) => Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 26),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '•',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        weakness,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendations(bool isDark, List<String> recommendations) {
    return Card(
      color: isDark ? Colors.black38 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  MdiIcons.lightbulbOutline,
                  color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recommendations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...recommendations.map((rec) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${recommendations.indexOf(rec) + 1}.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rec,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(bool isDark, String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? Colors.white60 : Colors.black54,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const Spacer(),
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
  
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes min ${remainingSeconds} sec';
  }
  
  Widget _buildSectionTitle(bool isDark, String title) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            color: isDark ? Colors.white24 : Colors.black12,
          ),
        ),
      ],
    );
  }
  
  // Update the _buildTopicPerformance method to properly handle topic data
  Widget _buildTopicPerformance(bool isDark) {
    final dynamic rawTopicPerformance = _resultData?['topicPerformance'];
    final Map<String, dynamic> topicPerformance = 
        rawTopicPerformance is Map<String, dynamic> ? rawTopicPerformance : {};
    
    if (topicPerformance.isEmpty) {
      return Center(
        child: Text(
          'No topic performance data available',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    
    return Column(
      children: topicPerformance.entries.map((entry) {
        final topic = entry.key;
        final data = entry.value is Map ? Map<String, dynamic>.from(entry.value) : <String, dynamic>{};
        
        // Ensure score is a double
        double score = 0.0;
        if (data['score'] is int) {
          score = (data['score'] as int).toDouble();
        } else if (data['score'] is double) {
          score = data['score'] as double;
        } else if (data['score'] is String) {
          score = double.tryParse(data['score'] as String) ?? 0.0;
        }
        
        // When score is missing but we have correct and total, calculate it
        if (score == 0.0 && data['correct'] != null && data['total'] != null) {
          final correct = data['correct'] as int;
          final total = data['total'] as int;
          if (total > 0) {
            score = (correct / total) * 100;
          }
        }
        
        final correct = data['correct'] ?? 0;
        final total = data['total'] ?? 0;
        
        // Only show topics with at least one question
        if (total <= 0) return Container();
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isDark ? Colors.black26 : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topic,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Score: ${score.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Correct: $correct/$total',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 10,
                        clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: isDark ? Colors.white10 : Colors.grey[200],
                        ),
                        child: Row(
                          children: [
                            Flexible(
                              flex: score.toInt(),
                              child: Container(
                                color: _getScoreColor(score, isDark),
                              ),
                            ),
                            Flexible(
                              flex: (100 - score.toInt()),
                              child: Container(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).where((widget) => widget != Container()).toList(),
    );
  }
  
  Color _getScoreColor(double score, bool isDark) {
    if (score >= 80) {
      return Colors.green;
    } else if (score >= 60) {
      return Colors.amber;
    } else {
      return Colors.red;
    }
  }
  
  // Update the _buildReviewButton method to show all questions
  Widget _buildReviewButton(bool isDark, List<dynamic> questions) {
    // Debug number of questions
    print('Questions for review: ${questions.length}');
    
    // Show all questions from the exam since API returns attempted questions
    if (questions.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        child: ElevatedButton.icon(
          onPressed: null, // Disable button
          icon: Icon(MdiIcons.clipboardCheckOutline),
          label: const Text('No Questions Available'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
            foregroundColor: isDark ? Colors.white60 : Colors.black45,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      child: ElevatedButton.icon(
        onPressed: () {
          print('Sending ${questions.length} questions to review');
          // Check a sample question for explanation
          if (questions.isNotEmpty) {
            print('Sample question explanation: ${questions[0]['explanation']}');
          }
          
          // Convert all questions to maps before passing to review screen
          final questionsForReview = questions.map((q) {
            // Create a new map from the question data
            final Map<String, dynamic> questionMap = Map<String, dynamic>.from(q);
            
            // Make sure isCorrect has a valid boolean value (defaults to false if missing)
            questionMap['isCorrect'] = q['isCorrect'] == true;
            
            return questionMap;
          }).toList();
          
          context.router.push(
            QuizReviewRoute(
              questions: List<Map<String, dynamic>>.from(questionsForReview),
            ),
          );
        },
        icon: Icon(MdiIcons.clipboardCheckOutline),
        label: Text('Review ${questions.length} Questions'),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
  
  Widget _buildBottomActions(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Dashboard Button
            Expanded(
              child: _buildActionButton(
                isDark,
                'Dashboard',
                onPressed: () => context.router.navigate(const UserAnalyticsRoute()),
                icon: MdiIcons.viewDashboard,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            
            // History Button
            Expanded(
              child: _buildActionButton(
                isDark,
                'History',
                onPressed: () => context.router.navigate(const ExamHistoryRoute()),
                icon: MdiIcons.history,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            
            // New Quiz Button (primary)
            Expanded(
              child: _buildActionButton(
                isDark,
                'Library',
                 onPressed: () {
                  // This is the most reliable way to navigate back to the tabs with the Library tab active
                  context.router.navigate(
                    const TabsRoute(
                      children: [LibraryRoute()]
                    )
                  );
                },
                icon: MdiIcons.bookshelf,
                color: isDark ? Colors.white70 : AppColors.brandDeepGold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    bool isDark,
    String label, {
    required VoidCallback onPressed,
    required IconData icon,
    Color? color,
    Color? textColor,
    Color? bgColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color ?? (isDark ? Colors.white70 : Colors.black54),
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textColor ?? color ?? (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add this helper method to safely get maps:
  Map<String, dynamic> _getMapSafely(dynamic value) {
    if (value == null) {
      return {};
    } else if (value is Map<String, dynamic>) {
      return value;
    } else if (value is Map) {
      return Map<String, dynamic>.from(value);
    } else if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    return {};
  }

  // Add this helper method to safely get lists:
  List<dynamic> _getListSafely(dynamic value) {
    if (value == null) {
      return [];
    } else if (value is List) {
      return value;
    } else if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded;
        }
      } catch (_) {}
    }
    return [];
  }
}
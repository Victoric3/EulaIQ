import 'package:auto_route/auto_route.dart';
import 'package:eulaiq/src/common/constants/dio_config.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:eulaiq/src/features/auth/providers/user_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

@RoutePage()
class UserAnalyticsScreen extends ConsumerStatefulWidget {
  const UserAnalyticsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<UserAnalyticsScreen> createState() => _UserAnalyticsScreenState();
}

class _UserAnalyticsScreenState extends ConsumerState<UserAnalyticsScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _analyticsData;
  String? _errorMessage;
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAnalytics();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadAnalytics() async {
    print("hit fetch user analytics");
    final user = ref.read(userProvider).value;
    if (user == null) {
      setState(() {
        _errorMessage = 'You need to log in to view analytics';
        _isLoading = false;
      });
      return;
    }
    
    try {
      print('Loading analytics for user: ${user.username}');
      final response = await DioConfig.dio?.get(
        '/examHistory/analytics/${user.username}',
      );
      
      if (response?.statusCode == 200) {
        // Debug response structure
        print('Raw response structure: ${response?.data.runtimeType}');
        
        // IMPORTANT FIX: Extract the nested 'data' field from the response
        final analyticsData = response?.data['data'] ?? response?.data;
        
        setState(() {
          _analyticsData = analyticsData;
          _isLoading = false;
        });
        
        // Debug extracted data
        print("Analytics data extracted: ${_analyticsData != null ? 'yes' : 'no'}");
        print("Top-level keys: ${_analyticsData?.keys.toList()}");
        print("Overall performance: ${_analyticsData?['overallPerformance']}");
        print("strengths: ${_analyticsData?['strengths']}");
      } else {
        throw Exception('Failed to load analytics: ${response?.statusCode}');
      }
    } catch (e) {
      print('Error loading analytics: $e');
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
        title: const Text('Performance Dashboard'),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
          indicatorColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'By Topic'),
            Tab(text: 'Trends'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        MdiIcons.alertCircleOutline,
                        size: 48,
                        color: isDark ? Colors.white60 : Colors.black45,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error Loading Analytics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                          });
                          _loadAnalytics();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(isDark),
                    _buildTopicsTab(isDark),
                    _buildTrendsTab(isDark),
                  ],
                ),
    );
  }
  
  Widget _buildOverviewTab(bool isDark) {
    final overallPerformance = _analyticsData?['overallPerformance'] ?? {};
    final examCount = _analyticsData?['examCount'] ?? 0;
    final totalQuestionsAnswered = _analyticsData?['totalQuestionsAnswered'] ?? 0;
    final strengthsList = List<Map<String, dynamic>>.from(
      _analyticsData?['strengths'] ?? []
    );
    final weaknessesList = List<Map<String, dynamic>>.from(
      _analyticsData?['weaknesses'] ?? []
    );
    
    final double percentage = overallPerformance['percentage']?.toDouble() ?? 0.0;
    
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _isLoading = true;
        });
        await _loadAnalytics();
      },
      color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Overall performance card
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
                  // Overall progress indicator
                  SizedBox(
                    height: 150,
                    width: 150,
                    child: Stack(
                      children: [
                        Center(
                          child: SizedBox(
                            height: 130,
                            width: 130,
                            child: CircularProgressIndicator(
                              value: percentage / 100,
                              strokeWidth: 12,
                              backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(percentage, isDark)),
                            ),
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${percentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                                ),
                              ),
                              Text(
                                'Overall',
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
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard(
                        isDark,
                        'Exams',
                        examCount.toString(),
                        MdiIcons.notebookCheckOutline,
                      ),
                      _buildStatCard(
                        isDark,
                        'Questions',
                        totalQuestionsAnswered.toString(),
                        MdiIcons.commentQuestionOutline,
                      ),
                      _buildStatCard(
                        isDark,
                        'Correct',
                        '${overallPerformance['correct'] ?? 0}',
                        MdiIcons.checkCircleOutline,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Strengths
          _buildSection(isDark, 'Your Strengths', strengthsList.isEmpty ? 
            _buildEmptyState(isDark, 'Complete more quizzes to identify your strengths') :
            Column(
              children: strengthsList.map((strength) => 
                _buildPerformanceItem(isDark, strength['topic'], strength['percentage'].toDouble(), icon: Icons.star)
              ).toList(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Weaknesses
          _buildSection(isDark, 'Areas to Improve', weaknessesList.isEmpty ? 
            _buildEmptyState(isDark, 'Complete more quizzes to identify areas for improvement') :
            Column(
              children: weaknessesList.map((weakness) => 
                _buildPerformanceItem(isDark, weakness['topic'], weakness['percentage'].toDouble(), isStrength: false)
              ).toList(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Difficulty performance
          _buildSection(isDark, 'Performance by Difficulty', 
            _buildDifficultyChart(isDark),
          ),
          
          // Add extra padding at the bottom to prevent cut-off
          const SizedBox(height: 80), // Added extra space at bottom
        ],
      ),
    );
  }
  
  Widget _buildTopicsTab(bool isDark) {
    final topicPerformance = _analyticsData?['topicPerformance'] as Map<String, dynamic>? ?? {};
    
    if (topicPerformance.isEmpty) {
      return _buildEmptyState(isDark, 'No topic performance data available yet');
    }
    
    // Convert to list for sorting
    final topicsList = topicPerformance.entries.map((entry) {
      final topic = entry.key;
      final data = entry.value as Map<String, dynamic>;
      final percentage = data['percentage']?.toDouble() ?? 0.0;
      final correct = data['correct'] ?? 0;
      final total = data['total'] ?? 0;
      
      return {
        'topic': topic,
        'percentage': percentage,
        'correct': correct,
        'total': total,
      };
    }).toList();
    
    // Sort by percentage (descending)
    topicsList.sort((a, b) => b['percentage'].compareTo(a['percentage']));
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Topic performance list
        ...topicsList.map((topicData) => 
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: isDark ? Colors.black38 : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          topicData['topic'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getScoreColor(topicData['percentage'], isDark).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${topicData['percentage'].toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _getScoreColor(topicData['percentage'], isDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Correct: ${topicData['correct']}/${topicData['total']}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: topicData['percentage'] / 100,
                    backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(topicData['percentage'], isDark)),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
          ),
        ).toList(),
        
        // Add extra padding at the bottom
        const SizedBox(height: 80), // Added extra space at bottom
      ],
    );
  }
  
  Widget _buildTrendsTab(bool isDark) {
    final progressTimeline = List<Map<String, dynamic>>.from(
      _analyticsData?['progressTimeline'] ?? []
    );
    
    if (progressTimeline.isEmpty) {
      return _buildEmptyState(isDark, 'No performance trend data available yet');
    }
    
    // Sort by date
    progressTimeline.sort((a, b) => 
      DateTime.parse(a['date'].toString())
        .compareTo(DateTime.parse(b['date'].toString()))
    );
    
    // Create chart data
    final chartData = progressTimeline.asMap().entries.map((entry) {
      final index = entry.key.toDouble();
      final data = entry.value;
      final score = data['score']?.toDouble() ?? 0.0;
      return FlSpot(index, score);
    }).toList();
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
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
                  'Score Trend',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 220,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 20,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: isDark ? Colors.white10 : Colors.grey[200]!,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              // Show only some labels to avoid overcrowding
                              if (value.toInt() % 3 != 0 && value.toInt() != progressTimeline.length - 1) {
                                return const SizedBox.shrink();
                              }
                              
                              if (value.toInt() >= progressTimeline.length) {
                                return const SizedBox.shrink();
                              }
                              
                              final date = DateTime.parse(progressTimeline[value.toInt()]['date'].toString());
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  DateFormat('MM/dd').format(date),
                                  style: TextStyle(
                                    color: isDark ? Colors.white60 : Colors.black54,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 20,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}%',
                                style: TextStyle(
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: false,
                      ),
                      minX: 0,
                      maxX: (progressTimeline.length - 1).toDouble(),
                      minY: 0,
                      maxY: 100,
                      lineBarsData: [
                        LineChartBarData(
                          spots: chartData,
                          isCurved: true,
                          color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                                strokeWidth: 1,
                                strokeColor: isDark ? Colors.black : Colors.white,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: (isDark ? AppColors.neonCyan : AppColors.brandDeepGold).withOpacity(0.2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Recent exams list
        Text(
          'Recent Exams',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        
        ...progressTimeline.reversed.take(5).map((exam) {
          final date = DateTime.parse(exam['date'].toString());
          final score = exam['score']?.toDouble() ?? 0.0;
          final examName = exam['examName'] ?? 'Unnamed Exam';
          
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: isDark ? Colors.black38 : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(
                examName,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Text(
                DateFormat('MMM dd, yyyy').format(date),
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getScoreColor(score, isDark).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${score.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(score, isDark),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
        
        // Add extra space after the list of recent exams
        const SizedBox(height: 80), // Added extra space at bottom
      ],
    );
  }
  
  Widget _buildStatCard(bool isDark, String label, String value, IconData icon) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
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
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSection(bool isDark, String title, Widget content) {
    return Card(
      color: isDark ? Colors.black38 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      // Add marginBottom to create more space after this card
      margin: const EdgeInsets.only(bottom: 16), // Added margin
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            content,
          ],
        ),
      ),
    );
  }
  
  Widget _buildPerformanceItem(bool isDark, String topic, double percentage, {bool isStrength = true, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isStrength 
                ? Colors.green 
                : Colors.orange
              ).withOpacity(isDark ? 0.3 : 0.2),
            ),
            child: Center(
              child: Icon(
                icon ?? (isStrength ? Icons.trending_up : Icons.trending_down),
                color: isStrength ? Colors.green : Colors.orange,
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
                  topic,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isStrength ? Colors.green : Colors.orange
                  ),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (isStrength ? Colors.green : Colors.orange).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isStrength ? Colors.green : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDifficultyChart(bool isDark) {
    final difficultyPerformance = _analyticsData?['difficultyPerformance'] as Map<String, dynamic>? ?? {};
    
    if (difficultyPerformance.isEmpty) {
      return _buildEmptyState(isDark, 'No difficulty data available yet');
    }
    
    // Debug difficulty data
    print('Difficulty performance data: $difficultyPerformance');
    
    // Create normalized difficulty map (merging case variants)
    final Map<String, Map<String, dynamic>> normalizedDifficulty = {};
    
    // Process each difficulty entry and normalize keys (easy, Easy -> Easy)
    difficultyPerformance.forEach((key, value) {
      if (value is Map && value['total'] != null && value['total'] > 0) {
        // Normalize key to title case
        final normalizedKey = key.toLowerCase() == 'easy' ? 'Easy' :
                         key.toLowerCase() == 'medium' ? 'Medium' :
                         key.toLowerCase() == 'hard' ? 'Hard' : key;
        
        // If we already have this difficulty level, merge the data
        if (normalizedDifficulty.containsKey(normalizedKey)) {
          final existingData = normalizedDifficulty[normalizedKey]!;
          final newData = Map<String, dynamic>.from(value);
          
          existingData['correct'] = (existingData['correct'] ?? 0) + (newData['correct'] ?? 0);
          existingData['total'] = (existingData['total'] ?? 0) + (newData['total'] ?? 0);
          
          // Recalculate percentage
          if (existingData['total'] > 0) {
            existingData['percentage'] = (existingData['correct'] / existingData['total']) * 100;
          }
        } else {
          // Just add the data with the normalized key
          normalizedDifficulty[normalizedKey] = Map<String, dynamic>.from(value);
        }
      }
    });
    
    // Standard difficulties to show (in order)
    final standardDifficulties = ['Easy', 'Medium', 'Hard'];
    
    return Column(
      children: standardDifficulties.map((difficulty) {
        final data = normalizedDifficulty[difficulty] ?? {'correct': 0, 'total': 0, 'percentage': 0.0};
        
        // Ensure percentage is a double
        double percentage = 0.0;
        if (data['percentage'] is int) {
          percentage = (data['percentage'] as int).toDouble();
        } else if (data['percentage'] is double) {
          percentage = data['percentage'] as double;
        }
        
        final correct = data['correct'] ?? 0;
        final total = data['total'] ?? 0;
        
        Color difficultyColor;
        switch (difficulty) {
          case 'Easy':
            difficultyColor = Colors.green;
            break;
          case 'Medium':
            difficultyColor = Colors.amber;
            break;
          case 'Hard':
            difficultyColor = Colors.red;
            break;
          default:
            difficultyColor = Colors.blue;
        }
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  difficulty,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Correct: $correct/$total',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: difficultyColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(difficultyColor),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildEmptyState(bool isDark, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              MdiIcons.chartBoxOutline,
              size: 64,
              color: isDark ? Colors.white24 : Colors.black12,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
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
}
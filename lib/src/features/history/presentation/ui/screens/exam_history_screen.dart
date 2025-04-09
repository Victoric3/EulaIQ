import 'package:auto_route/auto_route.dart';
import 'package:eulaiq/src/common/common.dart';
import 'package:eulaiq/src/common/constants/dio_config.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:eulaiq/src/features/auth/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

@RoutePage()
class ExamHistoryScreen extends ConsumerStatefulWidget {
  const ExamHistoryScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ExamHistoryScreen> createState() => _ExamHistoryScreenState();
}

class _ExamHistoryScreenState extends ConsumerState<ExamHistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _examHistoryItems = [];
  int _currentPage = 1;
  int _maxPages = 1;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadExamHistory();
  }
  
  Future<void> _loadExamHistory({bool refresh = false}) async {
    final user = ref.read(userProvider).value;
    
    if (user == null) {
      setState(() {
        _errorMessage = 'You need to log in to view exam history';
        _isLoading = false;
      });
      return;
    }
    
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _isLoading = true;
      });
    }
    
    try {
      final response = await DioConfig.dio?.get(
        '/examHistory',
        queryParameters: {
          'username': user.username,
          'page': _currentPage,
        },
      );
      
      if (response?.statusCode == 200) {
        setState(() {
          _examHistoryItems = response?.data['examHistory'] ?? [];
          _maxPages = response?.data['maxPages'] ?? 1;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load exam history: ${response?.statusCode}');
      }
    } catch (e) {
      print('Error loading exam history: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  void _loadNextPage() {
    if (_currentPage < _maxPages) {
      setState(() {
        _currentPage++;
        _isLoading = true;
      });
      _loadExamHistory();
    }
  }
  
  void _loadPreviousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
        _isLoading = true;
      });
      _loadExamHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Exam History'),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        elevation: 0,
        actions: [
          // Analytics button
          IconButton(
            icon: Icon(
              MdiIcons.viewDashboard,
              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            ),
            onPressed: () {
              context.router.push(const UserAnalyticsRoute());
            },
            tooltip: 'View Analytics',
          ),
        ],
      ),
      body: _isLoading && _examHistoryItems.isEmpty
          ? Center(
              child: CircularProgressIndicator(
                color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
              ),
            )
          : _errorMessage != null && _examHistoryItems.isEmpty
              ? _buildErrorState(isDark)
              : _buildExamHistoryList(isDark),
    );
  }
  
  Widget _buildErrorState(bool isDark) {
    return Center(
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
            'Error Loading Exam History',
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
              _loadExamHistory();
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
    );
  }
  
  Widget _buildExamHistoryList(bool isDark) {
    if (_examHistoryItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              MdiIcons.history,
              size: 64,
              color: isDark ? Colors.white24 : Colors.black12,
            ),
            const SizedBox(height: 16),
            Text(
              'No Exam History Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete quizzes to see your history here',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                context.router.navigate(const LibraryRoute());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Take a Quiz'),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () => _loadExamHistory(refresh: true),
      color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _examHistoryItems.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _examHistoryItems.length) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(
                        color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                      ),
                    ),
                  );
                }
                
                final examHistory = _examHistoryItems[index];
                final examName = examHistory['examName'] ?? 
                                 examHistory['exam']?['name'] ?? 
                                 'Unnamed Exam';
                                 
                final totalScore = examHistory['totalScore'] is int
                    ? (examHistory['totalScore'] as int).toDouble()
                    : (examHistory['totalScore'] as double? ?? 0.0);
                    
                final totalQuestions = examHistory['totalQuestions'] ?? 0;
                final timestamp = DateTime.parse(examHistory['timestamp'] ?? DateTime.now().toIso8601String());
                final timeSpent = examHistory['timeSpent'] ?? 0;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isDark ? Colors.black38 : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    onTap: () {
                      context.router.push(
                        QuizResultsRoute(examHistoryId: examHistory['_id']),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
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
                                  examName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getScoreColor(totalScore, isDark).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '${totalScore.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _getScoreColor(totalScore, isDark),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildInfoItem(
                                isDark,
                                'Date',
                                DateFormat('MMM dd, yyyy').format(timestamp),
                                MdiIcons.calendarOutline,
                              ),
                              const SizedBox(width: 16),
                              _buildInfoItem(
                                isDark,
                                'Questions',
                                totalQuestions.toString(),
                                MdiIcons.formatListNumbered,
                              ),
                              const SizedBox(width: 16),
                              _buildInfoItem(
                                isDark,
                                'Time',
                                _formatDuration(timeSpent),
                                MdiIcons.clockOutline,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: totalScore / 100,
                            backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(totalScore, isDark)),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Pagination controls
          if (_examHistoryItems.isNotEmpty)
            Container(
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _currentPage > 1 ? _loadPreviousPage : null,
                    icon: Icon(Icons.arrow_back_ios),
                    color: _currentPage > 1
                        ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                        : (isDark ? Colors.white38 : Colors.black26),
                  ),
                  Text(
                    'Page $_currentPage of $_maxPages',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  IconButton(
                    onPressed: _currentPage < _maxPages ? _loadNextPage : null,
                    icon: Icon(Icons.arrow_forward_ios),
                    color: _currentPage < _maxPages
                        ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                        : (isDark ? Colors.white38 : Colors.black26),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildInfoItem(bool isDark, String label, String value, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark ? Colors.white60 : Colors.black45,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black45,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    if (minutes < 1) {
      return '$seconds sec';
    }
    return '$minutes min';
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
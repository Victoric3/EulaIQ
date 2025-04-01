import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:eulaiq/src/features/library/presentation/providers/ebook_logs_provider.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:intl/intl.dart';

class ProcessingLogsView extends ConsumerStatefulWidget {
  final String ebookId;
  
  const ProcessingLogsView({
    Key? key,
    required this.ebookId,
  }) : super(key: key);
  
  @override
  ConsumerState<ProcessingLogsView> createState() => _ProcessingLogsViewState();
}

class _ProcessingLogsViewState extends ConsumerState<ProcessingLogsView> {
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      // Fetch logs when opened
      ref.read(ebookLogsProvider(widget.ebookId).notifier).fetchLogs();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logsState = ref.watch(ebookLogsProvider(widget.ebookId));
    
    // Scroll to bottom when new logs arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBg.withOpacity(0.95) : Colors.white,
        elevation: 0,
        title: Text(
          'Processing Logs',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Auto-refresh toggle
          IconButton(
            icon: Icon(
              logsState.isPolling ? Icons.sync : Icons.sync_disabled,
              color: logsState.isPolling 
                ? (isDark ? AppColors.neonCyan : AppColors.brandDeepGold)
                : (isDark ? Colors.white54 : Colors.black45),
            ),
            tooltip: logsState.isPolling ? 'Auto-refresh on' : 'Auto-refresh off',
            onPressed: () {
              ref.read(ebookLogsProvider(widget.ebookId).notifier).togglePolling();
            },
          ),
          // Manual refresh
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              ref.read(ebookLogsProvider(widget.ebookId).notifier).fetchLogs();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Logs content
          Expanded(
            child: logsState.isLoading && logsState.logs.isEmpty
                ? _buildLoadingIndicator(isDark)
                : logsState.logs.isEmpty
                    ? _buildEmptyState(isDark)
                    : _buildLogsList(isDark, logsState),
          ),
          
          // Continue Processing Button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.grey.shade100,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                  width: 0.5,
                ),
              ),
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                ref.read(ebookLogsProvider(widget.ebookId).notifier).continueProcessing();
              },
              icon: Icon(MdiIcons.refresh),
              label: const Text('Continue Processing'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingIndicator(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            strokeWidth: 2,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading logs...',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            MdiIcons.textBoxOutline,
            size: 48,
            color: isDark ? Colors.white30 : Colors.black26,
          ),
          const SizedBox(height: 16),
          Text(
            'No processing logs available',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try continuing the processing',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLogsList(bool isDark, EbookLogsState state) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: state.logs.length,
      itemBuilder: (context, index) {
        final log = state.logs[index];
        final timestamp = DateTime.tryParse(log['timestamp'] ?? '');
        final message = log['message'] ?? 'No message';
        final level = log['level'] ?? 'info';
        
        // Determine log level color
        Color levelColor;
        switch (level.toLowerCase()) {
          case 'error':
            levelColor = Colors.red;
            break;
          case 'warn':
          case 'warning':
            levelColor = Colors.orange;
            break;
          case 'info':
            levelColor = isDark ? Colors.white : Colors.black87;
            break;
          case 'debug':
            levelColor = Colors.blue;
            break;
          default:
            levelColor = isDark ? Colors.white70 : Colors.black54;
        }
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark 
              ? Colors.white.withOpacity(0.05) 
              : Colors.black.withOpacity(0.02),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark 
                ? Colors.white.withOpacity(0.1) 
                : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timestamp and level
              Row(
                children: [
                  Icon(
                    _getLogLevelIcon(level),
                    size: 14,
                    color: levelColor,
                  ),
                  const SizedBox(width: 8),
                  if (timestamp != null)
                    Text(
                      DateFormat('HH:mm:ss').format(timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontFamily: 'monospace',
                      ),
                    ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: levelColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      level.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: levelColor,
                      ),
                    ),
                  ),
                ],
              ),
              
              // Log message
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 22),
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              
              // Additional details
              if (log['step'] != null || log['data'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (log['step'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'Step: ${log['step']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        
                      if (log['data'] != null && log['data'] is Map)
                        ..._buildLogData(log['data'], isDark),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
  
  IconData _getLogLevelIcon(String level) {
    switch (level.toLowerCase()) {
      case 'error':
        return Icons.error_outline;
      case 'warn':
      case 'warning':
        return Icons.warning_amber_outlined;
      case 'info':
        return Icons.info_outline;
      case 'debug':
        return Icons.code;
      default:
        return Icons.arrow_right;
    }
  }
  
  List<Widget> _buildLogData(Map<dynamic, dynamic> data, bool isDark) {
    final widgets = <Widget>[];
    
    data.forEach((key, value) {
      if (value != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$key: ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  TextSpan(
                    text: value.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    });
    
    return widgets;
  }
}
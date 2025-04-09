import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';

class NotificationCard extends StatefulWidget {
  final String message;
  final NotificationType type;
  final VoidCallback onDismiss;
  final Duration duration;

  const NotificationCard({
    Key? key,
    required this.message,
    required this.type,
    required this.onDismiss,
    this.duration = const Duration(seconds: 4),
  }) : super(key: key);

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

enum NotificationType {
  success,
  error,
  info,
  warning
}

class _NotificationCardState extends State<NotificationCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: -100.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _progressAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: 20 + _slideAnimation.value,
          left: size.width * 0.05,
          right: size.width * 0.05,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _getBackgroundColor(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _getBorderColor(context).withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _getBorderColor(context).withOpacity(0.2),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _getBorderColor(context).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getIcon(),
                                color: _getBorderColor(context),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.message,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  _controller.reverse().then((_) => widget.onDismiss());
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            height: 2,
                            child: LinearProgressIndicator(
                              value: _progressAnimation.value,
                              backgroundColor: _getBorderColor(context).withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getBorderColor(context),
                              ),
                            ),
                          ),
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
    );
  }

  Color _getBackgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (widget.type) {
      case NotificationType.success:
        return isDark 
            ? AppColors.neonCyan.withOpacity(0.2) 
            : AppColors.brandDeepGold.withOpacity(0.15);
      case NotificationType.error:
        return Colors.red.withOpacity(isDark ? 0.2 : 0.15);
      case NotificationType.warning:
        return Colors.orange.withOpacity(isDark ? 0.2 : 0.15);
      case NotificationType.info:
        return Colors.blue.withOpacity(isDark ? 0.2 : 0.15);
    }
  }

  Color _getBorderColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (widget.type) {
      case NotificationType.success:
        return isDark ? AppColors.neonCyan : AppColors.brandDeepGold;
      case NotificationType.error:
        return Colors.red;
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.info:
        return Colors.blue;
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case NotificationType.success:
        return Icons.check_circle_outline;
      case NotificationType.error:
        return Icons.error_outline;
      case NotificationType.warning:
        return Icons.warning_amber_rounded;
      case NotificationType.info:
        return Icons.info_outline;
    }
  }
}
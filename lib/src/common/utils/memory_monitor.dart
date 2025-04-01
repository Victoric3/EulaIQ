import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// A utility class to monitor memory usage during development
class MemoryMonitor {
  static Timer? _timer;
  
  /// Start monitoring memory usage
  static void startMonitoring() {
    if (!kDebugMode) return; // Only run in debug mode
    
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkMemory();
    });
  }
  
  /// Stop monitoring memory usage
  static void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
  }
  
  /// Check current memory usage
  static void _checkMemory() {
    developer.log(
      'MEMORY CHECK',
      name: 'MemoryMonitor',
      time: DateTime.now(),
    );
  }
}
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';

/// Service to handle reader functions like position tracking
class ReaderService {
  static const String _positionPrefix = 'reader_position_';
  
  final Ref ref;
  EpubController? _epubController;
  
  ReaderService(this.ref) {
    _epubController = EpubController();
  }
  
  // Get the controller for use in widgets
  EpubController getController() {
    _epubController ??= EpubController();
    return _epubController!;
  }
  
  /// Save the current reading position for a story
  Future<bool> saveReadingPosition(String storyId, String position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString('$_positionPrefix$storyId', position);
    } catch (e) {
      print('Error saving reading position: $e');
      return false;
    }
  }
  
  /// Get the last reading position for a story
  Future<String?> getLastReadingPosition(String storyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_positionPrefix$storyId');
    } catch (e) {
      print('Error getting reading position: $e');
      return null;
    }
  }
  
  /// Delete reading position for a story
  Future<bool> deleteReadingPosition(String storyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove('$_positionPrefix$storyId');
    } catch (e) {
      print('Error deleting reading position: $e');
      return false;
    }
  }
  
  /// Get reading progress percentage for a story (0.0 to 1.0)
  Future<double> getReadingProgress(String storyId) async {
    try {
      final savedPosition = await getLastReadingPosition(storyId);
      if (savedPosition == null) return 0.0;
      
      final locationData = jsonDecode(savedPosition);
      if (locationData.containsKey('progress')) {
        return (locationData['progress'] as num).toDouble();
      }
      return 0.0;
    } catch (e) {
      print('Error getting reading progress: $e');
      return 0.0;
    }
  }
  
  /// Mark a story as read
  Future<bool> markAsRead(String storyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool('read_$storyId', true);
    } catch (e) {
      print('Error marking as read: $e');
      return false;
    }
  }
  
  /// Check if a story is marked as read
  Future<bool> isRead(String storyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('read_$storyId') ?? false;
    } catch (e) {
      print('Error checking read status: $e');
      return false;
    }
  }
}

/// Provider for the reader service
final readerServiceProvider = Provider<ReaderService>((ref) {
  return ReaderService(ref);
});
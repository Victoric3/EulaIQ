import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:eulaiq/src/common/constants/dio_config.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Status of sections for a specific eBook
class SectionStatus {
  final int sectionCount;
  final String status;
  final String? processingStatus;
  final bool needsUpdate;
  
  SectionStatus({
    required this.sectionCount,
    required this.status,
    this.processingStatus,
    required this.needsUpdate,
  });
  
  factory SectionStatus.fromJson(Map<String, dynamic> json) {
    return SectionStatus(
      sectionCount: json['sectionCount'] ?? 0,
      status: json['status'] ?? 'processing',
      processingStatus: json['processingStatus'],
      needsUpdate: json['needsUpdate'] ?? true,
    );
  }
}

/// Repository for managing eBook sections with local caching
class EbookSectionsRepository {
  final Ref ref;
  
  EbookSectionsRepository(this.ref);

  /// Check if sections need to be updated
  Future<SectionStatus> checkSectionsStatus(String ebookId) async {
    try {
      final response = await DioConfig.dio?.get('/ebook/$ebookId/sections-count');
      
      if (response?.statusCode == 200 && response?.data['success'] == true) {
        return SectionStatus.fromJson(response!.data['data']);
      } else {
        throw Exception('Failed to check section status: ${response?.statusCode}');
      }
    } catch (e) {
      throw Exception('Error checking section status: $e');
    }
  }
  
  /// Check if sections exist in local storage
  Future<bool> hasCachedSections(String ebookId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/ebook_sections_$ebookId.json');
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Check if EPUB file exists in local storage
  Future<bool> hasLocalEpub(String storyId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/epub_$storyId.epub');
      return await file.exists();
    } catch (e) {
      return false;
    }
  }
  
  /// Get the path to the local EPUB file if it exists
  Future<String?> getLocalEpubPath(String storyId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/epub_$storyId.epub';
      final file = File(filePath);
      
      if (await file.exists()) {
        return filePath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Download the EPUB file for a story
  Future<String> downloadEpub(
    String storyId, 
    String title,
    {Function(double, int, int)? onProgress}
  ) async {
    try {
      print('Starting EPUB download for story: $storyId');
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/epub_$storyId.epub';
      final file = File(filePath);
      
      // Delete existing file if it exists to ensure fresh content
      if (await file.exists()) {
        await file.delete();
        print('Deleted existing file for fresh download');
      }

      print('Sending download request to: /ebook/$storyId/sections');

      // Download the EPUB file with progress tracking
      await DioConfig.dio?.download(
        '/ebook/$storyId/sections',
        filePath,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 2),
        ),
        onReceiveProgress: (received, total) {
          print('Download progress: $received/$total');
          if (total != -1 && onProgress != null) {
            onProgress(received / total, received, total);
          }
        },
      );
      
      // Verify file was downloaded successfully
      if (await file.exists()) {
        print('Download successful, file saved at: $filePath');
        // Save download date to preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('epub_${storyId}_downloaded', DateTime.now().toIso8601String());
        
        return filePath;
      } else {
        throw Exception('Failed to download EPUB file - file was not created');
      }
    } catch (e) {
      print('Error downloading EPUB: $e');
      throw Exception('Error downloading EPUB: $e');
    }
  }
  
  /// Get the last download date for an EPUB
  Future<DateTime?> getLastDownloadDate(String storyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateStr = prefs.getString('epub_${storyId}_downloaded');
      
      if (dateStr != null) {
        return DateTime.parse(dateStr);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Delete the local EPUB file
  Future<bool> deleteLocalEpub(String storyId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/epub_$storyId.epub');
      
      if (await file.exists()) {
        await file.delete();
        
        // Also remove download date
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('epub_${storyId}_downloaded');
        
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
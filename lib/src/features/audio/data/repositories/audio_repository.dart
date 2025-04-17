import 'dart:io';
import 'package:dio/dio.dart';
import 'package:eulaiq/src/common/common.dart';
import 'package:eulaiq/src/common/constants/dio_config.dart';
import 'package:eulaiq/src/features/audio/data/models/audio_model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRepository {
  Future<List<AudioCollection>> fetchAudioCollections(
    String ebookId, {
    int page = 1,
    int limit = 10,
  }) async {
    try {
      print("called fetchAudioCollections with ebookId: $ebookId, page: $page, limit: $limit");

      final response = await DioConfig.dio?.get(
        '/audio/audiosByEbook/$ebookId',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );
      print('Response: ${response?.data}');

      if (response!.statusCode == 200 && response.data['success'] == true) {
        final collections = (response.data['data']['audioCollections'] as List)
            .map((collection) => AudioCollection.fromJson(collection))
            .toList();
        return collections;
      } else {
        throw Exception(response.data['message'] ?? 'Failed to load audio collections');
      }
    } catch (e) {
      throw Exception('Failed to load audio collections: $e');
    }
  }

  // New method to generate audio
  Future<Map<String, dynamic>> generateAudio({
    required String ebookId,
    required String title,
    String? description,
    required List<String> voiceActors,
    String module = "Simply_Explained_Style",
    String moduleDescription = "",
    bool useGpt4oAudio = false,
    String tone = 'Calm - Measured pacing with soothing, relaxed delivery',
  }) async {
    try {
      final dio = DioConfig.dio;
      if (dio == null) throw Exception('Dio not initialized');

      final response = await dio.post(
        '/audio/generateAudio',
        data: {
          'ebookId': ebookId,
          'title': title,
          'voiceActors': voiceActors,
          'module': module,
          'moduleDescription': moduleDescription,
          'useGpt4oAudio': useGpt4oAudio,
          'tones': tone,
        },
      );

      if (response.statusCode == 202 && response.data['success'] == true) {
        return {
          'collectionId': response.data['collectionId'],
          'status': response.data['status'],
          'message': response.data['message'],
          'waitingForEbook': response.data['waitingForEbook'] ?? false,
          'method': response.data['method'] ?? 'tts',
        };
      } else {
        throw Exception(response.data['message'] ?? 'Failed to generate audio');
      }
    } catch (e) {
      throw Exception('Failed to generate audio: $e');
    }
  }

  // New method to retry/continue audio generation
  Future<Map<String, dynamic>> continueAudioGeneration({
    required String collectionId,
    bool useGpt4oAudio = false
  }) async {
    try {
      final dio = DioConfig.dio;
      if (dio == null) throw Exception('Dio not initialized');

      final response = await dio.post(
        '/audio/continueAudioGeneration',
        data: {
          'collectionId': collectionId,
          'useGpt4oAudio': useGpt4oAudio
        },
      );

      if (response.statusCode == 202 && response.data['success'] == true) {
        return {
          'collectionId': response.data['collectionId'],
          'status': response.data['status'],
          'message': response.data['message'],
          'method': response.data['method'] ?? 'tts',
        };
      } else {
        throw Exception(response.data['message'] ?? 'Failed to continue audio generation');
      }
    } catch (e) {
      throw Exception('Failed to continue audio generation: $e');
    }
  }

  // Update the checkAudioGenerationStatus method with a much longer timeout
  Future<Map<String, dynamic>> checkAudioGenerationStatus(String collectionId) async {
    try {
      final dio = DioConfig.dio;
      if (dio == null) throw Exception('Dio not initialized');

      // Create options with extended timeout - 10 minutes should be sufficient for most cases
      final options = Options(
        sendTimeout: const Duration(minutes: 10),
        receiveTimeout: const Duration(minutes: 10),
      );

      final response = await dio.get(
        '/audio/getAudioGenerationStatus/$collectionId',
        options: options,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      } else {
        throw Exception(response.data['message'] ?? 'Failed to check audio generation status');
      }
    } catch (e) {
      throw Exception('Failed to check audio generation status: $e');
    }
  }

  // Method to fetch audio segments by collection ID
  Future<List<Audio>> fetchAudiosByCollectionId(String collectionId) async {
    try {
      final dio = DioConfig.dio;
      if (dio == null) throw Exception('Dio not initialized');

      final response = await dio.get(
        '/audio/audiosById',
        queryParameters: {
          'collectionId': collectionId,
        },
      );

      if (response.statusCode == 200) {
        print('Response: ${response.data[0]['segments']}');
        final audioList = (response.data as List)
            .map((audio) => Audio.fromJson(audio))
            .toList();
        
        // Sort by index to ensure proper playback order
        audioList.sort((a, b) => a.index.compareTo(b.index));
        return audioList;
      } else {
        throw Exception(response.data['message'] ?? 'Failed to load audio segments');
      }
    } catch (e) {
      throw Exception('Failed to load audio segments: $e');
    }
  }

  // Add this method to check for available audio segments by collection ID
  Future<bool> checkAudioSegmentsAvailable(String collectionId) async {
    try {
      final dio = DioConfig.dio;
      if (dio == null) throw Exception('Dio not initialized');

      final response = await dio.get(
        '/audio/audiosById',
        queryParameters: {
          'collectionId': collectionId,
        },
      );

      // If response is successful and contains at least one audio segment
      if (response.statusCode == 200) {
        final audioSegments = response.data as List;
        return audioSegments.isNotEmpty;
      }
      return false;
    } catch (e) {
      // If there's an error, assume no segments are available
      print('Error checking audio segments: $e');
      return false;
    }
  }

  // Update the streaming URL method with proper encoding and error logging
  String getStreamingUrl(String audioUrl) {
    try {
      // Double-encode to handle special characters in URLs
      final encodedUrl = Uri.encodeComponent(audioUrl);
      final streamUrl = '$baseURL/$serverVersion/audio/stream?audioUrl=$encodedUrl';
      return streamUrl;
    } catch (e) {
      print('Error generating streaming URL: $e');
      throw Exception('Failed to generate streaming URL: $e');
    }
  }

  // Add this function for testing connection to the streaming endpoint
  Future<bool> testStreamingConnection(String audioUrl) async {
    try {
      final dio = DioConfig.dio;
      if (dio == null) throw Exception('Dio not initialized');
      
      final streamingUrl = getStreamingUrl(audioUrl);
      
      // Just make a HEAD request to verify the endpoint works
      final response = await dio.head(
        streamingUrl,
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Test streaming connection failed: $e');
      return false;
    }
  }

  // Add explicit testing method to debug connection issues
  Future<Map<String, dynamic>> testEndpointConnections(String audioUrl) async {
    final Map<String, dynamic> results = {};
    final dio = DioConfig.dio;
    
    if (dio == null) {
      return {'error': 'Dio not initialized'};
    }
    
    try {
      // Test streaming endpoint
      final streamUrl = getStreamingUrl(audioUrl);
      results['streamUrl'] = streamUrl;
      
      try {
        final streamResponse = await dio.head(
          streamUrl,
          options: Options(
            validateStatus: (status) => true, // Accept any status code for diagnostics
            headers: {
              'Accept': '*/*',
              'Cache-Control': 'no-cache',
            },
            receiveTimeout: const Duration(seconds: 10),
          ),
        );
        
        results['streamStatus'] = 200;
        results['streamHeaders'] = streamResponse.headers.map;
      } catch (e) {
        results['streamError'] = e.toString();
      }
      
      // Test download endpoint
      final encodedDownloadUrl = Uri.encodeComponent(audioUrl);
      final downloadUrl = '$baseURL/$serverVersion/audio/download?audioUrl=$encodedDownloadUrl';
      results['downloadUrl'] = downloadUrl;
      
      try {
        final downloadResponse = await dio.head(
          downloadUrl,
          options: Options(
            validateStatus: (status) => true, // Accept any status code for diagnostics
            headers: {
              'Accept': '*/*',
              'Cache-Control': 'no-cache',
            },
            receiveTimeout: const Duration(seconds: 10),
          ),
        );
        
        results['downloadStatus'] = 200;
        results['downloadHeaders'] = downloadResponse.headers.map;
      } catch (e) {
        results['downloadError'] = e.toString();
      }
      
      return results;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Update the download audio method to use double encoding
  Future<File?> downloadAudio(
    String audioUrl, 
    String fileName, 
    String audioId,
    String title,
    Function(DownloadProgress) onProgress
  ) async {
    try {
      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Storage permission not granted');
      }
      
      // Get app's documents directory
      final dir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${dir.path}/eulaiq_downloads');
      
      // Create downloads directory if it doesn't exist
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      
      // Create file path
      final sanitizedFileName = fileName.replaceAll(RegExp(r'[^\w\s\-.]'), '_');
      final filePath = '${downloadsDir.path}/$sanitizedFileName';
      
      // Check if file already exists
      final file = File(filePath);
      if (await file.exists()) {
        return file; // File already downloaded
      }
      
      // Double-encode the audioUrl for query parameter
      final encodedUrl = Uri.encodeComponent(audioUrl);
      final downloadUrl = '$baseURL/$serverVersion/audio/download?audioUrl=$encodedUrl';
      
      print('Downloading from URL: $downloadUrl');
      
      // Download file with progress
      final dio = DioConfig.dio;
      if (dio == null) throw Exception('Dio not initialized');
      
      // Add more request options
      final options = Options(
        headers: {
          HttpHeaders.acceptEncodingHeader: '*',
          'Accept': '*/*',
          'Cache-Control': 'no-cache',
        },
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(minutes: 5), // Longer timeout for large files
      );
      
      await dio.download(
        downloadUrl,
        filePath,
        options: options,
        onReceiveProgress: (received, total) {
          print('Download progress: $received / $total (${(received / total * 100).toStringAsFixed(1)}%)');
          final progress = total > 0 ? received / total : 0.0;
          onProgress(DownloadProgress(
            downloaded: received, 
            total: total, 
            progress: progress,
            audioId: audioId,
            title: title,
          ));
        },
      );
      
      print('Download completed to: $filePath');
      return file;
    } catch (e) {
      print('Download error: $e');
      throw Exception('Failed to download audio: $e');
    }
  }

  // Get all downloaded audio files
  Future<List<Map<String, dynamic>>> getDownloadedAudioFiles() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${dir.path}/eulaiq_downloads');
      
      if (!await downloadsDir.exists()) {
        return [];
      }
      
      final files = await downloadsDir.list().toList();
      
      // Get metadata from local storage for these files
      // This is just a placeholder - you'll need to implement proper metadata storage
      
      return files.map((fileEntity) {
        final file = File(fileEntity.path);
        final fileName = file.path.split('/').last;
        
        return {
          'path': file.path,
          'fileName': fileName,
          'size': file.lengthSync(),
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Delete downloaded audio file
  Future<bool> deleteDownloadedAudio(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Check if audio is downloaded
  Future<bool> isAudioDownloaded(String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${dir.path}/eulaiq_downloads');
      
      if (!await downloadsDir.exists()) {
        return false;
      }
      
      final sanitizedFileName = fileName.replaceAll(RegExp(r'[^\w\s\-.]'), '_');
      final filePath = '${downloadsDir.path}/$sanitizedFileName';
      final file = File(filePath);
      
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  // Get local file path for downloaded audio
  Future<String?> getLocalAudioPath(String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${dir.path}/eulaiq_downloads');
      
      if (!await downloadsDir.exists()) {
        return null;
      }
      
      final sanitizedFileName = fileName.replaceAll(RegExp(r'[^\w\s\-.]'), '_');
      final filePath = '${downloadsDir.path}/$sanitizedFileName';
      final file = File(filePath);
      
      if (await file.exists()) {
        return file.path;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

// Class to track download progress
class DownloadProgress {
  final int downloaded;
  final int total;
  final double progress;
  final String audioId;
  final String title;
  
  DownloadProgress({
    required this.downloaded, 
    required this.total, 
    required this.progress,
    required this.audioId,
    required this.title,
  });
}
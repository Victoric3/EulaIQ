import 'dart:io';
import 'dart:math';
import 'package:auto_route/auto_route.dart';
import 'package:crypto/crypto.dart'; // Add this import for generating hashes
import 'package:eulaiq/src/common/common.dart';
import 'dart:convert';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:eulaiq/src/features/library/data/repositories/library_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:eulaiq/src/common/services/notification_service.dart';
import 'package:eulaiq/src/common/widgets/notification_card.dart';

final documentRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository(ref);
});

@RoutePage()
class DocumentViewerScreen extends ConsumerStatefulWidget {
  final String fileUrl;
  final String title;
  final String? fileType;
  final String ebookId;
  final int? page;
  
  const DocumentViewerScreen({
    Key? key,
    required this.fileUrl,
    required this.title,
    this.fileType,
    required this.ebookId,
    this.page,
  }) : super(key: key);
  
  @override
  ConsumerState<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  File? _localFile;
  bool _isLoading = true;
  String? _errorMessage;
  double _downloadProgress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  bool _isFullScreen = false;
  final PdfViewerController _pdfController = PdfViewerController();
  bool _isCached = false;
  bool _forceLoadLargePdf = false; // Add this flag to your class
  
  @override
  void initState() {
    super.initState();
    _checkCacheAndLoadDocument();
    
    // Set preferred orientation for reading
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
  
  @override
  void dispose() {
    // Reset orientation preferences
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    
    // Force memory cleanup - be thorough about it
    try {
      _pdfController.dispose();
    } catch (e) {
      print('Error disposing PDF controller: $e');
    }
    
    // Be aggressive with memory cleanup
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    
    // Add extra memory cleanup
    Future.microtask(() {
      imageCache.clear();
      imageCache.clearLiveImages();
      
      // Remove this line that's causing the error:
      // SfPdfViewer.clearCache();
    });

    super.dispose();
  }
  
  // Generate a unique filename for caching based on URL
  String _getCachedFileName(String url) {
    // Create a hash from the URL to use as filename
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    final hash = digest.toString();
    
    // Get file extension
    String ext = widget.fileType ?? _getFileTypeFromUrl(url);
    
    // Return filename with hash and extension
    return 'document_${hash.substring(0, 10)}.$ext';
  }
  
  // Check if document exists in cache
  Future<bool> _isDocumentCached() async {
    try {
      final cachedFile = await _getCachedFilePath();
      final exists = await cachedFile.exists();
      return exists;
    } catch (e) {
      print('Error checking cache: $e');
      return false;
    }
  }
  
  // Get the cached file path
  Future<File> _getCachedFilePath() async {
    final cacheDir = await getApplicationDocumentsDirectory();
    final fileName = _getCachedFileName(widget.fileUrl);
    return File('${cacheDir.path}/$fileName');
  }
  
  // Check cache first, then load document
  Future<void> _checkCacheAndLoadDocument() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final isCached = await _isDocumentCached();
      
      if (isCached) {
        // Document exists in cache, check size before loading
        final cachedFile = await _getCachedFilePath();
        final fileSize = await cachedFile.length();
        
        // Set tiered size thresholds for different handling approaches
        if (fileSize > 30 * 1024 * 1024) { // 30MB - Critical size
          // Automatically redirect to enhanced reader for extremely large files
          setState(() {
            _isLoading = false;
            _isCached = true;
          });
          
          NotificationService().showNotification(
            message: 'This document is too large for direct viewing. Redirecting to Enhanced Reader.',
            type: NotificationType.warning,
            duration: const Duration(seconds: 3),
          );
          
          // Navigate after notification shows
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              _openReaderScreen(context);
            }
          });
          return;
        } 
        else if (fileSize > 15 * 1024 * 1024) { // 15MB - Warning threshold
          setState(() {
            _localFile = cachedFile;
            _isLoading = false;
            _isCached = true;
// Add this flag to your class
          });
        } 
        else {
          // File is within reasonable size limits
          setState(() {
            _localFile = cachedFile;
            _isLoading = false;
            _isCached = true;
            _downloadProgress = 1.0;
          });
        }
        
        print('Document loaded from cache: ${cachedFile.path}, size: ${_formatBytes(fileSize)}');
      } else {
        // Document not in cache, download it
        await _loadDocument();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to check cache: $e';
      });
      
      NotificationService().showNotification(
        message: 'Error checking document cache: $e',
        type: NotificationType.error,
      );
    }
  }
  
  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    var i = (log(bytes) / log(1024)).floor();
    return "${(bytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}";
  }
  
  // Download the document if not cached
  Future<void> _loadDocument() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _downloadProgress = 0.0;
      _downloadedBytes = 0;
      _isCached = false;
    });
    
    try {
      
      // Get the target file path for caching
      final cachedFile = await _getCachedFilePath();
      
      // Fetch document from repository with progress tracking
      final fileBytes = await ref.read(documentRepositoryProvider).fetchEbookFile(
        widget.fileUrl,
        onProgress: (progress, receivedBytes) {
          setState(() {
            _downloadProgress = progress;
            _downloadedBytes = receivedBytes;
            _totalBytes = (_downloadProgress > 0) ? (receivedBytes / _downloadProgress).round() : 0;
          });
        }
      );
      
      // Check file size before processing - warn if too large
      if (fileBytes.length > 20 * 1024 * 1024) { // 20 MB
        NotificationService().showNotification(
          message: 'Warning: This document is large and may cause performance issues',
          type: NotificationType.warning,
          duration: const Duration(seconds: 5),
        );
      }
      
      // Save to cache file
      await cachedFile.writeAsBytes(fileBytes);
      
      setState(() {
        _localFile = cachedFile;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      
      // Show error notification
      NotificationService().showNotification(
        message: 'Failed to load document: ${e.toString()}',
        type: NotificationType.error,
      );
    }
  }
  
  String _getFileTypeFromUrl(String url) {
    // Extract extension from URL
    final parts = url.split('.');
    if (parts.length > 1) {
      final extension = parts.last.toLowerCase();
      if (['pdf', 'docx', 'doc', 'pptx', 'ppt', 'epub'].contains(extension)) {
        return extension;
      }
    }
    return 'pdf'; // Default to PDF
  }
  
  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
    
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _showActionMenu(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkBg : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isDark ? AppColors.neonCyan.withOpacity(0.2) : AppColors.brandDeepGold.withOpacity(0.1),
                    child: Icon(
                      MdiIcons.headphones,
                      color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                    ),
                  ),
                  title: const Text('Generate Audio'),
                  subtitle: const Text('Create audio narration for this chapter'),
                  onTap: () {
                    Navigator.pop(context);
                    _generateAudio();
                  },
                ),
                
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isDark ? AppColors.neonCyan.withOpacity(0.2) : AppColors.brandDeepGold.withOpacity(0.1),
                    child: Icon(
                      MdiIcons.checkboxMarkedCircleOutline,
                      color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                    ),
                  ),
                  title: const Text('Create Questions'),
                  subtitle: const Text('Generate quiz questions from current content'),
                  onTap: () {
                    Navigator.pop(context);
                    _createQuestions();
                  },
                ),
                
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isDark ? AppColors.neonCyan.withOpacity(0.2) : AppColors.brandDeepGold.withOpacity(0.1),
                    child: Icon(
                      MdiIcons.textBoxSearch,
                      color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                    ),
                  ),
                  title: const Text('Create Summary'),
                  subtitle: const Text('Generate summary of current content'),
                  onTap: () {
                    Navigator.pop(context);
                    _createSummary();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  void _generateAudio() {
    // Placeholder for audio generation
    NotificationService().showNotification(
      message: 'Audio generation started for this eBook',
      type: NotificationType.info,
      duration: const Duration(seconds: 3),
    );
  }
  
  void _createQuestions() {
    // Placeholder for question creation
    NotificationService().showNotification(
      message: 'Question generation started for this eBook',
      type: NotificationType.info,
      duration: const Duration(seconds: 3),
    );
  }
  
  void _createSummary() {
    // Placeholder for summary creation
    NotificationService().showNotification(
      message: 'Summary generation started for this eBook',
      type: NotificationType.info,
      duration: const Duration(seconds: 3),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Show loading state with better progress visualization
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Custom progress indicator with downloaded bytes
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 80,
                    width: 80,
                    child: CircularProgressIndicator(
                      value: _downloadProgress > 0 ? _downloadProgress : null,
                      strokeWidth: 6,
                      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                      color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                    ),
                  ),
                  Icon(
                    _isCached ? Icons.check_circle : Icons.stop_circle_outlined,
                    size: 30,
                    color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                _isCached ? 'Loading cached document...' : 'Downloading document...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              if (!_isCached) ...[
                const SizedBox(height: 8),
                // Show download progress
                Text(
                  '${(_downloadProgress * 100).toInt()}% • ${_formatBytes(_downloadedBytes)} / ${_totalBytes > 0 ? _formatBytes(_totalBytes) : '...'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    
    // Show error state
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load document',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadDocument,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }
    
    // Show document viewer
    return Scaffold(
      appBar: _isFullScreen ? null : AppBar(
        title: Text(widget.title),
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        actions: [
          // Enhanced Reader button
          IconButton(
            icon: Icon(MdiIcons.bookOpenPageVariant),
            onPressed: () {
              // Navigate to enhanced reader
              _openReaderScreen(context);
            },
            tooltip: 'Enhanced Reader',
          ),
          
          // Existing action buttons...
          IconButton(
            icon: Icon(MdiIcons.dotsVertical),
            onPressed: () => _showActionMenu(context, isDark),
            tooltip: 'More options',
          ),
          
          // Toggle fullscreen
          IconButton(
            icon: Icon(_isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
            onPressed: _toggleFullScreen,
            tooltip: _isFullScreen ? 'Exit fullscreen' : 'Fullscreen',
          ),
          
          // Share button
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              if (_localFile != null) {
                await Share.shareXFiles([XFile(_localFile!.path)], text: widget.title);
              }
            },
            tooltip: 'Share document',
          ),
        ],
      ),
      body: _buildDocumentViewer(isDark),
      // Add floating action button for creating content from current page
      floatingActionButton: _isFullScreen ? null : FloatingActionButton(
        backgroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        onPressed: () => _showActionMenu(context, isDark),
      ),
    );
  }
  
  Widget _buildDocumentViewer(bool isDark) {
    if (_localFile == null) {
      return const Center(child: Text('No file to display'));
    }
    
    // Get file type from path
    final fileExtension = _localFile!.path.split('.').last.toLowerCase();
    
    switch (fileExtension) {
      case 'pdf':
        // Check file size first (but skip if user forced loading)
        final fileSize = _localFile!.lengthSync();
        if (fileSize > 15 * 1024 * 1024 && !_forceLoadLargePdf) { // 15MB threshold
          // Show warning for large file with options
          return _buildLargeFileWarning(isDark, fileSize);
        }
        
        // Use SfPdfViewer with memory optimization settings
        return SfPdfViewer.file(
          _localFile!,
          controller: _pdfController,
          initialPageNumber: widget.page ?? 1, // Correct type for scroll position
          canShowScrollHead: true,
          canShowScrollStatus: true,
          enableDoubleTapZooming: true,
          enableTextSelection: false, // Disable text selection to save memory
          pageSpacing: 4,
          canShowPaginationDialog: false, // Disable pagination dialog to save memory
          onDocumentLoaded: (PdfDocumentLoadedDetails details) {
            if (widget.page != null && mounted) {
              Future.microtask(() {
                try {
                  if (widget.page! <= details.document.pages.count && widget.page! > 0) {
                    _pdfController.jumpToPage(widget.page!);
                  }
                } catch (e) {
                  print('Error navigating to page: $e');
                }
              });
            }
          },
          onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
            setState(() {
              _errorMessage = details.error;
            });
            
            // Handle memory errors
            if (details.description.contains('memory') || 
                details.description.contains('heap') || 
                details.error.contains('memory')) {
              NotificationService().showNotification(
                message: 'This PDF is too large for direct viewing. Using Enhanced Reader instead.',
                type: NotificationType.warning,
                duration: const Duration(seconds: 5),
              );
              
              // Navigate to enhanced reader after short delay
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  _openReaderScreen(context);
                }
              });
            }
          },
        );
        
      // For DOCX/PPTX: Use a placeholder for now with download option
      case 'docx':
      case 'doc':
      case 'pptx':
      case 'ppt':
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                fileExtension.contains('doc') ? MdiIcons.fileWordOutline : MdiIcons.filePowerpointOutline,
                size: 64,
                color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
              ),
              const SizedBox(height: 16),
              Text(
                'This document format is available for download',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  if (_localFile != null) {
                    await Share.shareXFiles([XFile(_localFile!.path)], text: widget.title);
                  }
                },
                icon: const Icon(Icons.download),
                label: const Text('Save Document'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        );
      
      default:
        return Center(
          child: Text(
            'Unsupported document format',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        );
    }
  }

  Widget _buildLargeFileWarning(bool isDark, int fileSize) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              MdiIcons.alertCircleOutline,
              size: 64,
              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
            ),
            const SizedBox(height: 16),
            Text(
              'Large Document Detected',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'This PDF is ${_formatBytes(fileSize)} which may cause performance issues or crashes when opened directly.',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    _openReaderScreen(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: const Text('Use Enhanced Reader'),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      // Force load PDF anyway
                      _forceLoadLargePdf = true; // Add this flag to your class
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                  ),
                  child: const Text('Continue Anyway'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Add this method to the _DocumentViewerScreenState class:
  int? getValidPageNumber() {
    if (widget.page == null) return null;
    
    // Ensure page is positive
    if (widget.page! <= 0) return 1;
    
    // We can't validate against max pages until document is loaded
    // but we'll provide the requested page number
    return widget.page;
  }

  void _openReaderScreen(BuildContext context) {
    context.router.navigate(
      ReaderRoute(
        storyId: widget.ebookId,
        title: widget.title,
      ),
    );
  }
}
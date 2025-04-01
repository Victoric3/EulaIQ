import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Manages global app lifecycle events and cleanups to ensure stability
/// during development (hot reload) and in production.
class AppLifecycleManager {
  /// Reset app state to handle hot reload and restart
  static void resetAppState() {
    // Reset system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    
    // Clear image cache
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    
    // Clear PDF cache - use correct method
    try {
      // Use PdfDocumentViewerController to clear cache if needed
      // SfPdfViewer doesn't have a static clearCache method
      _clearPdfCacheManually();
    } catch (e) {
      debugPrint('Error clearing PDF cache: $e');
    }
  }
  
  /// Manually clean PDF cache since there's no direct method
  static void _clearPdfCacheManually() {
    // Clear image cache which also affects PDF renders
    imageCache.clear();
    imageCache.clearLiveImages();
    
    // If you're using a specific directory for PDF cache,
    // you could delete files from that directory here
  }
  
  /// Listen to app lifecycle changes
  static void setupLifecycleObserver(BuildContext context) {
    WidgetsBinding.instance.addObserver(
      _AppLifecycleObserver(context),
    );
  }
}

class _AppLifecycleObserver with WidgetsBindingObserver {
  final BuildContext context;
  
  _AppLifecycleObserver(this.context);
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground - check if we need to refresh anything
    } else if (state == AppLifecycleState.inactive) {
      // App is inactive - persist any important state
    } else if (state == AppLifecycleState.detached) {
      // App is detached - clean up resources
      AppLifecycleManager.resetAppState();
    }
  }
}
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:eulaiq/src/common/common.dart';
import 'package:eulaiq/src/common/services/notification_service.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:eulaiq/src/features/quiz/presentation/ui/widgets/quiz_summary_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:eulaiq/src/features/reader/presentation/providers/ebook_sections_provider.dart';
import 'package:eulaiq/src/features/reader/presentation/providers/reader_service_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../common/widgets/notification_card.dart';

@RoutePage()
class ReaderScreen extends ConsumerStatefulWidget {
  final String storyId;
  final String title;

  const ReaderScreen({Key? key, required this.storyId, required this.title})
    : super(key: key);

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late EpubController _epubController;
  String? _lastCfi;
  EpubFlow _currentFlow = EpubFlow.scrolled;
  double _fontSize = 16.0;
  bool _showUI = true;
  bool _isDarkMode = false;
  double _currentProgress = 0.0;
  List<EpubChapter> _chapters = [];
  String _currentFontFamily = 'Default';
  double _lineHeight = 1.5;
  double _margin = 16.0;

  final List<String> _fontFamilies = [
    'Default',
    'Georgia',
    'Times New Roman',
    'Roboto',
    'OpenSans',
  ];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Key _epubViewerKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _epubController = EpubController();
    
    _loadSettings();
    _loadLastPosition();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _setSystemUIOverlayStyle();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  void _setSystemUIOverlayStyle() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            _isDarkMode ? Brightness.light : Brightness.dark,
        systemNavigationBarColor:
            _isDarkMode ? const Color(0xFF121212) : Colors.white,
        systemNavigationBarIconBrightness:
            _isDarkMode ? Brightness.light : Brightness.dark,
      ),
    );
  }

  Future<void> _loadLastPosition() async {
    final position = await ref
        .read(readerServiceProvider)
        .getLastReadingPosition(widget.storyId);
    if (position != null) {
      setState(() {
        _lastCfi = position;
      });
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontSize = prefs.getDouble('fontSize') ?? 16.0;
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _currentFontFamily = prefs.getString('fontFamily') ?? 'Default';
      _lineHeight = prefs.getDouble('lineHeight') ?? 1.5;
      _margin = prefs.getDouble('margin') ?? 16.0;
      // Load flow type preference (default to scrolled if not found)
      final flowType = prefs.getString('flowType') ?? 'scrolled';
      _currentFlow = flowType == 'paginated' ? EpubFlow.paginated : EpubFlow.scrolled;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', _fontSize);
    await prefs.setBool('isDarkMode', _isDarkMode);
    await prefs.setString('fontFamily', _currentFontFamily);
    await prefs.setDouble('lineHeight', _lineHeight);
    await prefs.setDouble('margin', _margin);
    // Save flow type preference
    await prefs.setString('flowType', _currentFlow == EpubFlow.paginated ? 'paginated' : 'scrolled');
  }

  String? _parseInitialCfi(String? savedLocation) {
    if (savedLocation == null) return null;
    
    // If the location starts with 'epubcfi', it's already a CFI string
    if (savedLocation.startsWith('epubcfi(')) {
      return savedLocation;
    }
    
    // Otherwise, try to parse as JSON
    try {
      final locationData = jsonDecode(savedLocation);
      return locationData['startCfi'];
    } catch (e) {
      print('Error parsing saved location: $e');
      // If JSON parsing fails, return the raw string as fallback
      // This handles both old formats and corrupted data
      return savedLocation;
    }
  }

  void _updateReaderTheme() {
    final currentCfi = _lastCfi;
    setState(() {
      _epubViewerKey = UniqueKey();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentCfi != null) {
        _epubController.display(cfi: currentCfi);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final epubState = ref.watch(
      epubProvider((id: widget.storyId, title: widget.title)),
    );

    final appTheme = ref.watch(currentAppThemeNotifierProvider).value;
    if (appTheme != null &&
        (_isDarkMode != (appTheme == CurrentAppTheme.dark))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _isDarkMode = appTheme == CurrentAppTheme.dark;
          _saveSettings();
          _setSystemUIOverlayStyle();
        });
      });
    }

    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      backgroundColor: _isDarkMode ? const Color(0xFF121212) : Colors.white,
      drawer: _buildTableOfContentsDrawer(),
      appBar: _showUI
          ? AppBar(
              title: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      shadows: [
                        // Add text shadow to keep text readable on any background
                        Shadow(
                          offset: const Offset(0, 1),
                          blurRadius: 3.0,
                          color: Colors.black.withOpacity(0.5),
                        ),
                      ],
                    ),
              ),
              backgroundColor: Colors.transparent, // Completely transparent
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: Theme.of(context).iconTheme.color,
                ),
                onPressed: () => context.router.pop(),
              ),
              actions: [
                // Refresh Button
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: Theme.of(context).iconTheme.color,
                  ),
                  tooltip: 'Refresh eBook content',
                  onPressed: _refreshEbook,
                ),
                // Your existing buttons...
                IconButton(
                  icon: Icon(
                    Icons.list,
                    color: Theme.of(context).iconTheme.color,
                  ),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.auto_awesome, // Better icon that represents AI actions
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 2),
                      ],
                    ),
                    tooltip: 'AI Actions',
                    onPressed: () => _showEbookActions(context),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.settings,
                    color: Theme.of(context).iconTheme.color,
                  ),
                  onPressed: () => _showReaderSettings(context),
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          epubState.isLoading
              ? _buildLoadingView(epubState.progress)
              : epubState.errorMessage != null
                  ? _buildErrorView(epubState.errorMessage!)
                  : epubState.epubFilePath == null
                      ? Center(
                          child: Text(
                            'No content available',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        )
                      : Padding(
                          padding: EdgeInsets.only(
                            // Top padding adapts to UI visibility and status bar height
                            top: _showUI 
                                ? MediaQuery.of(context).padding.top + 56.0 // Status bar + AppBar height
                                : MediaQuery.of(context).padding.top, // Just status bar when UI hidden
                            
                            // Increased bottom padding for better scrolling experience
                            bottom: _showUI 
                                ? kBottomNavigationBarHeight + MediaQuery.of(context).padding.bottom 
                                : MediaQuery.of(context).padding.bottom,
                            
                          ),
                          child: EpubViewer(
                            key: _epubViewerKey,
                            epubController: _epubController,
                            epubSource: EpubSource.fromFile(
                              File(epubState.epubFilePath!),
                            ),
                            initialCfi: _parseInitialCfi(_lastCfi),
                            displaySettings: EpubDisplaySettings(
                              flow: _currentFlow,
                              snap: true, // Always enable snap for better pagination behavior
                              theme: _isDarkMode ? EpubTheme.dark() : EpubTheme.light(),
                            ),
                            onEpubLoaded: () {
                              _epubController.setFontSize(fontSize: _fontSize);
                              _loadChapters();
                            },
                            onChaptersLoaded:
                                (chapters) => setState(() => _chapters = chapters),
                            onRelocated: _updateLocation,
                            onTextSelected:
                                (selection) => _showTextSelectionMenu(context, selection),
                          ),
                        ),
          if (!epubState.isLoading &&
              epubState.errorMessage == null &&
              epubState.epubFilePath != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                value: _currentProgress,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor.withOpacity(0.7),
                ),
                minHeight: 2,
              ),
            ),
          Positioned.fill(
            child: GestureDetector(
              onDoubleTap: () {
                setState(() {
                  _showUI = !_showUI;
                });
              },
              behavior: HitTestBehavior.translucent,
            ),
          ),
          if (_showUI &&
              !epubState.isLoading &&
              epubState.errorMessage == null &&
              epubState.epubFilePath != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.transparent, // Completely transparent
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Add shadow to buttons so they're visible on any background
                            Material(
                              color: Colors.transparent,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.skip_previous,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(color: Colors.black54, blurRadius: 3),
                                  ],
                                ),
                                onPressed: () => _epubController.prev(),
                              ),
                            ),
                            // Add shadow to text
                            Text(
                              '${(_currentProgress * 100).toInt()}%',
                              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      const Shadow(color: Colors.black54, blurRadius: 3),
                                    ],
                                  ),
                            ),
                            Material(
                              color: Colors.transparent,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.skip_next,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(color: Colors.black54, blurRadius: 3),
                                  ],
                                ),
                                onPressed: () => _epubController.next(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (!_showUI)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 50,
              child: GestureDetector(
                onTap: () {
                  setState(() => _showUI = true);
                },
                behavior: HitTestBehavior.translucent,
              ),
            ),
          if (!_showUI)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 50,
              child: GestureDetector(
                onTap: () {
                  setState(() => _showUI = true);
                },
                behavior: HitTestBehavior.translucent,
              ),
            ),
        ],
      ),
    );
  }

  void _loadChapters() {
    Future.delayed(const Duration(milliseconds: 500), () {
      final chapters = _epubController.getChapters();
      if (chapters.isNotEmpty) {
        setState(() => _chapters = chapters);
        if (_lastCfi == null && chapters.length > 1) {
          final startIndex =
              chapters[0].title.toLowerCase().contains('cover') ? 1 : 0;
          if (startIndex < chapters.length) {
            _epubController.display(cfi: chapters[startIndex].href);
          }
        }
      }
    });
  }

  void _updateLocation(EpubLocation location) {
    setState(() {
      _lastCfi = location.startCfi;
      _currentProgress = location.progress;
    });
    
    final locationData = {
      'startCfi': location.startCfi,
      'endCfi': location.endCfi,
      'progress': location.progress,
    };
    ref
        .read(readerServiceProvider)
        .saveReadingPosition(widget.storyId, jsonEncode(locationData));
  }

  Widget _buildTableOfContentsDrawer() {
    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Table of Contents',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _currentProgress,
                  backgroundColor: Theme.of(context).dividerColor,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${(_currentProgress * 100).toInt()}% read',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _chapters.length,
              itemBuilder: (context, index) {
                final chapter = _chapters[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    chapter.title,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  onTap: () {
                    _epubController.display(cfi: chapter.href);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showTextSelectionMenu(
    BuildContext context,
    EpubTextSelection selection,
  ) {
    try {
      final selectionText = selection.toString();

      final overlay =
          Overlay.of(context).context.findRenderObject() as RenderBox;
      showMenu(
        context: context,
        position: RelativeRect.fromRect(
          Rect.fromCenter(
            center: MediaQuery.of(context).size.center(Offset.zero),
            width: 100,
            height: 100,
          ),
          Offset.zero & overlay.size,
        ),
        items: [
          PopupMenuItem(
            child: ListTile(
              leading: const Icon(Icons.highlight),
              title: const Text('Highlight'),
              onTap: () {
                try {
                  _epubController.addHighlight(
                    cfi: selectionText,
                    color: Colors.yellow,
                    opacity: 0.5,
                  );
                } catch (e) {
                  print('Error highlighting: $e');
                }
                Navigator.pop(context);
              },
            ),
          ),
        ],
      );
    } catch (e) {
      print('Error showing text selection menu: $e');
    }
  }

  void _showReaderSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setModalState) => Container(
                  height: MediaQuery.of(context).size.height * 0.8,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        'Settings',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        title: Text(
                          'Dark Mode',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        trailing: Switch(
                          value: _isDarkMode,
                          onChanged: (value) {
                            setModalState(() => _isDarkMode = value);
                            setState(() => _isDarkMode = value);
                            ref
                                .read(currentAppThemeNotifierProvider.notifier)
                                .updateCurrentAppTheme(value);
                            _updateReaderTheme();
                            _setSystemUIOverlayStyle();
                            _saveSettings();
                          },
                        ),
                      ),
                      // In the _showReaderSettings method, add this ListTile after dark mode toggle:
                      ListTile(
                        title: Text(
                          'Reading Mode',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        subtitle: Row(
                          children: [
                            Expanded(
                              child: RadioListTile<EpubFlow>(
                                title: const Text('Pages'),
                                value: EpubFlow.paginated,
                                groupValue: _currentFlow,
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                onChanged: (value) {
                                  setModalState(() => _currentFlow = value!);
                                  setState(() => _currentFlow = value!);
                                  _saveSettings();
                                  _updateReaderTheme();
                                },
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<EpubFlow>(
                                title: const Text('Scrolling'),
                                value: EpubFlow.scrolled,
                                groupValue: _currentFlow,
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                onChanged: (value) {
                                  setModalState(() => _currentFlow = value!);
                                  setState(() => _currentFlow = value!);
                                  _saveSettings();
                                  _updateReaderTheme();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      ListTile(
                        title: Text(
                          'Font Size',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        subtitle: Slider(
                          value: _fontSize,
                          min: 12,
                          max: 24,
                          divisions: 12,
                          label: _fontSize.round().toString(),
                          onChanged: (value) {
                            setModalState(() => _fontSize = value);
                            setState(() => _fontSize = value);
                            _epubController.setFontSize(fontSize: value);
                            _saveSettings();
                          },
                        ),
                      ),
                      ListTile(
                        title: Text(
                          'Font Family',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        trailing: DropdownButton<String>(
                          value: _currentFontFamily,
                          onChanged: (value) {
                            if (value != null) {
                              setModalState(() => _currentFontFamily = value);
                              setState(() => _currentFontFamily = value);
                              _saveSettings();
                            }
                          },
                          items:
                              _fontFamilies
                                  .map(
                                    (font) => DropdownMenuItem(
                                      value: font,
                                      child: Text(font),
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
                      ListTile(
                        title: Text(
                          'Line Height',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        subtitle: Slider(
                          value: _lineHeight,
                          min: 1.0,
                          max: 2.0,
                          divisions: 10,
                          label: _lineHeight.toStringAsFixed(1),
                          onChanged: (value) {
                            setModalState(() => _lineHeight = value);
                            setState(() => _lineHeight = value);
                            _saveSettings();
                          },
                        ),
                      ),
                      ListTile(
                        title: Text(
                          'Margin',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        subtitle: Slider(
                          value: _margin,
                          min: 0,
                          max: 32,
                          divisions: 16,
                          label: _margin.round().toString(),
                          onChanged: (value) {
                            setModalState(() => _margin = value);
                            setState(() => _margin = value);
                            _saveSettings();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Widget _buildLoadingView(double progress) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(value: progress > 0 ? progress : null),
          const SizedBox(height: 16),
          Text(
            'Loading eBook...',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (progress > 0)
            Text(
              '${(progress * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading eBook',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed:
                () =>
                    ref
                        .read(
                          epubProvider((
                            id: widget.storyId,
                            title: widget.title,
                          )).notifier,
                        )
                        .downloadEpub(),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  // Update the _showEbookActions method for more visible icons:
  void _showEbookActions(BuildContext context) {
    final isDark = _isDarkMode;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
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
                  leading: Container(
                    width: 56,  // Larger size
                    height: 56, // Larger size
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.headphones,
                      color: Theme.of(context).primaryColor,
                      size: 28, // Larger icon
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
                  leading: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.quiz_outlined,
                      color: Theme.of(context).primaryColor,
                      size: 28,
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
                  leading: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.summarize_outlined,
                      color: Theme.of(context).primaryColor,
                      size: 28,
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
  // Show "coming soon" notification
  final notificationService = ref.read(notificationServiceProvider);
  notificationService.showNotification(
    message: 'Audio generation feature coming soon!',
    type: NotificationType.info,
    duration: const Duration(seconds: 3),
  );
}

  void _createQuestions() {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final scrimColor = Colors.black.withOpacity(0.5);
  
  // Show quiz summary dialog
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: scrimColor,
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.95, // Takes up 95% of the screen
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            color: isDark ? AppColors.darkBg : Colors.white,
            child: QuizSummaryView(
              ebookId: widget.storyId,
            ),
          ),
        ),
      );
    },
  );
}

 void _createSummary() {
  // Show "coming soon" notification
  final notificationService = ref.read(notificationServiceProvider);
  notificationService.showNotification(
    message: 'Summary generation feature coming soon!',
    type: NotificationType.info,
    duration: const Duration(seconds: 3),
  );
}

  Future<void> _refreshEbook() async {
    final notificationService = NotificationService();
    
    // Show refreshing notification
    notificationService.showNotification(
      message: 'Refreshing eBook content...',
      type: NotificationType.info,
      duration: const Duration(seconds: 2),
    );
    
    try {
      // Save current position before refresh
      final currentCfi = _lastCfi;
      
      // Reset the key to force rebuild of the viewer
      setState(() {
        _epubViewerKey = UniqueKey();
      });
      
      // Download fresh copy from server with forceRefresh flag
      await ref
          .read(
            epubProvider((
              id: widget.storyId,
              title: widget.title,
            )).notifier,
          )
          .downloadEpub(forceRefresh: true);
      
      // Show success notification
      notificationService.showNotification(
        message: 'eBook refreshed successfully!',
        type: NotificationType.success,
        duration: const Duration(seconds: 2),
      );
      
      // Restore position after a short delay to ensure content is loaded
      if (currentCfi != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _epubController.display(cfi: currentCfi);
        });
      }
    } catch (e) {
      print('Error refreshing eBook: $e');
      
      // Show error notification
      notificationService.showNotification(
        message: 'Failed to refresh eBook: ${e.toString()}',
        type: NotificationType.error,
        duration: const Duration(seconds: 3),
      );
    }
  }
}

import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:eulaiq/src/common/common.dart';
import 'package:eulaiq/src/common/widgets/notification_card.dart';
import 'package:eulaiq/src/features/auth/data/models/user_model.dart';
import 'package:eulaiq/src/features/create/data/repositories/ebook_repository.dart';
import 'package:eulaiq/src/features/library/presentation/providers/library_provider.dart';
import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:eulaiq/src/common/theme/app_theme.dart';
import 'package:eulaiq/src/common/services/notification_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../providers/ebook_provider.dart';
import '../../../../auth/providers/user_provider.dart';
import 'package:eulaiq/src/features/library/presentation/providers/library_refresh_provider.dart';
import 'package:eulaiq/src/features/create/presentation/providers/latest_ebook_provider.dart';
import 'package:eulaiq/src/features/library/data/models/ebook_model.dart';

@RoutePage()
class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({super.key});

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  CancelToken? _uploadCancelToken;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _uploadCancelToken?.cancel('User left the screen');
    _uploadCancelToken = null;
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final processingInfo = ref.watch(ebookProcessingProvider);
    final selectedFile = ref.watch(selectedFileProvider);
    final userState = ref.watch(userProvider);

    // Processing state logic remains the same...
    final bool showProcessingCard = selectedFile != null || 
        processingInfo.status == ProcessingStatus.processing || 
        processingInfo.status == ProcessingStatus.uploading ||
        processingInfo.status == ProcessingStatus.complete;
    
    final bool showUploadCard = !showProcessingCard || 
        (processingInfo.status == ProcessingStatus.complete && selectedFile == null);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
              ? [
                  AppColors.darkBg,
                  AppColors.darkBg.withOpacity(0.95),
                  AppColors.darkBg.withOpacity(0.9),
                ]
              : [
                  AppColors.neutralLightGray.withOpacity(0.5),
                  Colors.white,
                  AppColors.brandDeepGold.withOpacity(0.05),
                ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernHeader(context, isDark, userState.valueOrNull),
              
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        
                        // Upload card with smooth animation
                        if (showUploadCard)
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: _buildModernUploadCard(isDark),
                          ),

                        const SizedBox(height: 32),

                        // Processing state with smooth animation  
                        if (showProcessingCard)
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: _buildProcessingState(isDark, processingInfo, selectedFile),
                          ),
                        
                        // Modern supporting information
                        if (showUploadCard)
                          _buildSupportingInfo(isDark),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Improved header that matches the home screen style
  Widget _buildModernHeader(BuildContext context, bool isDark, UserModel? user) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 72, // Fixed height for consistency
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark 
                ? [
                    AppColors.darkBg.withOpacity(0.9),
                    AppColors.darkBg.withOpacity(0.85),
                  ]
                : [
                    Colors.white.withOpacity(0.9),
                    Colors.white.withOpacity(0.95),
                  ],
            ),
            border: Border(
              bottom: BorderSide(
                color: isDark
                  ? AppColors.neonCyan.withOpacity(0.1)
                  : AppColors.brandDeepGold.withOpacity(0.1),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Title section with icon and text
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark 
                            ? [AppColors.neonCyan.withOpacity(0.8), AppColors.neonPurple.withOpacity(0.5)]
                            : [AppColors.brandDeepGold.withOpacity(0.8), AppColors.brandWarmOrange.withOpacity(0.5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: isDark 
                              ? AppColors.neonCyan.withOpacity(0.2)
                              : AppColors.brandDeepGold.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        MdiIcons.bookPlus,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Create eBook',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.neutralDarkGray,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // User profile (if needed)
              if (user != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: user.photo.isNotEmpty
                    ? Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark 
                              ? AppColors.neonCyan.withOpacity(0.5)
                              : AppColors.brandDeepGold.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.network(
                            user.photo,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    : Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark 
                              ? AppColors.neonCyan.withOpacity(0.5)
                              : AppColors.brandDeepGold.withOpacity(0.5),
                            width: 1.5,
                          ),
                          color: isDark ? Colors.grey[850] : Colors.white,
                        ),
                        child: Center(
                          child: Text(
                            user.firstname.isNotEmpty ? user.firstname[0].toUpperCase() : 'U',
                            style: TextStyle(
                              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernUploadCard(bool isDark) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: isDark 
                  ? AppColors.neonCyan.withOpacity(0.1 * _animationController.value)
                  : AppColors.brandDeepGold.withOpacity(0.1 * _animationController.value),
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _pickFile(ref),
              borderRadius: BorderRadius.circular(24),
              splashColor: isDark 
                ? AppColors.neonCyan.withOpacity(0.1)
                : AppColors.brandDeepGold.withOpacity(0.1),
              highlightColor: isDark 
                ? AppColors.neonCyan.withOpacity(0.05)
                : AppColors.brandDeepGold.withOpacity(0.05),
              child: Ink(
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.4) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark 
                      ? AppColors.neonCyan.withOpacity(0.2 + 0.1 * _animationController.value)
                      : AppColors.brandDeepGold.withOpacity(0.2 + 0.1 * _animationController.value),
                    width: 1.5,
                  ),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 140,
                        width: 140,
                        child: LottieBuilder.asset(
                          isDark 
                            ? 'assets/animations/upload-darkmode.json'
                            : 'assets/animations/upload-lightmode.json',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Upload Your Document',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.neutralDarkGray,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark 
                            ? AppColors.neonCyan.withOpacity(0.1)
                            : AppColors.brandDeepGold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'PDF, DOCX, PPTX • Up to 20MB',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark 
                              ? AppColors.neonCyan
                              : AppColors.brandDeepGold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Modern supporting info section
  Widget _buildSupportingInfo(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 40),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.3) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark 
            ? Colors.white.withOpacity(0.1)
            : Colors.black.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your eBook will include:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildSupportingInfoItem(
            isDark, 
            'Interactive content with text, images, and links',
            MdiIcons.bookOpenPageVariant,
          ),
          const SizedBox(height: 16),
          
          _buildSupportingInfoItem(
            isDark, 
            'AI-generated audio narration for each chapter',
            MdiIcons.headphones,
          ),
          const SizedBox(height: 16),
          
          _buildSupportingInfoItem(
            isDark, 
            'Auto-generated quizzes and knowledge checks',
            MdiIcons.checkboxMarkedCircleOutline,
          ),
          const SizedBox(height: 16),
          
          _buildSupportingInfoItem(
            isDark, 
            'Smart search and advanced navigation features',
            MdiIcons.magnify,
          ),
        ],
      ),
    );
  }

  Widget _buildSupportingInfoItem(bool isDark, String text, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark 
              ? AppColors.neonCyan.withOpacity(0.1)
              : AppColors.brandDeepGold.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingState(bool isDark, processingInfo, PlatformFile? file) {
    final enhancedInfo = processingInfo;
    
    // Determine if we're in the initial processing state (just uploaded)
    final bool isInitialProcessing = 
      processingInfo.status == ProcessingStatus.processing && 
      (enhancedInfo.currentStep == null || enhancedInfo.currentStep == 'initializing');

    // Determine if we're currently uploading
    final bool isUploading = processingInfo.status == ProcessingStatus.uploading;

    // Status message based on processing state
    final String statusMessage;
    if (isUploading) {
      statusMessage = 'Uploading your document...';
    } else if (processingInfo.status == ProcessingStatus.complete) {
      statusMessage = 'Processing complete!';
    } else if (isInitialProcessing) {
      statusMessage = 'eBook created successfully!';
    } else if (enhancedInfo.currentStep != null) {
      statusMessage = enhancedInfo.currentStep!;
    } else {
      statusMessage = 'Processing your document...';
    }
    
    return Stack(
      children: [
        // Main card content
        Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark 
                ? (processingInfo.status == ProcessingStatus.complete 
                    ? AppColors.neonCyan 
                    : AppColors.neonCyan.withOpacity(0.2))
                : (processingInfo.status == ProcessingStatus.complete 
                    ? AppColors.brandDeepGold 
                    : AppColors.brandDeepGold.withOpacity(0.2)),
              width: processingInfo.status == ProcessingStatus.complete ? 2.0 : 1.0,
            ),
            boxShadow: [
              if (processingInfo.status == ProcessingStatus.complete) 
                BoxShadow(
                  color: isDark 
                    ? AppColors.neonCyan.withOpacity(0.2)
                    : AppColors.brandDeepGold.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Column(
            children: [
              // File info if available
              if (file != null) ...[
                Text(
                  file.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.neutralDarkGray,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _formatFileSize(file.size),
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Show success animation for initial processing state
              _buildProcessingAnimation(isDark, isInitialProcessing, processingInfo.status),
                
              const SizedBox(height: 24),

              // Status message - Different for initial processing
              Text(
                isInitialProcessing ? 'eBook created successfully!' : statusMessage,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.neutralDarkGray,
                ),
              ),
              
              // Subtitle for initial processing
              if (isInitialProcessing) ...[
                const SizedBox(height: 8),
                Text(
                  'Your eBook is ready to use while content processing continues in the background',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
              
              const SizedBox(height: 8),

              // Current step information if available - not for initial processing
              if (enhancedInfo.currentStep != null && 
                  processingInfo.status != ProcessingStatus.uploading &&
                  processingInfo.status != ProcessingStatus.complete &&
                  !isInitialProcessing) ...[
                Text(
                  'Current step: ${enhancedInfo.currentStep}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],

              // Estimated time remaining if available - not for initial processing
              if (enhancedInfo.timeRemaining != null && 
                  processingInfo.status != ProcessingStatus.complete &&
                  !isInitialProcessing) ...[
                Text(
                  'Estimated time remaining: ${_formatTimeRemaining(enhancedInfo.timeRemaining!)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],

              // Progress bar - hide for initial processing
              if (!isInitialProcessing) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: double.infinity,
                    height: 6,
                    child: LinearProgressIndicator(
                      value: processingInfo.progress,
                      backgroundColor: isDark 
                        ? Colors.white12 
                        : AppColors.neutralLightGray,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Progress percentage - hide for initial processing
                Text(
                  '${(processingInfo.progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],

              // Warning about errors if any
              if (enhancedInfo.hasErrors) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Processing encountered some issues but will continue',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Show view in library button if we have an ebookId (after upload)
              if (processingInfo.ebookId != null) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    // Create another eBook button - now just an icon
                    IconButton(
                      onPressed: () {
                        // IMPORTANT: First reset the processing info state
                        ref.read(ebookProcessingProvider.notifier).resetState();
                        
                        // Then reset the selected file after a tiny delay
                        Future.delayed(const Duration(milliseconds: 100), () {
                          ref.read(selectedFileProvider.notifier).state = null;
                        });
                      },
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                        size: 32,
                      ),
                      tooltip: 'Create Another eBook',
                      padding: const EdgeInsets.all(8),
                    ),
                    
                    // View in library button - takes most space
                    Expanded(
                      child: SizedBox(
                        height: 48, // Fixed height
                        child: ElevatedButton.icon(
                          onPressed: _viewCreatedEbook, // Use the new method
                          icon: const Icon(
                            Icons.library_books,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: Text(
                            isInitialProcessing || processingInfo.status == ProcessingStatus.processing
                              ? 'Start Using Now' 
                              : 'View eBook',
                            style: const TextStyle(fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        
        // Cancel button overlay - only during upload
        if (isUploading)
          Positioned(
            top: 16,
            right: 16,
            child: AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: _cancelUpload,
                child: Container(
                  width: 34,
                  height: 34,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black45 : Colors.white,
                    borderRadius: BorderRadius.circular(17), // Make it perfectly round
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 6,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        // More muted red color
                        color: isDark 
                          ? const Color.fromRGBO(220, 60, 60, 0.85)
                          : const Color.fromRGBO(200, 50, 50, 0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickFile(WidgetRef ref) async {
    final notificationService = ref.read(notificationServiceProvider);
    // Get isDark here
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'pptx'],
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        // Validate file size (max 20MB)
        if (file.size > 20 * 1024 * 1024) {
          notificationService.showNotification(
            message: 'File size exceeds 20MB limit',
            type: NotificationType.warning,
          );
          return;
        }
        
        // Validate file extension
        final extension = file.extension?.toLowerCase() ?? '';
        if (!['pdf', 'docx', 'pptx'].contains(extension)) {
          notificationService.showNotification(
            message: 'Unsupported file format. Please use PDF, DOCX or PPTX',
            type: NotificationType.warning,
          );
          return;
        }
        
        // Store the selected file
        ref.read(selectedFileProvider.notifier).state = file;
        
        try {
          // Get the notifier reference
          final notifier = ref.read(ebookProcessingProvider.notifier);
          
          // Create a new cancel token for this upload
          _uploadCancelToken = CancelToken();
          
          // Start the upload with timeout and cancel token
          await notifier.uploadFile(
            file,
            cancelToken: _uploadCancelToken,
            timeout: const Duration(seconds: 60), // 1 minute timeout
            onTimeout: () {
              notificationService.showNotification(
                message: 'Upload timed out. Please try again.',
                type: NotificationType.error,
              );
              // Reset state on timeout
              ref.read(selectedFileProvider.notifier).state = null;
            },
          );
          
          // Reset the upload flag
          
          // Check the current state
          final currentState = ref.read(ebookProcessingProvider);
          
          if (currentState.status == ProcessingStatus.processing) {
            // Show success notification
            notificationService.showNotification(
              message: 'Upload successful! Processing your document...',
              type: NotificationType.success,
            );
            
            // Start polling using the provider method
            notifier.startPolling();

            // Show info dialog for first-time users with correct isDark value
            _showProcessingInfoDialog(context, isDark);
          }

          // After successful upload, extract eBook data if available
          if (currentState.status == ProcessingStatus.processing && 
              currentState.ebookId != null) {
            
            // Extract eBook data directly from the full response
            final fullData = currentState.fullEbookData;
            Map<String, dynamic>? ebookData;
            
            // Try different paths where the eBook data might be located
            if (fullData?['ebook'] is Map<String, dynamic>) {
              ebookData = fullData?['ebook'] as Map<String, dynamic>;
            } else if (fullData != null) {
              // The data might be at top level
              ebookData = fullData;
            }
            
            if (ebookData != null) {
              print("Creating eBook model from: $ebookData");
              
              // Create a basic EbookModel with the data we have
              final newEbook = EbookModel(
                id: currentState.ebookId!,
                title: ebookData['title'] as String? ?? 
                       ebookData['name'] as String? ??
                       file.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
                slug: _extractSlug(fullData ?? {}), // Use the helper method
                author: 'You', // Default author
                createdAt: DateTime.now(),
                status: 'processing', // Always processing at this point
                tags: const [],
                coverImage: _extractCoverImageUrl(fullData ?? {}), // Use the improved method
              );
              
              // Store in the provider for later use
              ref.read(latestCreatedEbookProvider.notifier).state = newEbook;
              
              // Debug confirmation
              print("latestCreatedEbookProvider updated with: ${newEbook.id}");
            } else {
              // Fallback to minimal eBook data if we couldn't find it in the response
              final newEbook = EbookModel(
                id: currentState.ebookId!,
                title: file.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
                slug: null, // Add slug with null as fallback
                author: 'You',
                createdAt: DateTime.now(),
                status: 'processing',
                tags: const [],
              );
              
              // Store in the provider
              ref.read(latestCreatedEbookProvider.notifier).state = newEbook;
              print("latestCreatedEbookProvider updated with minimal data: ${newEbook.id}");
            }
          }
        } catch (error) {
          // Only show error if it wasn't a user cancellation
          if (_uploadCancelToken == null || !_uploadCancelToken!.isCancelled) {
            notificationService.showNotification(
              message: 'Upload failed: ${error.toString()}',
              type: NotificationType.error,
            );
          }
          // Reset state on error
          ref.read(selectedFileProvider.notifier).state = null;
        }
      }
    } catch (e) {
      notificationService.showNotification(
        message: 'Error selecting file: ${e.toString()}',
        type: NotificationType.error,
      );
    }
  }

  void _cancelUpload() {
    if (_uploadCancelToken != null && !_uploadCancelToken!.isCancelled) {
      _uploadCancelToken!.cancel('User cancelled upload');
      ref.read(notificationServiceProvider).showNotification(
        message: 'Upload cancelled',
        type: NotificationType.info,
      );
      
      // Reset state
      ref.read(selectedFileProvider.notifier).state = null;
      _uploadCancelToken = null;
    }
  }

  String _formatFileSize(int size) {
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double formattedSize = size.toDouble();
    
    while (formattedSize > 1024 && i < suffixes.length - 1) {
      formattedSize /= 1024;
      i++;
    }
    
    return '${formattedSize.toStringAsFixed(1)} ${suffixes[i]}';
  }


  // Add this helper method to format the time remaining
  String _formatTimeRemaining(int seconds) {
    if (seconds < 60) {
      return '$seconds seconds';
    } else if (seconds < 3600) {
      final minutes = (seconds / 60).floor();
      final remainingSeconds = seconds % 60;
      return '$minutes min ${remainingSeconds > 0 ? '$remainingSeconds sec' : ''}';
    } else {
      final hours = (seconds / 3600).floor();
      final minutes = ((seconds % 3600) / 60).floor();
      return '$hours hr ${minutes > 0 ? '$minutes min' : ''}';
    }
  }

  // Add this method to show a help dialog

  void _showProcessingInfoDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark 
              ? AppColors.neonCyan.withOpacity(0.3)
              : AppColors.brandDeepGold.withOpacity(0.3),
            width: 1,
          ),
        ),
        title: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'eBook Created!',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Success animation
            SizedBox(
              height: 100,
              width: 100,
              child: LottieBuilder.asset(
                isDark 
                  ? 'assets/animations/success-darkmode.json'
                  : 'assets/animations/success-lightmode.json',
                fit: BoxFit.contain,
                repeat: false,
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              'Your eBook has been created and is ready to use!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            
            Text(
              'Advanced processing continues in the background:',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            
            _buildInfoPoint(
              isDark, 
              ' Content analysis and organization', 
              Icons.auto_awesome
            ),
            const SizedBox(height: 8),
            _buildInfoPoint(
              isDark, 
              ' Audio generation for chapters', 
              Icons.headphones
            ),
            const SizedBox(height: 8),
            _buildInfoPoint(
              isDark, 
              ' Quiz and summary creation', 
              Icons.format_list_bulleted
            ),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark 
                  ? AppColors.neonCyan.withOpacity(0.1)
                  : AppColors.brandDeepGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark 
                    ? AppColors.neonCyan.withOpacity(0.3)
                    : AppColors.brandDeepGold.withOpacity(0.3),
                ),
              ),
              child: Text(
                'You can start using your eBook immediately while these features are being prepared!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Use a Row with tight constraints
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Convert Create Another to an icon button
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Reset the selected file
                      ref.read(selectedFileProvider.notifier).state = null;
                      // Also reset the processing info
                      ref.read(ebookProcessingProvider.notifier).resetState();
                    },
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                      size: 24,
                    ),
                    tooltip: 'Create Another eBook',
                  ),
                  
                  // Start Using Now button - made narrower
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      
                      // Use the improved navigation method
                      _viewCreatedEbook();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.neonCyan : AppColors.brandDeepGold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Start Using Now'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPoint(bool isDark, String text, IconData icon) {
    return Row(
      children: [
        Icon(
          icon, 
          size: 16, 
          color: isDark ? AppColors.neonCyan : AppColors.brandDeepGold
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  // Determine the appropriate animation to show
  Widget _buildProcessingAnimation(bool isDark, bool isInitialProcessing, ProcessingStatus status) {
    // Success animation for initial upload success or when processing is complete
    if (isInitialProcessing || status == ProcessingStatus.complete) {
      return SizedBox(
        height: 150,
        width: 150,
        child: LottieBuilder.asset(
          isDark 
            ? 'assets/animations/success-darkmode.json'
            : 'assets/animations/success-lightmode.json',
          fit: BoxFit.contain,
          repeat: false,
        ),
      );
    }
    
    // Processing animation for active processing state
    return SizedBox(
      height: 150,
      width: 150,
      child: LottieBuilder.asset(
        isDark 
          ? 'assets/animations/processing-darkmode.json'
          : 'assets/animations/processing.json',
        fit: BoxFit.contain,
        repeat: true,
      ),
    );
  }

  // Rename from _navigateToLibrary to _viewCreatedEbook for clarity
  void _viewCreatedEbook() {
    // Get the latest created eBook
    final latestEbook = ref.read(latestCreatedEbookProvider);
    print("latestEbook: $latestEbook");
    final bool hasEbook = latestEbook != null;
    
    if (hasEbook) {
      // Force the library to update with the new eBook in background
      ref.read(libraryProvider.notifier).addNewEbook(latestEbook);
      
      // Clear the latest eBook after injecting to prevent duplicate additions
      ref.read(latestCreatedEbookProvider.notifier).state = null;
      
      // Set refresh flag for when user visits library later
      ref.read(libraryRefreshProvider.notifier).state = true;
      
      // Navigate directly to the eBook detail screen
      context.router.navigate(EbookDetailRoute(
        id: latestEbook.id,
        slug: latestEbook.slug,
      ));
    } else {
      // Fallback to library navigation if we don't have the eBook
      _navigateToLibraryAsBackup();
    }
  }

  // Keep this as a fallback method
  void _navigateToLibraryAsBackup() {
    // Navigate to library tab
    final rootRouter = AutoRouter.of(context).root;
    final tabsRouter = rootRouter.innerRouterOf<TabsRouter>(TabsRoute.name);
    if (tabsRouter != null) {
      tabsRouter.setActiveIndex(1); // Library tab is at index 1
    } else {
      // Fallback to direct navigation
      context.router.navigate(const LibraryRoute());
    }
  }

  // Add this helper method to your class for better image extraction
  // Fix this method to properly extract the image URL from the nested ebook object
String? _extractCoverImageUrl(Map<String, dynamic> data) {
  // Try all possible fields where the image URL might be stored
  String? imageUrl;
  
  // Check direct fields first
  if (data['image'] is String) {
    imageUrl = data['image'];
  } else if (data['photo'] is String) {
    imageUrl = data['photo'];
  } else if (data['coverImage'] is String) {
    imageUrl = data['coverImage'];
  } 
  // Then check nested ebook object
  else if (data['ebook'] != null && data['ebook'] is Map<String, dynamic>) {
    final ebookData = data['ebook'] as Map<String, dynamic>;
    imageUrl = ebookData['image'] as String? ?? 
              ebookData['photo'] as String? ?? 
              ebookData['coverImage'] as String?;
  }
  
  // If we found an image URL, check if it needs the base URL added
  if (imageUrl != null && imageUrl.isNotEmpty) {
    // If the URL doesn't start with http/https, it might be a relative path
    if (!imageUrl.startsWith('http')) {
      // Add your API base URL here
      const baseUrl = baseURL;
      imageUrl = '$baseUrl$imageUrl';
    }
  }
  
  return imageUrl;
}

// Add this helper method to correctly extract the slug
String? _extractSlug(Map<String, dynamic> data) {
  // Try direct field first
  if (data['slug'] is String) {
    return data['slug'];
  } 
  // Then check nested ebook object
  else if (data['ebook'] != null && data['ebook'] is Map<String, dynamic>) {
    return data['ebook']['slug'] as String?;
  }
  return null;
}
}
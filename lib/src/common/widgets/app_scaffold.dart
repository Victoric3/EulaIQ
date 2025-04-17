import 'package:eulaiq/src/features/audio/presentation/ui/widgets/mini_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppScaffold extends ConsumerWidget {
  final Widget child;
  final bool showMiniPlayer;
  
  const AppScaffold({
    Key? key,
    required this.child,
    this.showMiniPlayer = true,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          // Main content
          Expanded(child: child),
          
          // Mini player
          if (showMiniPlayer) const MiniPlayer(),
          
          // Bottom padding to account for system navigation
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
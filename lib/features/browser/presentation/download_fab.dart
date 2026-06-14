import 'package:flutter/material.dart';

/// Animated download FAB that appears only when the browser is on a watchable
/// video page.
class DownloadFab extends StatelessWidget {
  const DownloadFab({
    required this.visible,
    required this.onPressed,
    super.key,
  });

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: visible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: FloatingActionButton.extended(
        onPressed: visible ? onPressed : null,
        icon: const Icon(Icons.download),
        label: const Text('Descargar'),
      ),
    );
  }
}

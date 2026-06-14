import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/empty_state.dart';
import '../application/downloader_notifier.dart';
import 'download_tile.dart';

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloaderProvider);
    final hasFinished = tasks.any((t) => !t.status.isActive);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Descargas'),
        actions: [
          if (hasFinished)
            IconButton(
              tooltip: 'Limpiar completadas',
              onPressed: () =>
                  ref.read(downloaderProvider.notifier).clearFinished(),
              icon: const Icon(Icons.cleaning_services_outlined),
            ),
        ],
      ),
      body: tasks.isEmpty
          ? EmptyState(
              icon: Icons.download_done_outlined,
              title: 'Sin descargas',
              message:
                  'Explora YouTube y toca el botón Descargar en cualquier video.',
              actionLabel: 'Ir a Explorar',
              onAction: () => context.go(Routes.browser),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => DownloadTile(task: tasks[i]),
            ),
    );
  }
}

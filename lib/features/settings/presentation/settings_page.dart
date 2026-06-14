import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_snackbar.dart';
import '../../../core/permissions/permission_service.dart';
import '../../downloader/data/file_paths.dart';
import '../application/settings_notifier.dart';

final _storagePathProvider = FutureProvider<String>((ref) async {
  final dir = await FilePaths.videosDir();
  return dir.parent.path;
});

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final storagePath = ref.watch(_storagePathProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          const _SectionHeader('Descargas'),
          SwitchListTile(
            secondary: const Icon(Icons.audiotrack_outlined),
            title: const Text('Preferir audio'),
            subtitle: const Text('Seleccionar audio por defecto al descargar'),
            value: settings.preferAudio,
            onChanged: notifier.setPreferAudio,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Notificaciones de progreso'),
            value: settings.showNotifications,
            onChanged: notifier.setShowNotifications,
          ),
          const Divider(),
          const _SectionHeader('Almacenamiento'),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Carpeta de descargas'),
            subtitle: Text(
              storagePath.maybeWhen(
                data: (path) => path,
                orElse: () => 'Calculando…',
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Permisos'),
            subtitle: const Text('Notificaciones y acceso a multimedia'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final granted = await PermissionService.requestMedia();
              if (!context.mounted) return;
              granted
                  ? AppSnackbar.showSuccess(context, 'Permisos concedidos')
                  : AppSnackbar.showInfo(
                      context, 'Algunos permisos fueron denegados');
            },
          ),
          const Divider(),
          const _SectionHeader('Acerca de'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text(AppConstants.appName),
            subtitle: Text('Navegador + descargador de YouTube · v1.0.0'),
          ),
          const ListTile(
            leading: Icon(Icons.warning_amber_outlined),
            title: Text('Uso responsable'),
            subtitle: Text(
              'Descarga solo contenido permitido por los términos de YouTube '
              'y las leyes de derechos de autor de tu país.',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.brandRed,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

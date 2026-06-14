import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import 'failure.dart';

/// Consistent snackbars used across the app.
class AppSnackbar {
  AppSnackbar._();

  static void showError(BuildContext context, Object error) {
    final message = switch (error) {
      Failure() => error.message,
      _ => error.toString(),
    };
    _show(context, message, AppColors.brandRed, Icons.error_outline);
  }

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, const Color(0xFF2E7D32), Icons.check_circle_outline);
  }

  static void showInfo(BuildContext context, String message) {
    _show(context, message, AppColors.surfaceVariant, Icons.info_outline);
  }

  static void _show(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: color,
        ),
      );
  }
}

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Thumbnail from a local file (cached cover) or a network URL, with a
/// consistent placeholder/error fallback. Async — never blocks the UI thread.
class ThumbnailImage extends StatelessWidget {
  const ThumbnailImage({
    this.url,
    this.filePath,
    this.width,
    this.height,
    this.borderRadius = 8,
    super.key,
  });

  final String? url;
  final String? filePath;
  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final Widget image;
    if (filePath != null && filePath!.isNotEmpty) {
      image = Image.file(
        File(filePath!),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    } else if (url != null && url!.isNotEmpty) {
      image = CachedNetworkImage(
        imageUrl: url!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (_, __) => _box(),
        errorWidget: (_, __, ___) => _fallback(),
      );
    } else {
      image = _fallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: image,
    );
  }

  Widget _box() => Container(
        width: width,
        height: height,
        color: AppColors.surfaceVariant,
      );

  Widget _fallback() => Container(
        width: width,
        height: height,
        color: AppColors.surfaceVariant,
        child: const Icon(Icons.movie_outlined, color: AppColors.onSurfaceMuted),
      );
}

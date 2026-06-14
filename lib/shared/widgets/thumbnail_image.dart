import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Renders a thumbnail from a network URL or a local file path, with a
/// consistent placeholder/error fallback.
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
    if (filePath != null && filePath!.isNotEmpty && File(filePath!).existsSync()) {
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
        placeholder: (_, __) => _placeholder(),
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

  Widget _placeholder() => Container(
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

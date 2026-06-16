import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Network thumbnail with a consistent placeholder/error fallback. Async +
/// cached, so it never blocks the UI thread while lists scroll.
class ThumbnailImage extends StatelessWidget {
  const ThumbnailImage({
    this.url,
    this.width,
    this.height,
    this.borderRadius = 8,
    super.key,
  });

  final String? url;
  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final Widget image = (url != null && url!.isNotEmpty)
        ? CachedNetworkImage(
            imageUrl: url!,
            width: width,
            height: height,
            fit: BoxFit.cover,
            placeholder: (_, __) => _box(),
            errorWidget: (_, __, ___) => _fallback(),
          )
        : _fallback();

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

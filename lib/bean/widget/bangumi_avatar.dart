import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/utils/device.dart';
import 'package:kazumi/utils/image_extension.dart';

class BangumiAvatar extends StatelessWidget {
  const BangumiAvatar({super.key, required this.imageUrl, this.radius});

  final String imageUrl;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) return _fallback();
    final diameter = (radius ?? 20) * 2;
    final reducedEffects = prefersReducedEffects();

    return CachedNetworkImage(
      imageUrl: imageUrl,
      memCacheWidth: diameter.cacheSize(context),
      memCacheHeight: diameter.cacheSize(context),
      fadeInDuration:
          reducedEffects ? Duration.zero : const Duration(milliseconds: 120),
      fadeOutDuration:
          reducedEffects ? Duration.zero : const Duration(milliseconds: 120),
      filterQuality: reducedEffects ? FilterQuality.low : FilterQuality.medium,
      imageBuilder: (context, provider) => _avatar(provider),
      placeholder: (context, url) => _fallback(),
      errorWidget: (context, url, error) => _fallback(),
      errorListener: (error) {
        KazumiLogger().w('BangumiAvatar: image load failed', error: error);
      },
    );
  }

  Widget _avatar(ImageProvider<Object> provider) {
    return CircleAvatar(radius: radius, backgroundImage: provider);
  }

  Widget _fallback() {
    return CircleAvatar(
      radius: radius,
      backgroundImage: const AssetImage('assets/images/noface.jpeg'),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';
import '../theme_config.dart';

class BrandLogo extends StatelessWidget {
  final String asset;
  final double size;
  final BoxFit fit;

  const BrandLogo({
    super.key,
    required this.asset,
    this.size = 32,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (asset.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        asset,
        width: size,
        height: size,
        fit: fit,
        placeholderBuilder: (_) => Icon(Icons.restaurant_rounded, color: Colors.white, size: size * 0.6),
      );
    }
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: fit,
      errorBuilder: (_, __, ___) => Icon(Icons.restaurant_rounded, color: Colors.white, size: size * 0.6),
    );
  }
}

class PlanBadge extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const PlanBadge({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final config = AppThemeConfig.current;
    final badgeColor = _badgeColor(label);
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: badgeColor, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: BrandLogo(asset: config.logoAsset, size: 28),
        ),
        const SizedBox(width: 6),
        badge,
      ],
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: content,
      ),
    );
  }

  Color _badgeColor(String label) {
    switch (label.toLowerCase()) {
      case 'elite':
        return kSecondary;
      case 'pro':
        return kPrimary;
      case 'trial':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }
}

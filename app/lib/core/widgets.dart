import 'package:flutter/material.dart';
import 'constants.dart';
import 'app_localizations.dart';

class CpLogo extends StatelessWidget {
  final double size;
  final bool rounded;

  const CpLogo({super.key, this.size = 72, this.rounded = true});

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      logoAsset,
      width: size,
      height: size,
      fit: BoxFit.cover,
    );

    if (!rounded) return image;

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .22),
      child: image,
    );
  }
}

class CpBrand extends StatelessWidget {
  final double logoSize;
  final bool showVersion;

  const CpBrand({super.key, this.logoSize = 46, this.showVersion = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CpLogo(size: logoSize),
        const SizedBox(width: 11),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              appName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: .3,
              ),
            ),
            if (showVersion)
              const Text(
                'Professional Point of Sale',
                style: TextStyle(
                  fontSize: 11,
                  color: inkMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class CpGradientCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const CpGradientCard({super.key, required this.child, this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [red, darkRed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class CopyrightFooter extends StatelessWidget {
  const CopyrightFooter({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        Text(
          AppLocalizations.t(
            'Copyright © CP Colonel Pos',
            'Copyright © CP Colonel Pos',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          AppLocalizations.t(
            'Hak cipta dilindungi Undang-Undang',
            'All rights reserved',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    ),
  );
}

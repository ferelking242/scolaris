import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class PlaceholderPage extends StatelessWidget {
  final IconData icon;
  final String labelKey;
  const PlaceholderPage({super.key, required this.icon, required this.labelKey});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(labelKey.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 4),
          Text('dashboard.noData'.tr(),
              style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

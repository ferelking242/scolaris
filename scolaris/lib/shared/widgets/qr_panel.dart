import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../presentation/providers/auth_providers.dart';

/// A simple QR panel that doubles as scanner-launcher on mobile platforms.
class QrPanel extends ConsumerWidget {
  const QrPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider);
    final token = '${user?.role.name ?? 'student'}:${user?.email ?? ''}';
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.outlineVariant.withOpacity(.6)),
              ),
              child: QrImageView(
                data: token,
                size: 220,
                backgroundColor: Colors.white,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: cs.primary,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: cs.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('nav.qr'.tr(),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(token, style: TextStyle(color: cs.onSurfaceVariant)),
            if (!kIsWeb) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scan'),
                onPressed: () {},
              ),
            ],
          ],
        ),
      ),
    );
  }
}

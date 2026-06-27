// Impression Desktop/Mobile : on écrit le HTML dans un fichier temporaire puis
// on l'ouvre avec l'application par défaut (navigateur) — l'utilisateur lance
// l'impression depuis là. `dart:html` n'existe pas hors web.
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

void triggerPrint(String htmlContent) {
  _open(htmlContent);
}

Future<void> _open(String htmlContent) async {
  final dir = await getTemporaryDirectory();
  final file = File(
      '${dir.path}/scolaris_${DateTime.now().millisecondsSinceEpoch}.html');
  await file.writeAsString(htmlContent);
  final uri = Uri.file(file.path);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

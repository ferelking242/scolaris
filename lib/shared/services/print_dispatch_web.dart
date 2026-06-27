// Impression Web : ouvre le HTML dans un nouvel onglet et déclenche l'impression.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void triggerPrint(String htmlContent) {
  final blob = html.Blob([htmlContent], 'text/html');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final win = html.window.open(url, '_blank');
  if (win != null) {
    Future.delayed(const Duration(milliseconds: 800), () {
      (win as html.Window).print();
      html.Url.revokeObjectUrl(url);
    });
  }
}

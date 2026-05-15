import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'package:universal_html/html.dart' as html;

Future<void> downloadInvoiceFile(String content, String filename) async {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], 'text/plain');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

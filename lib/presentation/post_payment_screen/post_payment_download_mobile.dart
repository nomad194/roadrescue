import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<void> downloadInvoiceFile(String content, String filename) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$filename');
  await file.writeAsString(content);
}

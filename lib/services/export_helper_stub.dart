// Native (non-web) implementation: saves text/PNG files to the documents directory.
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<void> downloadTextWeb(
  String content,
  String filename,
  String mimeType,
) async {
  throw UnsupportedError('downloadTextWeb is only supported on web');
}

Future<void> downloadPngWeb(Uint8List bytes, String filename) async {
  throw UnsupportedError('downloadPngWeb is only supported on web');
}

Future<String> exportChatNative(Uint8List bytes, String filename) async {
  final directory = await getApplicationDocumentsDirectory();
  final imagePath = await File('${directory.path}/$filename').create();
  await imagePath.writeAsBytes(bytes);
  return imagePath.path;
}

Future<String> exportTextNative(String content, String filename) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = await File('${directory.path}/$filename').create();
  await file.writeAsString(content, flush: true);
  return file.path;
}

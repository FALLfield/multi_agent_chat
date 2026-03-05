// Web implementation: triggers a browser download of any text content.
// Also provides downloadPngWeb and exportChatNative as stubs (not used on web).
import 'dart:typed_data';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Downloads a UTF-8 text string as a file in the browser.
Future<void> downloadTextWeb(
  String content,
  String filename,
  String mimeType,
) async {
  final bytes = Uint8List.fromList(utf8.encode(content));
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..setAttribute('download', filename)
    ..style.display = 'none';
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url); // free memory
}

// PNG download kept for potential future use
Future<void> downloadPngWeb(Uint8List bytes, String filename) async {
  final base64 = base64Encode(bytes);
  final dataUrl = 'data:image/png;base64,$base64';
  final anchor = web.HTMLAnchorElement()
    ..href = dataUrl
    ..setAttribute('download', filename)
    ..style.display = 'none';
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
}

Future<String> exportChatNative(Uint8List bytes, String filename) async {
  throw UnsupportedError('exportChatNative is not supported on web');
}

Future<String> exportTextNative(String content, String filename) async {
  throw UnsupportedError('exportTextNative is not supported on web');
}

// Conditionally imports the web or stub implementation.
// On web: uses package:web to trigger a browser download.
// On other platforms: uses path_provider + dart:io to save to disk.
export 'export_helper_stub.dart'
    if (dart.library.html) 'export_helper_web.dart';

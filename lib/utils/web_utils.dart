// Conditional import: picks the web implementation on web builds,
// the stub on Android / iOS / desktop builds.
export 'web_utils_stub.dart'
    if (dart.library.html) 'web_utils_web.dart';

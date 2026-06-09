// Web implementation — uses dart:html.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

bool isStandalonePwa() {
  try {
    return html.window.matchMedia('(display-mode: standalone)').matches;
  } catch (_) {
    return false;
  }
}

String getBrowserUserAgent() {
  try {
    return html.window.navigator.userAgent.toLowerCase();
  } catch (_) {
    return '';
  }
}

void triggerApkDownload() {
  try {
    html.AnchorElement(href: '/habitforge.apk')
      ..setAttribute('download', 'HabitForge.apk')
      ..click();
  } catch (_) {}
}

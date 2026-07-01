import 'package:flutter/services.dart';
import 'fullscreen_stub.dart'
    if (dart.library.html) 'fullscreen_web.dart' as impl;

void toggleFullscreen(bool makeFullscreen) {
  if (makeFullscreen) {
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      impl.requestFullscreen();
    } catch (_) {}
  } else {
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      impl.exitFullscreen();
    } catch (_) {}
  }
}

bool isCurrentlyFullscreen() {
  try {
    return impl.isFullscreen();
  } catch (_) {
    return false;
  }
}

import 'fullscreen_stub.dart'
    if (dart.library.html) 'fullscreen_web.dart' as impl;

void toggleFullscreen(bool makeFullscreen) {
  if (makeFullscreen) {
    try {
      impl.requestFullscreen();
    } catch (_) {}
  } else {
    try {
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

import 'dart:html' as html;

void requestFullscreen() {
  html.document.documentElement?.requestFullscreen();
}

void exitFullscreen() {
  html.document.exitFullscreen();
}

bool isFullscreen() {
  return html.document.fullscreenElement != null;
}

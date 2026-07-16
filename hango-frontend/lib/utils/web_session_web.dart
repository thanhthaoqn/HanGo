import 'dart:html' as html;

bool isSessionActive() {
  final active = html.window.sessionStorage['hango.active'];
  return active == 'true';
}

void setSessionActive() {
  html.window.sessionStorage['hango.active'] = 'true';
}

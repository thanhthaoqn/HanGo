import 'dart:html' as html;

bool isSessionActive() {
  final href = html.window.location.href;
  if (href.contains('payment-success') || href.contains('payment-failed') || href.contains('txnRef')) {
    return true;
  }
  final active = html.window.sessionStorage['hango.active'];
  return active == 'true';
}

void setSessionActive() {
  html.window.sessionStorage['hango.active'] = 'true';
}

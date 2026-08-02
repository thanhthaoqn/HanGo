import 'dart:html' as html;

bool isSessionActive() {
  final href = html.window.location.href;
  if (href.contains('payment-success') ||
      href.contains('payment-failed') ||
      href.contains('paymentStatus') ||
      href.contains('orderCode') ||
      href.contains('status=PAID') ||
      href.contains('txnRef')) {
    return true;
  }
  final active = html.window.sessionStorage['hango.active'];
  return active == 'true';
}

void setSessionActive() {
  html.window.sessionStorage['hango.active'] = 'true';
}

void clearPaymentUrlFromAddressBar() {
  try {
    final location = html.window.location;
    if (location.href.contains('payment-success') ||
        location.href.contains('payment-failed') ||
        location.href.contains('paymentStatus') ||
        location.href.contains('orderCode') ||
        location.href.contains('status=PAID')) {
      html.window.history.replaceState(null, '', location.pathname);
    }
  } catch (_) {}
}

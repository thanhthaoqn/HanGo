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

// Unlike sessionStorage (cleared when the tab/browser closes), localStorage
// survives a full browser restart -- that's the whole point of "Remember me".
bool isRememberMeEnabled() {
  return html.window.localStorage['hango.remember'] == 'true';
}

void setRememberMe(bool value) {
  if (value) {
    html.window.localStorage['hango.remember'] = 'true';
  } else {
    html.window.localStorage.remove('hango.remember');
  }
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

void navigateToUrl(String url) {
  html.window.location.href = url;
}

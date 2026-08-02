import 'web_session_stub.dart'
    if (dart.library.html) 'web_session_web.dart' as impl;

bool isSessionActive() {
  try {
    return impl.isSessionActive();
  } catch (_) {
    return true; // Fallback to true if any issue
  }
}

void setSessionActive() {
  try {
    impl.setSessionActive();
  } catch (_) {}
}

void clearPaymentUrlFromAddressBar() {
  try {
    impl.clearPaymentUrlFromAddressBar();
  } catch (_) {}
}

class RegisterVerificationGuard {
  bool _checkInProgress = false;
  bool _completed = false;
  bool _closing = false;

  bool get isClosing => _closing;

  bool tryStartCheck() {
    if (_checkInProgress || _completed || _closing) return false;
    _checkInProgress = true;
    return true;
  }

  void finishCheck() {
    _checkInProgress = false;
  }

  bool tryComplete() {
    if (_completed || _closing) return false;
    _completed = true;
    return true;
  }

  bool tryClose() {
    if (_closing) return false;
    _closing = true;
    return true;
  }
}

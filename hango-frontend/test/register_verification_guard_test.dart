import 'package:flutter_test/flutter_test.dart';
import 'package:hango/utils/register_verification_guard.dart';

void main() {
  test('allows only one verification request at a time', () {
    final guard = RegisterVerificationGuard();

    expect(guard.tryStartCheck(), isTrue);
    expect(guard.tryStartCheck(), isFalse);

    guard.finishCheck();
    expect(guard.tryStartCheck(), isTrue);
  });

  test('blocks further checks after verification completes', () {
    final guard = RegisterVerificationGuard();

    expect(guard.tryStartCheck(), isTrue);
    expect(guard.tryComplete(), isTrue);
    guard.finishCheck();

    expect(guard.tryComplete(), isFalse);
    expect(guard.tryStartCheck(), isFalse);
  });

  test('allows the registration route to close only once', () {
    final guard = RegisterVerificationGuard();

    expect(guard.tryClose(), isTrue);
    expect(guard.tryClose(), isFalse);
    expect(guard.isClosing, isTrue);
    expect(guard.tryStartCheck(), isFalse);
  });
}

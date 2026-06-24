import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'services/app_state.dart';

/// Helper widget để kiểm tra AppState provider có tồn tại trong tree hay không.
class ProviderCheck extends StatelessWidget {
  const ProviderCheck({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // ignore: unnecessary_statements
    final _ = context.read<AppState>();
    return child;
  }
}

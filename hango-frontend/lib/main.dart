import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'presentation/pages/learner/learner_home_page.dart';
import 'services/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'HanGo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF28B79B)),
          useMaterial3: true,
        ),
        // ✨ ĐÃ SỬA: Dùng Consumer để kiểm tra trạng thái Booting trước khi vào App
        home: Consumer<AppState>(
          builder: (context, appState, child) {
            if (appState.isBooting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF28B79B),
                    ),
                  ),
                ),
              );
            }
            // Khi bộ nạp session đã chạy xong (isBooting = false), mới vẽ trang này
            return const LearnerHomePage();
          },
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'theme/theme_service.dart';
import 'screens/chat_screen.dart';
import 'services/chat_service.dart';

Future<void> main() async {
  // Required before accessing SharedPreferences or any other plugin.
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => ChatService()),
      ],
      child: const MultiAgentApp(),
    ),
  );
}

class MultiAgentApp extends StatelessWidget {
  const MultiAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          title: 'Multi-Agent Chat',
          debugShowCheckedModeBanner: false,
          theme: themeService.lightTheme,
          darkTheme: themeService.darkTheme,
          themeMode: themeService.themeMode,
          home: const ChatScreen(),
        );
      },
    );
  }
}

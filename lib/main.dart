import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/app_state.dart';
import 'data/friend_state.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GuanyueApp());
}

class GuanyueApp extends StatelessWidget {
  const GuanyueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..load()),
        ChangeNotifierProvider(create: (_) => FriendState()..load()),
      ],
      child: MaterialApp(
        title: '观阅轨迹',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const HomeScreen(),
      ),
    );
  }
}

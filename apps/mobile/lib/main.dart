import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/api_client.dart';
import 'data/settings_store.dart';
import 'features/chat/chat_controller.dart';
import 'ui/app_shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsStore();
  await settings.load();
  final api = ApiClient(settings);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        Provider.value(value: api),
        ChangeNotifierProvider(create: (_) => ChatController(api, settings)..bootstrap()),
      ],
      child: const ValeraBotApp(),
    ),
  );
}

class ValeraBotApp extends StatelessWidget {
  const ValeraBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Valera Bot',
      debugShowCheckedModeBanner: false,
      theme: buildValeraTheme(),
      home: const AppShell(),
    );
  }
}

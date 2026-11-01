import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:valera_bot/main.dart';
import 'package:valera_bot/data/settings_store.dart';
import 'package:valera_bot/data/api_client.dart';
import 'package:valera_bot/features/chat/chat_controller.dart';

void main() {
  testWidgets('Valera Bot app builds', (tester) async {
    final settings = SettingsStore();
    final api = ApiClient(settings);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          Provider.value(value: api),
          ChangeNotifierProvider(create: (_) => ChatController(api, settings)),
        ],
        child: const ValeraBotApp(),
      ),
    );
    expect(find.textContaining('Valera'), findsWidgets);
  });
}

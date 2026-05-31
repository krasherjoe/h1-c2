import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:h_1_core/main.dart';
import 'package:h_1_core/plugin_system/plugin_registry.dart';
import 'package:h_1_core/plugin_system/plugin_context.dart';
import 'package:h_1_core/services/database_helper.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    sqfliteFfiInit();
    SharedPreferences.setMockInitialValues({});
    DatabaseHelper.testDatabase = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

    final db = await DatabaseHelper().database;
    final prefs = await SharedPreferences.getInstance();
    PluginRegistry.instance.setContext(PluginContext(database: db, preferences: prefs));

    await tester.pumpWidget(H1CoreApp(registry: PluginRegistry.instance));
    await tester.pumpAndSettle();
    expect(find.text('販売アシスト1号 コア'), findsOneWidget);

    await DatabaseHelper.testDatabase!.close();
    DatabaseHelper.testDatabase = null;
  });
}

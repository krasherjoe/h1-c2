import 'package:flutter/material.dart';
import '../plugin_system/plugin_registry.dart';

class TabNavigator extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final String initialRoute;

  const TabNavigator({
    super.key,
    required this.navigatorKey,
    required this.initialRoute,
  });

  @override
  Widget build(BuildContext context) {
    final routes = PluginRegistry.instance.getAllRoutes();
    return Navigator(
      key: navigatorKey,
      initialRoute: initialRoute,
      onGenerateRoute: (settings) {
        final builder = routes[settings.name];
        if (builder != null) {
          return MaterialPageRoute(
            builder: (_) => builder(context),
            settings: settings,
          );
        }
        return null;
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(settings.name ?? '')),
            body: Center(
              child: Text('画面が見つかりません: ${settings.name}'),
            ),
          ),
          settings: settings,
        );
      },
    );
  }
}

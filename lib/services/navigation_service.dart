import 'package:flutter/widgets.dart';

class NavigationService {
  static final NavigationService instance = NavigationService._();
  NavigationService._();

  Future<T?> pushNamed<T>(BuildContext context, String route) async => null;
}

class EnvConfig {
  EnvConfig._();

  static String get googleClientId =>
      const String.fromEnvironment('GOOGLE_CLIENT_ID');

  static String get googleClientIdOrDefault =>
      googleClientId.isNotEmpty
          ? googleClientId
          : '';

  /// ビルド日付 (YYYYMMDD)。dart-define で注入、未設定の場合は空文字
  static String get appBuildDate =>
      const String.fromEnvironment('APP_BUILD_DATE');
}

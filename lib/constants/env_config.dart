class EnvConfig {
  EnvConfig._();

  static String get googleClientId =>
      const String.fromEnvironment('GOOGLE_CLIENT_ID');

  static String get mattermostBaseUrl =>
      const String.fromEnvironment('MATTERMOST_BASE_URL',
          defaultValue: 'https://mm.ka.sugeee.com');

  static String get mattermostTeamName =>
      const String.fromEnvironment('MATTERMOST_TEAM_NAME',
          defaultValue: 'cyb');

  static String get mattermostWebhookUrl =>
      const String.fromEnvironment('MATTERMOST_WEBHOOK_URL');

  static String get googleClientIdOrDefault =>
      googleClientId.isNotEmpty
          ? googleClientId
          : '468424259506-vmdhvaf5npk65a0r6kic9097h2i06kqt.apps.googleusercontent.com';
}

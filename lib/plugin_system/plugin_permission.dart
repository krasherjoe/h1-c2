enum PluginPermission {
  readDatabase('データベース読み取り'),
  writeDatabase('データベース書き込み'),
  accessLocation('位置情報アクセス'),
  sendEmail('メール送信'),
  accessContacts('連絡先アクセス'),
  useCamera('カメラ使用'),
  accessStorage('ストレージアクセス');

  const PluginPermission(this.label);
  final String label;
}

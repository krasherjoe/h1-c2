import '../../../models/customer_model.dart';

Map<String, String> buildDefaultKanaMap() {
  return {
    '安': 'あ', '阿': 'あ', '浅': 'あ', '麻': 'あ', '新': 'あ',
    '青': 'あ', '赤': 'あ', '秋': 'あ', '明': 'あ', '有': 'あ',
    '伊': 'あ', '加': 'か', '鎌': 'か', '上': 'か', '川': 'か',
    '河': 'か', '北': 'か', '木': 'か', '菊': 'か', '岸': 'か',
    '工': 'か', '古': 'か', '後': 'か', '郡': 'か', '熊': 'か',
    '桑': 'か', '黒': 'か', '香': 'か', '金': 'か', '兼': 'か',
    '小': 'か', '佐': 'さ', '齋': 'さ', '齊': 'さ', '斎': 'さ',
    '斉': 'さ', '崎': 'さ', '柴': 'さ', '沢': 'さ', '澤': 'さ',
    '桜': 'さ', '櫻': 'さ', '酒': 'さ', '坂': 'さ', '榊': 'さ',
    '札': 'さ', '庄': 'し', '城': 'し', '島': 'さ', '嶋': 'さ',
    '鈴': 'す', '田': 'た', '高': 'た', '竹': 'た', '滝': 'た',
    '瀧': 'た', '立': 'た', '達': 'た', '谷': 'た', '多': 'た',
    '千': 'た', '太': 'た', '中': 'な', '永': 'な', '長': 'な',
    '南': 'な', '難': 'な', '橋': 'は', '林': 'は', '原': 'は',
    '浜': 'は', '服': 'は', '福': 'は', '藤': 'は', '富': 'は',
    '保': 'は', '畠': 'は', '畑': 'は', '松': 'ま', '前': 'ま',
    '真': 'ま', '町': 'ま', '間': 'ま', '馬': 'ま', '山': 'や',
    '矢': 'や', '柳': 'や', '良': 'ら', '涼': 'ら', '竜': 'ら',
    '渡': 'わ', '和': 'わ', '石': 'い', '井': 'い', '飯': 'い',
    '五': 'い', '吉': 'よ', '与': 'よ', '森': 'も', '守': 'も',
    '岡': 'お', '奥': 'お', '尾': 'お', '白': 'し', '志': 'し',
    '広': 'ひ', '弘': 'ひ', '平': 'ひ', '日': 'ひ',
    '布': 'ぬ', '内': 'う', '宇': 'う', '浦': 'う', '野': 'の',
    '能': 'の', '宮': 'み', '三': 'み', '水': 'み', '溝': 'み',
  };
}

String kanaCharToGroup(String char) {
  final code = char.codeUnitAt(0);
  if (code >= 0x3041 && code <= 0x3096) {
    if (code <= 0x304a) return 'あ';
    if (code <= 0x3052) return 'か';
    if (code <= 0x305c) return 'さ';
    if (code <= 0x3069) return 'た';
    if (code <= 0x306e) return 'な';
    if (code <= 0x307d) return 'は';
    if (code <= 0x3082) return 'ま';
    if (code <= 0x3087) return 'や';
    if (code <= 0x308d) return 'ら';
    return 'わ';
  }
  if (code >= 0x30a1 && code <= 0x30f6) {
    if (code <= 0x30aa) return 'あ';
    if (code <= 0x30b2) return 'か';
    if (code <= 0x30bc) return 'さ';
    if (code <= 0x30c9) return 'た';
    if (code <= 0x30ce) return 'な';
    if (code <= 0x30dd) return 'は';
    if (code <= 0x30e2) return 'ま';
    if (code <= 0x30e7) return 'や';
    if (code <= 0x30ed) return 'ら';
    return 'わ';
  }
  return '英数';
}

String resolveKana(Customer c) {
  final kana = c.kana ?? '';
  if (kana.isNotEmpty) return kana[0];
  if (c.headChar1 != null && c.headChar1!.isNotEmpty) return c.headChar1!;
  return c.displayName[0];
}

String kanaFirstChar(Customer c) {
  final kana = (c.kana ?? c.headChar1 ?? c.displayName[0]);
  return kana[0];
}

bool customerInSubGroup(Customer c, String group, String? subChar) {
  final first = kanaFirstChar(c);
  if (subChar == null) return kanaCharToGroup(first) == group;
  return kanaCharToGroup(first) == group && first == subChar;
}

String normalizedName(String name, bool ignoreCorpPrefix) {
  var n = name.replaceAll(RegExp(r'\s+'), '');
  n = n.replaceAll(RegExp(r'[\s\u3000]*(様|御中|殿|先生)$'), '');
  if (ignoreCorpPrefix) {
    for (final token in [
      '株式会社', '（株）', '(株)', '有限会社', '（有）', '(有)',
      '合同会社', '（同）', '(同)',
    ]) {
      n = n.replaceAll(token, '');
    }
  }
  return n.toLowerCase();
}

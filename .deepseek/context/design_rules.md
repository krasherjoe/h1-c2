# デザインルール

## 視覚階層（3層構造）

```
壁紙（最背面）         ← surfaceContainerLowest  フラット、影なし
  └─ カード（中層）     ← surface + 影          立体感あり
       └─ 入力フォーム  ← Colors.white           フラット、純白
```

| 層 | カラーソース | 影 | 用途 |
|---|---|---|---|---|
| 壁紙 | `ColorScheme.surfaceContainerLowest` | なし | Scaffold 背景 |
| カード | `adjustSurfaceContrast(surface, surfaceContainerLowest)` で自動調整 | `cs.shadow` 二重シャドウ | メニュータイル、パネル、各ブロック |
| 入力フォーム | `Colors.white` | なし | TextField, TextFormField 内部 |

## カードの影（Elevation）

```dart
// 標準的なカードの影（二重シャドウで立体感）
BoxShadow(
  color: cs.shadow.withValues(alpha: 0.12),
  blurRadius: 8,
  offset: const Offset(0, 2),
),
BoxShadow(
  color: cs.shadow.withValues(alpha: 0.06),
  blurRadius: 16,
  offset: const Offset(0, 4),
),
```

```dart
// 浮いている要素（スライドつまみ、FAB）: 強めの影
BoxShadow(
  color: cs.shadow.withValues(alpha: 0.2),
  blurRadius: 8,
  offset: const Offset(0, 4),
),
```

**禁止**: `Colors.black` / `Colors.black26` / `Colors.black38` の直指定（ダークモードで不自然になる）。

## コントラスト（文字色）

`lib/utils/theme_utils.dart` の `textColorOn()` を使うこと。

```dart
// 背景色に対して最適な文字色を返す（WCAG AA 4.5:1 準拠）
final textColor = textColorOn(someBackgroundColor);
```

**返り値:**
- 明るい背景 → `0xFF1A1A2E`（濃いネイビー、純黒ではない）
- 暗い背景 → `0xFFF0F0F0`（薄いグレー、純白ではない）

純白・純黒は入力フォーム内部とヘッダー行のみで使用し、通常のテキストには使わない。

## カラースキーム（Material 3）

`main.dart` で `colorSchemeSeed: Colors.indigo` を設定。
各ウィジェットはハードコードされた色ではなく `Theme.of(context).colorScheme` から取得する。

### 用途マッピング

| ColorScheme プロパティ | 用途 |
|---|---|
| `surface` | カードの背景色 |
| `surfaceContainerLowest` | 壁紙（Scaffold 全体の背景） |
| `surfaceContainerLow` | セクションの薄い背景（ステータスバー等） |
| `primary` | アクセント色、アイコン色、強調ボタン |
| `onPrimary` | primary 上のテキスト色 |
| `primaryContainer` | CircleAvatar の背景、薄いアクセント |
| `secondary` | サブアクセント |
| `secondaryContainer` | ステータスバーの背景（alpha 0.3 と併用） |
| `onSurface` | 主要テキスト色 |
| `onSurfaceVariant` | 補足テキスト（ID・説明文） |
| `shadow` | カードの影色（withValues で alpha 調整） |
| `outlineVariant` | 区切り線、薄いボーダー |

### 直接使ってはいけない色

- `Colors.black` / `Colors.white`（`textColorOn` 経由以外）
- `Colors.black26` / `Colors.black38`（`cs.shadow` を使うこと）
- 固定のARGB色（`Color(0xFF...)`） — テーマのカスタムカラーとして定義する場合を除く

## ダークモード

`main.dart` で `themeMode: ThemeMode.system` を設定済み。
全ウィジェットが `Theme.of(context)` 経由で自動適応する。

### ダークモードでの振る舞い

| 層 | ライトモード | ダークモード |
|---|---|---|
| 壁紙 | `#E5E5E8`（ソフトグレー） | `#2C2C2E`（ミディアムグレー） |
| カード | `adjustSurfaceContrast(surface, #E5E5E8, minRatio:2.0)` | `adjustSurfaceContrast(surface, #2C2C2E, minRatio:2.0)` |
| 影 | 黒影（半透明） | `cs.shadow` で自動調整 |
| 入力フォーム | `Colors.white` | `Colors.white`（常に白） |

## textColorOn 関数詳細

`lib/utils/theme_utils.dart` に定義:

```dart
/// WCAG AA 基準のコントラスト比 (4.5:1) を計算。
double contrastRatio(Color a, Color b);

/// 背景色に対して最大コントラストの文字色を返す。
/// 純白/純黒ではなく、僅かに色味を帯びた色を使う（視覚的に自然）。
Color textColorOn(Color background);
```

### 使用例

```dart
import '../utils/theme_utils.dart';

// カスタム背景色のテキスト
Container(
  color: someCustomColor,
  child: Text('ラベル', style: TextStyle(color: textColorOn(someCustomColor))),
)
```

### WCAG AA コンプライアンス

- `textColorOn()` は常に 4.5:1 以上のコントラスト比を保証する
- `contrastRatio()` は WCAG 2.1 の相対輝度計算式に準拠
- 通常テキスト（<18px）は 4.5:1、大テキスト（>=18px bold / >=24px）は 3:1 が基準

## チェックリスト

- [ ] Scaffold の背景に `surfaceContainerLowest` を使っているか
- [ ] カードに `cs.shadow` の二重シャドウを適用しているか
- [ ] テキスト色に `textColorOn()` を使っているか（カスタム背景色の場合）
- [ ] `Colors.black` / `Colors.white` を直指定していないか
- [ ] `Colors.black26` / `Colors.black38` を直指定していないか（代わりに `cs.shadow`）
- [ ] ダークモードでの見た目を確認したか

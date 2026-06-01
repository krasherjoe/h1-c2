# デザインルール

## 視覚階層（3層構造）

```
壁紙（最背面）         ← #E5E5E8（ライト）/ #2C2C2E（ダーク）  影なし
  └─ カード（中層）     ← #F5F5F7（ライト）/ #3A3A3D（ダーク）  影あり
       └─ 入力フォーム  ← 設定で切替（立体/縁取り）
```

| 層 | ライト | ダーク | 影 |
|---|---|---|---|---|
| 壁紙 | `#E5E5E8`（ソフトグレー） | `#2C2C2E`（ミディアムグレー） | なし |
| カード | `#F5F5F7`（薄グレー） | `#3A3A3D`（明るめグレー） | 二重シャドウ |
| AppBar背景 | `cs.primary` | `cs.primary` | なし |
| AppBar文字/アイコン | `cs.onPrimary` | `cs.onPrimary` | - |

## カードの影（Elevation）

```dart
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
// 浮いている要素（スライドつまみ、FAB）
BoxShadow(
  color: cs.shadow.withValues(alpha: 0.2),
  blurRadius: 8,
  offset: const Offset(0, 4),
),
```

**禁止**: `Colors.black` / `Colors.black26` / `Colors.black38` の直指定。

## 入力フィールド

設定画面から切替可能:

| スタイル | 設定値 | 背景色 | 枠線 |
|---|---|---|---|
| 立体（デフォルト） | `raised` | `#EEEEF0`（ライト）/ `#3E3E42`（ダーク） | なし |
| 縁取り | `outlined` | `Colors.white` | `OutlineInputBorder()` |

テーマ中央制御: `main.dart` の `InputDecorationTheme` で全フィールド一律適用。
個別の `InputDecoration` で上書きしないこと。

## コントラスト（文字色）

`lib/utils/theme_utils.dart` の `textColorOn()` を使うこと。

```dart
final textColor = textColorOn(someBackgroundColor);
```

**返り値:**
- 明るい背景 → `0xFF1A1A2E`（濃いネイビー）
- 暗い背景 → `0xFFF0F0F0`（薄いグレー）

純白・純黒は入力フォーム内部とヘッダー行のみ。

## カラースキーム（Material 3）

`main.dart` で `ColorScheme.fromSeed(seedColor: Colors.indigo)` を基準に、
壁紙色のみ `copyWith(surfaceContainerLowest: ...)` で上書き。

### 用途マッピング

| プロパティ | 用途 |
|---|---|
| `primary` | AppBar背景、強調ボタン |
| `onPrimary` | AppBar上のテキスト/アイコン |
| `surface` | カード背景（固定色で上書き） |
| `surfaceContainerLowest` | 壁紙（固定色で上書き） |
| `primaryContainer` | CircleAvatar、薄いアクセント |
| `secondary` / `secondaryContainer` | サブアクセント、ステータスバー |
| `onSurface` | 主要テキスト色 |
| `onSurfaceVariant` | 補足テキスト（ID・説明文） |
| `shadow` | カード影色（`withValues` でalpha調整） |
| `outlineVariant` | 区切り線、薄いボーダー |

### 禁止

- `Colors.black` / `Colors.white`（`textColorOn` 経由以外）
- `Colors.black26` / `Colors.black38`（代わりに `cs.shadow`）
- 固定ARGB色（カスタムカラー定義以外）

## テーマ切替

`main.dart` の `themeMode` は SharedPreferences の `theme_mode` キーから読む。
設定画面の「テーマ」セグメントボタンで変更可能（即時反映）。

| 値 | 動作 |
|---|---|
| `system`（デフォルト） | 端末設定に連動 |
| `light` | 常にライトモード |
| `dark` | 常にダークモード |

## ダークモード

`themeMode: ThemeMode.system` がデフォルト。
全ウィジェットが `Theme.of(context)` 経由で自動適応。

## textColorOn 関数詳細

`lib/utils/theme_utils.dart`:

- `contrastRatio(Color a, Color b)` → WCAG 2.1 相対輝度計算
- `textColorOn(Color background)` → 4.5:1以上を保証
- `adjustSurfaceContrast(Color card, Color background, {minRatio})` → カードと背景の輝度差確保

## チェックリスト

- [ ] Scaffold の背景に `surfaceContainerLowest` を使っているか
- [ ] カードに `cs.shadow` の二重シャドウを適用しているか
- [ ] テキスト色に `textColorOn()` を使っているか
- [ ] `Colors.black` / `Colors.white` を直指定していないか
- [ ] 入力フィールドはテーマの `InputDecorationTheme` に従っているか
- [ ] ダークモードでの見た目を確認したか

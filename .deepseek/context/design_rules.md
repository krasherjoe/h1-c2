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

## 伝票カード（D1一覧）

- **左端4pxの縦バー**を伝票種別の色（`documentTypeColor`）で表示する
- 色はテーマ対応（`documentTypeColor()` 関数参照）
- 種別チップも同じ色に統一する
- 実装は `document_explorer_config.dart` の `buildItemTileContent()`

| 種別 | 色値（ライトモード） |
|------|-------------------|
| 見積 | `#29B6F6`（水色） |
| 受注 | `cs.secondary` |
| 納品 | `cs.tertiary` |
| 請求 | `cs.error` |
| 領収 | `#388E3C`（緑） |

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

## UX原則（Mobile-First）

1. **選択するだけ**: テキスト入力を避け、タップ/スワイプで操作完了させる
2. **キーボード排除**: フィルタ欄などは「任意」とし、デフォルトルートではキーボード不要
3. **コンテキスト保持**: 全画面遷移を避け、BottomSheet/インライン/ダイアログでUIを完結させる
4. **スマホ前提**: タップターゲットは最小44px、1アクション=1タップを理想とする
5. **即登録**: マスター不在時は簡易入力でその場で登録できるようにする（フル編集画面への遷移は避ける）

### Windows Explorerライクな操作性

| 操作 | エクスプローラー | 本アプリでの対応 |
|------|----------------|----------------|
| 選択 | クリックで選択 | **タップで選択・決定**（ダブルタップ不要） |
| リネーム | F2 / ゆっくりクリック | **タップでインライン編集可能** |
| 追加 | 右クリック→新規 | **「+」ボタン → BottomSheet で選択/簡易登録** |
| 削除 | Delete / 右クリック | **スワイプ削除 / X ボタン** |
| 検索 | Ctrl+F | **画面上部のフィルタ欄（任意入力）** |
| 並び替え | ヘッダークリック | **タップでソート切替** |

**基本思想**: 「知ってる人は直感的に使え、知らない人も迷わない」UIを目指す。複数ステップ必要な操作は「選択するだけ」で完結させる。

## チェックリスト

- [ ] Scaffold の背景に `surfaceContainerLowest` を使っているか
- [ ] カードに `cs.shadow` の二重シャドウを適用しているか
- [ ] テキスト色に `textColorOn()` を使っているか
- [ ] `Colors.black` / `Colors.white` を直指定していないか
- [ ] 入力フィールドはテーマの `InputDecorationTheme` に従っているか
- [ ] 伝票カード左端にdoctype色の縦バーを適用しているか
- [ ] ダークモードでの見た目を確認したか

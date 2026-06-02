# 画面ID規則

## 書式
```
XXn: 画面名
```
- XX = モジュール接頭辞（2文字）
- n = 連番（1から）
- 画面名は日本語

## モジュール一覧

| 接頭辞 | モジュール |
|--------|-----------|
| D | 伝票 (Documents) |
| P | 商品 (Products) |
| C | 顧客 (Customers) |
| PJ | 案件 (Project) |
| MN | 覚書 (Memorandum) |
| CI | 自社情報 (Company Info) |
| AD | システム設定 (Admin/Settings) |
| DB | デバッグ (Debug) |
| CM | 通信 (Communication) |

## 画面一覧

### D: 伝票
| ID | 画面 | ファイル |
|----|------|---------|
| D1 | 伝票一覧 | document_explorer_config.dart |
| DE | 伝票編集 | document_editor.dart |
| DV | 伝票詳細 | document_viewer.dart |
| DP | 伝票プレビュー | document_preview_page.dart |

### P: 商品
| ID | 画面 | ファイル |
|----|------|---------|
| P1 | 商品一覧 | product_explorer_config.dart |
| PE | 商品編集 | product_editor_screen.dart |

### C: 顧客
| ID | 画面 | ファイル |
|----|------|---------|
| C1 | 顧客一覧 | customer_explorer_config.dart |
| CE | 顧客編集 | customer_edit_screen.dart |

### PJ: 案件
| ID | 画面 | ファイル |
|----|------|---------|
| PJ1 | 案件一覧 | project_list_screen.dart |
| PJ2 | 案件詳細 | project_detail_screen.dart |

### MN: 覚書
| ID | 画面 | ファイル |
|----|------|---------|
| MN1 | 覚書一覧 | memorandum_list_screen.dart |
| MN2 | 覚書入力 | memorandum_input_screen.dart |
| MP | 覚書プレビュー | memorandum_preview_screen.dart |

### CI: 自社情報
| ID | 画面 | ファイル |
|----|------|---------|
| CI | 自社情報 | company_profile_screen.dart |

### AD: システム設定
| ID | 画面 | ファイル |
|----|------|---------|
| AD | システム設定 | settings_screen.dart |

### DB: デバッグ
| ID | 画面 | ファイル |
|----|------|---------|
| DB | デバッグ | debug_screen.dart |

### 購入 (Purchase)
| ID | 画面 | ファイル |
|----|------|---------|
| PU1 | 仕入一覧 | purchase_explorer_config.dart (?) |
| PUE | 仕入編集 | purchase_editor.dart |
| PUV | 仕入詳細 | purchase_viewer.dart |
| PUP | 仕入プレビュー | purchase_preview_page.dart |

## ルール
1. 新規画面追加時は必ず本ファイルにIDを登録する
2. AppBar の title は `'ID:画面名'` 形式にする
3. 同じモジュール内で連番が重複しないこと
4. 2画面しかないモジュールは n=1,2 ではなく英字2文字でOK（DE,PE,CEなど）

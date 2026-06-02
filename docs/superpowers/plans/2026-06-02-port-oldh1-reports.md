# Port oldh1 Reports to h1-core Implementation Plan

**Goal:** Port monthly report (FP1), AR/AP ledger (LR), and tax report (TX) from oldh1 to h1-core plugin architecture.

**Architecture:** Three new screens in existing plugins (analysis & ar), using direct SQL via DatabaseHelper, pdf/printing for PDF export, and h1-core's existing document/invoice/purchase tables.

**Tech Stack:** Flutter, sqflite, pdf, printing, intl

---

### Task 1: Monthly Report Screen (`lib/plugins/analysis/screens/monthly_report_screen.dart`)

**Files:**
- Create: `lib/plugins/analysis/screens/monthly_report_screen.dart`
- Modify: `lib/plugins/analysis/analysis_plugin.dart`

**SQL approach:**
- Sales: SUM(documents.total) WHERE status='confirmed' AND document_type IN ('invoice','receipt')
- Cost: SUM(products.wholesale_price * document_items.quantity) FROM document_items JOIN documents JOIN products
- Purchases: SUM(purchases.total) WHERE status NOT IN ('draft','cancelled')
- Gross Profit = Sales - Cost
- Profit = Gross Profit - Purchases (simplified)

### Task 2: Ledger Screen (`lib/plugins/ar/screens/ledger_screen.dart`)

**Files:**
- Create: `lib/plugins/ar/screens/ledger_screen.dart`
- Modify: `lib/plugins/ar/ar_plugin.dart`

**Two tabs:** 売掛台帳 / 買掛台帳
- AR: invoices query grouping by customer
- AP: purchases query grouping by supplier
- PDF export via pdf/printing

### Task 3: Tax Report Screen (`lib/plugins/ar/screens/tax_report_screen.dart`)

**Files:**
- Create: `lib/plugins/ar/screens/tax_report_screen.dart`
- Uses same plugin modification as Task 2

**Period-based tax calculation from invoices table.**

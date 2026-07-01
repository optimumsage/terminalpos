# TerminalPOS

A modern, cross-platform **thermal-printer POS invoicing app** built with Flutter.
Targets Android today and is architected so an iOS app can be added later with no rewrite.

## Features

### Invoices
- Home screen lists all invoices with search, status chips and live totals.
- **New Invoice** defaults its name to the current date & time.
- Pick a template, edit header/customer/line items, discounts, tax and notes.
- **Clone** any invoice (deep copy with a fresh id, name and timestamp).
- **Preview** the exact paper output (WYSIWYG) and **Print**.

### Templates & branding
- Preset templates (Classic, Minimal, Bold, Compact) as declarative section configs.
- Toggle & reorder sections (logo, business info, bill-to, items, totals, notes, footer, QR).
- Editable header/footer, font scale, alignment; per-business logo upload.

### Products & calculations
- Reusable product catalog **plus** ad-hoc free-form line items.
- Per-line and whole-invoice discounts (percentage or fixed).
- Configurable currency (default **PKR — `Rs.`**), amount separators, decimals.
- Optional tax (off by default), lightweight "Bill to" block.

### Printer settings
- **Interfaces:** Bluetooth (fully supported), USB, LAN/WiFi (`IP:port`).
- **Languages:** ESC/POS, ZPL, CPCL.
- Paper size 44 / 58 / 72 / 80 mm + custom (mm ↔ inches).
- Cut mode & spacing, feed after print, copies, density, beep.
- Auto-connect to last printer; open cash drawer after print.
- Print command: Auto, GS v 0, ESC * 33 (Epson), ESC/Star (Star Micronics).
- Dynamic fields: date/time formats, auto-increment invoice number (prefix + padding).
- Test print.

### Data & backup
- Local-first storage (Drift/SQLite) — fully offline.
- JSON backup/restore and CSV export (via app storage + clipboard).

## Architecture

- **Flutter + Material 3**, `flutter_riverpod` for state, `go_router` for navigation.
- **Drift/SQLite** document store; rich domain models own JSON (de)serialization.
- **WYSIWYG printing:** the invoice is rendered as a Flutter widget sized to the
  printable dot width, then captured to a bitmap. The *same* bitmap drives both the
  preview and the print job.
- Two clean abstractions make the interface × language matrix tractable:
  - `PrinterTransport` — Bluetooth / USB / LAN (sends raw bytes).
  - `CommandBuilder` — ESC/POS / ZPL / CPCL (bitmap → device bytes).
  - Adding iOS later = new transport implementations only.

```
lib/
  core/        enums, money & amount formatting, calculation engine, dynamic fields
  models/      Invoice, Product, InvoiceTemplate, AppSettings
  data/        Drift database, repositories, backup service
  print/       render (document + rasterizer), builders (escpos/zpl/cpcl), transports
  features/    invoices, products, templates, settings (+ printer/backup)
  widgets/     shared UI (cards, empty states)
```

## Getting started

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generate Drift code
flutter run                                                # on a device/emulator
```

Requires Flutter 3.44+. Real thermal printing must be validated on hardware; the
preview works everywhere.

## Tests

```bash
flutter analyze
flutter test        # calculation engine, currency formatting, ESC/POS/ZPL/CPCL byte output
```

## Releases / CI

- **CI** (`.github/workflows/ci.yml`) runs analyze + tests on every push/PR.
- **Release** (`.github/workflows/release.yml`) builds a release APK and publishes a
  GitHub Release whenever a `v*` tag is pushed:

```bash
git tag v0.1.0
git push origin v0.1.0
```

## License

MIT — see [LICENSE](LICENSE).

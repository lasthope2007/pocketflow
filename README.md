# PocketFlow

**Your money. Your flow.**

A Persian-first, offline-first personal finance app for Android. Record daily income, allocate it across percentage-based budgets, and track spending from virtual category wallets.

> Status: early Flutter foundation / MVP in progress.

## MVP roadmap

- [x] Flutter project manifest and app foundation
- [x] Persian RTL dashboard
- [x] Local SQLite storage foundation
- [x] Default categories and percentage allocation on income
- [x] Basic expense recording and overspend confirmation
- [ ] Category and percentage editor
- [ ] Manual weekly rollover review
- [ ] Searchable transaction history and date filters
- [ ] Reports, backup, and restore
- [ ] App lock and accessibility polish

## Tech stack

- Flutter and Dart
- Material 3
- SQLite via sqflite
- intl for formatting

## Getting started

Install Flutter, then run:

    flutter pub get
    flutter run

## Product rules

- Persian-first, RTL interface; Toman display.
- Store money as integer Toman values, never floating-point.
- Each income uses the category percentages active when it is recorded.
- Percentages below 100% leave the remainder unallocated; above 100% is invalid.
- Transfers between categories are not income or expenses.
- Budget rollover is manual; no money is silently erased or moved.

## Privacy

No account or remote service is required. Do not commit real financial data, database files, signing keys, or secrets.

## License

MIT

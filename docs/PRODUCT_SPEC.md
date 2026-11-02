# PocketFlow — Product Requirements

## Product summary
A lightweight Android finance companion for irregular daily income and flexible budget control.

## Main workflow
1. Record income with amount, date, source, and optional note.
2. Allocate income across enabled categories using current percentages.
3. Record expenses against a category wallet.
4. Review remaining balances and activity.
5. At period end, decide manually what happens to each remaining balance.

## Navigation
- Home: balance, income summary, category cards, recent activity.
- Budgets: categories, percentage editor, wallet details, transfers.
- Activity: income, expense, and transfer history with filters.
- Reports: income and expense summaries and category breakdown.
- Settings: currency, theme, week start, backup, and privacy.

## Financial definitions
- Income: money received from an external source.
- Allocation: internal assignment of income to budget categories.
- Expense: money spent from a category.
- Transfer: movement between categories; not income or expense.
- Unallocated balance: income not assigned to a category.
- Category balance: allocations plus incoming transfers minus expenses and outgoing transfers.

Store money as integer Toman values. Never use double for currency calculations.

## Allocation rules
- Categories have editable integer percentages.
- Percentages may total less than 100%; the remainder stays unallocated.
- Percentages above 100% must be rejected.
- Each income uses a snapshot of percentages at entry time.
- Integer rounding remainder stays unallocated.
- Editing percentages affects future income only.

## Periods and manual rollover
- Weekly is the default budget period.
- User reviews each category at period end.
- No balance is silently erased or rolled over.
- For each category, user can carry all, carry part, or return remainder to unallocated funds.
- A period remains open until its review is confirmed.

## Expense rules
- Expenses require category, amount, date, and optional note.
- If an expense exceeds available balance, show the shortfall and ask for confirmation.
- Editing or deleting a transaction must keep balances consistent.

## UX direction
Persian-first RTL, readable typography, friendly energetic tone, deep ink/navy surfaces with mint accent, Material 3, accessible contrast, and encouraging empty states.

## Privacy
Offline-first local persistence. No account or remote transmission of financial data by default. Provide explicit backup and restore for device migration.

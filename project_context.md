# Nomi --- Project Context & Continuation Guide

> **Purpose**
>
> This is the current working handoff document for the Nomi project.
> Upload it to a new AI chat, coding assistant, IDE agent, or local
> model to continue development with minimal explanation.
>
> **Instruction to any AI/tool:** Treat this document as the current
> implementation state. Repository code is authoritative where it
> differs from this document. Do not restart the architecture, redo
> completed Accounts/Categories/Transactions work, redesign the
> Dashboard, or change finalized accounting semantics without a concrete
> reason.

**Last updated:** 2026-09-11\
**Current milestone:** Budget Engine feature implementation is complete,
including opening-balance integration, live Dashboard values, and derived
price/unit-price history. Full manual Budget regression remains required.\
**Verified before Budget work:** Accounts, Categories, Transactions,
ledger accounting, transaction editing/deletion, account history, and
transaction search/filtering passed regression testing.

------------------------------------------------------------------------

# 1. Project Identity

**Application:** Nomi\
**Tagline:** **Give every kwacha a job.**

The original planning name was Nomi. The Flutter package is `nomi`. Some
older internal identifiers may still say `NomiApp`, and the SQLite
database filename remains `kopa`. Do not rename these blindly.

Nomi is a polished, local-first Android personal-finance and zero-based
budgeting application. V1 must work without a backend, login, cloud
account, remote database, or internet connection.

------------------------------------------------------------------------

# 2. Technology Stack

-   Flutter / Dart
-   Android-first; development tested on a physical Android phone
-   Riverpod `^3.3.2`
-   Drift `^2.31.0`
-   `drift_flutter ^0.2.8`
-   `path_provider ^2.1.5`
-   `build_runner ^2.9.0`
-   `drift_dev ^2.31.0`
-   SQLite database filename remains `kopa`

Architecture:

``` text
Presentation / UI
        ↓
Riverpod application/state
        ↓
Services / business logic
        ↓
Repository interfaces
        ↓
Repository implementations
        ↓
Drift
        ↓
SQLite
```

Rules:

-   No SQL in widgets.
-   No financial/business calculations in widgets.
-   Repository interfaces expose domain models, not Drift-generated
    types.
-   Use service classes for real business logic.
-   Keep calculations deterministic and testable.
-   Keep repository implementations below abstractions.
-   V1 remains local-first.
-   Never manually edit `app_database.g.dart`.

------------------------------------------------------------------------

# 3. Money and Quantity

## Money

All money is integer minor units/ngwee. Never persist money as floating
point/SQLite REAL.

Examples:

``` text
K1.00      = 100
K10.00     = 1,000
K250.00    = 25,000
K14,850.00 = 1,485,000
```

Shared utility:

``` text
lib/core/utils/money.dart
```

Important operations include deterministic parsing and formatting such
as:

``` text
Money.tryParseToMinorUnits(...)
Money.formatMinorUnits(...)
Money.formatZmw(...)
```

Do not reintroduce `double.parse(...)*100`.

## Quantity

Item quantities use integer scale x1000.

``` text
1      = 1000
1.5    = 1500
0.25   = 250
```

Shared utility:

``` text
lib/core/utils/quantity.dart
```

Conceptually:

``` dart
class Quantity {
  static const int scale = 1000;
  static int toStored(num value);
  static double fromStored(int value);
  static String format(int value);
}
```

This allows item/unit-price calculations without storing floating-point
financial values.

------------------------------------------------------------------------

# 4. Ledger Semantics --- FINALIZED

The transaction ledger is authoritative financial history.

`Accounts.currentBalance` is a cached/materialized balance for fast UI
reads. Ledger mutations and cached balance changes must be atomic.

Conceptually:

``` text
currentBalance = openingBalance + net ledger effects
```

Negative account balances are allowed.

Transaction types:

``` text
Income
Expense
Transfer
```

Amounts are positive integers. Direction is determined by the service.

## Income

``` text
account += amount - fee
```

## Expense

``` text
account -= amount + fee
```

## Transfer

One logical transaction row:

``` text
source      -= amount + fee
destination += amount
```

Transfer principal is neither expense nor income. Only the fee reduces
wealth.

## Fees

-   Stored separately from transaction amount.
-   Never fold fees into principal.
-   Historical fee values remain preserved.
-   Budget fees are posted to the dedicated Expense category
    `expense.fees_charges`.

## Editing transactions

Transaction type is immutable in V1.

Editing:

1.  Reverse old financial effect.
2.  Apply new financial effect.
3.  Update transaction row.
4.  Perform atomically.

## Deleting transactions

Soft deletion:

1.  Reverse financial effect.
2.  Set `isDeleted = true`.
3.  Preserve transaction/history identifiers.
4.  Perform atomically.

------------------------------------------------------------------------

# 5. Accounts --- COMPLETE

Accounts support:

-   Persistent add/list/edit
-   Bank / Mobile Money / Cash / Other grouping
-   Provider selection
-   Opening/current balances
-   Integer money semantics
-   Live active-account total
-   Account Detail
-   Soft deactivation
-   Dashboard Total Money
-   Live account transaction history
-   Correct opening-balance editing under ledger semantics

Current account repository behavior when opening balance changes:

``` text
difference = newOpeningBalance - oldOpeningBalance
currentBalance += difference
```

Once Budget has been initialized, the same opening-balance difference
also updates Budget `initialAssignableAmount`. `AccountBudgetService`
coordinates the account repository and Budget repository inside one
shared Drift transaction. If Budget is uninitialized, only the account
changes. A zero difference never touches Budget settings. No fake ledger
transaction is created, and `AccountRepository` remains independent of
`BudgetRepository`.

------------------------------------------------------------------------

# 6. Categories --- COMPLETE

Final rules:

-   Separate `CategoryGroups` and `Categories`.
-   Expense and Income use shared hierarchy infrastructure.
-   Transfers have no category.
-   Soft deactivation.
-   Historical references survive deactivation.
-   Uncategorized transactions allowed.
-   Explicit persisted `sortOrder`.
-   Group names unique within type.
-   Category names unique within group.
-   Case-insensitive trimmed uniqueness.
-   Same category name allowed in different groups.
-   Stable `systemKey` for seeded defaults.
-   Seeded defaults may be renamed/reordered/deactivated while retaining
    identity.
-   Deactivating a group deactivates active children transactionally.
-   Moving a category appends it to destination group.
-   Idempotent default seeding.

Category regression passed before Budget work.

## Fees & Charges system keys

There was an important Budget bug caused by an ambiguous Fees & Charges
key.

Income already has a Fees & Charges category. Budget fees must NOT
resolve to it.

Canonical separation:

``` text
Income
└── Fees & Charges
    systemKey: income.fees_charges

Financial (Expense)
└── Fees & Charges
    systemKey: expense.fees_charges
```

Budget fee invariant:

``` text
transaction.fee
→ budget spending
→ expense.fees_charges
```

Do not use ambiguous `fees_charges`.

A clean reinstall was performed after this correction and the Budget
screen loaded correctly.

------------------------------------------------------------------------

# 7. Transactions --- COMPLETE CORE + ITEMIZATION EXTENDED

Core Transactions previously passed regression:

-   Income
-   Expense
-   Transfer
-   Separate fees
-   Atomic balance updates
-   Edit reverse-old/apply-new
-   Soft delete/reversal
-   Global transaction list
-   Account history
-   Search/filtering
-   Type/account/category/date filters

## Transaction itemization

Budget work extended Expenses with line items.

`TransactionLineItem` conceptually contains:

``` text
id
transactionId
categoryId
itemDefinitionId nullable
monthlyPlannedItemId nullable
nameSnapshot
quantity nullable (scaled x1000)
unitSnapshot nullable
amount (minor units)
createdAt
updatedAt
```

Rules:

-   Only Expense transactions may have line items.
-   Parent Expense amount remains the account-impact principal.
-   Line items are descriptive/category allocations and never directly
    change account balances.
-   If an Expense has no line items, parent `categoryId` is
    authoritative.
-   If an Expense has one or more line items, line-item categories are
    authoritative for Budget spending.
-   Sum of line-item amounts must equal parent transaction `amount`.
-   Fee is excluded from line-item total.
-   Each line amount \> 0.
-   Optional quantity \> 0.
-   Line category must be an Expense category.
-   An actual line can link to a `MonthlyPlannedItem`.
-   Child line items remain stored if parent transaction is
    soft-deleted; the parent deletion controls whether they are
    active/visible in calculations.

`TransactionLineItemRepository` supports, among other methods:

``` text
watchLineItemsForTransaction(transactionId)
getLineItemsForTransaction(transactionId)
getLineItemsForTransactions(transactionIds)
getLineItemsForPlannedItem(monthlyPlannedItemId)
getLineItemsForItemDefinition(itemDefinitionId)
create/update/delete line item
deleteLineItemsForTransaction(transactionId)
```

## TransactionService line-item semantics

Creation of Expense accepts line-item inputs.

Update accepts:

``` text
lineItems == null   → leave existing line items unchanged
lineItems == []     → remove all line items
lineItems non-empty → replace all line items
```

Itemized Expense save uses parent:

``` text
categoryId = null
```

because child line categories become authoritative.

## Delete semantics for itemized expense

Example:

``` text
Expense principal K300
Fee K5
Sugar K120
Soap K80
Vegetables K100
```

Account effect at creation:

``` text
-K305
```

Delete restores:

``` text
+K305
```

Do NOT reverse line amounts independently.

------------------------------------------------------------------------

# 8. Transaction Itemization UI --- IMPLEMENTED

## Add Transaction

Expense creation supports an `Itemize expense` mode.

Each line can contain:

-   Item name
-   Expense category
-   Quantity
-   Unit
-   Amount
-   Optional linked monthly planned item

When a planned item is selected, both:

``` text
monthlyPlannedItemId
itemDefinitionId
```

are preserved where available.

Changing a line category/group clears incompatible
planned/item-definition links.

Changing transaction month clears the monthly planned-item link because
a monthly plan belongs to a specific Budget month.

## Edit Transaction

Edit Expense now loads existing line items.

It supports:

-   Existing itemized Expense → edit itemization
-   Itemized → ordinary Expense by turning itemization off
-   Ordinary → itemized
-   Exact line total validation
-   Planned-item linking
-   Preserving item definition and planned-item IDs

Income/Transfer behavior remains unchanged.

## Transaction Detail

Transaction Detail now displays itemized Expenses.

Example:

``` text
TOTAL SPENT
-K305.00

Type              Expense
Account           Cash
Category          Itemized expense
Purchase          K300.00
Fee               K5.00
Account impact    K305.00

ITEMS

Sugar
Groceries • 2 kg
Linked to budget plan             K120.00

Soap
Household • 1 pack                 K80.00

Vegetables
Groceries                          K100.00

Items total                        K300.00
```

Top Expense amount remains `amount + fee`.

Existing Edit and Delete semantics were preserved.

------------------------------------------------------------------------

# 9. Budget Engine --- SEMANTICS FINALIZED

Nomi uses true zero-based/envelope budgeting. Only money actually owned
can be assigned. Do not budget speculative future income.

Mental model:

``` text
ACCOUNTS
Where is my money?

BUDGET
What is my money supposed to do?

TRANSACTIONS
What actually happened to my money?
```

## Category equation

``` text
Starting Available
+ Assigned
- Spent
= Ending Available
```

Unused category money rolls forward.

``` text
Starting Available(month N)
= Ending Available(month N-1)
```

Overspending is allowed and negative category availability rolls
forward.

## Assigned

Assigned is a deliberate monthly allocation.

-   It does not change account balances.
-   It can be changed/reassigned.
-   Negative assignments are internally valid where needed.
-   It is conceptually separate from item planning.

Planned items and category allocations remain distinct concepts.

However, after adding or editing a planned item, if the resulting total
known planned-item cost exceeds `Starting Available + Assigned`, Nomi
prompts the user to optionally increase Assigned by the exact funding
shortfall.

The allocation increase is never automatic.

If the user accepts, Assigned increases exactly enough for:

``` text
Starting Available + Assigned = known planned-item total
```

If the user declines, the planned-item change is still saved, Assigned
remains unchanged, and the funding-gap warning remains visible.

Allocations are never automatically reduced when planned items are
deleted, reduced in price, or become unpriced.

Actual spending does not participate in this comparison because planning
capacity is `Starting Available + Assigned`, not current Available.

## Spent

Ordinary Expense:

``` text
no line items → parent Expense category receives principal spending
```

Itemized Expense:

``` text
one or more line items → line-item categories receive principal spending
```

Fees always go to Expense `expense.fees_charges`.

## Transfers

Transfer principal has no Budget effect.

Transfer fee is spending in `expense.fees_charges`.

## Income and income fees

Example:

``` text
Income principal K5,000
Fee K20
```

Ledger:

``` text
+K4,980
```

Budget:

``` text
gross eligible income adds K5,000 to assignable money
fee adds K20 spending to expense.fees_charges
```

Do NOT add only net income and then also spend the fee.

Invariant:

``` text
gross income - fee spending = net wealth increase
```

## Historical recalculation

Budget totals are derived dynamically from ledger + allocations.
Backdated transaction edits/deletes must recalculate relevant
historical/current Budget results rather than relying on persisted
derived totals.

Inactive categories may still appear historically when they have
activity or a non-zero balance.

------------------------------------------------------------------------

# 10. Budget Persistence / Schema v4

Budget and item-level planning introduced additive schema version 4.

New tables:

``` text
BudgetSettings
BudgetMonths
BudgetAllocations
ItemDefinitions
MonthlyPlannedItems
TransactionLineItems
```

Earlier tables remain:

``` text
Accounts
CategoryGroups
Categories
Transactions
```

## BudgetSettings

Persist:

``` text
budgetStartDate
initialAssignableAmount
createdAt
updatedAt
```

Singleton.

`budgetStartDate` is an exact timestamp, not merely a month, to prevent
double-counting transactions occurring before initialization during the
same calendar month.

## BudgetMonths

``` text
id
year
month
createdAt
updatedAt
```

Unique `(year, month)`.

## BudgetAllocations

``` text
id
budgetMonthId
categoryId
assignedAmount
createdAt
updatedAt
```

Unique `(budgetMonthId, categoryId)`.

## ItemDefinitions

Reusable item identity/default metadata.

Conceptually:

``` text
id
name
defaultCategoryId nullable
defaultUnit nullable
isActive
createdAt
updatedAt
```

## MonthlyPlannedItems

``` text
id
budgetMonthId
categoryId
itemDefinitionId nullable
nameSnapshot
plannedQuantity nullable (x1000)
unitSnapshot nullable
plannedAmount nullable
isCompleted
sortOrder
note nullable
createdAt
updatedAt
```

`plannedAmount == null` means price unknown. Never use zero to represent
unknown price.

## TransactionLineItems

See Transaction section above.

------------------------------------------------------------------------

# 11. BudgetRepository --- CURRENT CONTRACT

Important capabilities include:

``` text
getBudgetSettings()
initializeBudget(budgetStartDate, initialAssignableAmount)
updateInitialAssignableAmount(delta)

getBudgetMonth(year, month)
getOrCreateBudgetMonth(year, month)

watchAllocationsForMonth(budgetMonthId)
getAllocationsForMonth(budgetMonthId)
getAllocation(budgetMonthId, categoryId)
setAllocation(budgetMonthId, categoryId, assignedAmount)
removeAllocation(budgetMonthId, categoryId)

sumAssignmentsThroughMonth(year, month)
sumAssignmentsBeforeMonth(year, month)

watchPlannedItemsForMonth(budgetMonthId)
watchPlannedItemsForCategory(budgetMonthId, categoryId)
getPlannedItemsForCategory(budgetMonthId, categoryId)
getPlannedItem(id)
createPlannedItem(...)
updatePlannedItem(...)
deletePlannedItem(id)
reorderPlannedItems(...)
```

------------------------------------------------------------------------

# 12. BudgetService --- CURRENT BEHAVIOR

Dependencies:

``` text
BudgetRepository
CategoryRepository
TransactionRepository
TransactionLineItemRepository
```

Fee category constant must resolve:

``` text
expense.fees_charges
```

`buildMonth(...)` conceptually:

1.  Validate Budget settings/month.
2.  Ensure required defaults exist.
3.  Resolve Expense Fees & Charges category.
4.  Load eligible transactions from exact Budget start through selected
    month.
5.  Batch-load Expense transaction line items.
6.  Load allocations/current and prior allocations.
7.  Income principal → gross eligible income.
8.  Income fee → Fees & Charges spending.
9.  Transfer principal → ignored.
10. Transfer fee → Fees & Charges spending.
11. Expense principal → line categories when itemized; otherwise parent
    category.
12. Validate itemized line sum.
13. Handle Uncategorized where necessary.
14. Include inactive historical categories when they have activity.
15. Derive monthly/cumulative Budget totals.

Category cumulative availability:

``` text
EndingAvailable = cumulative assigned - cumulative spent
StartingAvailable = prior cumulative assigned - prior cumulative spent
```

Left/Available To Assign:

``` text
initialAssignableAmount
+ gross eligible income
- cumulative assignments
```

Fees do not directly subtract from Left To Assign; they affect category
availability/spending.

------------------------------------------------------------------------

# 13. Budget Initialization --- IMPLEMENTED

First Budget initialization:

``` text
initialAssignableAmount = sum(active account.currentBalance)
budgetStartDate = exact DateTime.now()
create/get current BudgetMonth
```

Transactions before exact `budgetStartDate` are not replayed into the
new Budget because their financial effect is already represented by the
starting cash snapshot.

This is why later opening-balance edits require explicit integration
with `initialAssignableAmount`.

------------------------------------------------------------------------

# 14. Budget UI --- IMPLEMENTED

The Budget tab is live.

It supports:

-   Budget initialization
-   Month navigation
-   Left/Available To Assign
-   Assigned / Spent / Available summary
-   Category groups
-   Category rows
-   Editing monthly Assigned amount
-   Category navigation to item planning
-   Live Budget calculations from ledger

Category rows retain the chevron/navigation affordance. Tapping the
category name/arrow opens item planning. Tapping Assigned opens
allocation editing.

**Do not regress this behavior.**

------------------------------------------------------------------------

# 15. Item-Level Budget Planning --- IMPLEMENTED

Category detail supports:

-   Envelope summary
-   Starting / Assigned / Spent / Available
-   Add planned item
-   Edit planned item
-   Delete planned item
-   Manual completion checkbox
-   Quantity
-   Unit
-   Planned amount
-   Unknown price
-   Note
-   Known planned total
-   Unplanned balance / funding gap
-   Unpriced item count
-   Warning when plan exceeds category funding
-   Explicit add/edit confirmation to optionally fund an item-plan
    shortfall

Important semantic decision:

``` text
Item plan ≠ category allocation
```

After validated add/edit input, known planned cost is recalculated with
the proposed value replacing the edited item's old value. Null prices do
not contribute. Funding is `Starting Available + Assigned`; spending is
excluded.

If the plan exceeds funding, the user chooses either **Keep current
allocation** or **Increase allocation**. Keeping saves the item without
changing Assigned. Increasing saves the item and raises Assigned by the
exact shortfall in one coordinated transaction. Delete, completion,
price reductions, and known-to-unknown changes never lower Assigned.

The calculation is implemented by `PlannedItemFundingCalculator`; the
Riverpod `PlannedItemController` performs assessment and coordinates the
planned-item mutation with the existing allocation controller. The
category detail screen watches the monthly Budget summary so accepted
allocation increases refresh its envelope and funding-gap display.

------------------------------------------------------------------------

# 16. Planned-vs-Actual Item Fulfillment --- IMPLEMENTED

A dedicated provider loads actual linked line items for a planned item
using:

``` text
TransactionLineItemRepository.getLineItemsForPlannedItem(...)
```

The Budget category detail now shows actual fulfillment.

Example:

``` text
Sugar
5 kg • K300.00

In progress

Actual spent       K124.00
Planned            K300.00
Under plan         K176.00

Quantity           2 / 5 kg
40% of planned quantity

1 linked purchase
```

Multiple actual purchases can fulfill one planned item.

Money variance does NOT determine completion.

Quantity completion is derived only when actual quantities use
comparable units. If units/quantities are incompatible or missing, Nomi
shows monetary actuals/variance but does not pretend quantities are
comparable.

Manual completion remains available for plans where quantity is not
meaningful.

------------------------------------------------------------------------

# 17. Important UI Lifecycle Bug --- RESOLVED

Symptom:

``` text
A TextEditingController was used after being disposed.
Once you have called dispose() on a TextEditingController,
it can no longer be used.
```

Observed after successful saves in:

-   Category Budget Assigned amount dialog
-   Planned Budget item dialog

Data saved correctly, then the UI crashed during dialog teardown.

Cause:

Controllers were created outside the dialog and manually disposed
immediately after `showDialog()` returned, while Flutter could still be
finishing dialog dismissal/rebuild animation.

Fix:

Both dialogs were changed to proper stateful dialog widgets that own
their controllers and dispose them from the dialog State's `dispose()`
lifecycle.

Do not revert to:

``` text
create controller outside dialog
await showDialog(...)
controller.dispose()
```

for these dialogs.

------------------------------------------------------------------------

# 18. Dashboard --- BUDGET INTEGRATION IMPLEMENTED

The Dashboard design is established and liked. **Do not redesign it.**

Live:

``` text
Total Money = sum(active account.currentBalance)
```

The established Dashboard design now renders live current-calendar-month
Budget values:

-   Available = total category Ending Available
-   Left to assign = Budget Engine `leftToAssign`
-   Income = current-month gross income
-   Spent = current-month Expense principal excluding separately shown fees
-   Fees = current-month fees
-   Remaining = gross income minus all current-month spending
-   Budget rows = up to three active category rows using planning capacity,
    spending, and Ending Available

`principalSpent`, `remainingThisMonth`, and category `planningCapacity`
are domain getters. The widget renders those results rather than
duplicating Budget calculations. Loading, calculation failure,
uninitialized Budget, and initialized/no-activity states are explicit.
Total Money remains the live active-account balance total.

------------------------------------------------------------------------

# 19. CURRENT WORK --- START HERE IN A NEW SESSION

Latest confirmed milestone:

> **Budget Engine core semantics, persistence, monthly allocations, live
> Budget screen, item planning, Expense itemization, Transaction Detail
> itemization, planned-vs-actual fulfillment, and user-confirmed
> planned-item shortfall funding are implemented. Opening-balance Budget
> coordination, Dashboard Budget integration, and item price history are
> also implemented.**

The user has tested the current app after a clean reinstall and reported
that the Budget experience is working and looks good.

Do not restart setup.\
Do not redo Riverpod/Drift selection.\
Do not redo Accounts.\
Do not redo Categories.\
Do not redo Transactions.\
Do not redo Budget semantics.\
Do not redesign the Dashboard.\
Do not automatically fund or reduce category allocations from planned-item
totals; only the explicit add/edit confirmation may increase Assigned.\
Do not start SMS/mobile-money automation yet.

## Exact next task --- Full manual Budget regression

The remaining work is verification rather than new Budget feature
implementation. Run the checklist in section 21 on a clean physical-phone
installation, report any analyzer/compiler/runtime/test failures, and fix
only concrete regressions. Do not mark the entire Budgeting phase complete
until that regression passes.

------------------------------------------------------------------------

# 20. Price / Unit-Price History --- IMPLEMENTED

Actual line items contain enough data to derive purchase history without
storing floating-point prices.

Desired concept:

``` text
Sugar

03 Sep   2 kg   K124   K62/kg
11 Sep   3 kg   K192   K64/kg

Latest unit price     K64/kg
Previous              K62/kg
Change                +3.2%
```

Use integer money + scaled quantity. Do not persist a floating-point
unit price.

History is derived from actual `TransactionLineItems` joined to active
parent transactions for `occurredAt` and payee. Soft-deleted parent
transactions are excluded without deleting child rows.

The repository already has:

``` text
getLineItemsForItemDefinition(itemDefinitionId)
getLineItemsForPlannedItem(monthlyPlannedItemId)
```

`ItemPriceHistoryService` uses reusable `itemDefinitionId` for cross-month
history when available. Current ad-hoc planned items commonly have no stable
definition, so the conservative fallback includes only transaction lines
directly linked to that monthly planned item. It never globally matches item
names.

`ItemPurchaseHistoryEntry` derives rounded minor-units-per-whole-unit using
integer arithmetic and normalized trimmed/lowercase units. The newest and
previous prices are compared only when units match. Percentage change is
stored transiently as integer basis points; neither unit prices nor trends
are persisted.

Each planned-item card has a compact Price history affordance opening a
dialog with newest-first purchases, dates, payees, quantities, amounts,
unit prices where derivable, and latest/previous/change summary. Missing
quantity or unit remains visible as purchase history but does not produce a
unit price.

------------------------------------------------------------------------

# 21. Full Budget Regression --- REQUIRED BEFORE COMPLETION

Run this on a physical phone from a clean application/database state. Record
the observed amounts at each stage so later edits and reversals can be
verified exactly.

## A. Accounts and Budget initialization

1. Create Bank, Mobile Money, and Cash accounts with known opening balances.
2. Verify Total Money equals the active-account sum.
3. Edit an opening balance before Budget initialization; verify opening and
   current balance change by the same difference and no error occurs.
4. Initialize Budget; verify initial Left To Assign equals current active
   account money and pre-initialization transactions are not replayed.
5. Edit an opening balance upward after initialization; verify account
   current balance and Budget Left To Assign both rise by the exact difference.
6. Edit it downward and then to zero; verify both fall exactly once while
   existing transaction effects remain preserved.
7. Edit account metadata without changing opening balance; verify Budget
   values do not change.
8. Relaunch and verify account and Budget snapshot persistence.

## B. Allocations, rollover, and item planning

9. Assign and reassign several Expense categories; verify Left To Assign and
   category equations.
10. Navigate previous/current/next months and verify no read creates visible
    allocations.
11. Leave category money unused and verify it becomes next month Starting
    Available.
12. Overspend a category and verify negative availability rolls forward.
13. Add known planned items within `Starting Available + Assigned`; verify no
    funding confirmation.
14. Add/edit beyond funding; verify the dialog's planned total, funding, and
    exact shortfall.
15. Keep current allocation; verify item saves, Assigned stays unchanged, and
    the funding-gap warning remains.
16. Perform another underfunded add/edit and accept; verify Assigned increases
    only by the full current shortfall and the detail UI refreshes.
17. Verify rollover funds the plan without unnecessary assignment.
18. Record spending and edit an already-funded plan without increasing its
    total; verify spending does not cause duplicate funding.
19. Test price increase/decrease, unchanged price, unknown→known, and
    known→unknown edits; verify replacement rather than double-counting.
20. Delete and toggle completion; verify Assigned never decreases or changes.

## C. Ledger and Budget calculations

21. Add an ordinary Expense; verify its parent category receives principal
    spending and the account loses principal plus fee.
22. Add a fully itemized Expense across categories; verify child categories
    receive spending, parent principal is not double-counted, and account
    impact still occurs once.
23. Add Expense, Income, and Transfer fees; verify every fee posts to Expense
    `expense.fees_charges` and remains separate from principal.
24. Verify gross Income enters assignable money and its fee remains Budget
    spending.
25. Verify Transfer principal has zero Budget income/spending effect.
26. Edit ordinary and itemized Expenses, including itemized→ordinary and
    ordinary→itemized; verify exact reversal/reapplication.
27. Edit/delete Income and Transfer records; verify live historical/current
    Budget recalculation and correct account reversal.
28. Delete an itemized Expense; verify the account restores only parent
    principal plus fee and Budget line spending disappears.
29. Confirm inactive historical categories/accounts remain intelligible.

## D. Planned-vs-actual and price history

30. Link one and then multiple actual purchase lines to a planned item; verify
    actual amount, variance, quantity progress, and manual completion.
31. Mix missing/incompatible quantities or units; verify Nomi does not show a
    false quantity completion or unit-price comparison.
32. Open Price history; verify newest-first dates, payees, quantities, amounts,
    rounded unit prices, Latest, Previous, and Change.
33. Verify trivial unit case/whitespace differences compare while incompatible
    units do not.
34. Verify a line without quantity remains a purchase record but has no unit
    price.
35. Soft-delete a parent Expense; verify its line disappears from actuals and
    price history without deleting the historical child row.
36. For a stable `itemDefinitionId`, verify history spans purchases/months. For
    an ad-hoc planned item, verify only direct linked purchases appear and no
    same-name global matching occurs.

## E. Dashboard and persistence

37. Before Budget initialization on a clean state, verify Dashboard Budget
    areas show a neutral setup state while Total Money remains live.
38. After initialization, verify Dashboard month label is the current calendar
    month and Available/Left to Assign match the Budget screen.
39. Verify Income, principal Spent, Fees, and Remaining match current-month
    Budget data without double-counting fees.
40. Verify displayed category rows use live planning capacity, spending, and
    Ending Available; verify loading/no-activity/error states do not crash.
41. Edit an opening balance and add/edit/delete transactions while Dashboard is
    mounted; verify values refresh.
42. Relaunch and revisit months; verify all allocations, plans, actual links,
    rollover, history, and Dashboard results remain consistent.

------------------------------------------------------------------------

# 22. Development Phase Status

``` text
Foundation                         🟢 Complete
Database infrastructure            🟡 Ongoing cross-cutting
Repository architecture            🟡 Ongoing cross-cutting
Accounts                            🟢 Complete
Categories                          🟢 Complete + regression-tested
Transactions                        🟢 Complete + regression-tested
Budget Engine core                  🟢 Implemented
Budget item planning                🟢 Implemented + confirmed shortfall funding
Transaction itemization             🟢 Implemented
Planned-vs-actual fulfillment       🟢 Implemented
Opening balance ↔ Budget            🟢 Implemented; regression pending
Dashboard Budget integration        🟢 Implemented; regression pending
Price/unit-price history            🟢 Implemented; regression pending
Full Budget regression              🟠 Prepared / must be run manually
Goals                               ⬜ Not started
Recurring Transactions              ⬜ Not started
Reports                             ⬜ Not started
SMS infrastructure                  ⬜ Not started
Provider parsers                    ⬜ Not started
Reconciliation                      ⬜ Not started
SMS Inbox                           ⬜ Not started
Backup / Restore / Export           ⬜ Not started
Final integration/testing           ⬜ Not started
```

------------------------------------------------------------------------

# 23. Navigation / Theme Guardrails

Primary navigation:

``` text
Home | Budget | + | Transactions | More
```

App shell uses `IndexedStack`.

Because child screens remain mounted, nested FABs require unique Hero
tags or disabled Hero behavior. Do not remove `IndexedStack` merely to
solve Hero collisions.

Design direction:

-   Professional/international
-   Premium but restrained
-   Neutral background
-   White surfaces
-   Emerald accents
-   Strong typography hierarchy
-   Comfortable whitespace
-   Restrained borders/shadows

Approximate palette:

``` dart
primary       = Color(0xFF12B76A)
primaryDark   = Color(0xFF079455)
background    = Color(0xFFF7F8FA)
surface       = Colors.white
textPrimary   = Color(0xFF101828)
textSecondary = Color(0xFF667085)
border        = Color(0xFFEAECF0)
warning       = Color(0xFFF79009)
danger        = Color(0xFFF04438)
```

------------------------------------------------------------------------

# 24. Flutter Compatibility

On the user's current Flutter SDK, `DropdownButtonFormField` uses:

``` dart
value:
```

`initialValue:` previously produced:

``` text
The named parameter 'initialValue' isn't defined
```

Preserve the working `value:` approach unless the SDK is deliberately
upgraded and verified.

------------------------------------------------------------------------

# 25. Future SMS Architecture --- DEFERRED

Do not start this before the core product roadmap reaches it.

Direction:

``` text
SmsParser
   ├── MtnMomoParser
   ├── AirtelMoneyParser
   └── ZamtelMoneyParser
```

Pipeline:

``` text
Raw SMS
   ↓
Provider detection
   ↓
Provider parser
   ↓
Parsed candidate + confidence
   ↓
Duplicate check
   ↓
Reconciliation
   ↓
Review decision
   ↓
Transaction service
   ↓
Ledger
```

Raw SMS should remain locally available for audit/debugging.

------------------------------------------------------------------------

# 26. Backup / Portability Requirement

V1 eventually requires:

``` text
Full versioned backup
Restore into clean installation
JSON export
CSV transaction export
Round-trip validation
```

Database decisions must preserve portability.

------------------------------------------------------------------------

# 27. Development Rules for AI Coding Tools

1.  Do not put SQL in widgets.
2.  Do not put business/financial calculations in widgets.
3.  Keep repositories abstract.
4.  Keep Drift types below repository boundaries.
5.  Use Riverpod for state/dependency wiring.
6.  Store money as integer minor units.
7.  Store quantities as scaled integers.
8.  Never count transfer principal as expense/income.
9.  Represent fees separately.
10. Budget fees to `expense.fees_charges`.
11. Preserve historical fee values.
12. Preserve transaction/external IDs.
13. Use the ledger as authoritative financial history.
14. Update cached account balances atomically with ledger mutations.
15. Soft-delete ledger transactions.
16. Line items never directly change account balances.
17. Itemized Expense line totals must equal parent principal.
18. Item plan and category allocation are separate concepts.
19. On planned-item add/edit only, prompt before optionally increasing
    Assigned by the exact shortfall over `Starting Available + Assigned`.
20. Never automatically change an allocation; never reduce Assigned in
    response to planned-item changes.
21. Unknown planned price is `null`, never zero.
22. Keep calculations deterministic and testable.
23. Prefer correctness over visual complexity.
24. Keep UI professional/international.
25. Do not add backend/cloud dependencies to V1.
26. Keep backup/export possible.
27. Use stable IDs plus created/updated timestamps for important
    entities.
28. Avoid speculative refactors.
29. Do not build screens far ahead of data/business rules.
30. Give every feature a clear definition of done.
31. Test important flows on the physical Android phone.
32. Update this document after meaningful development sessions.
33. When changes touch much of one source file, prefer a full
    replacement file.
34. Repository code is authoritative if it differs from this handoff.

------------------------------------------------------------------------

# 28. Build Commands

``` bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart run build_runner clean
flutter clean
flutter pub get
flutter analyze
flutter run
```

Never manually edit:

``` text
app_database.g.dart
```

------------------------------------------------------------------------

# 29. Practical V1 Roadmap

``` text
Accounts ✓
    ↓
Categories ✓
    ↓
Transactions + Transfers + Fees ✓
    ↓
Budget Engine feature implementation ✓
    ↓
Full Budget regression ← NEXT
    ↓
Goals
    ↓
Recurring Transactions
    ↓
Reports
    ↓
SMS infrastructure
    ↓
Provider parsers
    ↓
Reconciliation
    ↓
SMS Inbox
    ↓
Backup / Restore / Export
    ↓
Full integration testing
```

------------------------------------------------------------------------

# 30. Handoff Prompt for the Next AI Session

Use:

> Read `project_context.md` fully. This is the current state of my Nomi
> Flutter project. Accounts, Categories, and core Transactions are
> complete and regression-tested. The Budget Engine, monthly
> allocations, item planning, Expense itemization, Transaction Detail
> itemization, planned-vs-actual fulfillment, and explicit planned-item
> shortfall funding confirmation, opening-balance Budget coordination,
> Dashboard Budget values, and price history are implemented.
> Continue from **CURRENT WORK --- START HERE IN A NEW SESSION**. The
> exact next task is the full clean-state physical-phone Budget regression
> in section 21. Do not mark Budgeting complete until it passes. Preserve
> all documented Budget/ledger semantics and fix only concrete failures.

For an agent that can inspect the repository:

> Read `project_context.md`, then inspect the repository. Repository
> code is authoritative where it differs from the handoff. Continue with
> full Budget regression. Do not redo completed features,
> redesign the Dashboard, change Riverpod/Drift, alter ledger semantics,
> automatically change category allocations from item plans outside the
> explicit add/edit confirmation, or start SMS
> automation.

------------------------------------------------------------------------

# 31. Immediate Continuation Summary

``` text
PROJECT:
Nomi — local-first Flutter personal finance / zero-based budgeting app.

TAGLINE:
Give every kwacha a job.

STACK:
Flutter/Dart
Riverpod
Drift/SQLite
Integer minor-unit money
Scaled integer item quantities

STABLE:
Accounts
Categories
Transactions
Ledger accounting
Transaction edit/delete
Transaction filtering
Budget semantics
Budget persistence
Monthly allocations
Budget screen
Item planning
Expense itemization
Edit itemization
Transaction Detail itemization
Planned-vs-actual fulfillment
Explicit planned-item funding confirmation
Opening-balance Budget coordination
Dashboard live Budget integration
Derived item price/unit-price history

IMPORTANT FIXES:
Expense Fees & Charges uses systemKey expense.fees_charges.
Income Fees & Charges remains separate.
Budget/planned-item dialogs own their TextEditingControllers and dispose them
from their State lifecycle.
Budget category rows retain chevron/navigation into item planning.

IMPORTANT PRODUCT DECISION:
Planning and funding remain separate decisions. After planned-item add/edit,
Nomi offers an explicit choice to increase Assigned by the exact shortfall
over Starting Available + Assigned. Declining still saves the plan. No
planned-item action ever automatically reduces Assigned, and spending is not
part of planning capacity.

NEXT:
Run the full clean-state physical-phone Budget regression in section 21.
Fix concrete failures, then mark Budgeting complete.

DO NOT:
Restart setup.
Redo completed phases.
Use doubles for money.
Treat transfer principal as expense/income.
Make line items affect account balances.
Automatically change category allocations from item plans outside the
explicit add/edit increase confirmation.
Put financial calculations in widgets.
Start SMS automation yet.
Rename the kopa SQLite database casually.
```

------------------------------------------------------------------------

**End of current Nomi project handoff context.**

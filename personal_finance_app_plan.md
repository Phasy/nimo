# Personal Finance App — V1 Application Plan

## Working Name

**[NAME TO BE DECIDED]**

### Product tagline

**Give every kwacha a job.**

> Note: The visual identity should be professional, modern, international, and product-focused. Local/Zambian realities should influence functionality and financial logic, not the branding or visual aesthetic.

---

# 1. Product Vision

Build a polished, local-first personal finance and zero-based budgeting application inspired by the core budgeting philosophy of EveryDollar, but designed around the user's actual financial environment.

The first version is strictly for personal use and must work fully on the Android device without cloud services.

The application should help answer four questions:

1. How much money do I have?
2. What is every kwacha supposed to do?
3. How much can I safely spend?
4. What is my money actually costing me, including transaction fees?

The product should be designed so that a future CodeIgniter 4 backend can be added without requiring a major rewrite of the Flutter application.

---

# 2. Product Principles

## 2.1 Zero-based budgeting

The fundamental budgeting model is:

    Income - Assigned Budget = Left To Assign

A completed budget should normally reach:

    Left To Assign = K0

This does not mean the user has no money. It means every kwacha has been given a purpose.

## 2.2 Budget first, expense tracking second

The application is not primarily an expense tracker.

It should help the user decide what money should do before the money is spent.

## 2.3 Local-first

V1 must work without:

- Cloud services
- User accounts
- Login
- Backend APIs
- Internet connectivity
- Remote databases

All financial data should be stored locally on the device.

## 2.4 User owns the data

The user must be able to export and back up their data.

The architecture should never make the user dependent on the future backend.

## 2.5 Mobile money is first-class

Mobile money is one of the most important payment mechanisms for the target environment.

The application must support:

- Airtel Money
- MTN MoMo
- Zamtel Money
- Other mobile-money providers

Mobile-money fees must be treated as real financial costs.

## 2.6 SMS automation

Android SMS messages containing financial transactions should eventually be detected and parsed automatically.

The SMS parser should extract, where available:

- Provider
- Transaction ID
- Transaction type
- Amount
- Balance after transaction
- Sender
- Recipient
- Phone number
- Date/time
- Raw message

## 2.7 Do not hard-code provider fees

Provider fees can change.

The actual fee for a transaction should be derived from the information available in the SMS whenever possible.

The provider-reported balance should be used to reconcile the account and infer the difference between the transaction amount and the actual account movement.

## 2.8 Professional visual identity

The application should look like a polished international finance product.

Avoid:

- African-themed decorative elements
- Flags
- Ethnic patterns
- Stereotypical regional visual design
- NGO-like visual language
- Excessive branding around geography

The local environment should be reflected through excellent functionality rather than visual stereotypes.

---

# 3. Technology Stack

## V1

- Flutter
- Dart
- Android-first
- SQLite local database
- Local filesystem for backup/export
- Local notifications where useful
- State-management solution selected during implementation
- Repository/service architecture

No backend is required for V1.

## Future

- CodeIgniter 4
- REST API
- Server database
- Authentication
- Synchronization
- Multi-device support

The Flutter application must be architected so that local repositories can eventually be replaced or supplemented with API repositories.

---

# 4. High-Level Architecture

    Flutter UI
        |
        v
    State Management
        |
        v
    Services / Business Logic
        |
        v
    Repository Interfaces
        |
        v
    SQLite Repository
        |
        v
    Local Database

Future:

    Flutter UI
        |
        v
    State Management
        |
        v
    Services / Business Logic
        |
        +-------------------+
        |                   |
        v                   v
    Local Repository     API Repository
                            |
                            v
                       CodeIgniter 4
                            |
                            v
                         Database

The UI must never communicate directly with SQLite.

---

# 5. Recommended Flutter Project Structure

    lib/
    |
    +-- main.dart
    |
    +-- app/
    |   +-- app.dart
    |   +-- routes.dart
    |   +-- theme.dart
    |
    +-- core/
    |   +-- constants/
    |   +-- database/
    |   +-- errors/
    |   +-- utils/
    |   +-- widgets/
    |
    +-- data/
    |   +-- models/
    |   +-- repositories/
    |   +-- database/
    |   +-- sms/
    |
    +-- features/
        +-- dashboard/
        +-- budget/
        +-- transactions/
        +-- accounts/
        +-- goals/
        +-- reports/
        +-- sms_inbox/
        +-- settings/

Business services should include:

    services/
    +-- budget_service.dart
    +-- transaction_service.dart
    +-- account_service.dart
    +-- goal_service.dart
    +-- reconciliation_service.dart
    +-- fee_service.dart
    +-- sms_service.dart

---

# 6. Core Data Model

The initial entities are:

- Account
- Category
- Budget
- BudgetItem
- Transaction
- Goal
- GoalContribution
- RecurringTransaction
- SmsRecord
- Settings

Future entities may include:

- Merchant
- Payee
- IncomeSource
- Attachment
- SyncRecord

---

# 7. Database Schema

## 7.1 accounts

Fields:

- id
- name
- type
- provider
- opening_balance
- current_balance
- is_active
- created_at
- updated_at

Account types:

- bank
- mobile_money
- cash
- other

Mobile-money providers:

- Airtel Money
- MTN MoMo
- Zamtel Money
- Other

The provider should not be required for bank/cash accounts.

---

# 8. categories

Fields:

- id
- name
- icon
- type
- parent_id
- is_default
- is_active
- created_at
- updated_at

Category groups should be customizable.

Initial groups:

## Housing

- Rent
- Mortgage
- Maintenance

## Utilities

- Electricity
- Water
- Internet

## Food

- Groceries
- Market
- Restaurants
- Takeaway

## Transport

- Fuel
- Taxi
- Bus
- Car maintenance

## Communication

- Airtime
- Data

## Family

- Family support
- School
- Other support

## Financial

- Debt
- Bank fees
- Mobile money fees
- Other fees

## Personal

- Clothing
- Entertainment
- Personal care

## Giving

- Charity
- Other giving

These are defaults only. The user must be able to add, edit, deactivate, and reorganize categories.

---

# 9. transactions

Fields:

- id
- account_id
- category_id
- type
- amount
- fee
- description
- merchant
- transaction_date
- transaction_id
- source
- balance_after
- notes
- created_at
- updated_at

Transaction types:

- income
- expense
- transfer

Possible sources:

- manual
- sms
- imported
- system

Important:

The transaction amount and transaction fee must be stored separately.

Example:

    Amount = K250
    Fee = K5
    Total account impact = K255

The historical fee must never change because a provider's default fee setting was changed later.

---

# 10. Transfers

Transfers must never be treated as ordinary expenses.

Example:

    Bank -> MTN MoMo
    Amount = K500
    Fee = K5

The accounting effect is:

    Bank       -K505
    MTN MoMo   +K500
    Fee        -K5

The K500 is not spending.

Only the K5 is an expense.

A transfer should link the source and destination transaction records.

---

# 11. budgets

Fields:

- id
- month
- year
- expected_income
- created_at
- updated_at

## budget_items

Fields:

- id
- budget_id
- category_id
- planned_amount

Core calculation:

    Total Income
    -
    Total Assigned
    =
    Left To Assign

A budget should visually show:

- Green: K0 left to assign
- Amber: money still unassigned
- Red: budget exceeds available income

---

# 12. Budget Category Calculations

For every category:

    Budgeted
    -
    Actual Spending
    =
    Remaining

Example:

    Food
    Budgeted: K3,000
    Spent: K2,450
    Remaining: K550

The application may additionally calculate:

    Remaining / Days Remaining

to show a daily suggested spending amount.

---

# 13. Account Balance Calculation

For an account:

    Opening Balance
    + Income
    - Expenses
    - Fees
    + Transfers In
    - Transfers Out
    =
    Calculated Balance

Where possible, compare this against the balance reported by the provider.

---

# 14. Goals

Fields:

- id
- name
- target_amount
- current_amount
- target_date
- monthly_contribution
- notes
- is_active
- created_at
- updated_at

Examples:

- Emergency Fund
- School Fees
- Car
- Home
- Christmas
- Vacation

## goal_contributions

Fields:

- id
- goal_id
- amount
- date
- note
- created_at

A contribution should be traceable.

---

# 15. Recurring Transactions

Fields:

- id
- name
- amount
- fee
- account_id
- category_id
- type
- frequency
- next_date
- active
- notes

Examples:

- Rent
- Internet
- Subscription
- School payment
- Insurance

Recurring transactions should initially create planned items rather than blindly assuming that the transaction actually occurred.

Distinguish:

    Planned
    Actual

---

# 16. SMS Architecture

The SMS system is a major feature.

Pipeline:

    Android SMS
        |
        v
    SMS Receiver
        |
        v
    Provider Detection
        |
        v
    Provider-specific Parser
        |
        v
    ParsedSmsTransaction
        |
        v
    Reconciliation Engine
        |
        v
    Review Queue
        |
        v
    Confirmed Transaction
        |
        v
    SQLite

---

# 17. SMS Parser Design

Create a generic parser interface.

Conceptually:

    SmsParser

Implement provider-specific parsers:

    AirtelMoneySmsParser
    MtnMoMoSmsParser
    ZamtelMoneySmsParser

All parsers should return a common normalized structure.

Example:

    ParsedSmsTransaction

Fields:

- provider
- transaction_id
- type
- amount
- balance_after
- sender
- recipient
- phone_number
- transaction_date
- raw_message
- confidence

Do not let provider-specific details leak into the rest of the application.

---

# 18. SMS Templates

Do not rely only on generic keywords.

Provider messages should be identified by their known templates.

Examples of transaction types:

## Airtel Money

- Send
- Receive
- Cash withdrawal
- Cash deposit
- Bill payment
- Airtime
- Other

## MTN MoMo

- Send
- Receive
- Cash withdrawal
- Cash deposit
- Bill payment
- Airtime
- Other

## Zamtel Money

Use the same normalized transaction categories.

The exact SMS formats should be collected from real messages during development.

---

# 19. Raw SMS Storage

Store the original SMS locally.

Suggested SmsRecord:

- id
- sender
- provider
- body
- received_at
- parsed
- transaction_id
- parser_version

Reasons:

1. Debugging
2. Parser improvement
3. Reprocessing old messages
4. Detecting provider format changes
5. Auditing

The raw SMS should not normally be displayed in the primary user interface.

---

# 20. Transaction Deduplication

Transaction IDs should be used to prevent duplicate records.

Ideally:

    provider + transaction_id

must be unique.

If an SMS is received twice, only one transaction should be created.

If no transaction ID exists, use a fallback matching strategy involving:

- Provider
- Amount
- Timestamp
- Transaction type
- Account
- Recipient/sender

Fallback matching must be conservative.

---

# 21. Balance Reconciliation

Every SMS containing a provider-reported balance should be treated as a balance observation.

Example:

Previous known balance:

    K2,957

SMS:

    Sent K500
    New balance K2,450

Expected:

    K2,957 - K500 = K2,457

Observed:

    K2,450

Difference:

    K7

Nomi should infer:

    Likely fee = K7

This should be marked internally as an inferred fee rather than claiming that the SMS explicitly stated the fee.

---

# 22. Fee Reconciliation Rules

For a sending transaction:

    Previous Balance
    - Transaction Amount
    - Fee
    =
    New Balance

Therefore:

    Fee =
    Previous Balance
    - Transaction Amount
    - New Balance

For receiving:

    Previous Balance
    + Amount
    - Fee
    =
    New Balance

Therefore:

    Fee =
    Previous Balance
    + Amount
    - New Balance

Do not infer a fee if the result is suspicious or impossible.

---

# 23. Handling Balance Discrepancies

Example:

Previous balance:

    K1,000

SMS:

    Sent K200
    New balance K600

Expected:

    K800

Observed:

    K600

Difference:

    K200

Do not automatically classify K200 as a fee.

Instead create a reconciliation warning:

    Balance discrepancy

    Expected balance: K800
    Provider balance: K600
    Difference: K200

Actions:

    Review
    Ignore
    Reconcile manually

Possible causes:

- Missing SMS
- Another transaction
- Automatic payment
- Incorrect previous balance
- Out-of-order SMS
- Provider adjustment

---

# 24. Ledger Balance vs Provider Balance

The system should distinguish:

## Calculated balance

What Nomi believes the account balance should be based on recorded transactions.

## Reported balance

What the provider most recently reported.

## Reconciled balance

The balance verified by the user or successful reconciliation.

This prevents silent corruption of financial data.

---

# 25. SMS Confidence

Every parser result should have a confidence score or classification.

High confidence:

- Provider identified
- Transaction ID found
- Amount found
- Type found
- Balance found

Lower confidence:

- Provider identified
- Amount found
- Some required fields missing

Low-confidence transactions should go into the review queue rather than being silently added to the ledger.

---

# 26. SMS Inbox

Create a dedicated Inbox screen.

Example:

    Inbox

    3 new transactions

    Airtel Money
    Sent K250
    Balance K1,420

    [Confirm] [Review]

    MTN MoMo
    Received K1,000
    Balance K4,820

    [Confirm] [Review]

The user should be able to:

- Confirm
- Edit
- Assign category
- Reject
- Ignore
- View details

After confirmation, the transaction becomes part of the main ledger.

---

# 27. Dashboard Screen

Purpose:

Give the user an immediate understanding of their current financial position.

Example:

    Good morning

    September 2026

    AVAILABLE
    K8,420

    Total money
    K14,850

    ----------------------------

    THIS MONTH

    Income          K21,000
    Spent            K9,230
    Fees               K180
    Remaining        K11,590

    ----------------------------

    BUDGET

    Food
    K2,450 / K3,000

    Transport
    K1,200 / K2,000

    Utilities
    K1,150 / K1,300

    ----------------------------

    UPCOMING

    Tomorrow
    Rent             K4,500

    12 Sep
    Electricity        K650

    ----------------------------

    + Add Transaction

Interactions:

- Tap Available -> Accounts
- Tap Income -> Income transactions
- Tap Spent -> Expense transactions
- Tap Fees -> Fee report
- Tap category -> Category detail
- Tap upcoming item -> Planned/recurring transaction
- Add Transaction -> Transaction creation flow

---

# 28. Budget Screen

Purpose:

Manage the current month's zero-based budget.

Top:

    September 2026

    Income
    K21,000

    Assigned
    K21,000

    Left to assign
    K0

Categories grouped by category group.

Each category should display:

    Category
    Spent / Budgeted
    Remaining

Example:

    Food
    K2,450 / K3,000
    K550 remaining

Interactions:

- Tap category -> Category detail
- Long press/swipe -> Edit budget
- Add category
- Reorder categories
- Change planned amount

---

# 29. Category Detail Screen

Example:

    Food

    Budgeted
    K3,000

    Spent
    K2,450

    Remaining
    K550

    K18/day available

    ----------------------------

    Transactions

    Sep 1
    Shoprite        K450

    Sep 4
    Market          K800

    Sep 6
    Shoprite       K1,200

    + Add Expense

Actions:

- Add transaction
- Edit budget
- View transactions
- Move transaction to another category

---

# 30. Add Transaction Screen

The screen must be optimized for speed.

Top:

    New Transaction

    K 250

Transaction type:

    Expense | Income | Transfer

Fields:

- Amount
- Account
- Category
- Description
- Merchant
- Date
- Fee
- Notes

For mobile-money accounts, prominently show Fee.

Example:

    Amount
    K250

    Fee
    K5

    Total
    K255

    Account balance after
    K1,245

Save should be quick and obvious.

---

# 31. Transfer Screen

Example:

    Transfer

    From
    MTN MoMo

    To
    Airtel Money

    Amount
    K500

    Fee
    K5

    ----------------------------

    MTN MoMo
    -K505

    Airtel Money
    +K500

    Actual cost
    K5

    [TRANSFER]

Transfers must never be counted as ordinary spending.

---

# 32. Transactions Screen

Purpose:

Provide a complete financial ledger.

Group transactions by date.

Example:

    Transactions

    September 2026

    Today

    MTN MoMo
    Transport
    -K255

    Airtel Money
    Food
    -K102.50

    Bank
    Salary
    +K18,000

    Yesterday

    MTN MoMo
    Family
    -K500

Filtering:

- Account
- Category
- Transaction type
- Date
- Provider
- Fee
- Search

---

# 33. Transaction Detail Screen

Example:

    Transport

    -K255.00

    Taxi
    6 September 2026

    ----------------------------

    Account
    MTN MoMo

    Amount
    K250

    Mobile Money fee
    K5

    Total
    K255

    Budget
    Transport

    Notes
    ...

Actions:

- Edit
- Delete
- Change category
- View source SMS
- Reconcile if applicable

---

# 34. Accounts Screen

Purpose:

Show where money physically exists.

Example:

    Accounts

    TOTAL
    K14,850

    ----------------------------

    Bank

    Zanaco
    K7,500

    ----------------------------

    Mobile Money

    MTN MoMo
    K3,250

    Airtel Money
    K2,100

    ----------------------------

    Cash

    Wallet
    K2,000

    + Add Account

Interactions:

- Add account
- Edit account
- Deactivate account
- View account
- Reconcile balance

---

# 35. Account Detail Screen

Example:

    MTN MoMo

    Balance
    K3,250

    ----------------------------

    September

    Money in      K4,000
    Money out     K1,750
    Fees             K75

    ----------------------------

    Transactions...

Display both:

- Calculated balance
- Latest provider-reported balance
- Difference, if any

---

# 36. Goals Screen

Example:

    Goals

    Emergency Fund

    K8,500 / K30,000
    28%

    Monthly contribution
    K2,000

    ----------------------------

    School Fees

    K7,000 / K12,000

    Due
    January 2027

    ----------------------------

    Car

    K2,100 / K5,000

    + New Goal

Interactions:

- Create goal
- Edit goal
- Add contribution
- View history
- Mark complete
- Archive

---

# 37. Recurring Transactions Screen

Example:

    Recurring

    Rent
    K4,500
    Monthly
    1st

    Internet
    K450
    Monthly
    5th

    School
    K1,500
    Monthly

    + Add Recurring

Recurring transactions should appear in upcoming cash-flow information.

---

# 38. Reports Screen

V1 should have useful reports, not excessive charts.

Required reports:

## Spending by category

Show:

- Category
- Amount
- Percentage
- Budget vs actual

## Income vs spending

Monthly comparison.

## Account balances

Current balance by account.

## Fees

Show:

    MTN MoMo      K75
    Airtel Money  K52
    Bank          K20
    Other         K33

    TOTAL         K180

## Mobile-money fee analytics

Show:

- Total fees
- Number of transactions
- Average fee
- Fees by provider
- Fees over time

Eventually:

    You have paid K1,240 in transaction fees this year.

---

# 39. Settings Screen

Sections:

## Budget

- Default categories
- Budget preferences

## Accounts

- Manage accounts

## Mobile Money

- Providers
- Default settings
- SMS parsing settings

## Transactions

- Categories
- Merchants

## Appearance

- Theme
- Dark mode later

## Data

- Export
- Backup
- Restore

## About

- Version
- Licenses
- Application information

---

# 40. Data Export

Required formats:

- JSON
- CSV

JSON should contain the complete application state.

CSV should primarily contain transaction data for spreadsheet analysis.

Export should be available without an internet connection.

---

# 41. Local Backup and Restore

Required features:

    Create Backup
    Restore Backup

Backup should contain:

- Accounts
- Categories
- Transactions
- Budgets
- Goals
- Goal contributions
- Recurring transactions
- SMS records
- Settings

A restore should be tested against a clean installation.

Never assume that a filename displayed in the UI is sufficient. Validate backup version and schema before importing.

---

# 42. Navigation

Recommended bottom navigation:

    Home | Budget | + | Transactions | More

The central + button should open:

    What do you want to record?

    Expense
    Income
    Transfer

The More section contains:

- Accounts
- Goals
- Reports
- Recurring
- SMS Inbox
- Settings

---

# 43. Visual Design

The design should be:

- Minimal
- Professional
- Premium
- Calm
- Trustworthy
- Information-focused
- International

Avoid unnecessary decoration.

The primary visual hierarchy should emphasize:

1. Money amount
2. Remaining amount
3. Budget status
4. Account status
5. Supporting information

Use a restrained palette.

Suggested direction:

- Deep green/emerald as primary
- Green for positive
- Amber for warnings
- Red for problems
- Neutral backgrounds
- Strong typography
- Excellent spacing
- Rounded but not excessive cards

Dark mode can be added after the core experience is stable.

---

# 44. Business Rules

## Rule 1: Transactions have three fundamental types

    Income
    Expense
    Transfer

## Rule 2: Transfers are not expenses

Only fees attached to transfers are expenses.

## Rule 3: Fees are separate from amounts

    Amount = K250
    Fee = K5
    Account impact = K255

## Rule 4: Historical fees never change

Changing a default provider fee must not modify old transactions.

## Rule 5: Budget spending uses the actual financial cost

If K250 costs K5 to send, the account loses K255.

The budget treatment should be explicitly defined during implementation, but the fee must always be represented separately.

## Rule 6: Provider-reported balances are observations

Never blindly overwrite the ledger without reconciliation.

## Rule 7: Transaction IDs should prevent duplicates

## Rule 8: Low-confidence SMS parsing requires review

## Rule 9: User categories are customizable

## Rule 10: Data must be exportable

---

# 45. "Can I Afford This?" Future Feature

Eventually provide a quick affordability check.

Example:

    Can I afford K850?

Nomi considers:

- Current account balances
- Budget remaining
- Upcoming bills
- Expected income
- Goal contributions
- Other commitments

Possible result:

    YES

    You have K1,420 remaining
    in Shopping.

    After this purchase:
    K570 remaining.

Or:

    NOT SAFELY

    You have K400 available
    for Shopping.

    This purchase would put
    the category K450 over budget.

This is a future feature, not required for the earliest MVP.

---

# 46. Irregular Income Mode

Future feature.

Support:

- Monthly income
- Weekly income
- Fortnightly income
- Irregular income
- Multiple income sources

For irregular income, calculate a conservative planning income based on historical data.

Do not force US-specific rules such as 50/30/20.

The user controls their own budget.

---

# 47. Paycheck / Cash-Flow Planning

Future feature.

Show:

    Money coming in
    Money going out
    Upcoming commitments
    Expected balance

Example:

    September 10
    Salary       +K18,000

    September 12
    Rent          -K4,500

    September 15
    School        -K1,500

This helps the user understand not only how much money they have, but when they have it.

---

# 48. Development Phases

# Phase 1 — Foundation

Tasks:

- Establish folder architecture
- Configure app theme
- Configure routing
- Create reusable widgets
- Create money display component
- Create application shell
- Create navigation

Definition of done:

- App launches
- Navigation works
- Theme works
- No business logic in UI

---

# Phase 2 — Database

Tasks:

- Implement SQLite
- Create schema
- Create migrations/versioning
- Create models
- Implement database access

Definition of done:

- Database can be created
- Schema can be upgraded
- CRUD works for initial entities
- Data persists after app restart

---

# Phase 3 — Repository Layer

Tasks:

- AccountRepository
- CategoryRepository
- TransactionRepository
- BudgetRepository
- GoalRepository
- RecurringRepository
- SmsRepository

Definition of done:

- UI does not directly access SQLite
- Repositories are testable
- Interfaces are suitable for future API implementations

---

# Phase 4 — Accounts

Tasks:

- Account list
- Add account
- Edit account
- Account detail
- Opening balance
- Balance calculation
- Account transactions

Test:

    Bank K10,000
    MTN K2,000
    Cash K500

Expected total:

    K12,500

---

# Phase 5 — Categories

Tasks:

- Default categories
- Add
- Edit
- Deactivate
- Reorder
- Parent groups

Definition of done:

- Categories are completely user-customizable

---

# Phase 6 — Transactions

Tasks:

- Add expense
- Add income
- Add transfer
- Edit
- Delete
- Transaction list
- Transaction detail
- Filtering
- Search

Definition of done:

- Ledger is reliable
- Transfers are correctly separated from expenses

---

# Phase 7 — Mobile Money

Tasks:

- Mobile-money account type
- Providers
- Fee field
- Fee display
- Transfer fee handling
- Account impact calculation

Test:

    MTN balance = K1,000
    Send K200
    Fee = K5

Expected:

    Balance = K795

---

# Phase 8 — SMS

Tasks:

- Android SMS receiver
- Permission handling
- SMS storage
- Provider detection
- Parser interface
- Airtel parser
- MTN parser
- Zamtel parser
- Transaction ID extraction
- Balance extraction
- Transaction extraction
- Confidence scoring
- Deduplication

Definition of done:

Real SMS messages can be parsed reliably on the development device.

---

# Phase 9 — Reconciliation

Tasks:

- Previous balance lookup
- New balance extraction
- Expected balance calculation
- Difference calculation
- Fee inference
- Discrepancy detection
- Review workflow

Definition of done:

Nomi can distinguish:

1. Correct transaction
2. Transaction + fee
3. Missing transaction / discrepancy
4. Duplicate SMS

---

# Phase 10 — SMS Inbox

Tasks:

- Inbox list
- Review transaction
- Confirm
- Edit
- Reject
- Ignore
- Assign category
- Link to account

Definition of done:

A real mobile-money SMS can become a ledger transaction with minimal manual input.

---

# Phase 11 — Budget Engine

Tasks:

- Monthly budget
- Expected income
- Budget categories
- Assigned amounts
- Left to assign
- Category remaining
- Spending calculations

Definition of done:

Zero-based budget calculations are correct.

---

# Phase 12 — Dashboard

Tasks:

- Total money
- Available amount
- Income
- Spending
- Fees
- Budget progress
- Upcoming expenses
- Quick add

Definition of done:

The dashboard gives a useful financial snapshot immediately after opening the app.

---

# Phase 13 — Goals

Tasks:

- Goal creation
- Goal editing
- Contributions
- Progress
- Target dates
- Goal history

---

# Phase 14 — Recurring Transactions

Tasks:

- Create recurring item
- Edit
- Pause
- Resume
- Upcoming schedule
- Planned transaction generation

---

# Phase 15 — Reports

Tasks:

- Spending by category
- Income vs expenses
- Account balances
- Fees
- Mobile-money fee analysis

---

# Phase 16 — Backup and Export

Tasks:

- JSON export
- CSV export
- Full backup
- Restore
- Backup versioning
- Restore validation

Definition of done:

The complete application can be backed up and restored successfully.

---

# 49. Testing Strategy

Finance applications must prioritize correctness over visual polish.

Tests should cover:

## Money calculations

- Income
- Expense
- Fee
- Transfer
- Multiple fees
- Zero fee
- Negative/invalid values

## Account balances

- Opening balance
- Income
- Expense
- Transfer
- Fees
- Reconciliation

## Budget

- Income
- Assigned
- Left to assign
- Category spending
- Remaining amount

## SMS

- Valid message
- Duplicate message
- Missing transaction ID
- Missing balance
- Unexpected formatting
- Unknown provider
- Low confidence
- Out-of-order SMS

## Backup

- Export
- Import
- Corrupt backup
- Older backup version
- Duplicate records

---

# 50. Real-World Test Scenario

Use this scenario as a core integration test.

Initial balances:

    Bank      K10,000
    MTN       K2,000
    Airtel    K1,000
    Cash        K500

Total:

    K13,500

Salary:

    +K18,000 Bank

Transfer:

    Bank -> MTN
    K2,000
    Fee K10

Expected:

    Bank decreases by K2,010
    MTN increases by K2,000
    K10 is an expense

Grocery purchase:

    MTN
    K450
    Fee K5

Expected:

    MTN decreases by K455

Taxi:

    Airtel
    K100
    Fee K3

Expected:

    Airtel decreases by K103

Family support:

    Bank
    K1,000

The system must correctly calculate:

- Total assets
- Each account balance
- Total spending
- Total fees
- Budget category spending
- Transfers without double-counting
- Mobile-money fees

---

# 51. V1 Definition of Done

V1 is complete when all of the following are true:

- [ ] App runs fully offline
- [ ] Data persists locally
- [ ] Accounts work
- [ ] Categories work
- [ ] Income works
- [ ] Expenses work
- [ ] Transfers work
- [ ] Fees work
- [ ] Budgets work
- [ ] Zero-based budgeting works
- [ ] Goals work
- [ ] Recurring transactions work
- [ ] Reports work
- [ ] Backup works
- [ ] Restore works
- [ ] JSON export works
- [ ] CSV export works
- [ ] SMS detection works
- [ ] SMS parsing works
- [ ] Transaction IDs prevent duplicates
- [ ] Provider balances are stored
- [ ] Fee inference works where possible
- [ ] Balance discrepancies are detected
- [ ] SMS review queue works
- [ ] Real-world integration test passes

---

# 52. Future Roadmap

## V2

- Improved SMS parser
- More provider templates
- Bank SMS parsing
- Better cash-flow planning
- Notifications
- Better reports
- Dark mode
- "Can I afford this?"
- Irregular income mode

## V3

- CodeIgniter 4 backend
- Authentication
- Remote database
- Sync
- Multi-device support
- Conflict resolution

## V4

Potential integrations:

- Bank integrations
- Mobile-money APIs where available
- Automatic transaction synchronization
- Advanced financial analytics

---

# 53. Backend Compatibility Requirements

Even though the backend does not exist in V1, design for it.

Every important entity should have:

- Stable ID
- Created timestamp
- Updated timestamp

Avoid database structures that only make sense locally.

Avoid putting business rules inside UI widgets.

Keep business calculations inside services.

Keep repositories abstract.

The future API should expose concepts equivalent to the local repositories.

---

# 54. Development Rules

1. Do not add cloud services to V1.
2. Do not put SQL inside widgets.
3. Do not put business calculations inside widgets.
4. Do not hard-code provider fees into transactions.
5. Never treat transfers as ordinary expenses.
6. Always preserve transaction IDs where available.
7. Store raw SMS messages locally.
8. Do not silently accept low-confidence SMS parsing.
9. Never silently overwrite a balance discrepancy.
10. Keep financial calculations deterministic and testable.
11. Prefer correctness over visual complexity.
12. Keep the UI professional and internationally styled.
13. Do not introduce backend assumptions prematurely.
14. Export/backup must remain possible.
15. Every feature must have a clear definition of done.

---

# 55. Suggested Development Workflow

For every feature:

    1. Define data model
    2. Implement database changes
    3. Implement repository
    4. Implement business service
    5. Write unit tests
    6. Implement state management
    7. Implement UI
    8. Connect UI to service
    9. Test real-world scenario
    10. Mark feature complete

Do not build large amounts of UI before the underlying business rules are proven.

---

# 56. Project Tracking

Track every phase using:

- Not Started
- In Progress
- Blocked
- Complete

For each task record:

- Date started
- Date completed
- Notes
- Bugs discovered
- Decisions made

When a design decision changes, document the reason.

This document should remain the master product plan.

---

# 57. Immediate Next Steps

After creating the Flutter project:

1. Create the folder structure.
2. Create the application shell.
3. Implement theme.
4. Implement navigation.
5. Decide on state-management package.
6. Decide on SQLite package.
7. Create database schema.
8. Implement database versioning.
9. Implement models.
10. Implement repositories.
11. Build Accounts.
12. Build Categories.
13. Build Transactions.
14. Build Transfers.
15. Build Fees.
16. Build Budget Engine.
17. Build Dashboard.
18. Build Goals.
19. Build Recurring Transactions.
20. Build Reports.
21. Build SMS infrastructure.
22. Build provider parsers.
23. Build reconciliation.
24. Build SMS Inbox.
25. Build Backup/Restore.
26. Run full integration testing.

---

# 58. Product Success Criteria

The application succeeds if, at the end of a normal month, the user can open it and immediately understand:

    How much money do I have?

    Where is that money?

    How much have I spent?

    How much have I paid in fees?

    What is left in each budget?

    What bills are coming?

    Am I on track?

And the majority of mobile-money transactions should eventually be captured automatically from SMS with little or no manual data entry.

The ideal experience is:

    SMS arrives
        ->
    Nomi detects it
        ->
    Nomi understands it
        ->
    Nomi reconciles the balance
        ->
    Nomi identifies the fee
        ->
    User selects/accepts category
        ->
    Transaction enters ledger
        ->
    Budget updates automatically

---

# 59. Product North Star

## Give every kwacha a job.

Nomi should make personal finance feel less like accounting and more like having a clear plan.

The application should be:

- Simple enough to use every day
- Powerful enough to trust with real financial data
- Local-first
- Privacy-conscious
- Accurate
- Automated where possible
- Professional enough to feel like a finished commercial product
- Architected for a future cloud/backend version without requiring one today

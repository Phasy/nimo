import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/utils/money.dart';
import '../../../domain/models/finance_account.dart';
import '../../../domain/models/finance_category.dart';
import '../../../domain/models/finance_transaction.dart';
import '../../accounts/application/account_providers.dart';
import '../../categories/application/category_providers.dart';
import '../application/transaction_providers.dart';
import 'add_transaction_screen.dart';
import 'transaction_detail_screen.dart';

enum TransactionDateFilter {
  all,
  today,
  thisWeek,
  thisMonth,
  custom,
}

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState
    extends ConsumerState<TransactionsScreen> {
  final TextEditingController _searchController =
  TextEditingController();

  TransactionType? _selectedType;
  int? _selectedAccountId;
  int? _selectedCategoryId;

  TransactionDateFilter _selectedDateFilter =
      TransactionDateFilter.all;

  DateTimeRange? _customDateRange;

  bool get _hasActiveFilters {
    return _searchController.text.trim().isNotEmpty ||
        _selectedType != null ||
        _selectedAccountId != null ||
        _selectedCategoryId != null ||
        _selectedDateFilter != TransactionDateFilter.all;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setTransactionType(
      TransactionType? type,
      ) {
    setState(() {
      _selectedType = type;
    });
  }

  void _setAccount(
      int? accountId,
      ) {
    setState(() {
      _selectedAccountId = accountId;
    });
  }

  void _setCategory(
      int? categoryId,
      ) {
    setState(() {
      _selectedCategoryId = categoryId;
    });
  }

  void _setDateFilter(
      TransactionDateFilter filter,
      ) {
    setState(() {
      _selectedDateFilter = filter;

      if (filter != TransactionDateFilter.custom) {
        _customDateRange = null;
      }
    });
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();

    final initialRange = _customDateRange ??
        DateTimeRange(
          start: DateTime(
            now.year,
            now.month,
            1,
          ),
          end: now,
        );

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(
        now.year + 10,
        12,
        31,
      ),
      initialDateRange: initialRange,
    );

    if (!mounted || range == null) {
      return;
    }

    setState(() {
      _customDateRange = range;
      _selectedDateFilter =
          TransactionDateFilter.custom;
    });
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _selectedType = null;
      _selectedAccountId = null;
      _selectedCategoryId = null;
      _selectedDateFilter =
          TransactionDateFilter.all;
      _customDateRange = null;
    });
  }

  List<FinanceTransaction> _filterTransactions({
    required List<FinanceTransaction> transactions,
    required List<FinanceAccount> accounts,
    required List<FinanceCategory> categories,
  }) {
    final search =
    _searchController.text.trim().toLowerCase();

    return transactions.where((transaction) {
      if (_selectedType != null &&
          transaction.type != _selectedType) {
        return false;
      }

      if (_selectedAccountId != null) {
        final matchesSource =
            transaction.accountId ==
                _selectedAccountId;

        final matchesDestination =
            transaction.destinationAccountId ==
                _selectedAccountId;

        if (!matchesSource &&
            !matchesDestination) {
          return false;
        }
      }

      if (_selectedCategoryId != null &&
          transaction.categoryId !=
              _selectedCategoryId) {
        return false;
      }

      if (!_matchesDateFilter(
        transaction.occurredAt,
      )) {
        return false;
      }

      if (search.isEmpty) {
        return true;
      }

      final sourceAccount = _findAccount(
        accounts,
        transaction.accountId,
      );

      final destinationAccount =
      transaction.destinationAccountId == null
          ? null
          : _findAccount(
        accounts,
        transaction.destinationAccountId!,
      );

      final category =
      transaction.categoryId == null
          ? null
          : _findCategory(
        categories,
        transaction.categoryId!,
      );

      final searchableValues = <String>[
        transaction.payee ?? '',
        transaction.note ?? '',
        sourceAccount?.name ?? '',
        destinationAccount?.name ?? '',
        category?.name ?? '',
        transaction.type.name,
      ];

      return searchableValues.any(
            (value) =>
            value.toLowerCase().contains(search),
      );
    }).toList();
  }

  bool _matchesDateFilter(
      DateTime occurredAt,
      ) {
    final transactionDate = DateTime(
      occurredAt.year,
      occurredAt.month,
      occurredAt.day,
    );

    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    switch (_selectedDateFilter) {
      case TransactionDateFilter.all:
        return true;

      case TransactionDateFilter.today:
        return transactionDate == today;

      case TransactionDateFilter.thisWeek:
        final startOfWeek = today.subtract(
          Duration(
            days: today.weekday - 1,
          ),
        );

        final endOfWeek = startOfWeek.add(
          const Duration(days: 6),
        );

        return !transactionDate.isBefore(
          startOfWeek,
        ) &&
            !transactionDate.isAfter(
              endOfWeek,
            );

      case TransactionDateFilter.thisMonth:
        return transactionDate.year ==
            today.year &&
            transactionDate.month ==
                today.month;

      case TransactionDateFilter.custom:
        final range = _customDateRange;

        if (range == null) {
          return true;
        }

        final start = DateTime(
          range.start.year,
          range.start.month,
          range.start.day,
        );

        final end = DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
        );

        return !transactionDate.isBefore(start) &&
            !transactionDate.isAfter(end);
    }
  }

  FinanceAccount? _findAccount(
      List<FinanceAccount> accounts,
      int id,
      ) {
    for (final account in accounts) {
      if (account.id == id) {
        return account;
      }
    }

    return null;
  }

  FinanceCategory? _findCategory(
      List<FinanceCategory> categories,
      int id,
      ) {
    for (final category in categories) {
      if (category.id == id) {
        return category;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(
      transactionsProvider,
    );

    final accountsAsync = ref.watch(
      accountsProvider,
    );

    final categoriesAsync = ref.watch(
      categoriesProvider(null),
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Transactions'),
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            return const _EmptyTransactions();
          }

          return accountsAsync.when(
            data: (accounts) {
              return categoriesAsync.when(
                data: (categories) {
                  final filteredTransactions =
                  _filterTransactions(
                    transactions: transactions,
                    accounts: accounts,
                    categories: categories,
                  );

                  return Column(
                    children: [
                      _FilterSection(
                        searchController:
                        _searchController,
                        selectedType:
                        _selectedType,
                        selectedAccountId:
                        _selectedAccountId,
                        selectedCategoryId:
                        _selectedCategoryId,
                        selectedDateFilter:
                        _selectedDateFilter,
                        customDateRange:
                        _customDateRange,
                        accounts: accounts,
                        categories: categories,
                        hasActiveFilters:
                        _hasActiveFilters,
                        onSearchChanged: (_) {
                          setState(() {});
                        },
                        onTypeSelected:
                        _setTransactionType,
                        onAccountSelected:
                        _setAccount,
                        onCategorySelected:
                        _setCategory,
                        onDateFilterSelected:
                        _setDateFilter,
                        onPickCustomDateRange:
                        _pickCustomDateRange,
                        onClearFilters:
                        _clearFilters,
                      ),
                      Expanded(
                        child:
                        filteredTransactions.isEmpty
                            ? _NoMatchingTransactions(
                          onClearFilters:
                          _clearFilters,
                        )
                            : _TransactionsList(
                          transactions:
                          filteredTransactions,
                          accounts: accounts,
                          categories:
                          categories,
                        ),
                      ),
                    ],
                  );
                },
                loading: () =>
                const _LoadingState(),
                error: (_, __) =>
                const _LoadError(),
              );
            },
            loading: () =>
            const _LoadingState(),
            error: (_, __) =>
            const _LoadError(),
          );
        },
        loading: () =>
        const _LoadingState(),
        error: (_, __) =>
        const _LoadError(),
      ),
      floatingActionButton:
      FloatingActionButton(
        heroTag:
        'transactions_add_transaction_fab',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
              const AddTransactionScreen(),
            ),
          );
        },
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        child: const Icon(
          Icons.add_rounded,
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  final TextEditingController searchController;

  final TransactionType? selectedType;
  final int? selectedAccountId;
  final int? selectedCategoryId;

  final TransactionDateFilter
  selectedDateFilter;

  final DateTimeRange? customDateRange;

  final List<FinanceAccount> accounts;
  final List<FinanceCategory> categories;

  final bool hasActiveFilters;

  final ValueChanged<String>
  onSearchChanged;

  final ValueChanged<TransactionType?>
  onTypeSelected;

  final ValueChanged<int?>
  onAccountSelected;

  final ValueChanged<int?>
  onCategorySelected;

  final ValueChanged<TransactionDateFilter>
  onDateFilterSelected;

  final VoidCallback
  onPickCustomDateRange;

  final VoidCallback onClearFilters;

  const _FilterSection({
    required this.searchController,
    required this.selectedType,
    required this.selectedAccountId,
    required this.selectedCategoryId,
    required this.selectedDateFilter,
    required this.customDateRange,
    required this.accounts,
    required this.categories,
    required this.hasActiveFilters,
    required this.onSearchChanged,
    required this.onTypeSelected,
    required this.onAccountSelected,
    required this.onCategorySelected,
    required this.onDateFilterSelected,
    required this.onPickCustomDateRange,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        8,
        20,
        8,
      ),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            textInputAction:
            TextInputAction.search,
            decoration: InputDecoration(
              hintText:
              'Search transactions',
              prefixIcon: const Icon(
                Icons.search_rounded,
              ),
              suffixIcon:
              searchController.text.isEmpty
                  ? null
                  : IconButton(
                tooltip:
                'Clear search',
                onPressed: () {
                  searchController
                      .clear();
                  onSearchChanged('');
                },
                icon: const Icon(
                  Icons.close_rounded,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          SingleChildScrollView(
            scrollDirection:
            Axis.horizontal,
            child: Row(
              children: [
                _TypeFilterChip(
                  label: 'All',
                  selected:
                  selectedType == null,
                  onTap: () =>
                      onTypeSelected(null),
                ),
                const SizedBox(width: 8),
                _TypeFilterChip(
                  label: 'Expenses',
                  selected: selectedType ==
                      TransactionType.expense,
                  onTap: () =>
                      onTypeSelected(
                        TransactionType.expense,
                      ),
                ),
                const SizedBox(width: 8),
                _TypeFilterChip(
                  label: 'Income',
                  selected: selectedType ==
                      TransactionType.income,
                  onTap: () =>
                      onTypeSelected(
                        TransactionType.income,
                      ),
                ),
                const SizedBox(width: 8),
                _TypeFilterChip(
                  label: 'Transfers',
                  selected: selectedType ==
                      TransactionType.transfer,
                  onTap: () =>
                      onTypeSelected(
                        TransactionType.transfer,
                      ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _AccountFilter(
                  accounts: accounts,
                  selectedAccountId:
                  selectedAccountId,
                  onSelected:
                  onAccountSelected,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CategoryFilter(
                  categories: categories,
                  selectedCategoryId:
                  selectedCategoryId,
                  onSelected:
                  onCategorySelected,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SingleChildScrollView(
            scrollDirection:
            Axis.horizontal,
            child: Row(
              children: [
                _DateFilterChip(
                  label: 'All time',
                  selected:
                  selectedDateFilter ==
                      TransactionDateFilter
                          .all,
                  onTap: () =>
                      onDateFilterSelected(
                        TransactionDateFilter.all,
                      ),
                ),
                const SizedBox(width: 8),
                _DateFilterChip(
                  label: 'Today',
                  selected:
                  selectedDateFilter ==
                      TransactionDateFilter
                          .today,
                  onTap: () =>
                      onDateFilterSelected(
                        TransactionDateFilter
                            .today,
                      ),
                ),
                const SizedBox(width: 8),
                _DateFilterChip(
                  label: 'This week',
                  selected:
                  selectedDateFilter ==
                      TransactionDateFilter
                          .thisWeek,
                  onTap: () =>
                      onDateFilterSelected(
                        TransactionDateFilter
                            .thisWeek,
                      ),
                ),
                const SizedBox(width: 8),
                _DateFilterChip(
                  label: 'This month',
                  selected:
                  selectedDateFilter ==
                      TransactionDateFilter
                          .thisMonth,
                  onTap: () =>
                      onDateFilterSelected(
                        TransactionDateFilter
                            .thisMonth,
                      ),
                ),
                const SizedBox(width: 8),
                _DateFilterChip(
                  label: _customDateLabel,
                  selected:
                  selectedDateFilter ==
                      TransactionDateFilter
                          .custom,
                  onTap:
                  onPickCustomDateRange,
                  icon: Icons
                      .date_range_outlined,
                ),
              ],
            ),
          ),

          if (hasActiveFilters) ...[
            const SizedBox(height: 8),
            Align(
              alignment:
              Alignment.centerRight,
              child: TextButton.icon(
                onPressed:
                onClearFilters,
                icon: const Icon(
                  Icons
                      .filter_alt_off_rounded,
                  size: 18,
                ),
                label: const Text(
                  'Clear filters',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String get _customDateLabel {
    if (customDateRange == null) {
      return 'Custom';
    }

    final start =
        customDateRange!.start;
    final end =
        customDateRange!.end;

    return '${_shortDate(start)} – ${_shortDate(end)}';
  }

  String _shortDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _TypeFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor:
      AppTheme.primary.withValues(
        alpha: 0.12,
      ),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected
            ? AppTheme.primary
            : AppTheme.border,
      ),
      labelStyle: TextStyle(
        color: selected
            ? AppTheme.primaryDark
            : AppTheme.textSecondary,
        fontWeight: selected
            ? FontWeight.w600
            : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(12),
      ),
      showCheckmark: false,
    );
  }
}

class _DateFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _DateFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: icon == null
          ? null
          : Icon(
        icon,
        size: 17,
        color: selected
            ? AppTheme.primaryDark
            : AppTheme.textSecondary,
      ),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor:
      AppTheme.primary.withValues(
        alpha: 0.12,
      ),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected
            ? AppTheme.primary
            : AppTheme.border,
      ),
      labelStyle: TextStyle(
        color: selected
            ? AppTheme.primaryDark
            : AppTheme.textSecondary,
        fontWeight: selected
            ? FontWeight.w600
            : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(12),
      ),
      showCheckmark: false,
    );
  }
}

class _AccountFilter extends StatelessWidget {
  final List<FinanceAccount> accounts;
  final int? selectedAccountId;
  final ValueChanged<int?> onSelected;

  const _AccountFilter({
    required this.accounts,
    required this.selectedAccountId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int?>(
      value: selectedAccountId,
      isExpanded: true,
      decoration:
      const InputDecoration(
        labelText: 'Account',
        prefixIcon: Icon(
          Icons
              .account_balance_wallet_outlined,
        ),
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text(
            'All accounts',
          ),
        ),
        ...accounts.map(
              (account) =>
              DropdownMenuItem<int?>(
                value: account.id,
                child: Text(
                  account.name,
                  overflow:
                  TextOverflow.ellipsis,
                ),
              ),
        ),
      ],
      onChanged: onSelected,
    );
  }
}

class _CategoryFilter
    extends StatelessWidget {
  final List<FinanceCategory> categories;
  final int? selectedCategoryId;
  final ValueChanged<int?> onSelected;

  const _CategoryFilter({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int?>(
      value: selectedCategoryId,
      isExpanded: true,
      decoration:
      const InputDecoration(
        labelText: 'Category',
        prefixIcon: Icon(
          Icons.category_outlined,
        ),
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text(
            'All categories',
          ),
        ),
        ...categories.map(
              (category) =>
              DropdownMenuItem<int?>(
                value: category.id,
                child: Text(
                  category.name,
                  overflow:
                  TextOverflow.ellipsis,
                ),
              ),
        ),
      ],
      onChanged: onSelected,
    );
  }
}

class _TransactionsList
    extends StatelessWidget {
  final List<FinanceTransaction>
  transactions;

  final List<FinanceAccount> accounts;
  final List<FinanceCategory> categories;

  const _TransactionsList({
    required this.transactions,
    required this.accounts,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        20,
        8,
        20,
        100,
      ),
      itemCount: transactions.length,
      separatorBuilder: (_, __) =>
      const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final transaction =
        transactions[index];

        return _TransactionTile(
          transaction: transaction,
          sourceAccount: _findAccount(
            transaction.accountId,
          ),
          destinationAccount:
          transaction
              .destinationAccountId ==
              null
              ? null
              : _findAccount(
            transaction
                .destinationAccountId!,
          ),
          category:
          transaction.categoryId == null
              ? null
              : _findCategory(
            transaction.categoryId!,
          ),
        );
      },
    );
  }

  FinanceAccount? _findAccount(
      int id,
      ) {
    for (final account in accounts) {
      if (account.id == id) {
        return account;
      }
    }

    return null;
  }

  FinanceCategory? _findCategory(
      int id,
      ) {
    for (final category in categories) {
      if (category.id == id) {
        return category;
      }
    }

    return null;
  }
}

class _TransactionTile
    extends StatelessWidget {
  final FinanceTransaction transaction;

  final FinanceAccount? sourceAccount;
  final FinanceAccount? destinationAccount;

  final FinanceCategory? category;

  const _TransactionTile({
    required this.transaction,
    required this.sourceAccount,
    required this.destinationAccount,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: InkWell(
        borderRadius:
        BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  TransactionDetailScreen(
                    transactionId:
                    transaction.id,
                  ),
            ),
          );
        },
        child: Padding(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primary
                      .withValues(
                    alpha: 0.08,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  _icon,
                  color:
                  AppTheme.primaryDark,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style:
                      Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                        fontWeight:
                        FontWeight
                            .w600,
                        color:
                        AppTheme
                            .textPrimary,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      _subtitle,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style:
                      Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color:
                        AppTheme
                            .textSecondary,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      _formattedDate,
                      style:
                      Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color:
                        AppTheme
                            .textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              Text(
                _formattedAmount,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  fontWeight:
                  FontWeight.w700,
                  color:
                  _amountColor,
                ),
              ),

              const SizedBox(width: 6),

              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color:
                AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _title {
    switch (transaction.type) {
      case TransactionType.income:
        final payee =
        transaction.payee?.trim();

        if (payee != null &&
            payee.isNotEmpty) {
          return payee;
        }

        return category?.name ??
            'Income';

      case TransactionType.expense:
        final payee =
        transaction.payee?.trim();

        if (payee != null &&
            payee.isNotEmpty) {
          return payee;
        }

        return category?.name ??
            'Expense';

      case TransactionType.transfer:
        return 'Transfer';
    }
  }

  String get _subtitle {
    final accountName =
        sourceAccount?.name ??
            'Unknown account';

    switch (transaction.type) {
      case TransactionType.income:
      case TransactionType.expense:
        final categoryName =
            category?.name ??
                'Uncategorized';

        return '$categoryName • $accountName';

      case TransactionType.transfer:
        final destinationName =
            destinationAccount?.name ??
                'Unknown account';

        return '$accountName → $destinationName';
    }
  }

  String get _formattedDate {
    final date =
        transaction.occurredAt;

    final day =
    date.day.toString().padLeft(
      2,
      '0',
    );

    final month =
    date.month.toString().padLeft(
      2,
      '0',
    );

    return '$day/$month/${date.year}';
  }

  String get _formattedAmount {
    switch (transaction.type) {
      case TransactionType.income:
        return '+${Money.formatZmw(
          transaction.amount -
              transaction.fee,
        )}';

      case TransactionType.expense:
        return '-${Money.formatZmw(
          transaction.amount +
              transaction.fee,
        )}';

      case TransactionType.transfer:
        return Money.formatZmw(
          transaction.amount,
        );
    }
  }

  IconData get _icon {
    switch (transaction.type) {
      case TransactionType.income:
        return Icons.south_west_rounded;

      case TransactionType.expense:
        return Icons.north_east_rounded;

      case TransactionType.transfer:
        return Icons.swap_horiz_rounded;
    }
  }

  Color get _amountColor {
    switch (transaction.type) {
      case TransactionType.income:
        return Colors.green.shade700;

      case TransactionType.expense:
      case TransactionType.transfer:
        return AppTheme.textPrimary;
    }
  }
}

class _NoMatchingTransactions
    extends StatelessWidget {
  final VoidCallback onClearFilters;

  const _NoMatchingTransactions({
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(28),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primary
                    .withValues(
                  alpha: 0.08,
                ),
                borderRadius:
                BorderRadius.circular(
                  22,
                ),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 32,
                color:
                AppTheme.primaryDark,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'No matching transactions',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight:
                FontWeight.w700,
                color:
                AppTheme.textPrimary,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Try changing your search or filters.',
              textAlign:
              TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color:
                AppTheme.textSecondary,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 16),

            TextButton.icon(
              onPressed:
              onClearFilters,
              icon: const Icon(
                Icons
                    .filter_alt_off_rounded,
              ),
              label: const Text(
                'Clear filters',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState
    extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child:
      CircularProgressIndicator(),
    );
  }
}

class _LoadError
    extends StatelessWidget {
  const _LoadError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(28),
        child: Text(
          'Something went wrong while loading your transactions.',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(
            color:
            AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _EmptyTransactions
    extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(28),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primary
                    .withValues(
                  alpha: 0.08,
                ),
                borderRadius:
                BorderRadius.circular(
                  22,
                ),
              ),
              child: const Icon(
                Icons
                    .receipt_long_outlined,
                size: 32,
                color:
                AppTheme.primaryDark,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'No transactions yet',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight:
                FontWeight.w700,
                color:
                AppTheme.textPrimary,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Add your first income, expense, or transfer.',
              textAlign:
              TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color:
                AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/category_group.dart';
import '../../../domain/models/finance_category.dart';
import '../application/category_providers.dart';

class AddCategoryScreen extends ConsumerStatefulWidget {
  const AddCategoryScreen({
    super.key,
    required this.type,
    this.category,
    this.initialGroupId,
  });

  final CategoryType type;
  final FinanceCategory? category;

  final int? initialGroupId;

  @override
  ConsumerState<AddCategoryScreen> createState() =>
      _AddCategoryScreenState();
}

class _AddCategoryScreenState
    extends ConsumerState<AddCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  int? _selectedGroupId;
  bool _isSaving = false;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();

    final category = widget.category;

    if (category != null) {
      _nameController.text = category.name;
      _selectedGroupId = category.groupId;
    } else {
      _selectedGroupId = widget.initialGroupId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(
      categoryGroupsProvider(widget.type),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit category' : 'Add category',
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      body: groupsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Could not load category groups.',
            ),
          ),
        ),
        data: (groups) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _FormCard(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Category details',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF101828),
                        ),
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: _nameController,
                        textCapitalization:
                        TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          hintText: 'e.g. Groceries',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final trimmed =
                              value?.trim() ?? '';

                          if (trimmed.isEmpty) {
                            return 'Enter a category name.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      DropdownButtonFormField<int>(
                        value: _selectedGroupId,
                        decoration: const InputDecoration(
                          labelText: 'Group',
                          border: OutlineInputBorder(),
                        ),
                        items: groups
                            .map(
                              (group) =>
                              DropdownMenuItem<int>(
                                value: group.id,
                                child: Text(group.name),
                              ),
                        )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedGroupId = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Choose a group.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      Text(
                        widget.type == CategoryType.expense
                            ? 'This category will be available for expense transactions.'
                            : 'This category will be available for income transactions.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                          color:
                          const Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed:
                    _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : Text(
                      _isEditing
                          ? 'Save changes'
                          : 'Add category',
                    ),
                  ),
                ),
                if (_isEditing) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : _confirmDeactivate,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF04438),
                        side: const BorderSide(
                          color: Color(0xFFF04438),
                        ),
                      ),
                      child: const Text('Deactivate category'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final groupId = _selectedGroupId;

    if (groupId == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final repository = ref.read(
        categoryRepositoryProvider,
      );

      final name = _nameController.text.trim();

      if (_isEditing) {
        final current = widget.category!;

        final updated = current.copyWith(
          name: name,
          groupId: groupId,
          updatedAt: DateTime.now(),
        );

        await repository.updateCategory(updated);
      } else {
        final existingCategories = await ref.read(
          categoriesProvider(groupId).future,
        );

        final nextSortOrder =
        existingCategories.isEmpty
            ? 0
            : existingCategories
            .map(
              (category) =>
          category.sortOrder,
        )
            .reduce(
              (a, b) => a > b ? a : b,
        ) +
            1;

        await repository.createCategory(
          groupId: groupId,
          name: name,
          sortOrder: nextSortOrder,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Could not update category.'
                : 'Could not add category.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _confirmDeactivate() async {
    final category = widget.category;

    if (category == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Deactivate category?'),
          content: Text(
            '${category.name} will no longer appear when creating new transactions. Historical transactions will keep this category.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF04438),
              ),
              child: const Text('Deactivate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final repository = ref.read(
        categoryRepositoryProvider,
      );

      await repository.deactivateCategory(
        category.id,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not deactivate category.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFEAECF0),
        ),
      ),
      child: child,
    );
  }
}
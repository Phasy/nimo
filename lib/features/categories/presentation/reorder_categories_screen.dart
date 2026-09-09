import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/category_group.dart';
import '../../../domain/models/finance_category.dart';
import '../application/category_providers.dart';

class ReorderCategoriesScreen extends ConsumerStatefulWidget {
  const ReorderCategoriesScreen({
    super.key,
    required this.group,
  });

  final CategoryGroup group;

  @override
  ConsumerState<ReorderCategoriesScreen> createState() =>
      _ReorderCategoriesScreenState();
}

class _ReorderCategoriesScreenState
    extends ConsumerState<ReorderCategoriesScreen> {
  List<FinanceCategory>? _categories;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(
      categoriesProvider(widget.group.id),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(
          'Reorder ${widget.group.name}',
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => const Center(
          child: Text(
            'Could not load categories.',
          ),
        ),
        data: (categories) {
          _categories ??=
          List<FinanceCategory>.from(categories);

          final items = _categories!;

          if (items.isEmpty) {
            return const Center(
              child: Text(
                'No categories to reorder.',
              ),
            );
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              32,
            ),
            itemCount: items.length,
            onReorder: _reorder,
            itemBuilder: (context, index) {
              final category = items[index];

              return Container(
                key: ValueKey(category.id),
                margin: const EdgeInsets.only(
                  bottom: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFEAECF0),
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF3),
                      borderRadius:
                      BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Color(0xFF079455),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(
                    category.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing:
                  ReorderableDragStartListener(
                    index: index,
                    child: const Icon(
                      Icons.drag_handle_rounded,
                      color: Color(0xFF98A2B3),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      final item =
      _categories!.removeAt(oldIndex);

      _categories!.insert(
        newIndex,
        item,
      );
    });
  }

  Future<void> _save() async {
    final categories = _categories;

    if (categories == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final repository = ref.read(
        categoryRepositoryProvider,
      );

      await repository.reorderCategories(
        widget.group.id,
        categories
            .map(
              (category) => category.id,
        )
            .toList(),
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
            'Could not save category order.',
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
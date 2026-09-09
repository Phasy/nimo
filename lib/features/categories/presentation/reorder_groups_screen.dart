import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/category_group.dart';
import '../application/category_providers.dart';

class ReorderGroupsScreen extends ConsumerStatefulWidget {
  const ReorderGroupsScreen({
    super.key,
    required this.type,
  });

  final CategoryType type;

  @override
  ConsumerState<ReorderGroupsScreen> createState() =>
      _ReorderGroupsScreenState();
}

class _ReorderGroupsScreenState
    extends ConsumerState<ReorderGroupsScreen> {
  List<CategoryGroup>? _groups;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(
      categoryGroupsProvider(widget.type),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Reorder groups'),
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
      body: groupsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => const Center(
          child: Text('Could not load groups.'),
        ),
        data: (groups) {
          _groups ??= List<CategoryGroup>.from(groups);

          final items = _groups!;

          if (items.isEmpty) {
            return const Center(
              child: Text('No groups to reorder.'),
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
              final group = items[index];

              return Container(
                key: ValueKey(group.id),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFEAECF0),
                  ),
                ),
                child: ListTile(
                  title: Text(
                    group.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  leading: CircleAvatar(
                    backgroundColor:
                    const Color(0xFFECFDF3),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Color(0xFF079455),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  trailing: ReorderableDragStartListener(
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

      final item = _groups!.removeAt(oldIndex);
      _groups!.insert(newIndex, item);
    });
  }

  Future<void> _save() async {
    final groups = _groups;

    if (groups == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final repository = ref.read(
        categoryRepositoryProvider,
      );

      await repository.reorderGroups(
        groups.map((group) => group.id).toList(),
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
            'Could not save group order.',
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
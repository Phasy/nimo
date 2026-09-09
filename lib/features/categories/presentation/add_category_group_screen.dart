import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/category_group.dart';
import '../application/category_providers.dart';

class AddCategoryGroupScreen extends ConsumerStatefulWidget {
  const AddCategoryGroupScreen({
    super.key,
    required this.type,
    this.group,
  });

  final CategoryType type;
  final CategoryGroup? group;

  @override
  ConsumerState<AddCategoryGroupScreen> createState() =>
      _AddCategoryGroupScreenState();
}

class _AddCategoryGroupScreenState
    extends ConsumerState<AddCategoryGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  bool _isSaving = false;

  bool get _isEditing => widget.group != null;

  @override
  void initState() {
    super.initState();

    final group = widget.group;

    if (group != null) {
      _nameController.text = group.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit group' : 'Add group',
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFEAECF0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Group details',
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
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g. Education',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';

                      if (trimmed.isEmpty) {
                        return 'Enter a group name.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  Text(
                    widget.type == CategoryType.expense
                        ? 'This group will contain expense categories.'
                        : 'This group will contain income categories.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color: const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : Text(
                  _isEditing
                      ? 'Save changes'
                      : 'Add group',
                ),
              ),
            ),

            if (_isEditing) ...[
              const SizedBox(height: 14),

              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed:
                  _isSaving ? null : _confirmDeactivate,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF04438),
                    side: const BorderSide(
                      color: Color(0xFFF04438),
                    ),
                  ),
                  child: const Text('Deactivate group'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
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

      final duplicateExists = await repository.groupNameExists(
        name: name,
        type: widget.type,
        excludingGroupId: widget.group?.id,
      );

      if (duplicateExists) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'A ${widget.type.name} group named "$name" already exists.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );

        setState(() {
          _isSaving = false;
        });

        return;
      }

      if (_isEditing) {
        final current = widget.group!;

        final updated = current.copyWith(
          name: name,
          updatedAt: DateTime.now(),
        );

        await repository.updateGroup(updated);
      } else {
        final groups = await ref.read(
          categoryGroupsProvider(widget.type).future,
        );

        final nextSortOrder = groups.isEmpty
            ? 0
            : groups
            .map(
              (group) => group.sortOrder,
        )
            .reduce(
              (a, b) => a > b ? a : b,
        ) +
            1;

        await repository.createGroup(
          name: name,
          type: widget.type,
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
                ? 'Could not update group.'
                : 'Could not add group.',
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
    final group = widget.group;

    if (group == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Deactivate group?'),
          content: Text(
            '${group.name} and all active categories inside it will be deactivated. Historical transactions will keep their existing category references.',
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

      await repository.deactivateGroup(
        group.id,
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
            'Could not deactivate group.',
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
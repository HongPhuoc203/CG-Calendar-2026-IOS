import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/event_type_model.dart';
import '../../providers/event_types_provider.dart';
import '../../providers/repositories_providers.dart';

/// Event Type Management Screen - CRUD operations for event types
class EventTypeManagementScreen extends ConsumerWidget {
  const EventTypeManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventTypesAsync = ref.watch(eventTypesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: eventTypesAsync.when(
        data: (eventTypes) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(eventTypesStreamProvider);
            },
            child: eventTypes.isEmpty
                ? _buildEmptyState(context, ref)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: eventTypes.length,
                    itemBuilder: (context, index) {
                      return _EventTypeCard(eventType: eventTypes[index]);
                    },
                  ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, stack) => Center(
          child: Text(
            'Error: $error',
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateEventTypeDialog(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.category_outlined,
            size: 64,
            color: AppColors.textDarkSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No event types yet',
            style: TextStyle(
              color: AppColors.textDarkSecondary.withValues(alpha: 0.7),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateEventTypeDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Create First Event Type'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateEventTypeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _EventTypeFormDialog(),
    );
  }
}

/// Card displaying event type information
class _EventTypeCard extends ConsumerWidget {
  final EventTypeModel eventType;

  const _EventTypeCard({required this.eventType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.category,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventType.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (eventType.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          eventType.description!,
                          style: const TextStyle(
                            color: AppColors.textDarkSecondary,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  color: AppColors.primary,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => _EventTypeFormDialog(eventType: eventType),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  color: AppColors.error,
                  onPressed: () => _showDeleteDialog(context, ref),
                ),
              ],
            ),
          ),
          if (eventType.defaultChecklistItems.isNotEmpty) ...[
            const Divider(color: AppColors.borderDark, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.checklist,
                        size: 16,
                        color: AppColors.textDarkSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Default Checklist (${eventType.defaultChecklistItems.length} items)',
                        style: const TextStyle(
                          color: AppColors.textDarkSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...eventType.defaultChecklistItems.take(3).map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_box_outline_blank,
                            size: 16,
                            color: AppColors.textDarkSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item,
                              style: const TextStyle(
                                color: AppColors.textDarkSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (eventType.defaultChecklistItems.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+ ${eventType.defaultChecklistItems.length - 3} more items',
                        style: TextStyle(
                          color: AppColors.textDarkSecondary.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Delete Event Type?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete ${eventType.name}? This action cannot be undone.',
          style: const TextStyle(color: AppColors.textDarkSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final eventTypeRepo = ref.read(eventTypeRepositoryProvider);
                await eventTypeRepo.deleteEventType(eventType.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Event type deleted'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Dialog for creating/editing event type
class _EventTypeFormDialog extends ConsumerStatefulWidget {
  final EventTypeModel? eventType;

  const _EventTypeFormDialog({this.eventType});

  @override
  ConsumerState<_EventTypeFormDialog> createState() => _EventTypeFormDialogState();
}

class _EventTypeFormDialogState extends ConsumerState<_EventTypeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<String> _checklistItems = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.eventType != null) {
      _nameController.text = widget.eventType!.name;
      _descriptionController.text = widget.eventType!.description ?? '';
      _checklistItems = List.from(widget.eventType!.defaultChecklistItems);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.eventType != null;

    return AlertDialog(
      backgroundColor: AppColors.surfaceDark,
      title: Text(
        isEditing ? 'Edit Event Type' : 'Create Event Type',
        style: const TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    hintText: 'e.g. Live Performance, Photoshoot',
                    labelStyle: TextStyle(color: AppColors.textDarkSecondary),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter event type name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Optional description',
                    labelStyle: TextStyle(color: AppColors.textDarkSecondary),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Default Checklist',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addChecklistItem,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Item', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_checklistItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'No checklist items yet',
                        style: TextStyle(
                          color: AppColors.textDarkSecondary.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                else
                  ..._checklistItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.drag_indicator,
                            color: AppColors.textDarkSecondary,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            color: AppColors.error,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _checklistItems.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Text(isEditing ? 'Update' : 'Create'),
        ),
      ],
    );
  }

  void _addChecklistItem() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: AppColors.backgroundDark,
          title: const Text(
            'Add Checklist Item',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter item...',
              hintStyle: TextStyle(color: AppColors.textDarkSecondary),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    _checklistItems.add(controller.text.trim());
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final eventTypeRepo = ref.read(eventTypeRepositoryProvider);
      
      final eventType = EventTypeModel(
        id: widget.eventType?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        defaultChecklistItems: _checklistItems,
        createdAt: widget.eventType?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.eventType != null) {
        await eventTypeRepo.updateEventType(eventType);
      } else {
        await eventTypeRepo.createEventType(eventType);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.eventType != null ? 'Event type updated' : 'Event type created'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

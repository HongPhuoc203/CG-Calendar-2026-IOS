import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/enums/reminder_unit.dart';

/// Reminder option data
class ReminderOption {
  final String label;
  final int value;
  final ReminderUnit unit;

  const ReminderOption({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderOption &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          unit == other.unit;

  @override
  int get hashCode => value.hashCode ^ unit.hashCode;
}

/// Quick reminder options
class ReminderOptions {
  static const fiveDays = ReminderOption(
    label: '5 ngày trước',
    value: 5,
    unit: ReminderUnit.days,
  );

  static const twoDays = ReminderOption(
    label: '2 ngày trước',
    value: 2,
    unit: ReminderUnit.days,
  );

  static const oneDay = ReminderOption(
    label: '1 ngày trước',
    value: 1,
    unit: ReminderUnit.days,
  );

  static const twelveHours = ReminderOption(
    label: '12 giờ trước',
    value: 12,
    unit: ReminderUnit.hours,
  );

  static const oneHour = ReminderOption(
    label: '1 giờ trước',
    value: 1,
    unit: ReminderUnit.hours,
  );

  static const List<ReminderOption> quickOptions = [
    fiveDays,
    twoDays,
    oneDay,
    twelveHours,
    oneHour,
  ];
}

/// Reminder Picker Dialog - Select quick options or custom time
class ReminderPicker extends StatefulWidget {
  final List<ReminderOption> selectedReminders;
  final Function(List<ReminderOption>) onRemindersChanged;

  const ReminderPicker({
    super.key,
    required this.selectedReminders,
    required this.onRemindersChanged,
  });

  @override
  State<ReminderPicker> createState() => _ReminderPickerState();
}

class _ReminderPickerState extends State<ReminderPicker> {
  late List<ReminderOption> _selectedReminders;

  @override
  void initState() {
    super.initState();
    _selectedReminders = List.from(widget.selectedReminders);
  }

  void _toggleReminder(ReminderOption option) {
    setState(() {
      if (_selectedReminders.contains(option)) {
        _selectedReminders.remove(option);
      } else {
        _selectedReminders.add(option);
      }
    });
  }

  void _addCustomReminder() {
    showDialog(
      context: context,
      builder: (context) => _CustomReminderDialog(
        onAdd: (option) {
          setState(() {
            _selectedReminders.add(option);
          });
        },
      ),
    );
  }

  void _removeReminder(ReminderOption option) {
    setState(() {
      _selectedReminders.remove(option);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Quick Options
        const Text(
          'Chọn nhanh',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ReminderOptions.quickOptions.map((option) {
            final isSelected = _selectedReminders.contains(option);
            return FilterChip(
              selected: isSelected,
              label: Text(option.label),
              onSelected: (_) => _toggleReminder(option),
              selectedColor: AppColors.primary.withValues(alpha: 0.3),
              checkmarkColor: AppColors.primary,
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.borderDark,
              ),
              backgroundColor: AppColors.surfaceDark,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textDarkSecondary,
              ),
            );
          }).toList(),
        ),

        // Custom Option
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _addCustomReminder,
          icon: const Icon(Icons.add),
          label: const Text('Tùy chỉnh thời gian'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
          ),
        ),

        // Selected Custom Reminders
        if (_selectedReminders.any(
          (r) => !ReminderOptions.quickOptions.contains(r),
        )) ...[
          const SizedBox(height: 16),
          const Text(
            'Thông báo tùy chỉnh',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ..._selectedReminders
              .where((r) => !ReminderOptions.quickOptions.contains(r))
              .map((option) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      option.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.error,
                    onPressed: () => _removeReminder(option),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            );
          }).toList(),
        ],

        const SizedBox(height: 24),

        // Action Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                widget.onRemindersChanged(_selectedReminders);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Xong'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Custom Reminder Dialog - Input specific time
class _CustomReminderDialog extends StatefulWidget {
  final Function(ReminderOption) onAdd;

  const _CustomReminderDialog({required this.onAdd});

  @override
  State<_CustomReminderDialog> createState() => _CustomReminderDialogState();
}

class _CustomReminderDialogState extends State<_CustomReminderDialog> {
  final _valueController = TextEditingController(text: '1');
  ReminderUnit _selectedUnit = ReminderUnit.hours;

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_valueController.text);
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số hợp lệ'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final option = ReminderOption(
      label: '$value ${_selectedUnit.displayName.toLowerCase()} trước',
      value: value,
      unit: _selectedUnit,
    );

    widget.onAdd(option);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceDark,
      title: const Text(
        'Tùy chỉnh thời gian',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _valueController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Số lượng',
                    labelStyle: TextStyle(color: AppColors.textDarkSecondary),
                    filled: true,
                    fillColor: AppColors.backgroundDark,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<ReminderUnit>(
                  value: _selectedUnit,
                  dropdownColor: AppColors.backgroundDark,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Đơn vị',
                    labelStyle: TextStyle(color: AppColors.textDarkSecondary),
                    filled: true,
                    fillColor: AppColors.backgroundDark,
                    border: OutlineInputBorder(),
                  ),
                  items: ReminderUnit.values.map((unit) {
                    return DropdownMenuItem(
                      value: unit,
                      child: Text(unit.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedUnit = value;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: const Text('Thêm'),
        ),
      ],
    );
  }
}

/// Show Reminder Picker Dialog
Future<void> showReminderPicker({
  required BuildContext context,
  required List<ReminderOption> selectedReminders,
  required Function(List<ReminderOption>) onRemindersChanged,
}) {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surfaceDark,
      title: const Text(
        'Cài đặt thông báo',
        style: TextStyle(color: Colors.white),
      ),
      contentPadding: const EdgeInsets.all(24),
      content: SizedBox(
        width: double.maxFinite,
        child: ReminderPicker(
          selectedReminders: selectedReminders,
          onRemindersChanged: onRemindersChanged,
        ),
      ),
    ),
  );
}

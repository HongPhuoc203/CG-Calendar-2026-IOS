import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/event_model.dart';
import '../../data/models/artist_model.dart';
import '../../data/models/event_type_model.dart';
import '../../core/enums/user_role.dart';
import '../../data/models/user_model.dart';
import '../../providers/artists_provider.dart';
import '../../providers/event_types_provider.dart';
import '../../providers/repositories_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/events_provider.dart';
import '../../data/models/reminder_model.dart';
import '../widgets/reminder_picker.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/utils/logger.dart';

/// Create/Edit Event Screen - For creating new events or editing existing ones
class CreateEditEventScreen extends ConsumerStatefulWidget {
  final EventModel? event; // null = create, non-null = edit
  final DateTime? initialDate; // pre-fills start date when launching from calendar

  const CreateEditEventScreen({
    super.key,
    this.event,
    this.initialDate,
  });

  @override
  ConsumerState<CreateEditEventScreen> createState() => _CreateEditEventScreenState();
}

class _CreateEditEventScreenState extends ConsumerState<CreateEditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 1));
  bool _isAllDay = false;

  List<String> _selectedArtistIds = [];
  String? _selectedEventTypeId;
  List<ChecklistItem> _checklistItems = [];
  Map<String, dynamic> _customFields = {};
  List<EventLink> _links = [];
  List<ReminderOption> _reminderOptions = [];

  // Finance data
  double _revenue = 0;
  List<ExpenseItem> _expenses = [];
  int _artistSharePercent = 60; // Configurable, default 60%

  bool _isLoading = false;
  bool _isEditMode = false;


  /// Artist name whose selection forces a specific share percentage.
  static const String _tangDuyTanName = 'Tăng Duy Tân';
  static const int _tangDuyTanSharePercent = 80;

  static const String _dba = 'DBA';
  static const int _dbaSharePercent = 0;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.event != null;

    if (_isEditMode) {
      _loadEventData();
    } else {
      // Default reminder: 1 hour before
      _reminderOptions = [ReminderOptions.oneHour, ReminderOptions.oneDay];

      if (widget.initialDate != null) {
        final now = DateTime.now();
        final d = widget.initialDate!;
        _startTime = DateTime(d.year, d.month, d.day, now.hour, now.minute);
        _endTime = _startTime.add(const Duration(hours: 1));
      }
    }
  }

  void _loadEventData() {
    final event = widget.event!;
    _titleController.text = event.title;
    _descriptionController.text = event.description ?? '';
    _locationController.text = event.location ?? '';
    _notesController.text = event.notes ?? '';
    _startTime = event.startTime;
    _endTime = event.endTime;
    _isAllDay = event.isAllDay;
    _selectedArtistIds = List.from(event.artistIds);
    _selectedEventTypeId = event.eventTypeId;
    _checklistItems = event.checklistItems.map((item) => item.copyWith()).toList();
    _customFields = Map.from(event.customFields);
    _links = event.links.map((link) => link.copyWith()).toList();

    // Load finance data
    if (event.finance != null) {
      _revenue = event.finance!.revenue;
      _expenses = event.finance!.expenses.map((e) => e.copyWith()).toList();
      _artistSharePercent = event.finance!.artistSharePercent;
    }

    _loadReminders();
  }

  Future<void> _loadReminders() async {
    if (!_isEditMode) return;

    try {
      final reminderRepo = ref.read(reminderRepositoryProvider);
      final reminders = await reminderRepo.getRemindersByEventId(widget.event!.id);

      setState(() {
        _reminderOptions = reminders.map((r) {
          return ReminderOption(
            label: r.displayText,
            value: r.value,
            unit: r.unit,
          );
        }).toList();
      });
    } catch (e) {
      // Ignore errors on loading reminders
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _startTime : _endTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surfaceDark,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date == null || !mounted) return;

    if (_isAllDay) {
      setState(() {
        if (isStart) {
          _startTime = DateTime(date.year, date.month, date.day, 0, 0);
          if (_endTime.isBefore(_startTime)) {
            _endTime = DateTime(date.year, date.month, date.day, 23, 59);
          }
        } else {
          _endTime = DateTime(date.year, date.month, date.day, 23, 59);
        }
      });
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? _startTime : _endTime),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surfaceDark,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (time != null && mounted) {
      setState(() {
        final newDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );

        if (isStart) {
          _startTime = newDateTime;
          if (_endTime.isBefore(_startTime)) {
            _endTime = _startTime.add(const Duration(hours: 1));
          }
        } else {
          _endTime = newDateTime;
        }
      });
    }
  }

  Future<void> _loadEventTypeChecklist(String eventTypeId) async {
    try {
      final eventTypeRepo = ref.read(eventTypeRepositoryProvider);
      final eventType = await eventTypeRepo.getEventTypeById(eventTypeId);

      if (eventType != null && mounted) {
        setState(() {
          _checklistItems = eventType.defaultChecklistItems
              .map((item) => ChecklistItem(
            id: const Uuid().v4(),
            title: item,
            isCompleted: false,
          ))
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải checklist: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _addChecklistItem() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          title: const Text('Thêm mục checklist', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Nhập nội dung...',
              hintStyle: TextStyle(color: AppColors.textDarkSecondary),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    _checklistItems.add(ChecklistItem(
                      id: const Uuid().v4(),
                      title: controller.text,
                      isCompleted: false,
                    ));
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Thêm'),
            ),
          ],
        );
      },
    );
  }

  void _addCustomField() {
    showDialog(
      context: context,
      builder: (context) {
        final keyController = TextEditingController();
        final valueController = TextEditingController();
        return AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          title: const Text('Thêm trường tùy chỉnh', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keyController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Tên trường',
                  labelStyle: TextStyle(color: AppColors.textDarkSecondary),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: valueController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Giá trị',
                  labelStyle: TextStyle(color: AppColors.textDarkSecondary),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                if (keyController.text.isNotEmpty && valueController.text.isNotEmpty) {
                  setState(() {
                    _customFields[keyController.text] = valueController.text;
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Thêm'),
            ),
          ],
        );
      },
    );
  }

  void _addLink() {
    showDialog(
      context: context,
      builder: (context) {
        final titleController = TextEditingController();
        final urlController = TextEditingController();
        String linkType = 'other';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceDark,
              title: const Text('Thêm link', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Tiêu đề',
                      labelStyle: TextStyle(color: AppColors.textDarkSecondary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: urlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'URL',
                      hintText: 'https://...',
                      labelStyle: TextStyle(color: AppColors.textDarkSecondary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: linkType,
                    dropdownColor: AppColors.surfaceDark,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Loại',
                      labelStyle: TextStyle(color: AppColors.textDarkSecondary),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'drive', child: Text('Google Drive')),
                      DropdownMenuItem(value: 'other', child: Text('Khác')),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        linkType = value!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.isNotEmpty && urlController.text.isNotEmpty) {
                      setState(() {
                        _links.add(EventLink(
                          id: const Uuid().v4(),
                          title: titleController.text,
                          url: urlController.text,
                          type: linkType,
                        ));
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Thêm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedArtistIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất một nghệ sĩ'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedEventTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn loại sự kiện'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(authStateProvider).value;
      if (currentUser == null) throw Exception('User not authenticated');

      final eventRepo = ref.read(eventRepositoryProvider);

      final eventId = _isEditMode ? widget.event!.id : const Uuid().v4();

      // Always persist finance so artistSharePercent is never lost,
      // even when revenue and expenses are both zero.
      final finance = EventFinance(
        revenue: _revenue,
        expenses: _expenses,
        artistSharePercent: _artistSharePercent,
      );

      final effectiveStart = _isAllDay
          ? DateTime(_startTime.year, _startTime.month, _startTime.day, 0, 0)
          : _startTime;
      final effectiveEnd = _isAllDay
          ? DateTime(_endTime.year, _endTime.month, _endTime.day, 23, 59)
          : _endTime;

      final event = EventModel(
        id: eventId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        startTime: effectiveStart,
        endTime: effectiveEnd,
        isAllDay: _isAllDay,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        artistIds: _selectedArtistIds,
        eventTypeId: _selectedEventTypeId!,
        checklistItems: _checklistItems,
        customFields: _customFields,
        links: _links,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        finance: finance,
        createdBy: _isEditMode ? widget.event!.createdBy : currentUser.uid,
        createdAt: _isEditMode ? widget.event!.createdAt : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_isEditMode) {
        await eventRepo.updateEvent(event);
      } else {
        await eventRepo.createEvent(event);
      }

      await _saveReminders(event.id);

      ref.invalidate(eventsStreamProvider);

      if (!_isEditMode && _reminderOptions.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? 'Đã cập nhật sự kiện' : 'Đã tạo sự kiện'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
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

  @override
  Widget build(BuildContext context) {
    final artistsAsync = ref.watch(artistsStreamProvider);
    final eventTypesAsync = ref.watch(eventTypesStreamProvider);
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final userProfile = userProfileAsync.value;

    ref.listen<AsyncValue<UserModel?>>(currentUserProfileProvider, (previous, next) {
      if (!_isEditMode && _selectedArtistIds.isEmpty) {
        next.whenData((user) {
          if (user != null && user.role == UserRole.editor && user.managedArtistIds.isNotEmpty) {
            setState(() {
              _selectedArtistIds = List.from(user.managedArtistIds);
            });
          }
        });
      }
    });

    final filteredArtistsAsync = artistsAsync.whenData((artists) {
      if (userProfile == null) return <ArtistModel>[];
      if (userProfile.role.canManageSystem) return artists;
      if (userProfile.role == UserRole.editor) {
        return artists
            .where((a) => userProfile.managedArtistIds.contains(a.id))
            .toList();
      }
      return <ArtistModel>[];
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditMode ? 'Sửa sự kiện' : 'Tạo sự kiện',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
                : const Text(
              'Lưu',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Thông tin cơ bản'),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _titleController,
                label: 'Tiêu đề sự kiện',
                hint: 'Nhập tiêu đề...',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tiêu đề';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _descriptionController,
                label: 'Mô tả',
                hint: 'Nhập mô tả...',
                maxLines: 3,
              ),

              const SizedBox(height: 32),

              _buildSectionTitle('Thời gian'),
              const SizedBox(height: 16),
              _buildAllDayToggle(),
              const SizedBox(height: 12),
              _buildDateTimePicker(
                label: 'Bắt đầu',
                dateTime: _startTime,
                onTap: () => _selectDate(context, true),
              ),
              const SizedBox(height: 16),
              _buildDateTimePicker(
                label: 'Kết thúc',
                dateTime: _endTime,
                onTap: () => _selectDate(context, false),
              ),

              const SizedBox(height: 32),

              _buildSectionTitle('Địa điểm'),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _locationController,
                label: 'Địa điểm',
                hint: 'Nhập địa điểm...',
                prefixIcon: Icons.location_on_outlined,
              ),

              const SizedBox(height: 32),

              _buildSectionTitle('Nghệ sĩ'),
              const SizedBox(height: 16),
              filteredArtistsAsync.when(
                data: (artists) => _buildArtistsSelector(
                  artists,
                  allArtists: artistsAsync.value ?? artists,
                  isLocked: userProfile?.role == UserRole.editor,
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text('Lỗi: $error', style: const TextStyle(color: AppColors.error)),
              ),

              const SizedBox(height: 32),

              _buildSectionTitle('Loại sự kiện'),
              const SizedBox(height: 16),
              eventTypesAsync.when(
                data: (eventTypes) => _buildEventTypeSelector(eventTypes),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text('Lỗi: $error', style: const TextStyle(color: AppColors.error)),
              ),

              const SizedBox(height: 32),

              _buildSectionTitle('Checklist'),
              const SizedBox(height: 8),
              Text(
                'Các mục công việc cần hoàn thành',
                style: TextStyle(
                  color: AppColors.textDarkSecondary.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              _buildChecklistEditor(),

              const SizedBox(height: 32),

              _buildSectionTitle('Thông tin bổ sung'),
              const SizedBox(height: 16),
              _buildCustomFieldsEditor(),

              const SizedBox(height: 32),

              _buildSectionTitle('Links & Tài liệu'),
              const SizedBox(height: 16),
              _buildLinksEditor(),

              const SizedBox(height: 32),

              _buildSectionTitle('Ghi chú'),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _notesController,
                label: 'Ghi chú',
                hint: 'Thêm ghi chú...',
                maxLines: 4,
              ),

              const SizedBox(height: 32),

              _buildSectionTitle('Thông báo'),
              const SizedBox(height: 8),
              Text(
                'Nhắc nhở trước khi sự kiện bắt đầu',
                style: TextStyle(
                  color: AppColors.textDarkSecondary.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              _buildRemindersEditor(),

              const SizedBox(height: 32),

              _buildSectionTitle('Tài chính'),
              const SizedBox(height: 8),
              Text(
                'Quản lý doanh thu và chi phí',
                style: TextStyle(
                  color: AppColors.textDarkSecondary.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              _buildFinanceEditor(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Shared UI helpers ───────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    IconData? prefixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppColors.textDarkSecondary) : null,
        labelStyle: const TextStyle(color: AppColors.textDarkSecondary),
        hintStyle: const TextStyle(color: AppColors.textDarkSecondary),
        filled: true,
        fillColor: AppColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildAllDayToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isAllDay ? AppColors.primary : AppColors.borderDark,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.wb_sunny_outlined,
            color: _isAllDay ? AppColors.primary : AppColors.textDarkSecondary,
            size: 22,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Sự kiện cả ngày',
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
          Switch(
            value: _isAllDay,
            activeColor: AppColors.primary,
            onChanged: (value) {
              setState(() {
                _isAllDay = value;
                if (value) {
                  _startTime = DateTime(
                      _startTime.year, _startTime.month, _startTime.day, 0, 0);
                  _endTime = DateTime(
                      _endTime.year, _endTime.month, _endTime.day, 23, 59);
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimePicker({
    required String label,
    required DateTime dateTime,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Row(
          children: [
            Icon(
              label == 'Bắt đầu' ? Icons.event_outlined : Icons.event_available_outlined,
              color: AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textDarkSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isAllDay
                        ? DateFormat('EEEE, d MMMM y').format(dateTime)
                        : DateFormat('EEEE, d MMMM y - HH:mm').format(dateTime),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textDarkSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistsSelector(
      List<ArtistModel> artists, {
        /// Full (unfiltered) artist list used for the share-percent auto-rule.
        List<ArtistModel> allArtists = const [],
        bool isLocked = false,
      }) {
    if (artists.isEmpty) {
      return const Text(
        'Không có nghệ sĩ nào được gán',
        style: TextStyle(color: AppColors.textDarkSecondary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isLocked) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bạn chỉ có thể chọn nghệ sĩ được gán cho tài khoản',
                    style: TextStyle(
                      color: AppColors.primary.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: artists.map((artist) {
            final isSelected = _selectedArtistIds.contains(artist.id);
            return FilterChip(
              selected: isSelected,
              label: Text(artist.name),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedArtistIds.add(artist.id);
                  } else {
                    _selectedArtistIds.remove(artist.id);
                  }

                  // Tự động cập nhật tỉ lệ chia sẻ dựa trên danh sách nghệ sĩ đã chọn
                  final selectedArtists = allArtists.where((a) => _selectedArtistIds.contains(a.id)).toList();
                  bool hasDBA = selectedArtists.any((a) => a.name.trim().toUpperCase() == _dba.toUpperCase());
                  bool hasTDT = selectedArtists.any((a) => a.name.trim().toUpperCase() == _tangDuyTanName.toUpperCase());

                  if (hasDBA) {
                    _artistSharePercent = _dbaSharePercent; // 0%
                  } else if (hasTDT) {
                    _artistSharePercent = _tangDuyTanSharePercent; // 80%
                  } else if (_selectedArtistIds.isNotEmpty) {
                    // Nếu không có nghệ sĩ đặc biệt, và tỉ lệ đang là 0% hoặc 80% (do tự động gán trước đó), đưa về 60%
                    if (_artistSharePercent == _dbaSharePercent || _artistSharePercent == _tangDuyTanSharePercent) {
                      _artistSharePercent = 60;
                    }
                  }
                });
              },
              selectedColor: ArtistModelX(artist).color.withValues(alpha: 0.3),
              checkmarkColor: ArtistModelX(artist).color,
              side: BorderSide(color: ArtistModelX(artist).color),
              backgroundColor: AppColors.surfaceDark,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textDarkSecondary,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEventTypeSelector(List<EventTypeModel> eventTypes) {
    if (eventTypes.isEmpty) {
      return const Text(
        'Không có loại sự kiện nào',
        style: TextStyle(color: AppColors.textDarkSecondary),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedEventTypeId,
      dropdownColor: AppColors.surfaceDark,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Chọn loại sự kiện',
        hintStyle: const TextStyle(color: AppColors.textDarkSecondary),
        filled: true,
        fillColor: AppColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
      ),
      items: eventTypes.map((type) {
        return DropdownMenuItem(
          value: type.id,
          child: Text(type.name),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedEventTypeId = value;
        });
        if (value != null && !_isEditMode) {
          _loadEventTypeChecklist(value);
        }
      },
    );
  }

  Widget _buildChecklistEditor() {
    return Column(
      children: [
        ..._checklistItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Row(
              children: [
                const Icon(Icons.drag_indicator, color: AppColors.textDarkSecondary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: AppColors.error,
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
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _addChecklistItem,
          icon: const Icon(Icons.add),
          label: const Text('Thêm mục checklist'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomFieldsEditor() {
    return Column(
      children: [
        if (_customFields.isEmpty)
          Text(
            'Chưa có thông tin bổ sung',
            style: TextStyle(
              color: AppColors.textDarkSecondary.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          )
        else
          ..._customFields.entries.map((entry) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        color: AppColors.textDarkSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: Text(
                      entry.value.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.error,
                    onPressed: () {
                      setState(() {
                        _customFields.remove(entry.key);
                      });
                    },
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _addCustomField,
          icon: const Icon(Icons.add),
          label: const Text('Thêm trường'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildLinksEditor() {
    return Column(
      children: [
        if (_links.isEmpty)
          Text(
            'Chưa có link nào',
            style: TextStyle(
              color: AppColors.textDarkSecondary.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          )
        else
          ..._links.asMap().entries.map((entry) {
            final index = entry.key;
            final link = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Row(
                children: [
                  Icon(
                    link.type == 'drive' ? Icons.folder_outlined : Icons.link,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          link.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          link.url,
                          style: const TextStyle(
                            color: AppColors.textDarkSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.error,
                    onPressed: () {
                      setState(() {
                        _links.removeAt(index);
                      });
                    },
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _addLink,
          icon: const Icon(Icons.add),
          label: const Text('Thêm link'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildRemindersEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_reminderOptions.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_off_outlined,
                  color: AppColors.textDarkSecondary.withValues(alpha: 0.7),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Chưa có thông báo',
                  style: TextStyle(
                    color: AppColors.textDarkSecondary.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else
          ..._reminderOptions.map((option) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_active_outlined,
                    color: AppColors.primary,
                    size: 20,
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
                ],
              ),
            );
          }).toList(),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            showReminderPicker(
              context: context,
              selectedReminders: _reminderOptions,
              onRemindersChanged: (options) {
                setState(() {
                  _reminderOptions = options;
                });
              },
            );
          },
          icon: const Icon(Icons.add),
          label: Text(_reminderOptions.isEmpty ? 'Thêm thông báo' : 'Sửa thông báo'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Future<List<String>> _getRecipientUserIds({
    required String creatorUid,
    required List<String> eventArtistIds,
  }) async {
    final uids = <String>{creatorUid};

    try {
      final userRepo = ref.read(userRepositoryProvider);
      final allActiveUsers = await userRepo.getAllActiveUsers();

      for (final user in allActiveUsers) {
        if (user.role.canManageSystem) {
          uids.add(user.id);
          continue;
        }

        if (user.role == UserRole.editor) {
          final isRelevant = user.managedArtistIds
              .any((id) => eventArtistIds.contains(id));
          if (isRelevant) uids.add(user.id);
          continue;
        }

        if (user.role == UserRole.viewer && user.artistId != null) {
          if (eventArtistIds.contains(user.artistId)) {
            uids.add(user.id);
          }
        }
      }
    } catch (e) {
      logger.w('⚠️ _getRecipientUserIds failed, fallback to creator: $e');
    }

    return uids.toList();
  }

  Future<void> _saveReminders(String eventId) async {
    if (_reminderOptions.isEmpty) {
      if (_isEditMode) {
        try {
          final reminderRepo = ref.read(reminderRepositoryProvider);
          await reminderRepo.deleteRemindersByEventId(eventId);
        } catch (_) {}
      }
      return;
    }

    try {
      final reminderRepo = ref.read(reminderRepositoryProvider);
      final currentUser = ref.read(authStateProvider).value;
      if (currentUser == null) return;

      final recipientIds = await _getRecipientUserIds(
        creatorUid: currentUser.uid,
        eventArtistIds: _selectedArtistIds,
      );

      logger.i('📬 recipientIds (${recipientIds.length}): $recipientIds');

      final reminders = _reminderOptions.map((option) {
        final triggerTime = _startTime.subtract(
          option.unit.toDuration(option.value),
        );
        return ReminderModel(
          id: const Uuid().v4(),
          eventId: eventId,
          value: option.value,
          unit: option.unit,
          recipientUserIds: recipientIds,
          triggerTime: triggerTime,
          isSent: false,
          createdAt: DateTime.now(),
        );
      }).toList();

      if (_isEditMode) {
        await reminderRepo.replaceRemindersForEvent(eventId, reminders);
      } else {
        await reminderRepo.createReminders(reminders);
      }

      logger.i('✅ Saved ${reminders.length} reminders → ${recipientIds.length} recipients');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cảnh báo: Không thể lưu thông báo. Lỗi: $e'),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ─── Finance editor ──────────────────────────────────────────────────────────

  Widget _buildFinanceEditor() {
    final artistShareAmount = _revenue * (_artistSharePercent / 100);
    final totalExpenses = _expenses.fold<double>(0, (sum, item) => sum + item.amount);
    final netIncome = _revenue - totalExpenses - artistShareAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Revenue input ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.attach_money,
                      color: AppColors.success,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Doanh thu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  prefixText: '₫ ',
                  prefixStyle: const TextStyle(
                    color: AppColors.success,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  hintText: '0',
                  hintStyle: TextStyle(
                    color: AppColors.textDarkSecondary.withValues(alpha: 0.5),
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _revenue = NumberFormatter.parse(value);
                  });
                },
                controller: TextEditingController(
                  text: _revenue > 0 ? NumberFormatter.format(_revenue) : '',
                )..selection = TextSelection.collapsed(
                  offset: _revenue > 0 ? NumberFormatter.format(_revenue).length : 0,
                ),
              ),
              // Artist share selector & preview
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            children: [
                              Icon(
                                Icons.percent,
                                size: 16,
                                color: AppColors.warning.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 8),
                              const Flexible(
                                child: Text(
                                  'Tỉ lệ nghệ sĩ nhận',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Nút tăng/giảm để chỉnh đơn vị 5%
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 14),
                                color: AppColors.warning,
                                onPressed: _artistSharePercent > 0
                                    ? () => setState(() {
                                          _artistSharePercent = (_artistSharePercent - 5).clamp(0, 100);
                                        })
                                    : null,
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                              ),
                              SizedBox(
                                width: 36,
                                child: Text(
                                  '$_artistSharePercent%',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.warning,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 14),
                                color: AppColors.warning,
                                onPressed: _artistSharePercent < 80
                                    ? () => setState(() {
                                          _artistSharePercent = (_artistSharePercent + 5).clamp(0, 100);
                                        })
                                    : null,
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Các nút chọn nhanh
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [30, 50, 60, 80].map((p) {
                        final isSelected = _artistSharePercent == p;
                        return InkWell(
                          onTap: () => setState(() => _artistSharePercent = p),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.warning : AppColors.surfaceDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? AppColors.warning : AppColors.borderDark,
                              ),
                            ),
                            child: Text(
                              '$p%',
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (_revenue > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Thành tiền: ${artistShareAmount.toVND()}',
                          style: TextStyle(
                            color: AppColors.warning.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Expenses list ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.remove_circle_outline,
                      color: AppColors.error,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Chi phí',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    totalExpenses.toVND(),
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (_expenses.isNotEmpty) ...[
                const SizedBox(height: 12),
                ..._expenses.asMap().entries.map((entry) {
                  final index = entry.key;
                  final expense = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            expense.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          expense.amount.toVND(),
                          style: const TextStyle(
                            color: AppColors.textDarkSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          color: AppColors.primary,
                          onPressed: () => _editExpense(index),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Chỉnh sửa',
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          color: AppColors.error,
                          onPressed: () {
                            setState(() {
                              _expenses.removeAt(index);
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Xóa',
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addExpense,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Thêm chi phí'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Net income summary ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: netIncome >= 0
                  ? [
                AppColors.success.withValues(alpha: 0.2),
                AppColors.success.withValues(alpha: 0.1),
              ]
                  : [
                AppColors.error.withValues(alpha: 0.2),
                AppColors.error.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: netIncome >= 0 ? AppColors.success : AppColors.error,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thu nhập ròng',
                    style: TextStyle(
                      color: AppColors.textDarkSecondary.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    netIncome.toVND(),
                    style: TextStyle(
                      color: netIncome >= 0 ? AppColors.success : AppColors.error,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Icon(
                netIncome >= 0 ? Icons.trending_up : Icons.trending_down,
                color: netIncome >= 0 ? AppColors.success : AppColors.error,
                size: 48,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _editExpense(int index) {
    final expense = _expenses[index];
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController(text: expense.name);
        final amountController = TextEditingController(
          text: NumberFormatter.format(expense.amount),
        );

        return AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          title: const Text(
            'Chỉnh sửa chi phí',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Tên chi phí',
                  labelStyle: TextStyle(color: AppColors.textDarkSecondary),
                  hintText: 'VD: Thuê quần áo',
                  hintStyle: TextStyle(color: AppColors.textDarkSecondary),
                  filled: true,
                  fillColor: AppColors.backgroundDark,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Số tiền',
                  labelStyle: TextStyle(color: AppColors.textDarkSecondary),
                  hintText: '0',
                  prefixText: '₫ ',
                  prefixStyle: TextStyle(color: AppColors.textDarkSecondary),
                  hintStyle: TextStyle(color: AppColors.textDarkSecondary),
                  filled: true,
                  fillColor: AppColors.backgroundDark,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && amountController.text.isNotEmpty) {
                  final amount = NumberFormatter.parse(amountController.text);
                  if (amount > 0) {
                    setState(() {
                      _expenses[index] = ExpenseItem(
                        id: expense.id,
                        name: nameController.text,
                        amount: amount,
                      );
                    });
                    Navigator.pop(context);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  void _addExpense() {
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController();
        final amountController = TextEditingController();

        return AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          title: const Text(
            'Thêm chi phí',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Tên chi phí',
                  labelStyle: TextStyle(color: AppColors.textDarkSecondary),
                  hintText: 'VD: Thuê quần áo',
                  hintStyle: TextStyle(color: AppColors.textDarkSecondary),
                  filled: true,
                  fillColor: AppColors.backgroundDark,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Số tiền',
                  labelStyle: TextStyle(color: AppColors.textDarkSecondary),
                  hintText: '0',
                  prefixText: '₫ ',
                  prefixStyle: TextStyle(color: AppColors.textDarkSecondary),
                  hintStyle: TextStyle(color: AppColors.textDarkSecondary),
                  filled: true,
                  fillColor: AppColors.backgroundDark,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && amountController.text.isNotEmpty) {
                  final amount = NumberFormatter.parse(amountController.text);
                  if (amount > 0) {
                    setState(() {
                      _expenses.add(ExpenseItem(
                        id: const Uuid().v4(),
                        name: nameController.text,
                        amount: amount,
                      ));
                    });
                    Navigator.pop(context);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Thêm'),
            ),
          ],
        );
      },
    );
  }
}
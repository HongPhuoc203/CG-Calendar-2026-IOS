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
import '../../providers/services_providers.dart';
import '../../providers/events_provider.dart';
import '../../data/models/reminder_model.dart';
import '../widgets/reminder_picker.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/utils/logger.dart';

/// Create/Edit Event Screen - For creating new events or editing existing ones
class CreateEditEventScreen extends ConsumerStatefulWidget {
  final EventModel? event; // null = create, non-null = edit

  const CreateEditEventScreen({
    super.key,
    this.event,
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
  
  List<String> _selectedArtistIds = [];
  String? _selectedEventTypeId;
  List<ChecklistItem> _checklistItems = [];
  Map<String, dynamic> _customFields = {};
  List<EventLink> _links = [];
  List<ReminderOption> _reminderOptions = [];
  
  // Finance data
  double _revenue = 0;
  List<ExpenseItem> _expenses = [];

  bool _isLoading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.event != null;
    
    if (_isEditMode) {
      _loadEventData();
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
    _selectedArtistIds = List.from(event.artistIds);
    _selectedEventTypeId = event.eventTypeId;
    _checklistItems = event.checklistItems.map((item) => item.copyWith()).toList();
    _customFields = Map.from(event.customFields);
    _links = event.links.map((link) => link.copyWith()).toList();
    
    // Load finance data
    if (event.finance != null) {
      _revenue = event.finance!.revenue;
      _expenses = event.finance!.expenses.map((e) => e.copyWith()).toList();
    }
    
    // Load reminders
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

    if (date != null && mounted) {
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
            // Auto-adjust end time if needed
            if (_endTime.isBefore(_startTime)) {
              _endTime = _startTime.add(const Duration(hours: 1));
            }
          } else {
            _endTime = newDateTime;
          }
        });
      }
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
      
      // Create finance data if revenue or expenses exist
      EventFinance? finance;
      if (_revenue > 0 || _expenses.isNotEmpty) {
        finance = EventFinance(
          revenue: _revenue,
          expenses: _expenses,
        );
      }

      final event = EventModel(
        id: eventId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        startTime: _startTime,
        endTime: _endTime,
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

      // Save reminders
      await _saveReminders(event.id);
      
      // Force refresh events list (đảm bảo UI cập nhật ngay)
      ref.invalidate(eventsStreamProvider);
      
      // Small delay to ensure Firestore commits the data
      if (!_isEditMode && _reminderOptions.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
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

    // Auto-select managed artists for editor when creating a new event
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

    // Filter artists based on user role:
    // - super_editor: sees all artists
    // - editor: only sees their managed artists
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
              // Title
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
              
              // Date & Time
              _buildSectionTitle('Thời gian'),
              const SizedBox(height: 16),
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
              
              // Location
              _buildSectionTitle('Địa điểm'),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _locationController,
                label: 'Địa điểm',
                hint: 'Nhập địa điểm...',
                prefixIcon: Icons.location_on_outlined,
              ),
              
              const SizedBox(height: 32),
              
              // Artists
              _buildSectionTitle('Nghệ sĩ'),
              const SizedBox(height: 16),
              filteredArtistsAsync.when(
                data: (artists) => _buildArtistsSelector(
                  artists,
                  isLocked: userProfile?.role == UserRole.editor,
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text('Lỗi: $error', style: const TextStyle(color: AppColors.error)),
              ),
              
              const SizedBox(height: 32),
              
              // Event Type
              _buildSectionTitle('Loại sự kiện'),
              const SizedBox(height: 16),
              eventTypesAsync.when(
                data: (eventTypes) => _buildEventTypeSelector(eventTypes),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text('Lỗi: $error', style: const TextStyle(color: AppColors.error)),
              ),
              
              const SizedBox(height: 32),
              
              // Checklist
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
              
              // Custom Fields
              _buildSectionTitle('Thông tin bổ sung'),
              const SizedBox(height: 16),
              _buildCustomFieldsEditor(),
              
              const SizedBox(height: 32),
              
              // Links
              _buildSectionTitle('Links & Tài liệu'),
              const SizedBox(height: 16),
              _buildLinksEditor(),
              
              const SizedBox(height: 32),
              
              // Notes
              _buildSectionTitle('Ghi chú'),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _notesController,
                label: 'Ghi chú',
                hint: 'Thêm ghi chú...',
                maxLines: 4,
              ),
              
              const SizedBox(height: 32),
              
              // Reminders
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
              
              // Finance
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
                    DateFormat('EEEE, d MMMM y - HH:mm').format(dateTime),
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

  Widget _buildArtistsSelector(List<ArtistModel> artists, {bool isLocked = false}) {
    if (artists.isEmpty) {
      return const Text(
        'Không có nghệ sĩ nào được gán',
        style: TextStyle(color: AppColors.textDarkSecondary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hint for editor
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
          // Only auto-load checklist when creating new event
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

  Future<void> _saveReminders(String eventId) async {
    if (_reminderOptions.isEmpty) return;

    try {
      final reminderRepo = ref.read(reminderRepositoryProvider);
      final localScheduler = ref.read(localNotificationSchedulerProvider);
      final currentUser = ref.read(authStateProvider).value;
      if (currentUser == null) return;

      // Delete existing reminders if editing
      if (_isEditMode) {
        await reminderRepo.deleteRemindersByEventId(eventId);
      }

      // Create new reminders
      final reminders = _reminderOptions.map((option) {
        final triggerTime = _startTime.subtract(
          option.unit.toDuration(option.value),
        );

        return ReminderModel(
          id: const Uuid().v4(),
          eventId: eventId,
          value: option.value,
          unit: option.unit,
          recipientUserIds: [currentUser.uid], // TODO: Add all relevant users
          triggerTime: triggerTime,
          isSent: false,
          createdAt: DateTime.now(),
        );
      }).toList();

      // Save to Firestore
      await reminderRepo.createReminders(reminders);
      
      // Schedule local notifications (không cần Cloud Functions!)
      final event = EventModel(
        id: eventId,
        title: _titleController.text,
        artistIds: _selectedArtistIds,
        startTime: _startTime,
        endTime: _endTime,
        eventTypeId: _selectedEventTypeId!,
        location: _locationController.text.trim(),
        notes: _notesController.text.trim(),
        checklistItems: _checklistItems,
        createdBy: currentUser.uid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await localScheduler.scheduleEventReminders(
        event: event,
        reminders: reminders,
      );
      
      logger.i('✅ Scheduled ${reminders.length} local notifications');
    } catch (e) {
      // Show error to user
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

  Widget _buildFinanceEditor() {
    final totalExpenses = _expenses.fold<double>(0, (sum, item) => sum + item.amount);
    final netIncome = _revenue - totalExpenses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Revenue input
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
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Expenses list
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

        // Net income summary
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

import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../../core/constants/app_colors.dart';
import '../../data/models/artist_model.dart';
import '../../data/models/event_model.dart';
import '../../providers/artists_provider.dart';
import '../../providers/repositories_providers.dart';

class ExportRevenueScreen extends ConsumerStatefulWidget {
  const ExportRevenueScreen({super.key});

  @override
  ConsumerState<ExportRevenueScreen> createState() =>
      _ExportRevenueScreenState();
}

class _ExportRevenueScreenState extends ConsumerState<ExportRevenueScreen> {
  DateTime _fromDate = DateTime(DateTime.now().year, 1, 1);
  DateTime _toDate = DateTime.now();
  bool _isExporting = false;

  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currencyFormat = NumberFormat('#,###', 'vi_VN');

  // --- Date pickers ---

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: _toDate,
      builder: _darkDatePickerTheme,
    );
    if (picked != null) setState(() => _fromDate = picked);
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: _fromDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: _darkDatePickerTheme,
    );
    if (picked != null) setState(() => _toDate = picked);
  }

  Widget Function(BuildContext, Widget?) get _darkDatePickerTheme =>
      (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.primary,
                surface: AppColors.surfaceDark,
              ),
            ),
            child: child!,
          );

  // --- Excel Export (Web-compatible) ---

  Future<void> _exportExcel(List<EventModel> events, List<ArtistModel> artists) async {
    setState(() => _isExporting = true);

    try {
      final artistMap = {for (var a in artists) a.id: a.name};
      final excel = Excel.createExcel();

      _buildEventDetailSheet(excel, events, artistMap);
      _buildExpenseDetailSheet(excel, events, artistMap);
      _buildSummaryByArtistSheet(excel, events, artistMap);

      // Remove default "Sheet1"
      excel.delete('Sheet1');

      // Get file bytes
      final bytes = excel.encode();
      if (bytes == null) throw Exception('Không thể tạo file Excel');

      // Generate filename
      final fileName =
          'DoanhThu_${_dateFormat.format(_fromDate).replaceAll('/', '-')}_den_${_dateFormat.format(_toDate).replaceAll('/', '-')}.xlsx';

      if (kIsWeb) {
        // Web: Trigger browser download
        _downloadFileWeb(bytes, fileName);
      } else {
        // Mobile/Desktop: Use share
        _shareFileMobile(bytes, fileName);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ File đã được tạo thành công!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi xuất file: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// Download file on web
  void _downloadFileWeb(List<int> bytes, String fileName) {
    final blob = html.Blob([Uint8List.fromList(bytes)]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  /// Share file on mobile/desktop
  Future<void> _shareFileMobile(List<int> bytes, String fileName) async {
    // This will only be called on mobile/desktop
    // For now, just download (similar to web)
    // You can implement actual file sharing here if needed
    throw UnimplementedError('Share on mobile not yet implemented');
  }

  // Sheet 1: Chi tiết từng sự kiện
  void _buildEventDetailSheet(
      Excel excel, List<EventModel> events, Map<String, String> artistMap) {
    final sheet = excel['Chi tiết sự kiện'];
    _setSheetHeaders(sheet, [
      'STT',
      'Tên sự kiện',
      'Nghệ sĩ',
      'Ngày bắt đầu',
      'Ngày kết thúc',
      'Doanh thu (₫)',
      'Tổng chi phí (₫)',
      'Lợi nhuận (₫)',
      'Địa điểm',
      'Ghi chú',
    ]);

    for (var i = 0; i < events.length; i++) {
      final e = events[i];
      final artistNames = e.artistIds
          .map((id) => artistMap[id] ?? id)
          .join(', ');
      final finance = e.finance;
      final revenue = finance?.revenue ?? 0;
      final expenses = finance?.totalExpenses ?? 0;
      final net = revenue - expenses;

      sheet.appendRow([
        TextCellValue((i + 1).toString()),
        TextCellValue(e.title),
        TextCellValue(artistNames),
        TextCellValue(_dateFormat.format(e.startTime)),
        TextCellValue(_dateFormat.format(e.endTime)),
        TextCellValue(_currencyFormat.format(revenue)),
        TextCellValue(_currencyFormat.format(expenses)),
        TextCellValue(_currencyFormat.format(net)),
        TextCellValue(e.location ?? ''),
        TextCellValue(e.notes ?? ''),
      ]);
    }

    // Totals row
    final totalRevenue = events.fold<double>(
        0, (s, e) => s + (e.finance?.revenue ?? 0));
    final totalExpenses = events.fold<double>(
        0, (s, e) => s + (e.finance?.totalExpenses ?? 0));
    final totalNet = totalRevenue - totalExpenses;

    sheet.appendRow([
      TextCellValue(''),
      TextCellValue('TỔNG CỘNG'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(_currencyFormat.format(totalRevenue)),
      TextCellValue(_currencyFormat.format(totalExpenses)),
      TextCellValue(_currencyFormat.format(totalNet)),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    _autoStyleTotalsRow(sheet);
  }

  // Sheet 2: Chi tiết từng khoản chi phí
  void _buildExpenseDetailSheet(
      Excel excel, List<EventModel> events, Map<String, String> artistMap) {
    final sheet = excel['Chi phí chi tiết'];
    _setSheetHeaders(sheet, [
      'STT',
      'Tên sự kiện',
      'Nghệ sĩ',
      'Ngày',
      'Tên chi phí',
      'Số tiền (₫)',
    ]);

    var row = 1;
    for (final e in events) {
      if (e.finance == null || e.finance!.expenses.isEmpty) continue;
      final artistNames =
          e.artistIds.map((id) => artistMap[id] ?? id).join(', ');

      for (final expense in e.finance!.expenses) {
        sheet.appendRow([
          TextCellValue(row.toString()),
          TextCellValue(e.title),
          TextCellValue(artistNames),
          TextCellValue(_dateFormat.format(e.startTime)),
          TextCellValue(expense.name),
          TextCellValue(_currencyFormat.format(expense.amount)),
        ]);
        row++;
      }
    }
  }

  // Sheet 3: Tổng hợp theo nghệ sĩ
  void _buildSummaryByArtistSheet(
      Excel excel, List<EventModel> events, Map<String, String> artistMap) {
    final sheet = excel['Tổng hợp theo nghệ sĩ'];
    _setSheetHeaders(sheet, [
      'Nghệ sĩ',
      'Số sự kiện',
      'Doanh thu (₫)',
      'Tổng chi phí (₫)',
      'Lợi nhuận (₫)',
    ]);

    // Group by artist
    final Map<String, _ArtistStat> stats = {};
    for (final e in events) {
      for (final artistId in e.artistIds) {
        stats.putIfAbsent(
            artistId,
            () => _ArtistStat(name: artistMap[artistId] ?? artistId));
        stats[artistId]!.eventCount++;
        stats[artistId]!.revenue += e.finance?.revenue ?? 0;
        stats[artistId]!.expenses += e.finance?.totalExpenses ?? 0;
      }
    }

    for (final stat in stats.values) {
      sheet.appendRow([
        TextCellValue(stat.name),
        TextCellValue(stat.eventCount.toString()),
        TextCellValue(_currencyFormat.format(stat.revenue)),
        TextCellValue(_currencyFormat.format(stat.expenses)),
        TextCellValue(_currencyFormat.format(stat.revenue - stat.expenses)),
      ]);
    }
  }

  void _setSheetHeaders(Sheet sheet, List<String> headers) {
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#1565C0'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
  }

  void _autoStyleTotalsRow(Sheet sheet) {
    final lastRow = sheet.maxRows - 1;
    final totalStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#263238'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );
    for (var i = 0; i < 10; i++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: lastRow));
      cell.cellStyle = totalStyle;
    }
  }

  // --- Preview table (summary) ---

  Future<List<EventModel>> _fetchEvents() async {
    final repo = ref.read(eventRepositoryProvider);
    return repo.getEventsByDateRange(
      _fromDate,
      DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59),
    );
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final artistsAsync = ref.watch(artistsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        title: const Text('Xuất file Doanh thu',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Date range card ---
            _buildSectionCard(
              title: 'Chọn khoảng thời gian',
              icon: Icons.date_range,
              child: Row(
                children: [
                  Expanded(
                    child: _buildDateButton(
                      label: 'Từ ngày',
                      date: _fromDate,
                      onTap: _pickFromDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDateButton(
                      label: 'Đến ngày',
                      date: _toDate,
                      onTap: _pickToDate,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --- Excel content info ---
            _buildSectionCard(
              title: 'Nội dung file Excel',
              icon: Icons.table_chart_outlined,
              child: Column(
                children: [
                  _buildSheetInfo(
                    icon: Icons.event_note,
                    color: AppColors.primary,
                    name: 'Sheet 1 – Chi tiết sự kiện',
                    desc:
                        'Tên sự kiện, nghệ sĩ, ngày, doanh thu, chi phí, lợi nhuận',
                  ),
                  const SizedBox(height: 8),
                  _buildSheetInfo(
                    icon: Icons.receipt_long,
                    color: AppColors.warning,
                    name: 'Sheet 2 – Chi phí chi tiết',
                    desc: 'Từng khoản chi phí của từng sự kiện',
                  ),
                  const SizedBox(height: 8),
                  _buildSheetInfo(
                    icon: Icons.bar_chart,
                    color: AppColors.success,
                    name: 'Sheet 3 – Tổng hợp theo nghệ sĩ',
                    desc:
                        'Tổng doanh thu, chi phí, lợi nhuận gộp theo từng nghệ sĩ',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- Export button ---
            artistsAsync.when(
              data: (artists) => SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isExporting
                      ? null
                      : () async {
                          final events = await _fetchEvents();
                          if (!mounted) return;
                          if (events.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Không có sự kiện nào trong khoảng thời gian này'),
                                backgroundColor: AppColors.warning,
                              ),
                            );
                            return;
                          }
                          await _exportExcel(events, artists);
                        },
                  icon: _isExporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white),
                        )
                      : const Icon(Icons.download, size: 22),
                  label: Text(
                    _isExporting ? 'Đang tạo file...' : 'Xuất Excel',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Lỗi: $e',
                  style: const TextStyle(color: AppColors.error)),
            ),

            const SizedBox(height: 12),
            Center(
              child: Text(
                kIsWeb
                    ? 'File sẽ được tải xuống trực tiếp vào máy'
                    : 'File sẽ được chia sẻ sau khi tạo xong',
                style: TextStyle(
                  color: AppColors.textDarkSecondary.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
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
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildDateButton({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.backgroundDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textDarkSecondary, fontSize: 11)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  _dateFormat.format(date),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetInfo({
    required IconData icon,
    required Color color,
    required String name,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(desc,
                  style: const TextStyle(
                      color: AppColors.textDarkSecondary, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Internal helper for artist aggregation
class _ArtistStat {
  final String name;
  int eventCount = 0;
  double revenue = 0;
  double expenses = 0;

  _ArtistStat({required this.name});
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Trợ giúp',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // ── Hướng dẫn sử dụng ──────────────────────────────
            _buildSectionTitle('Hướng dẫn sử dụng'),
            const SizedBox(height: 12),

            _buildGuideItem(
              icon: Icons.calendar_today_outlined,
              title: 'Lịch sự kiện',
              description:
                  'Xem toàn bộ sự kiện theo tháng, tuần hoặc ngày. Nhấn vào sự kiện để xem chi tiết.',
            ),
            _buildGuideItem(
              icon: Icons.bar_chart_outlined,
              title: 'Doanh thu',
              description:
                  'Theo dõi doanh thu theo ngày, tuần hoặc tháng. Xem chi tiết từng sự kiện và nghệ sĩ.',
            ),
            _buildGuideItem(
              icon: Icons.notifications_outlined,
              title: 'Thông báo',
              description:
                  'Nhận thông báo nhắc nhở trước sự kiện. Cài đặt thời gian nhắc trong chi tiết sự kiện.',
            ),
            _buildGuideItem(
              icon: Icons.check_circle_outline,
              title: 'Checklist công việc',
              description:
                  'Mỗi sự kiện có danh sách công việc cần làm. Tick vào từng mục khi hoàn thành.',
            ),
            _buildGuideItem(
              icon: Icons.link_outlined,
              title: 'Liên kết tài liệu',
              description:
                  'Đính kèm link Google Drive hoặc tài liệu liên quan vào từng sự kiện để truy cập nhanh.',
            ),
            _buildGuideItem(
              icon: Icons.person_outline,
              title: 'Phân quyền người dùng',
              description:
                  'Viewer chỉ xem được thông tin của nghệ sĩ mình phụ trách. Editor quản lý nhiều nghệ sĩ. Super Editor có toàn quyền hệ thống.',
            ),

            const SizedBox(height: 28),

            // ── Liên hệ hỗ trợ ─────────────────────────────────
            _buildSectionTitle('Liên hệ hỗ trợ'),
            const SizedBox(height: 12),

            _buildContactItem(
              icon: Icons.email_outlined,
              title: 'Email hỗ trợ',
              subtitle: 'cgcalendar2@gmail.com',
              onTap: () => _launchUrl('mailto:cgcalendar2@gmail.com'),
            ),
            

            const SizedBox(height: 28),

            // ── Phiên bản ───────────────────────────────────────
            Center(
              child: Text(
                'Phiên bản 1.0.0',
                style: TextStyle(
                  color: AppColors.textDarkSecondary.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildGuideItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: AppColors.textDarkSecondary.withValues(alpha: 0.8),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderDark, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.success, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textDarkSecondary,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
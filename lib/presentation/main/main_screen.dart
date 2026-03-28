import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/enums/user_role.dart';
import '../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../home/home_screen.dart';
import '../calendar/calendar_screen.dart';
import '../revenue/revenue_screen.dart';
import '../profile/profile_screen.dart';
import '../ai_chat/ai_chat_screen.dart';

/// Main screen with bottom navigation
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _screensWithRevenue = [
    HomeScreen(),
    CalendarScreen(),
    RevenueScreen(),
    AiChatScreen(),
    ProfileScreen(),
  ];

  static const List<Widget> _screensEditor = [
    HomeScreen(),
    CalendarScreen(),
    AiChatScreen(),
    ProfileScreen(),
  ];

  static final BottomNavigationBarItem _aiNavItem = BottomNavigationBarItem(
    icon: ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF4285F4), Color(0xFF9C27B0)],
      ).createShader(bounds),
      child: const Icon(Icons.auto_awesome_outlined, color: Colors.white),
    ),
    activeIcon: ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF4285F4), Color(0xFF9C27B0)],
      ).createShader(bounds),
      child: const Icon(Icons.auto_awesome, color: Colors.white),
    ),
    label: 'AI',
  );

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<UserModel?>>(currentUserProfileProvider,
        (previous, next) {
      final nowEditor = next.maybeWhen(
        data: (u) => u?.role == UserRole.editor,
        orElse: () => false,
      );
      if (!nowEditor) return;

      final previousWasEditor = previous?.maybeWhen(
            data: (u) => u?.role == UserRole.editor,
            orElse: () => false,
          ) ??
          false;
      if (previousWasEditor) return;

      setState(() {
        if (_selectedIndex == 2) {
          _selectedIndex = 0;
        } else if (_selectedIndex > 2) {
          _selectedIndex -= 1;
        }
      });
    });

    final currentUser = ref.watch(currentUserProfileProvider);
    final isEditor = currentUser.maybeWhen(
      data: (u) => u?.role == UserRole.editor,
      orElse: () => false,
    );

    final screens = isEditor ? _screensEditor : _screensWithRevenue;
    final safeIndex = _selectedIndex.clamp(0, screens.length - 1);
    if (safeIndex != _selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedIndex = safeIndex);
      });
    }

    final items = isEditor
        ? [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Trang chủ',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Lịch',
            ),
            _aiNavItem,
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Cá nhân',
            ),
          ]
        : [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Trang chủ',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Lịch',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Doanh thu',
            ),
            _aiNavItem,
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Cá nhân',
            ),
          ];

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.borderDark, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: safeIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surfaceDark,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textDarkSecondary,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: items,
        ),
      ),
    );
  }
}

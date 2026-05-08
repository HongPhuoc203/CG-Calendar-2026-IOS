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
import '../revenue/dba_revenue_screen.dart';

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

  static const List<Widget> _screensEditorNoRevenue = [
    HomeScreen(),
    CalendarScreen(),
    AiChatScreen(),
    ProfileScreen(),
  ];

  static const List<Widget> _screensEditorWithRevenue = [
    HomeScreen(),
    CalendarScreen(),
    RevenueScreen(),
    AiChatScreen(),
    ProfileScreen(),
  ];

  static const List<Widget> _screensSuperEditor = [
    HomeScreen(),
    CalendarScreen(),
    RevenueScreen(),
    DBARevenueScreen(),
    AiChatScreen(),
    ProfileScreen(),
  ];

  static const BottomNavigationBarItem _dbaNavItem = BottomNavigationBarItem(
    icon: Icon(Icons.analytics_outlined),
    activeIcon: Icon(Icons.analytics),
    label: 'DBA',
  );

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
    // Clamp selected index khi screens list thay đổi do role/permission
    ref.listen<AsyncValue<UserModel?>>(currentUserProfileProvider,
        (previous, next) {
      final prevHasRevenue = previous?.maybeWhen(
            data: (u) {
              if (u == null) return false;
              if (u.role == UserRole.superEditor) return true;
              if (u.role == UserRole.editor) return u.canViewRevenue;
              return u.role != UserRole.editor;
            },
            orElse: () => false,
          ) ??
          false;

      final nowHasRevenue = next.maybeWhen(
        data: (u) {
          if (u == null) return false;
          if (u.role == UserRole.superEditor) return true;
          if (u.role == UserRole.editor) return u.canViewRevenue;
          return u.role != UserRole.editor;
        },
        orElse: () => false,
      );

      // Tab doanh thu (index 2) bị mất → reset về trang chủ nếu đang ở đó
      if (prevHasRevenue && !nowHasRevenue && _selectedIndex >= 2) {
        setState(() => _selectedIndex = 0);
      }
    });

    final currentUser = ref.watch(currentUserProfileProvider);
    final user = currentUser.asData?.value;
    final role = user?.role ?? UserRole.viewer;

    final isEditor = role == UserRole.editor;
    final isSuperEditor = role == UserRole.superEditor;
    final editorCanViewRevenue = isEditor && (user?.canViewRevenue ?? false);

    List<Widget> screens;
    if (isSuperEditor) {
      screens = _screensSuperEditor;
    } else if (isEditor) {
      screens = editorCanViewRevenue
          ? _screensEditorWithRevenue
          : _screensEditorNoRevenue;
    } else {
      screens = _screensWithRevenue;
    }

    final safeIndex = _selectedIndex.clamp(0, screens.length - 1);
    if (safeIndex != _selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedIndex = safeIndex);
      });
    }

    final items = [
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
      if (!isEditor || editorCanViewRevenue)
        const BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_outlined),
          activeIcon: Icon(Icons.bar_chart),
          label: 'Doanh thu',
        ),
      if (isSuperEditor) _dbaNavItem,
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

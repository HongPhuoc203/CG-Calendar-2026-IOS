import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
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

  final List<Widget> _screens = const [
    HomeScreen(),
    CalendarScreen(),
    RevenueScreen(),
    AiChatScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.borderDark, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surfaceDark,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textDarkSecondary,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: [
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
            // AI Tab với gradient icon
            BottomNavigationBarItem(
              icon: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF4285F4), Color(0xFF9C27B0)],
                ).createShader(bounds),
                child: const Icon(Icons.auto_awesome_outlined,
                    color: Colors.white),
              ),
              activeIcon: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF4285F4), Color(0xFF9C27B0)],
                ).createShader(bounds),
                child: const Icon(Icons.auto_awesome, color: Colors.white),
              ),
              label: 'AI',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Cá nhân',
            ),
          ],
        ),
      ),
    );
  }
}

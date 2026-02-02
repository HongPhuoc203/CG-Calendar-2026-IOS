import 'package:flutter/material.dart';

/// App color palette - Based on Stitch Design System
class AppColors {
  // Primary Colors (từ Stitch)
  static const Color primary = Color(0xFF195DE6); // #195de6
  static const Color primaryDark = Color(0xFF0D47B5);
  static const Color primaryLight = Color(0xFF4A7BED);
  
  // Background (Dark Mode chủ yếu)
  static const Color backgroundDark = Color(0xFF111621); // #111621
  static const Color backgroundLight = Color(0xFFF6F6F8); // #f6f6f8
  static const Color surfaceDark = Color(0xFF1A2233); // #1a2233 - Cards, inputs
  static const Color cardBackground = Colors.white;
  
  // Text Colors
  static const Color textPrimary = Color(0xFF1F2937); // gray-900
  static const Color textSecondary = Color(0xFF6B7280); // gray-500
  static const Color textDisabled = Color(0xFF9CA3AF); // gray-400
  static const Color textDark = Colors.white;
  static const Color textDarkSecondary = Color(0xFF93A5C8); // Stitch meta text
  
  // Status Colors
  static const Color success = Color(0xFF10B981); // green-500
  static const Color successLight = Color(0xFF34D399);
  static const Color warning = Color(0xFFF59E0B); // amber-500
  static const Color error = Color(0xFFEF4444); // red-500
  static const Color errorDark = Color(0xFF7F1D1D); // red-900
  static const Color info = Color(0xFF3B82F6); // blue-500
  
  // Event Status Colors (từ calendar design)
  static const Color confirmed = Color(0xFF10B981); // Green
  static const Color pending = Color(0xFFF59E0B); // Orange
  static const Color cancelled = Color(0xFF6B7280); // Gray
  
  // Artist Colors (for calendar events - vibrant colors)
  static const List<Color> artistColors = [
    Color(0xFFFF6B6B), // Red
    Color(0xFFED4A7B), // Pink
    Color(0xFF9B59B6), // Purple
    Color(0xFF3498DB), // Blue
    Color(0xFF1ABC9C), // Teal
    Color(0xFF16A085), // Dark Teal
    Color(0xFF2ECC71), // Green
    Color(0xFFF39C12), // Orange
    Color(0xFFE67E22), // Dark Orange
    Color(0xFFE74C3C), // Dark Red
  ];
  
  // Border Colors
  static const Color borderLight = Color(0xFFD1D5DB); // gray-300
  static const Color borderDark = Color(0xFF374151); // gray-700
  
  // Overlay & Shadows
  static const Color overlay = Color(0x80000000);
  static const Color shadowLight = Color(0x1A000000);
  static const Color shadowDark = Color(0x40000000);
}


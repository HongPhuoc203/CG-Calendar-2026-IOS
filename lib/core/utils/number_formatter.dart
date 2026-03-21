import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Format number with thousand separator (1.200.000)
class NumberFormatter {
  static final _formatter = NumberFormat('#,###', 'vi_VN');

  /// Format number to string with dots (1.200.000)
  static String format(num number) {
    return _formatter.format(number);
  }

  /// Format number as Vietnamese currency with ₫ symbol
  static String formatCurrency(num number) {
    return '₫${format(number)}';
  }

  /// Format number to compact string (e.g. 1.2tr, 500k)
  static String formatCompact(num number) {
    if (number.abs() >= 1000000000) {
      return '${(number / 1000000000).toStringAsFixed(1)}tỷ';
    } else if (number.abs() >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}tr';
    } else if (number.abs() >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}k';
    }
    return format(number);
  }

  /// Parse formatted string back to number
  static double parse(String text) {
    // Remove all dots and parse
    final cleaned = text.replaceAll('.', '').replaceAll(',', '');
    return double.tryParse(cleaned) ?? 0;
  }
}

/// TextInputFormatter for currency input with thousand separators
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Remove all non-digit characters
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.isEmpty) {
      return const TextEditingValue();
    }

    // Parse to number
    final number = int.tryParse(digitsOnly);
    if (number == null) {
      return oldValue;
    }

    // Format with thousand separators
    final formatted = NumberFormatter.format(number);

    // Calculate new cursor position
    int newOffset = formatted.length;
    if (newValue.selection.baseOffset < newValue.text.length) {
      // If cursor is not at the end, try to maintain relative position
      final digitsBeforeCursor = newValue.text
          .substring(0, newValue.selection.baseOffset)
          .replaceAll(RegExp(r'[^\d]'), '')
          .length;
      
      int currentDigits = 0;
      for (int i = 0; i < formatted.length; i++) {
        if (RegExp(r'\d').hasMatch(formatted[i])) {
          currentDigits++;
          if (currentDigits == digitsBeforeCursor) {
            newOffset = i + 1;
            break;
          }
        }
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}

/// Extension for currency display
extension CurrencyDisplay on num {
  /// Format as Vietnamese currency
  String toVND() {
    return '₫${NumberFormatter.format(this)}';
  }
}

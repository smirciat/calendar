import 'package:flutter/material.dart';

/// Preset colors for family calendar members (matches server auto-assign order).
const calendarColorPalette = [
  '#4285F4', // blue
  '#EA4335', // red
  '#34A853', // green
  '#FBBC04', // yellow
  '#AB47BC', // purple
  '#FF6D00', // orange
  '#00897B', // teal
  '#E91E63', // pink
  '#000000', // black
];

Color swatchCheckColor(String hex) {
  return parseCalendarColor(hex).computeLuminance() > 0.5
      ? Colors.black
      : Colors.white;
}

Color parseCalendarColor(String hex) {
  final value = hex.replaceFirst('#', '');
  return Color(int.parse('FF$value', radix: 16));
}

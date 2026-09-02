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

/// Text/icon color that contrasts with [background].
Color contrastingTextOn(Color background) {
  return background.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
}

Color swatchCheckColor(String hex) {
  return contrastingTextOn(parseCalendarColor(hex));
}

Color parseCalendarColor(String hex) {
  final value = hex.replaceFirst('#', '');
  return Color(int.parse('FF$value', radix: 16));
}

/// Chip fill + label colors for an event on [surface] (usually scaffold background).
class CalendarEventChipColors {
  const CalendarEventChipColors({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}

CalendarEventChipColors eventChipColors(String hex, Color surface) {
  final base = parseCalendarColor(hex);
  final background = base.computeLuminance() < 0.08
      ? base
      : Color.alphaBlend(base.withValues(alpha: 0.22), surface);

  return CalendarEventChipColors(
    background: background,
    foreground: contrastingTextOn(background),
  );
}

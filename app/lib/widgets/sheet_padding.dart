import 'package:flutter/material.dart';

/// Padding for modal bottom sheets so action buttons clear the keyboard
/// and Android/iOS system navigation areas.
EdgeInsets modalSheetPadding(
  BuildContext context, {
  double horizontal = 16,
  double base = 16,
}) {
  final media = MediaQuery.of(context);
  return EdgeInsets.fromLTRB(
    horizontal,
    0,
    horizontal,
    base + media.viewPadding.bottom + media.viewInsets.bottom,
  );
}

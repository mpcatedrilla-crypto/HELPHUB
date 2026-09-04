// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:helphub/theme/app_theme.dart';

void main() {
  test('HelpHub theme uses the production Material design system', () {
    final theme = AppTheme.lightTheme;

    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, AppTheme.primaryBlue);
    expect(theme.scaffoldBackgroundColor, AppTheme.backgroundColor);
    expect(theme.cardTheme.shape, isNotNull);
  });
}

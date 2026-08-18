import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mkvoodoo_ui/pages/settings_page.dart';
import 'package:mkvoodoo_ui/controllers/settings_controller.dart';
import 'package:mkvoodoo_ui/services/theme_provider.dart';
import 'package:mkvoodoo_ui/services/backend_bridge.dart';

class MockBackendBridge extends Fake implements BackendBridge {
  @override
  Future<Map<String, dynamic>> getConfig() async => {
    'output_dir': 'D:/Convert',
    'naming_template': 'S{S:02d}E{E:02d}',
    'parallel_jobs': 2,
    'tmdb_api_key': 'existing-key',
    'review_before_convert': true,
    'skip_existing': true,
    'show_notifications': true,
  };

  @override
  Future<List<Map<String, dynamic>>> getAvailableEncoders() async => [
    {'video_encoder': 'h264_nvenc', 'label': 'NVIDIA NVENC'},
    {'video_encoder': 'libx264', 'label': 'Software'},
  ];
}

void main() {
  testWidgets('SettingsPage renders TMDB API Key field', (
    WidgetTester tester,
  ) async {
    final mockBridge = MockBackendBridge();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => SettingsController(mockBridge)),
          Provider<BackendBridge>.value(value: mockBridge),
        ],
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );

    await tester.pumpAndSettle();

    // Verify presence of "Web Services" section
    expect(find.text('WEB SERVICES'), findsOneWidget);

    // Verify TMDB text field
    expect(find.text('TMDB API Key'), findsOneWidget);
    expect(find.text('existing-key'), findsOneWidget);

    // Verify update toggles
    expect(find.text('Automatic Update Checks'), findsOneWidget);
  });
}

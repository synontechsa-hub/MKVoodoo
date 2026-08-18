// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mkvoodoo_ui/main.dart';
import 'package:mkvoodoo_ui/services/backend_bridge.dart';
import 'package:mkvoodoo_ui/services/theme_provider.dart';
import 'package:mkvoodoo_ui/services/clipper_api.dart';
import 'package:mkvoodoo_ui/models/clip_media_info.dart';
import 'package:mkvoodoo_ui/models/clip_frame.dart';
import 'package:mkvoodoo_ui/models/thumbnail_candidate.dart';
import 'package:mkvoodoo_ui/controllers/dashboard_controller.dart';
import 'package:mkvoodoo_ui/controllers/wizard_controller.dart';
import 'package:mkvoodoo_ui/controllers/queue_controller.dart';
import 'package:mkvoodoo_ui/controllers/settings_controller.dart';
import 'package:mkvoodoo_ui/controllers/youtube_controller.dart';
import 'package:mkvoodoo_ui/controllers/navigation_controller.dart';
import 'package:mkvoodoo_ui/controllers/clipper_controller.dart';
import 'package:mkvoodoo_ui/models/backend_status.dart';

class MockBackendBridge extends BackendBridge {
  MockBackendBridge() : super.internal();
  @override
  Future<BackendStatus> checkStatus() async => BackendStatus.ready;

  @override
  Future<Map<String, dynamic>> getConfig() async => {
    'output_dir': 'C:/Videos',
    'naming_template': 'S{S:02d}E{E:02d} - {title}',
    'review_before_convert': true,
    'skip_existing': true,
  };

  @override
  Future<Map<String, dynamic>> getQueueStatus() async => {
    'jobs': [],
    'stats': {
      'active_jobs': 0,
      'done_jobs': 0,
      'failed_jobs': 0,
      'processed_gb': 0.0,
    },
    'storage': {'total_gb': 500, 'free_gb': 200, 'used_percent': 60},
    'hardware': {
      'label': 'CPU (Software)',
      'is_hardware': false,
      'video_encoder': 'libx264',
    },
  };

  @override
  Future<List<Map<String, dynamic>>> getAvailableEncoders() async => [];

  @override
  Future<Map<String, dynamic>> getYoutubeInfo(String url) async => {
    'title': 'Mock Video',
    'thumbnail': 'https://mock.com/thumb.jpg',
    'uploader': 'Mock Channel',
  };

  @override
  Stream<String> downloadYoutube(
    String url, {
    bool audioOnly = false,
    String format = 'mp3',
  }) async* {
    yield '🚀 Starting download...';
    yield '⏱ Progress: 50.0%';
    yield '✓ Downloaded to: C:/Downloads/mock.mp4';
  }

  @override
  Future<List<Map<String, dynamic>>> searchMetadata(
    String query, {
    bool isTv = false,
  }) async => [
    {
      'id': 1,
      'title': 'Mock Movie',
      'date': '2024-01-01',
      'poster_url': 'https://mock.com/poster.jpg',
      'overview': 'Mock overview',
    },
  ];
}

class FakeClipperApi implements ClipperApi {
  @override
  Future<ClipMediaInfo> getMediaInfo(String source) async => const ClipMediaInfo(
    source: 'mock.mp4',
    durationUs: 1000000,
    width: 1920,
    height: 1080,
    isVariableFrameRate: false,
    frameRateReason: 'cfr',
  );

  @override
  Future<List<ClipFrame>> getNearbyFrames(
    String source,
    int aroundUs, {
    int before = 1,
    int after = 1,
  }) async => [];

  @override
  Future<void> exportClip(
    String source,
    String output,
    int inUs,
    int outUs,
    String container,
  ) async {}

  @override
  Future<List<ThumbnailCandidate>> generateThumbnails(
    String source,
    int inUs,
    int outUs,
    String cacheDirectory,
  ) async => [];

  @override
  Future<void> saveThumbnail(
    String source,
    int timestampUs,
    String output,
    String format,
  ) async {}
}

void main() {
  testWidgets('Dashboard smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final bridge = MockBackendBridge();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<BackendBridge>.value(value: bridge),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(
            create: (context) => DashboardController(bridge),
          ),
          ChangeNotifierProvider(create: (context) => WizardController(bridge)),
          ChangeNotifierProvider(create: (context) => QueueController(bridge)),
          ChangeNotifierProvider(
            create: (context) => SettingsController(bridge),
          ),
          ChangeNotifierProvider(
            create: (context) => YoutubeController(bridge),
          ),
          ChangeNotifierProvider(create: (_) => NavigationController()),
          ChangeNotifierProvider(
            create: (_) => ClipperController(FakeClipperApi()),
          ),
        ],
        child: const MKVoodooApp(clipperPage: SizedBox.shrink()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('System Overview'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_to_photos_rounded));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('New Conversion Job'), findsOneWidget);
  });

  testWidgets('YouTube Tab integration test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final bridge = MockBackendBridge();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<BackendBridge>.value(value: bridge),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(
            create: (context) => DashboardController(bridge),
          ),
          ChangeNotifierProvider(create: (context) => WizardController(bridge)),
          ChangeNotifierProvider(create: (context) => QueueController(bridge)),
          ChangeNotifierProvider(
            create: (context) => SettingsController(bridge),
          ),
          ChangeNotifierProvider(
            create: (context) => YoutubeController(bridge),
          ),
          ChangeNotifierProvider(create: (_) => NavigationController()),
          ChangeNotifierProvider(
            create: (_) => ClipperController(FakeClipperApi()),
          ),
        ],
        child: const MKVoodooApp(clipperPage: SizedBox.shrink()),
      ),
    );

    await tester.tap(find.byIcon(Icons.smart_display_rounded));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('YouTube Downloader'), findsOneWidget);

    final textField = find.byType(TextField);
    await tester.enterText(textField, 'https://youtube.com/watch?v=mock');
    await tester.pump();

    await tester.tap(find.text('Fetch'));

    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Mock Video'), findsOneWidget);
    expect(find.text('Uploader: Mock Channel'), findsOneWidget);

    expect(find.text('Audio Only (Music Mode)'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Format'), findsOneWidget);
    expect(find.text('MP3'), findsOneWidget);
  });
}

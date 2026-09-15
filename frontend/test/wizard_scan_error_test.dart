import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mkvoodoo_ui/controllers/wizard_controller.dart';
import 'package:mkvoodoo_ui/models/scan_proposal.dart';
import 'package:mkvoodoo_ui/pages/wizard_page.dart';
import 'package:mkvoodoo_ui/services/backend_bridge.dart';

class ScanBridge extends Fake implements BackendBridge {
  Object? error;
  List<ScanProposal> results = [];

  @override
  Future<Map<String, dynamic>> getConfig() async => {};

  @override
  Future<List<ScanProposal>> scanInputs(List<String> inputs) async {
    if (error != null) throw error!;
    return results;
  }
}

void main() {
  testWidgets('Empty scan shows supported formats and allows reselection', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bridge = ScanBridge();
    final controller = WizardController(bridge);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(home: Scaffold(body: WizardPage())),
      ),
    );
    controller.handleDroppedFiles(['unsupported-folder']);
    await tester.pumpAndSettle();
    expect(find.textContaining('No supported videos found'), findsOneWidget);
    expect(find.textContaining('M4V'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Choose Different Files'));
    await tester.pumpAndSettle();
    expect(find.text('Select Source Folder'), findsOneWidget);
    expect(controller.scanError, isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('Scan failure is visible and retry can recover', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bridge = ScanBridge()
      ..error = Exception('Unsupported file type: video.xyz');
    final controller = WizardController(bridge);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(home: Scaffold(body: WizardPage())),
      ),
    );
    controller.handleDroppedFiles(['video.xyz']);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Unsupported file type: video.xyz'),
      findsOneWidget,
    );
    expect(controller.isScanning, isFalse);
    expect(tester.takeException(), isNull);
    bridge.error = null;
    bridge.results = [
      ScanProposal(
        source: 'video.m4v',
        relative: 'video.m4v',
        outputFilename: 'video.mkv',
        originalFilename: 'video.m4v',
        season: 1,
        episode: 1,
        title: 'Video',
        tracks: {'audio': [], 'subtitles': []},
      ),
    ];
    await tester.tap(find.text('Retry Scan'));
    await tester.pumpAndSettle();
    expect(controller.scanError, isNull);
    expect(controller.proposals, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}

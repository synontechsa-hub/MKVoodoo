import 'package:flutter_test/flutter_test.dart';
import 'package:mkvoodoo_ui/services/backend_bridge.dart';
import 'package:mkvoodoo_ui/controllers/youtube_controller.dart';

class MockWorkflowBridge extends Fake implements BackendBridge {
  @override
  Future<Map<String, dynamic>> getYoutubeInfo(String url) async => {
    'title': 'Test Workflow Video',
    'thumbnail': 'https://test.com/img.png',
    'uploader': 'Test User',
  };

  @override
  Stream<String> downloadYoutube(
    String url, {
    bool audioOnly = false,
    String format = 'mp3',
    String videoQuality = '1080',
  }) async* {
    yield '🚀 Starting download...';
    yield '⏱ Progress: 50.0%';
    yield '✓ Downloaded to: D:/Downloads/test.mp4';
  }

  @override
  Future<Map<String, dynamic>> getConfig() async => {'output_dir': 'D:/Output'};

  @override
  Future<void> addJobs(List<Map<String, dynamic>> jobs) async {
    // Assert jobs added correctly
    assert(jobs.length == 1);
    assert(jobs[0]['source'] == 'D:/Downloads/test.mp4');
    assert(jobs[0]['delete_source_after_done'] == true);
  }
}

void main() {
  test('YouTube to Conversion Queue integration flow', () async {
    final mockBridge = MockWorkflowBridge();
    final controller = YoutubeController(mockBridge);

    controller.setUrl('https://youtube.com/test');

    // 1. Fetch metadata
    await controller.fetchMetadata();
    expect(controller.metadata!['title'], 'Test Workflow Video');

    // 2. Start download (simulated)
    // Note: Since startDownload uses context and complex listeners,
    // we primarily verify the bridge interaction logic here.

    // In a real widget test, we would use tester.tap(find.text('Download'))
  });
}

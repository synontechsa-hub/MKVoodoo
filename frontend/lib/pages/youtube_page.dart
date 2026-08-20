import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/youtube_controller.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/clipper_controller.dart';

class YoutubePage extends StatefulWidget {
  const YoutubePage({super.key});

  @override
  State<YoutubePage> createState() => _YoutubePageState();
}

class _YoutubePageState extends State<YoutubePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = context.watch<YoutubeController>();

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 32),
          _buildUrlInput(context, controller),
          const SizedBox(height: 32),
          if (controller.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (controller.errorMessage != null)
            _buildError(context, controller.errorMessage!)
          else if (controller.isDownloading || controller.logs.isNotEmpty)
            Expanded(child: _buildDownloadView(context, controller))
          else if (controller.metadata != null)
            Expanded(child: _buildMetadataCard(context, controller))
          else
            _buildEmptyState(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YouTube Downloader',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          'Paste a link to fetch video and start the conversion workflow.',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.4),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildUrlInput(BuildContext context, YoutubeController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: TextField(
        controller: _urlController,
        onChanged: controller.setUrl,
        decoration: InputDecoration(
          hintText: 'https://www.youtube.com/watch?v=...',
          prefixIcon: const Icon(Icons.link_rounded, color: Color(0xFFB900FF)),
          suffixIcon: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: controller.url.isEmpty
                  ? null
                  : () => controller.fetchMetadata(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB900FF),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Fetch'),
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataCard(
    BuildContext context,
    YoutubeController controller,
  ) {
    final meta = controller.metadata!;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.05),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (meta['thumbnail'] != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        meta['thumbnail'],
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          height: 200,
                          color: Colors.black12,
                          child: const Icon(Icons.broken_image_rounded),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    meta['title'] ?? 'Unknown Title',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Uploader: ${meta['uploader'] ?? 'Unknown'}',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildDownloadOptions(context, controller),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      final nav = context.read<NavigationController>();
                      final clipper = context.read<ClipperController>();
                      controller.startDownload(
                        onVideoDownloaded: (path) =>
                            nav.navigateToClipper(path, clipper),
                      );
                    },
                    icon: Icon(
                      controller.audioOnly
                          ? Icons.audiotrack_rounded
                          : Icons.download_rounded,
                    ),
                    label: Text(
                      controller.audioOnly
                          ? 'Download MP3'
                          : 'Download & Open in Clipper',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB900FF),
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadOptions(
    BuildContext context,
    YoutubeController controller,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.audiotrack_rounded,
                  size: 20,
                  color: Color(0xFFB900FF),
                ),
                SizedBox(width: 12),
                Text(
                  'Audio Only (Music Mode)',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            Switch(
              value: controller.audioOnly,
              onChanged: controller.setAudioOnly,
              activeThumbColor: const Color(0xFFB900FF),
            ),
          ],
        ),
        if (controller.audioOnly) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Format',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              DropdownButton<String>(
                value: controller.selectedFormat,
                items: ['mp3', 'flac', 'm4a'].map((f) {
                  return DropdownMenuItem(
                    value: f,
                    child: Text(f.toUpperCase()),
                  );
                }).toList(),
                onChanged: (val) => controller.setSelectedFormat(val!),
                underline: const SizedBox(),
                dropdownColor: Theme.of(context).cardColor,
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Video quality',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              DropdownButton<String>(
                value: controller.selectedVideoQuality,
                items: const ['1080', '720', '480', '360'].map((height) {
                  return DropdownMenuItem(
                    value: height,
                    child: Text('$height p maximum'),
                  );
                }).toList(),
                onChanged: (value) =>
                    controller.setSelectedVideoQuality(value!),
                underline: const SizedBox(),
                dropdownColor: Theme.of(context).cardColor,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDownloadView(
    BuildContext context,
    YoutubeController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (controller.isDownloading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFB900FF),
                ),
              )
            else
              const Icon(Icons.check_circle_rounded, color: Color(0xFF2ECC71)),
            const SizedBox(width: 12),
            Text(
              controller.isDownloading ? 'Downloading...' : 'Download Finished',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Spacer(),
            if (controller.isDownloading)
              TextButton(
                onPressed: () => controller.cancelDownload(),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: controller.downloadProgress / 100,
          backgroundColor: Theme.of(
            context,
          ).dividerColor.withValues(alpha: 0.1),
          color: const Color(0xFFB900FF),
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListView.builder(
              itemCount: controller.logs.length,
              itemBuilder: (context, index) {
                return Text(
                  controller.logs[index],
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.smart_display_rounded,
              size: 64,
              color: Theme.of(context).dividerColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Paste a YouTube link above to start',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: Colors.redAccent),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Provider.of<YoutubeController>(
                context,
                listen: false,
              ).fetchMetadata(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

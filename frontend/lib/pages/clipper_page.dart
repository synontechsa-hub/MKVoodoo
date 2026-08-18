import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../controllers/clipper_controller.dart';

class ClipperPage extends StatefulWidget {
  const ClipperPage({super.key});

  @override
  State<ClipperPage> createState() => _ClipperPageState();
}

class _ClipperPageState extends State<ClipperPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = context.watch<ClipperController>();
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () =>
            unawaited(controller.togglePlayback()),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            unawaited(controller.stepFrame(-1)),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            unawaited(controller.stepFrame(1)),
        const SingleActivator(LogicalKeyboardKey.keyI): () =>
            unawaited(controller.setIn()),
        const SingleActivator(LogicalKeyboardKey.keyO): () =>
            unawaited(controller.setOut()),
      },
      child: Focus(
        autofocus: true,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: controller.hasSource
              ? _buildEditor(context, controller)
              : _buildEmpty(context, controller),
        ),
      ),
    );
  }

  Widget _buildEmpty(
    BuildContext context,
    ClipperController controller,
  ) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 540),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.content_cut_rounded,
                size: 56,
                color: Color(0xFF39FF14),
              ),
              const SizedBox(height: 18),
              Text(
                'Precision Clipper',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Open a local video to preview it, set exact frame boundaries, and export a precise MP4 or MKV clip.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: controller.isLoading
                    ? null
                    : () => _pickSource(controller),
                icon: const Icon(Icons.video_file_rounded),
                label: Text(controller.isLoading ? 'Opening…' : 'Open video'),
              ),
              if (controller.errorMessage != null) ...[
                const SizedBox(height: 16),
                _message(context, controller.errorMessage!, isError: true),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildEditor(BuildContext context, ClipperController controller) {
    final media = controller.mediaInfo!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Precision Clipper',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    '${media.width} × ${media.height} • ${media.isVariableFrameRate ? 'Variable' : 'Constant'} frame rate',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: controller.isLoading
                  ? null
                  : () => _pickSource(controller),
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Open another'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildPreview(context, controller)),
              const SizedBox(width: 20),
              SizedBox(width: 320, child: _buildInspector(context, controller)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context, ClipperController controller) =>
      Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ColoredBox(
                color: Colors.black,
                child: Video(controller: controller.videoController),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildTimeline(context, controller),
        ],
      );

  Widget _buildTimeline(BuildContext context, ClipperController controller) {
    final duration = controller.mediaInfo!.durationUs;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => unawaited(controller.stepFrame(-1)),
                  icon: const Icon(Icons.skip_previous_rounded),
                ),
                IconButton(
                  onPressed: () => unawaited(controller.togglePlayback()),
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
                IconButton(
                  onPressed: () => unawaited(controller.stepFrame(1)),
                  icon: const Icon(Icons.skip_next_rounded),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatUs(controller.currentUs),
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const Text(' / '),
                Text(
                  _formatUs(duration),
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const Spacer(),
                Checkbox(
                  value: controller.loopSelection,
                  onChanged: (value) =>
                      controller.setLoopSelection(value ?? false),
                ),
                const Text('Loop selection'),
              ],
            ),
            Slider(
              value: controller.currentUs.clamp(0, duration).toDouble(),
              min: 0,
              max: duration.toDouble().clamp(1, double.infinity),
              onChanged: (value) => unawaited(controller.seekTo(value.round())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInspector(BuildContext context, ClipperController controller) =>
      ListView(
        children: [
          _boundaryCard(context, controller),
          const SizedBox(height: 14),
          _thumbnailCard(context, controller),
          const SizedBox(height: 14),
          _exportCard(context, controller),
          if (controller.errorMessage != null) ...[
            const SizedBox(height: 14),
            _message(context, controller.errorMessage!, isError: true),
          ],
          if (controller.successMessage != null) ...[
            const SizedBox(height: 14),
            _message(context, controller.successMessage!),
          ],
        ],
      );

  Widget _boundaryCard(BuildContext context, ClipperController controller) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Selection', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _timeRow('In', controller.selection.inUs),
              _timeRow('Out', controller.selection.outUs),
              _timeRow('Duration', controller.selection.durationUs),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => unawaited(controller.setIn()),
                      child: const Text('Set In (I)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => unawaited(controller.setOut()),
                      child: const Text('Set Out (O)'),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: controller.clearSelection,
                child: const Text('Clear selection'),
              ),
            ],
          ),
        ),
      );

  Widget _thumbnailCard(
    BuildContext context,
    ClipperController controller,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thumbnails', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed:
                controller.selection.isComplete &&
                    !controller.isGeneratingThumbnails
                ? () => unawaited(controller.generateThumbnails())
                : null,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(
              controller.isGeneratingThumbnails
                  ? 'Generating…'
                  : 'Generate suggestions',
            ),
          ),
          if (controller.thumbnails.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: controller.thumbnails
                  .map(
                    (candidate) => InkWell(
                      onTap: () =>
                          unawaited(controller.seekTo(candidate.timestampUs)),
                      child: Tooltip(
                        message:
                            '${_formatUs(candidate.timestampUs)} • score ${candidate.score.toStringAsFixed(2)}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(candidate.path),
                            width: 132,
                            height: 74,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _saveThumbnail(context, controller),
            icon: const Icon(Icons.image_outlined),
            label: const Text('Save current frame'),
          ),
        ],
      ),
    ),
  );

  Widget _exportCard(BuildContext context, ClipperController controller) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Export', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'In and Out are inclusive frame boundaries.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: controller.canExport
                    ? () => _exportClip(controller, 'mp4')
                    : null,
                icon: const Icon(Icons.file_upload_outlined),
                label: Text(
                  controller.isExporting ? 'Exporting…' : 'Export MP4',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: controller.canExport
                    ? () => _exportClip(controller, 'mkv')
                    : null,
                child: const Text('Export MKV'),
              ),
            ],
          ),
        ),
      );

  Widget _timeRow(String label, int? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Text(label),
        const Spacer(),
        Text(value == null ? '—' : _formatUs(value)),
      ],
    ),
  );

  Widget _message(
    BuildContext context,
    String message, {
    bool isError = false,
  }) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: (isError ? Colors.red : const Color(0xFF39FF14)).withValues(
        alpha: 0.12,
      ),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(message),
  );

  Future<void> _pickSource(ClipperController controller) async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Open video',
      type: FileType.video,
    );
    final source = result?.files.single.path;
    if (source != null) await controller.openSource(source);
  }

  Future<void> _exportClip(
    ClipperController controller,
    String container,
  ) async {
    final output = await FilePicker.saveFile(
      dialogTitle: 'Export precise clip',
      fileName: 'clip.$container',
      type: FileType.custom,
      allowedExtensions: [container],
    );
    if (output != null) await controller.export(output, container);
  }

  Future<void> _saveThumbnail(
    BuildContext context,
    ClipperController controller,
  ) async {
    final output = await FilePicker.saveFile(
      dialogTitle: 'Save thumbnail',
      fileName: 'thumbnail.png',
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg'],
    );
    if (output == null) return;
    final format = output.toLowerCase().endsWith('.jpg') ? 'jpg' : 'png';
    await controller.saveThumbnail(output, format);
  }

  String _formatUs(int microseconds) {
    final duration = Duration(microseconds: microseconds);
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(duration.inHours)}:${two(duration.inMinutes.remainder(60))}:${two(duration.inSeconds.remainder(60))}.${(duration.inMilliseconds.remainder(1000)).toString().padLeft(3, '0')}';
  }
}

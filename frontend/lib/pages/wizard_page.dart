import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../controllers/wizard_controller.dart';
import '../widgets/wizard/proposal_table.dart';

class WizardPage extends StatefulWidget {
  const WizardPage({super.key});

  @override
  State<WizardPage> createState() => _WizardPageState();
}

class _WizardPageState extends State<WizardPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isDragging = false;
  final ScrollController _logScrollController = ScrollController();

  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_logScrollController.hasClients) {
      _logScrollController.animateTo(
        _logScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = context.watch<WizardController>();

    // Scroll to bottom when new logs are added
    if (controller.isConverting || controller.conversionLog.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return DropTarget(
      onDragDone: (details) {
        final paths = details.files.map((f) => f.path).toList();
        controller.handleDroppedFiles(paths);
      },
      onDragEntered: (details) => setState(() => _isDragging = true),
      onDragExited: (details) => setState(() => _isDragging = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _isDragging
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)
              : Colors.transparent,
        ),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New Conversion Job',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              const SizedBox(height: 32),
              if (controller.inputPaths.isEmpty)
                _buildFolderPicker(context, controller)
              else if (controller.isScanning)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (controller.isConverting || controller.conversionLog.isNotEmpty)
                Expanded(child: _buildConversionLog(context, controller))
              else if (controller.proposals != null)
                const Expanded(child: ProposalTable())
              else
                _buildReadyToScanView(context, controller),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadyToScanView(BuildContext context, WizardController controller) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 16),
            Text(
              'No files scanned yet',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => controller.runScan(),
              child: const Text('Retry Scan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderPicker(BuildContext context, WizardController controller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                ),
                boxShadow: [
                  if (isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: -5,
                    ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB900FF).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.folder_open_rounded,
                      color: Color(0xFFB900FF),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Select Source Folder',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pick the directory or specific files you want to convert.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.mouse_outlined,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'or drag and drop them here',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => controller.pickInputFolder(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB900FF),
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Browse Folders',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => controller.pickInputFiles(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB900FF),
                      side: const BorderSide(color: Color(0xFFB900FF)),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Select Files',
                      style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildConversionLog(BuildContext context, WizardController controller) {
    final isFinished = !controller.isConverting && !controller.isAborting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (controller.isConverting) ...[
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Converting...',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ] else if (controller.isAborting) ...[
              const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
              const SizedBox(width: 12),
              const Text(
                'Aborting...',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ] else ...[
              const Icon(Icons.check_circle_rounded, color: Color(0xFF2ECC71)),
              const SizedBox(width: 12),
              const Text(
                'Conversion Finished',
                style: TextStyle(color: Color(0xFF2ECC71), fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
            const Spacer(),
            if (controller.isConverting && !controller.isAborting)
              TextButton.icon(
                onPressed: () => controller.abortConversion(),
                icon: const Icon(Icons.stop_circle_rounded, color: Colors.redAccent),
                label: const Text(
                  'ABORT CONVERSION',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              )
            else if (isFinished)
              ElevatedButton.icon(
                onPressed: () => controller.reset(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Start New Job'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB900FF),
                  foregroundColor: Colors.black,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white.withValues(alpha: 0.02) 
                      : Colors.black.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                  ),
                ),
                child: ListView.builder(
                  controller: _logScrollController,
                  itemCount: controller.conversionLog.length,
                  itemBuilder: (context, index) {
                    final line = controller.conversionLog[index];
                    Color lineColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
                    if (line.contains('✓') || line.contains('success')) {
                      lineColor = const Color(0xFF2ECC71);
                    } else if (line.contains('✗') ||
                        line.contains('failed') ||
                        line.contains('Error')) {
                      lineColor = Colors.redAccent;
                    } else if (line.contains('⟳') || line.contains('Retry')) {
                      lineColor = Colors.orangeAccent;
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        line,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: lineColor,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

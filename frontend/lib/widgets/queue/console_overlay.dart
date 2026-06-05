import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/queue_controller.dart';

class ConsoleOverlay extends StatefulWidget {
  const ConsoleOverlay({super.key});

  @override
  State<ConsoleOverlay> createState() => _ConsoleOverlayState();
}

class _ConsoleOverlayState extends State<ConsoleOverlay> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<QueueController>();
    
    // Auto scroll to bottom whenever logs update
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Container(
      margin: const EdgeInsets.only(top: 24),
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB900FF).withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.terminal_rounded, color: Color(0xFFB900FF), size: 16),
                  SizedBox(width: 8),
                  Text('Processing Queue...',
                      style: TextStyle(color: Color(0xFFB900FF), fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => controller.clearConsole(),
                    icon: const Icon(Icons.delete_outline_rounded, size: 14),
                    label: const Text('Clear', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFB900FF)),
                  ),
                ],
              ),
            ],
          ),
          Divider(color: Theme.of(context).dividerColor, height: 24),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: controller.consoleLogs.length,
              itemBuilder: (context, index) {
                final line = controller.consoleLogs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                     line,
                     style: TextStyle(
                       color: line.startsWith('❌') ? Colors.redAccent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                       fontFamily: 'monospace',
                       fontSize: 12,
                     ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

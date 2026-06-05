import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../controllers/queue_controller.dart';
import '../widgets/queue/console_overlay.dart';

class QueuePage extends StatefulWidget {
  const QueuePage({super.key});

  @override
  State<QueuePage> createState() => _QueuePageState();
}

class _QueuePageState extends State<QueuePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = context.watch<QueueController>();

    return DropTarget(
      onDragDone: (details) async {
        final messenger = ScaffoldMessenger.of(context);
        final paths = details.files.map((f) => f.path).toList();

        if (paths.isNotEmpty) {
          try {
            await controller.addToQueue(paths);
          } catch (e) {
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Error adding to queue: $e'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          }
        }
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conversion Queue',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      Text(
                        'Manage your background tasks and pending jobs.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (controller.selectedIds.isNotEmpty)
                        _buildActionButton(
                          icon: Icons.delete_sweep_rounded,
                          label: 'Remove Selected (${controller.selectedIds.length})',
                          color: Colors.redAccent,
                          onPressed: () async {
                            try {
                              await controller.removeSelected();
                            } catch (e) {
                              _showError(e.toString());
                            }
                          },
                        )
                      else ...[
                        if (controller.isProcessing)
                          _buildActionButton(
                            icon: Icons.stop_rounded,
                            label: 'Stop Processing',
                            color: Colors.redAccent,
                            onPressed: () async => await controller.stopProcessing(),
                          )
                        else
                          _buildActionButton(
                            icon: Icons.play_arrow_rounded,
                            label: 'Resume Queue',
                            color: const Color(0xFFB900FF),
                            onPressed: controller.jobs != null &&
                                    controller.jobs!.any((j) => j['status'] == 'pending')
                                ? () => controller.resumeQueue()
                                : null,
                          ),
                        const SizedBox(width: 12),
                        _buildActionButton(
                          icon: Icons.restore_rounded,
                          label: 'Reset Failed',
                          color: Colors.orangeAccent,
                          onPressed: controller.jobs != null &&
                                  controller.jobs!.any((j) => j['status'] == 'failed')
                              ? () async {
                                  try {
                                    await controller.resetFailed();
                                  } catch (e) {
                                    _showError(e.toString());
                                  }
                                }
                              : null,
                        ),
                      ],
                      const SizedBox(width: 12),
                      _buildActionButton(
                        icon: Icons.cleaning_services_rounded,
                        label: 'Clear Done',
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                        onPressed: controller.jobs != null &&
                                controller.jobs!.any((j) =>
                                    j['status'] == 'done' ||
                                    j['status'] == 'skipped')
                            ? () async {
                                try {
                                  await controller.clearCompleted();
                                } catch (e) {
                                  _showError(e.toString());
                                }
                              }
                            : null,
                      ),
                      const SizedBox(width: 12),
                      _buildActionButton(
                        icon: Icons.history_rounded,
                        label: 'Clear History',
                        color: Colors.redAccent.withValues(alpha: 0.5),
                        onPressed: controller.jobs != null &&
                                controller.jobs!.any((j) =>
                                    j['status'] != 'pending' &&
                                    j['status'] != 'in_progress')
                            ? () => _confirmClearAllHistory(context, controller)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () => controller.refreshQueue(),
                        icon: Icon(Icons.refresh_rounded,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                        tooltip: 'Refresh Status',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              if (controller.isLoading && controller.jobs == null)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (controller.jobs == null || controller.jobs!.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_rounded,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                        const SizedBox(height: 16),
                        Text(
                          'No jobs in queue',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
                        child: Row(
                          children: [
                            Checkbox(
                              value: controller.jobs != null &&
                                  controller.jobs!.isNotEmpty &&
                                  controller.selectedIds.length == controller.jobs!.length,
                              onChanged: (val) {
                                controller.toggleSelectAll(val == true);
                              },
                            ),
                            Text(
                              'Select All Jobs (${controller.jobs!.length})',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          itemCount: controller.jobs!.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final job = controller.jobs![index];
                            final id = job['id'] as String;
                            final status = job['status'] as String;
                            final source = job['source'] as String;
                            final attempts = job['attempts'] ?? 0;
                            final output = job['output'] as String;
                            final filename = source.split('\\').last.split('/').last;
                            final outFilename = output.split('\\').last.split('/').last;

                            Color statusColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
                            IconData statusIcon = Icons.help_outline;

                            switch (status) {
                              case 'pending':
                                statusColor = Colors.blueAccent;
                                statusIcon = Icons.hourglass_empty_rounded;
                                break;
                              case 'in_progress':
                                statusColor = Colors.orangeAccent;
                                statusIcon = Icons.sync_rounded;
                                break;
                              case 'done':
                                statusColor = const Color(0xFF2ECC71);
                                statusIcon = Icons.check_circle_rounded;
                                break;
                              case 'failed':
                                statusColor = Colors.redAccent;
                                statusIcon = Icons.error_rounded;
                                break;
                              case 'skipped':
                                statusColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3);
                                statusIcon = Icons.skip_next_rounded;
                                break;
                            }

                            final progress = controller.jobProgress[id] ?? 0.0;
                            String statusLabel = status.toUpperCase();
                            if (status == 'in_progress') {
                              statusLabel = '${progress.toStringAsFixed(1)}%';
                            }

                            return ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white.withValues(alpha: 0.03)
                                        : Colors.black.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: controller.isSelected(id)
                                          ? const Color(0xFFB900FF).withValues(alpha: 0.5)
                                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                                      width: controller.isSelected(id) ? 1.5 : 1,
                                    ),
                                    boxShadow: controller.isSelected(id)
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFFB900FF).withValues(alpha: 0.15),
                                              blurRadius: 15,
                                              spreadRadius: -2,
                                            )
                                          ]
                                        : null,
                                  ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: controller.isSelected(id),
                                        onChanged: (val) {
                                          controller.toggleSelect(id, val == true);
                                        },
                                      ),
                                      Icon(statusIcon, color: statusColor, size: 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Tooltip(
                                              message: source,
                                              child: Text(
                                                filename,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Tooltip(
                                              message: output,
                                              child: Text(
                                                'Destination: $outFilename',
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.4),
                                                  fontSize: 10,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Attempts',
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.3),
                                              fontSize: 8,
                                            ),
                                          ),
                                          Text(
                                            attempts.toString(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (status == 'in_progress') ...[
                                    const SizedBox(height: 12),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        return Container(
                                          height: 6,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Stack(
                                            children: [
                                              AnimatedContainer(
                                                duration: const Duration(milliseconds: 300),
                                                width: constraints.maxWidth * (progress / 100),
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(4),
                                                  gradient: const LinearGradient(
                                                    colors: [Color(0xFFB900FF), Color(0xFF39FF14)],
                                                    begin: Alignment.centerLeft,
                                                    end: Alignment.centerRight,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(0xFF39FF14).withValues(alpha: 0.4),
                                                      blurRadius: 8,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                        ),
                      ),
                    ],
                  ),
                ),
              if (controller.isProcessing) const ConsoleOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $message'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _confirmClearAllHistory(BuildContext context, QueueController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Clear All History', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          'This will remove all completed, failed, and skipped jobs from the queue. Pending jobs will be kept. Continue?',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await controller.clearAllHistory();
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.2)),
        ),
      ),
    );
  }
}

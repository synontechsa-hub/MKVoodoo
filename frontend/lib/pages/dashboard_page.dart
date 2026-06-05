import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/backend_status.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/dashboard/stats_cards.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DashboardController>();

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, controller.isLoading),
          const SizedBox(height: 32),
          if (controller.isLoading && controller.status != BackendStatus.ready)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (controller.status != BackendStatus.ready)
            _buildErrorState(context, controller)
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Row(
                      children: [
                        StatusCard(
                          title: 'Queue Status',
                          value: controller.activeJobs > 0 ? 'Processing' : 'Idle',
                          subtitle: '${controller.activeJobs} active jobs',
                          icon: Icons.loop_rounded,
                          color: controller.activeJobs > 0 ? Colors.orangeAccent : const Color(0xFFB900FF),
                        ),
                        const SizedBox(width: 24),
                        StatusCard(
                          title: 'Disk Space',
                          value: '${controller.storage['free_gb'] ?? 0} GB Free',
                          subtitle: '${controller.storage['used_percent'] ?? 0}% utilized',
                          icon: Icons.storage_rounded,
                          color: (controller.storage['used_percent'] ?? 0) > 90 ? Colors.redAccent : Colors.greenAccent,
                        ),
                        const SizedBox(width: 24),
                        StatusCard(
                          title: 'Hardware',
                          value: controller.hardware['label']?.split('(').first.trim() ?? 'CPU',
                          subtitle: controller.hardware['is_hardware'] == true ? 'GPU Accelerated' : 'Software Encoding',
                          icon: Icons.memory_rounded,
                          color: const Color(0xFF7000FF),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        SmallStatsCard(
                          label: 'Processed',
                          value: '${controller.processedGB.toStringAsFixed(2)} GB',
                          icon: Icons.data_usage_rounded,
                        ),
                        const SizedBox(width: 16),
                        SmallStatsCard(
                          label: 'Completed',
                          value: '${controller.doneJobs}',
                          icon: Icons.check_circle_rounded,
                          color: const Color(0xFF2ECC71),
                        ),
                        const SizedBox(width: 16),
                        SmallStatsCard(
                          label: 'Failed',
                          value: '${controller.failedJobs}',
                          icon: Icons.error_rounded,
                          color: Colors.redAccent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isLoading) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Overview',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Monitor your conversion engine and storage in real-time.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const Spacer(),
        if (!isLoading)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFB900FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 8,
                  height: 8,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFB900FF)),
                ),
                SizedBox(width: 8),
                Text('LIVE', style: TextStyle(color: Color(0xFFB900FF), fontWeight: FontWeight.bold, fontSize: 10)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, DashboardController controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.redAccent),
          const SizedBox(height: 16),
          const Text('Backend Disconnected', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Ensure the conversion engine is running.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => controller.fetchData(),
            child: const Text('Retry Connection'),
          ),
        ],
      ),
    );
  }
}

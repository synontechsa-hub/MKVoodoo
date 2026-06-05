import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/scan_proposal.dart';
import '../../controllers/wizard_controller.dart';
import '../../services/backend_bridge.dart';
import 'track_selection_dialog.dart';
import 'bulk_edit_dialog.dart';

class ProposalTable extends StatefulWidget {
  const ProposalTable({super.key});

  @override
  State<ProposalTable> createState() => _ProposalTableState();
}

class _ProposalTableState extends State<ProposalTable> {
  Future<void> _showTrackSelectionDialog(BuildContext context, ScanProposal proposal) async {
    final bridge = context.read<BackendBridge>();
    final controller = context.read<WizardController>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    Map<String, List<Map<String, dynamic>>> tracks;
    try {
      tracks = await bridge.getTracks(proposal.source);
      if (context.mounted) Navigator.pop(context); // Dismiss loading
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to probe tracks: $e'), backgroundColor: Colors.redAccent),
        );
      }
      return;
    }

    if (!context.mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TrackSelectionDialog(
        audioTracks: tracks['audio']!,
        subtitleTracks: tracks['subtitles']!,
        initialAudio: proposal.selectedAudioTracks,
        initialSubs: proposal.selectedSubtitleTracks,
        initialBitrate: proposal.audioBitrate ?? controller.defaultAudioBitrate,
      ),
    );

    if (result != null) {
      controller.updateProposalTracks(
        proposal,
        result['audio'],
        result['subtitles'],
        result['bitrate'],
      );
    }
  }

  Future<void> _bulkEdit(BuildContext context, WizardController controller) async {
    if (controller.proposals == null || controller.proposals!.isEmpty) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => BulkEditDialog(
        initialBitrate: controller.defaultAudioBitrate,
      ),
    );

    if (result != null) {
      controller.applyBulkSettings(result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Applied settings to ${controller.proposals!.length} files.'),
            backgroundColor: const Color(0xFF2ECC71),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WizardController>();
    final proposals = controller.proposals!;

    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFFB900FF)),
            const SizedBox(width: 12),
            Text(
              'Discovered ${proposals.length} files. Review the naming below.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => controller.reset(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Change Folder'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => _bulkEdit(context, controller),
              icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
              label: const Text('Bulk Edit All'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB900FF).withValues(alpha: 0.1),
                foregroundColor: const Color(0xFFB900FF),
                side: const BorderSide(color: Color(0xFFB900FF), width: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(width: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.psychology_rounded, size: 20, color: Color(0xFFB900FF)),
                  const SizedBox(width: 12),
                  const Text('Smart Naming', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  Switch(
                    value: controller.useSmartNaming,
                    onChanged: (val) => controller.useSmartNaming = val,
                    activeThumbColor: const Color(0xFFB900FF),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    Theme.of(context).dividerColor.withValues(alpha: 0.05),
                  ),
                  columns: const [
                    DataColumn(label: Text('Source')),
                    DataColumn(label: Text('Season')),
                    DataColumn(label: Text('Episode')),
                    DataColumn(label: Text('Options')),
                    DataColumn(label: Text('Output Name')),
                  ],
                  rows: proposals
                      .map(
                        (proposal) => DataRow(
                          cells: [
                            DataCell(
                              Text(
                                proposal.relative,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DataCell(
                              Text('S${proposal.season.toString().padLeft(2, '0')}'),
                            ),
                            DataCell(
                              Text('E${proposal.episode.toString().padLeft(2, '0')}'),
                            ),
                            DataCell(
                              IconButton(
                                icon: Icon(
                                  Icons.tune_rounded,
                                  color: (proposal.selectedAudioTracks != null || proposal.selectedSubtitleTracks != null)
                                      ? const Color(0xFFB900FF)
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                  size: 20,
                                ),
                                onPressed: () => _showTrackSelectionDialog(context, proposal),
                                tooltip: 'Configure Tracks & Quality',
                              ),
                            ),
                            DataCell(
                              Text(
                                controller.useSmartNaming ? proposal.outputFilename : proposal.originalFilename,
                                style: const TextStyle(
                                  color: Color(0xFFB900FF),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              onPressed: () => controller.startConversion(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB900FF),
                foregroundColor: Colors.black,
                minimumSize: const Size(200, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Start Conversion',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

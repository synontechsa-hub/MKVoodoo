import 'package:flutter/material.dart';

class BulkEditDialog extends StatefulWidget {
  final String? initialBitrate;

  const BulkEditDialog({super.key, this.initialBitrate});

  @override
  State<BulkEditDialog> createState() => _BulkEditDialogState();
}

class _BulkEditDialogState extends State<BulkEditDialog> {
  String _bitrate = '128k';
  String _audioStrategy = 'all'; // all, first
  String _subStrategy = 'all'; // all, none

  @override
  void initState() {
    super.initState();
    if (widget.initialBitrate != null) _bitrate = widget.initialBitrate!;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.auto_fix_high_rounded, color: Color(0xFF00D2FF)),
          SizedBox(width: 12),
          Text('Bulk Settings'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'These settings will be applied to ALL files in the current batch.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const Text('Audio Quality', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _bitrate,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              items: ['96k', '128k', '160k', '192k', '256k', '320k', 'copy']
                  .map((b) => DropdownMenuItem(
                        value: b,
                        child: Text(b == 'copy' ? 'Passthrough (Copy)' : b),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => _bitrate = val!),
            ),
            const SizedBox(height: 24),
            const Text('Audio Track Strategy', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _audioStrategy,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Keep All Audio Tracks')),
                DropdownMenuItem(value: 'first', child: Text('Keep First Audio Track Only')),
              ],
              onChanged: (val) => setState(() => _audioStrategy = val!),
            ),
            const SizedBox(height: 24),
            const Text('Subtitle Strategy', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _subStrategy,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Keep All Subtitles')),
                DropdownMenuItem(value: 'none', child: Text('Strip All Subtitles')),
              ],
              onChanged: (val) => setState(() => _subStrategy = val!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, {
            'bitrate': _bitrate,
            'audio_strategy': _audioStrategy,
            'sub_strategy': _subStrategy,
          }),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00D2FF),
            foregroundColor: Colors.black,
          ),
          child: const Text('Apply to All'),
        ),
      ],
    );
  }
}

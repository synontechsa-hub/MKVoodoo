import 'package:flutter/material.dart';

class BulkEditDialog extends StatefulWidget {
  final String? initialBitrate;

  const BulkEditDialog({super.key, this.initialBitrate});

  @override
  State<BulkEditDialog> createState() => _BulkEditDialogState();
}

class _BulkEditDialogState extends State<BulkEditDialog> {
  String _bitrate = '128k';
  String _audioStrategy = 'all'; // all, first, lang
  String _subStrategy = 'all'; // all, none, lang

  final Map<String, bool> _selectedLanguages = {
    'en': true,
    'ja': false,
    'it': false,
    'de': false,
    'fr': false,
    'es': false,
    'ar': false,
    'ru': false,
    'zh': false,
    'pt': false,
    'ko': false,
  };

  final Map<String, String> _languageLabels = {
    'en': 'English',
    'ja': 'Japanese',
    'it': 'Italian',
    'de': 'German',
    'fr': 'French',
    'es': 'Spanish',
    'ar': 'Arabic',
    'ru': 'Russian',
    'zh': 'Chinese',
    'pt': 'Portuguese',
    'ko': 'Korean',
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.auto_fix_high_rounded, color: Color(0xFFB900FF)),
          SizedBox(width: 12),
          Text('Bulk Settings'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
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
                value: _bitrate,
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
                value: _audioStrategy,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Keep All Audio Tracks')),
                  DropdownMenuItem(value: 'first', child: Text('Keep First Audio Track Only')),
                  DropdownMenuItem(value: 'lang', child: Text('Keep Specific Languages Only')),
                ],
                onChanged: (val) => setState(() => _audioStrategy = val!),
              ),
              const SizedBox(height: 24),
              const Text('Subtitle Strategy', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _subStrategy,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Keep All Subtitles')),
                  DropdownMenuItem(value: 'none', child: Text('Strip All Subtitles')),
                  DropdownMenuItem(value: 'lang', child: Text('Keep Specific Languages Only')),
                ],
                onChanged: (val) => setState(() => _subStrategy = val!),
              ),
              if (_audioStrategy == 'lang' || _subStrategy == 'lang') ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                const Text('Target Languages', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'Files will keep tracks matching these languages + any "undefined" tracks.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _selectedLanguages.keys.map((lang) {
                    return FilterChip(
                      label: Text(_languageLabels[lang]!),
                      selected: _selectedLanguages[lang]!,
                      onSelected: (selected) {
                        setState(() => _selectedLanguages[lang] = selected);
                      },
                      selectedColor: const Color(0xFFB900FF).withValues(alpha: 0.2),
                      checkmarkColor: const Color(0xFFB900FF),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
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
            'languages': _selectedLanguages.entries
                .where((e) => e.value)
                .map((e) => e.key)
                .toList(),
          }),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB900FF),
            foregroundColor: Colors.black,
          ),
          child: const Text('Apply to All'),
        ),
      ],
    );
  }
}

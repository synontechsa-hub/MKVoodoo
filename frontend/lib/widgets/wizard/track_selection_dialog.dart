import 'package:flutter/material.dart';

class TrackSelectionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> audioTracks;
  final List<Map<String, dynamic>> subtitleTracks;
  final List<int>? initialAudio;
  final List<int>? initialSubs;
  final String? initialBitrate;

  const TrackSelectionDialog({
    super.key,
    required this.audioTracks,
    required this.subtitleTracks,
    this.initialAudio,
    this.initialSubs,
    this.initialBitrate,
  });

  @override
  State<TrackSelectionDialog> createState() => _TrackSelectionDialogState();
}

class _TrackSelectionDialogState extends State<TrackSelectionDialog> {
  late List<int> _selectedAudio;
  late List<int> _selectedSubs;
  late String _bitrate;

  @override
  void initState() {
    super.initState();
    _selectedAudio = widget.initialAudio != null
        ? List.from(widget.initialAudio!)
        : widget.audioTracks.map((t) => t['index'] as int).toList();
    _selectedSubs = widget.initialSubs != null
        ? List.from(widget.initialSubs!)
        : widget.subtitleTracks.map((t) => t['index'] as int).toList();
    _bitrate = widget.initialBitrate ?? '128k';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configure Tracks'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const Text('Audio Tracks', style: TextStyle(fontWeight: FontWeight.bold)),
              ...widget.audioTracks.map((t) => CheckboxListTile(
                    title: Text('${t['title']} (${t['language']})'),
                    subtitle: Text('${t['codec']} - ${t['channels']} ch'),
                    value: _selectedAudio.contains(t['index']),
                    onChanged: (val) {
                      setState(() {
                        if (val!) {
                          _selectedAudio.add(t['index']);
                        } else {
                          _selectedAudio.remove(t['index']);
                        }
                      });
                    },
                  )),
              const SizedBox(height: 16),
              const Text('Subtitle Tracks', style: TextStyle(fontWeight: FontWeight.bold)),
              ...widget.subtitleTracks.map((t) => CheckboxListTile(
                    title: Text('${t['title']} (${t['language']})'),
                    subtitle: Text(t['codec']),
                    value: _selectedSubs.contains(t['index']),
                    onChanged: (val) {
                      setState(() {
                        if (val!) {
                          _selectedSubs.add(t['index']);
                        } else {
                          _selectedSubs.remove(t['index']);
                        }
                      });
                    },
                  )),
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
            'audio': _selectedAudio,
            'subtitles': _selectedSubs,
            'bitrate': _bitrate,
          }),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

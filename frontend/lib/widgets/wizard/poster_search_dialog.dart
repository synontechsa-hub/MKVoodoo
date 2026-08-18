import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mkvoodoo_ui/services/backend_bridge.dart';

class PosterSearchDialog extends StatefulWidget {
  final String initialQuery;
  final bool isTv;

  const PosterSearchDialog({
    super.key,
    required this.initialQuery,
    this.isTv = false,
  });

  @override
  State<PosterSearchDialog> createState() => _PosterSearchDialogState();
}

class _PosterSearchDialogState extends State<PosterSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    _performSearch();
  }

  Future<void> _performSearch() async {
    if (_searchController.text.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final bridge = context.read<BackendBridge>();
      final results = await bridge.searchMetadata(
        _searchController.text,
        isTv: widget.isTv,
      );
      setState(() => _results = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Fetch Official Poster'),
      content: SizedBox(
        width: 500,
        height: 500,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search movie or TV show...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: _performSearch,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                  ? const Center(child: Text('No results found.'))
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = _results[index];
                        return ListTile(
                          leading: item['poster_url'] != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    item['poster_url'],
                                    width: 40,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(Icons.movie_rounded),
                          title: Text(item['title'] ?? 'Unknown'),
                          subtitle: Text(item['date']?.split('-').first ?? ''),
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

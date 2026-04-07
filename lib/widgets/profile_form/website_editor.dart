import 'package:flutter/material.dart';

class WebsiteEditor extends StatefulWidget {
  final List<String> blockedWebsites;
  final ValueChanged<List<String>> onChanged;

  const WebsiteEditor({
    super.key,
    required this.blockedWebsites,
    required this.onChanged,
  });

  @override
  State<WebsiteEditor> createState() => _WebsiteEditorState();
}

class _WebsiteEditorState extends State<WebsiteEditor> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addWebsite() {
    final website = _controller.text.trim().toLowerCase();
    if (website.isEmpty || !website.contains('.')) return;
    if (widget.blockedWebsites.contains(website)) return;

    widget.onChanged([...widget.blockedWebsites, website]);
    _controller.clear();
  }

  void _removeWebsite(String website) {
    widget.onChanged(
      widget.blockedWebsites.where((w) => w != website).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Blocked Websites',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'e.g. youtube.com',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _addWebsite(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle),
              onPressed: _addWebsite,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...widget.blockedWebsites.map((website) => ListTile(
              dense: true,
              title: Text(website),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => _removeWebsite(website),
              ),
            )),
      ],
    );
  }
}

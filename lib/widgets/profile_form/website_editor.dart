import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/bevel.dart';

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
        Text(
          'BLOCKED WEBSITES',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: Bevel.sunken(),
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: AppColors.onSurface),
                  decoration: const InputDecoration(
                    hintText: 'e.g. youtube.com',
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) => _addWebsite(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: Bevel.raised(fill: AppColors.primaryContainer),
              child: IconButton(
                icon: const Icon(
                  Icons.add,
                  color: AppColors.onPrimaryContainer,
                ),
                onPressed: _addWebsite,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...widget.blockedWebsites.asMap().entries.map((entry) {
          final index = entry.key;
          final website = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 2),
            color: index.isEven
                ? AppColors.surfaceContainerHigh
                : AppColors.surfaceContainerLow,
            child: ListTile(
              dense: true,
              title: Text(
                website,
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 13,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppColors.outline),
                onPressed: () => _removeWebsite(website),
              ),
            ),
          );
        }),
      ],
    );
  }
}

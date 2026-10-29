import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/library_controller.dart';
import '../reader/reader_screen.dart';

Future<void> pickAndImportDocuments(BuildContext context) async {
  const documents = XTypeGroup(
    label: 'Documents',
    extensions: ['txt', 'md', 'epub', 'pdf'],
    mimeTypes: [
      'text/plain',
      'text/markdown',
      'application/epub+zip',
      'application/pdf',
    ],
  );
  final files = await openFiles(acceptedTypeGroups: const [documents]);
  if (files.isEmpty || !context.mounted) return;
  final paths = files
      .map((f) => f.path)
      .whereType<String>()
      .toList(growable: false);
  if (paths.isEmpty) return;

  final library = context.read<LibraryController>();
  final imported = <Doc>[];
  for (final path in paths) {
    final progress = ValueNotifier<(double, String)>((0, 'Preparing'));
    if (!context.mounted) break;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImportProgressDialog(progress: progress),
    );
    try {
      final doc = await library.importFile(
        path,
        onProgress: (value, stage) => progress.value = (value, stage),
      );
      imported.add(doc);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyImportError(error))),
        );
      }
    } finally {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      progress.dispose();
    }
  }

  if (imported.isNotEmpty && context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReaderScreen(doc: imported.first)),
    );
    if (imported.length > 1 && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${imported.length} documents imported to your library.')),
      );
    }
  }
}

Future<void> importArticleFlow(BuildContext context) async {
  final controller = TextEditingController();
  final url = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Read a link'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sotto fetches the article once, extracts the words, and reads them offline. Nothing else is requested.',
            style: Theme.of(dialogContext).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(hintText: 'https://…'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
          child: const Text('Fetch'),
        ),
      ],
    ),
  );
  if (url == null || url.isEmpty || !context.mounted) return;

  final library = context.read<LibraryController>();
  final progress = ValueNotifier<(double, String)>((0.05, 'Fetching article'));
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ImportProgressDialog(progress: progress),
  );
  try {
    final doc = await library.importArticle(
      url,
      onProgress: (value, stage) => progress.value = (value, stage),
    );
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReaderScreen(doc: doc)),
    );
  } catch (error) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_friendlyImportError(error))),
    );
  } finally {
    progress.dispose();
  }
}

String _friendlyImportError(Object error) {
  final message = error.toString().replaceFirst('FormatException: ', '');
  if (message.length > 220) {
    return 'That document could not be imported.';
  }
  return message;
}

class ImportProgressDialog extends StatelessWidget {
  const ImportProgressDialog({super.key, required this.progress});

  final ValueNotifier<(double, String)> progress;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: ValueListenableBuilder<(double, String)>(
        valueListenable: progress,
        builder: (context, value, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value.$2, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: value.$1 == 0 ? null : value.$1.clamp(0, 1),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              value.$1 >= 1 ? 'Finishing' : '${(value.$1 * 100).round()}%',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../state/settings_controller.dart';
import '../../tts/model_catalog.dart';
import '../../tts/model_repository.dart';
import '../../tts/tts_service.dart';

Future<void> showModelSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.9,
      child: ModelSheet(),
    ),
  );
}

class ModelSheet extends StatefulWidget {
  const ModelSheet({super.key});

  @override
  State<ModelSheet> createState() => _ModelSheetState();
}

class _ModelSheetState extends State<ModelSheet> {
  final Map<String, double> _progress = {};
  final Set<String> _installing = {};
  Map<String, bool> _installed = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final repo = context.read<ModelRepository>();
    final result = <String, bool>{};
    for (final spec in modelCatalog) {
      result[spec.id] = await repo.isInstalled(spec.id);
    }
    if (mounted) setState(() => _installed = result);
  }

  Future<void> _install(ModelSpec spec) async {
    final repo = context.read<ModelRepository>();
    final settings = context.read<SettingsController>();
    setState(() {
      _installing.add(spec.id);
      _progress[spec.id] = 0;
    });
    try {
      await repo.download(
        spec.id,
        onProgress: (value) {
          if (mounted) setState(() => _progress[spec.id] = value.fraction);
        },
      );
      if (settings.modelId == spec.id) {
        if (mounted) await context.read<TtsService>().load(modelId: spec.id, forceReload: true);
      }
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${spec.name} is ready on this device.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed. $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _installing.remove(spec.id);
          _progress.remove(spec.id);
        });
      }
    }
  }

  Future<void> _delete(ModelSpec spec) async {
    final repo = context.read<ModelRepository>();
    final settings = context.read<SettingsController>();
    if (settings.modelId == spec.id) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Switch to another model before deleting this one.')),
        );
      }
      return;
    }
    await repo.delete(spec.id);
    await _refresh();
  }

  Future<void> _select(ModelSpec spec) async {
    final settings = context.read<SettingsController>();
    final installed = _installed[spec.id] ?? false;
    if (!installed) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Download ${spec.name}?'),
          content: Text(
            '${spec.sizeMb.toStringAsFixed(1)} MB will be downloaded once from Hugging Face, verified against a SHA-256 checksum, then stored on this device.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Not now')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Download')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await _install(spec);
      if (!mounted) return;
    }
    settings.modelId = spec.id;
    if (mounted) {
      await context.read<TtsService>().load(modelId: spec.id, forceReload: true);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final tokens = SottoTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Voice models', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Nano ships inside the app. Micro and Mini download once, then run entirely offline.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: modelCatalog.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final spec = modelCatalog[index];
                final selected = settings.modelId == spec.id;
                final installed = _installed[spec.id] ?? false;
                final installing = _installing.contains(spec.id);
                return PaperCard(
                  borderColor: selected ? tokens.accent : tokens.hairline,
                  color: selected ? tokens.accentWash.withValues(alpha: 0.5) : null,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(spec.name, style: Theme.of(context).textTheme.titleLarge),
                          ),
                          if (spec.bundled)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: tokens.olive.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'BUILT IN',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: tokens.olive,
                                      letterSpacing: 0.8,
                                    ),
                              ),
                            ),
                          if (selected)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(Icons.check_circle_rounded, color: tokens.accent, size: 20),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(spec.tagline, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            '${spec.sizeMb.toStringAsFixed(1)} MB',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(width: 8),
                          const Dot(size: 3),
                          const SizedBox(width: 8),
                          Text(
                            installed ? 'Installed' : 'Not downloaded',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: installed ? tokens.olive : tokens.muted,
                                ),
                          ),
                        ],
                      ),
                      if (installing) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: _progress[spec.id] ?? 0,
                            minHeight: 6,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (!installed)
                            FilledButton.tonal(
                              onPressed: installing ? null : () => _install(spec),
                              child: Text(installing ? 'Downloading…' : 'Download'),
                            )
                          else if (!spec.bundled)
                            OutlinedButton(
                              onPressed: () => _delete(spec),
                              child: const Text('Delete'),
                            ),
                          const Spacer(),
                          if (!selected)
                            FilledButton(
                              onPressed: () => _select(spec),
                              child: const Text('Use this'),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.memory_rounded, size: 16, color: tokens.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Micro and Mini need roughly 250–500 MB of free RAM while speaking. Nano is the safe choice on 2 GB phones.',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

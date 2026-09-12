import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../domain/models.dart';

Future<void> showAddTorrentSheet(
  BuildContext context,
  SeedexController controller, {
  String initialMagnet = '',
  String initialSourceUrl = '',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => FractionallySizedBox(
      heightFactor: 0.93,
      child: AddTorrentSheet(
        controller: controller,
        initialMagnet: initialMagnet,
        initialSourceUrl: initialSourceUrl,
      ),
    ),
  );
}

class AddTorrentSheet extends StatefulWidget {
  const AddTorrentSheet({
    required this.controller,
    this.initialMagnet = '',
    this.initialSourceUrl = '',
    super.key,
  });

  final SeedexController controller;
  final String initialMagnet;
  final String initialSourceUrl;

  @override
  State<AddTorrentSheet> createState() => _AddTorrentSheetState();
}

class _AddTorrentSheetState extends State<AddTorrentSheet> {
  late final TextEditingController _magnetController;
  late final TextEditingController _sourceController;
  PlatformFile? _torrentFile;
  int _mode = 0;
  double _ratio = 1;
  bool _submitting = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _magnetController = TextEditingController(text: widget.initialMagnet);
    _sourceController = TextEditingController(text: widget.initialSourceUrl);
  }

  @override
  void dispose() {
    _magnetController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _pickTorrent() async {
    final selected = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const <String>['torrent'],
    );
    if (selected != null) setState(() => _torrentFile = selected);
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      if (_mode == 0) {
        await widget.controller.addMagnet(
          magnet: _magnetController.text,
          manualSource: _sourceController.text.trim(),
          ratioTarget: _ratio,
        );
      } else {
        final selectedPath = _torrentFile?.path;
        if (selectedPath == null || selectedPath.isEmpty) {
          throw const FormatException('Choose a .torrent file first.');
        }
        await widget.controller.addTorrentFile(
          originalPath: selectedPath,
          manualSource: _sourceController.text.trim(),
          ratioTarget: _ratio,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = error
              .toString()
              .replaceFirst('FormatException: ', '')
              .replaceFirst('FileSystemException: ', '');
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text('Add torrent', style: theme.textTheme.headlineMedium)),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(CupertinoIcons.xmark_circle_fill),
              ),
            ],
          ),
          const SizedBox(height: 18),
          CupertinoSlidingSegmentedControl<int>(
            groupValue: _mode,
            thumbColor: theme.cardTheme.color ?? theme.colorScheme.surface,
            onValueChanged: (int? value) {
              if (value != null) setState(() => _mode = value);
            },
            children: const <int, Widget>{
              0: Padding(
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 18),
                child: Text('Magnet link'),
              ),
              1: Padding(
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 18),
                child: Text('.torrent file'),
              ),
            },
          ),
          const SizedBox(height: 22),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _mode == 0
                ? TextField(
                    key: const ValueKey<String>('magnet'),
                    controller: _magnetController,
                    minLines: 4,
                    maxLines: 7,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Magnet link',
                      hintText: 'magnet:?xt=urn:btih:…',
                      alignLabelWithHint: true,
                    ),
                  )
                : _FilePickerCard(file: _torrentFile, onPressed: _pickTorrent),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _sourceController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Source website · optional',
              hintText: 'https://example.org/page',
              prefixIcon: Icon(CupertinoIcons.globe, size: 20),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Seedex also records tracker domains, but labels them as inferred—not the original website.',
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 24),
          Text('Sharing target', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: <double>[0.5, 1, 2, 3].map((double value) {
              return ChoiceChip(
                label: Text('${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}:1'),
                selected: _ratio == value,
                onSelected: (_) => setState(() => _ratio = value),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: <Widget>[
                Icon(CupertinoIcons.folder, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Save to', style: theme.textTheme.labelMedium),
                      const SizedBox(height: 2),
                      Text(
                        widget.controller.settings.downloadPath,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_error.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Text(_error, style: theme.textTheme.bodyMedium?.copyWith(color: SeedexPalette.red)),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Start torrent'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilePickerCard extends StatelessWidget {
  const _FilePickerCard({required this.file, required this.onPressed});

  final PlatformFile? file;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      key: const ValueKey<String>('file'),
      borderRadius: BorderRadius.circular(18),
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          children: <Widget>[
            Icon(
              file == null ? CupertinoIcons.doc_badge_plus : CupertinoIcons.doc_checkmark_fill,
              color: file == null ? theme.colorScheme.primary : SeedexPalette.green,
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              file?.name ?? 'Choose a .torrent file',
              style: theme.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              file == null ? 'Tap to browse this device' : formatBytes(file!.size),
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showCreateGoalSheet(BuildContext context, SeedexController controller) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => CreateGoalSheet(controller: controller),
  );
}

class CreateGoalSheet extends StatefulWidget {
  const CreateGoalSheet({required this.controller, super.key});

  final SeedexController controller;

  @override
  State<CreateGoalSheet> createState() => _CreateGoalSheetState();
}

class _CreateGoalSheetState extends State<CreateGoalSheet> {
  GoalMetric _metric = GoalMetric.uploadedBytes;
  final TextEditingController _amount = TextEditingController(text: '1');
  final TextEditingController _title = TextEditingController(text: 'Seed 1 TB');
  String _unit = 'TB';
  DateTime? _deadline;
  String _error = '';

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    super.dispose();
  }

  void _updateSuggestedTitle() {
    final amount = _amount.text.trim().isEmpty ? '1' : _amount.text.trim();
    _title.text = switch (_metric) {
      GoalMetric.uploadedBytes => 'Seed $amount $_unit',
      GoalMetric.overallRatio => 'Reach a $amount ratio',
      GoalMetric.torrentsAtOne => 'Share back on $amount torrents',
      GoalMetric.seedingHours => 'Seed for $amount hours',
    };
  }

  void _create() {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0 || _title.text.trim().isEmpty) {
      setState(() => _error = 'Enter a title and a target greater than zero.');
      return;
    }
    final target = _metric == GoalMetric.uploadedBytes
        ? bytesFromAmount(amount, _unit).toDouble()
        : amount;
    widget.controller.addGoal(
      title: _title.text.trim(),
      metric: _metric,
      target: target,
      deadline: _deadline,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        22 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('New goal', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 22),
            DropdownButtonFormField<GoalMetric>(
              initialValue: _metric,
              decoration: const InputDecoration(labelText: 'Measure'),
              items: const <DropdownMenuItem<GoalMetric>>[
                DropdownMenuItem(value: GoalMetric.uploadedBytes, child: Text('Data uploaded')),
                DropdownMenuItem(value: GoalMetric.overallRatio, child: Text('Overall ratio')),
                DropdownMenuItem(value: GoalMetric.torrentsAtOne, child: Text('Torrents reaching 1:1')),
                DropdownMenuItem(value: GoalMetric.seedingHours, child: Text('Time spent seeding')),
              ],
              onChanged: (GoalMetric? value) {
                if (value == null) return;
                setState(() {
                  _metric = value;
                  _updateSuggestedTitle();
                });
              },
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Target'),
                    onChanged: (_) => _updateSuggestedTitle(),
                  ),
                ),
                if (_metric == GoalMetric.uploadedBytes) ...<Widget>[
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 104,
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(value: 'MB', child: Text('MB')),
                        DropdownMenuItem(value: 'GB', child: Text('GB')),
                        DropdownMenuItem(value: 'TB', child: Text('TB')),
                      ],
                      onChanged: (String? value) {
                        if (value == null) return;
                        setState(() {
                          _unit = value;
                          _updateSuggestedTitle();
                        });
                      },
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Goal name'),
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final selected = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                  initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)),
                );
                if (selected != null) setState(() => _deadline = selected);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Deadline · optional',
                  prefixIcon: Icon(CupertinoIcons.calendar, size: 20),
                ),
                child: Text(_deadline == null ? 'No deadline' : compactDate(_deadline!)),
              ),
            ),
            if (_error.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(_error, style: theme.textTheme.bodyMedium?.copyWith(color: SeedexPalette.red)),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _create,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text('Create goal'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

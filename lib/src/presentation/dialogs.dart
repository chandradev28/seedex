import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../data/torrent_metadata_parser.dart';
import '../domain/models.dart';

Future<void> showAddTorrentSheet(
  BuildContext context,
  SeedexController controller, {
  String initialMagnet = '',
  String initialTorrentFile = '',
  String initialSourceUrl = '',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => FractionallySizedBox(
      heightFactor: 0.96,
      child: AddTorrentSheet(
        controller: controller,
        initialMagnet: initialMagnet,
        initialTorrentFile: initialTorrentFile,
        initialSourceUrl: initialSourceUrl,
      ),
    ),
  );
}

class AddTorrentSheet extends StatefulWidget {
  const AddTorrentSheet({
    required this.controller,
    this.initialMagnet = '',
    this.initialTorrentFile = '',
    this.initialSourceUrl = '',
    super.key,
  });

  final SeedexController controller;
  final String initialMagnet;
  final String initialTorrentFile;
  final String initialSourceUrl;

  @override
  State<AddTorrentSheet> createState() => _AddTorrentSheetState();
}

class _AddTorrentSheetState extends State<AddTorrentSheet> {
  late final TextEditingController _magnetController;
  late final TextEditingController _sourceController;
  late int _inputMode;
  String _torrentPath = '';
  String _torrentName = '';
  String _existingDataPath = '';
  int _metadataBytes = 0;
  TorrentStartMode _startMode = TorrentStartMode.downloadAndSeed;
  double _ratio = 1;
  bool _submitting = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _magnetController = TextEditingController(text: widget.initialMagnet);
    _sourceController = TextEditingController(text: widget.initialSourceUrl);
    _inputMode = widget.initialTorrentFile.isEmpty ? 0 : 1;
    _torrentPath = widget.initialTorrentFile;
    _torrentName = _fileName(widget.initialTorrentFile);
    if (_torrentPath.isNotEmpty) {
      unawaited(_loadMetadataPreview(_torrentPath));
    }
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
    final selectedPath = selected?.path;
    if (selectedPath == null || selectedPath.isEmpty || !mounted) return;
    setState(() {
      _torrentPath = selectedPath;
      _torrentName = selected?.name ?? _fileName(selectedPath);
      _metadataBytes = 0;
    });
    await _loadMetadataPreview(selectedPath);
  }

  Future<void> _loadMetadataPreview(String filePath) async {
    if (filePath.startsWith('content://') || filePath.startsWith('file://')) {
      return;
    }
    try {
      final hint = TorrentMetadataParser.parse(
        await File(filePath).readAsBytes(),
      );
      if (!mounted || filePath != _torrentPath) return;
      setState(() {
        _metadataBytes = hint.totalBytes;
        if (hint.name.isNotEmpty) _torrentName = hint.name;
      });
    } on Object {
      // libtorrent performs the authoritative validation on import.
    }
  }

  String _fileName(String value) {
    if (value.isEmpty) return '';
    final uri = Uri.tryParse(value);
    final parsedPath = uri?.path ?? '';
    final pathValue = parsedPath.isNotEmpty ? parsedPath : value;
    final segments = pathValue.split('/').where((String item) {
      return item.isNotEmpty;
    }).toList();
    return segments.isEmpty ? 'Shared torrent file' : segments.last;
  }

  Future<void> _pickExistingDataFolder() async {
    final selected = await FilePicker.getDirectoryPath();
    if (selected != null && mounted) {
      setState(() => _existingDataPath = selected);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      if (_inputMode == 0) {
        final typedSource = _sourceController.text.trim();
        final isSharedSource = widget.initialSourceUrl.isNotEmpty &&
            typedSource == widget.initialSourceUrl;
        await widget.controller.addMagnet(
          magnet: _magnetController.text,
          sourceUrl: isSharedSource ? typedSource : '',
          manualSource: isSharedSource ? '' : typedSource,
          ratioTarget: _ratio,
          startMode: _startMode,
          existingDataPath: _existingDataPath,
        );
      } else {
        if (_torrentPath.isEmpty) {
          throw const FormatException('Choose a .torrent file first.');
        }
        await widget.controller.addTorrentFile(
          originalPath: _torrentPath,
          manualSource: _sourceController.text.trim(),
          ratioTarget: _ratio,
          startMode: _startMode,
          existingDataPath: _existingDataPath,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error
            .toString()
            .replaceFirst('FormatException: ', '')
            .replaceFirst('FileSystemException: ', '')
            .replaceFirst('TelegramApiException: ', '');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usingExisting = _startMode == TorrentStartMode.existingData;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Add torrent', style: theme.textTheme.headlineMedium),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(CupertinoIcons.xmark_circle_fill),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: <Widget>[
                Text(
                  'How should Seedex start?',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                CupertinoSlidingSegmentedControl<TorrentStartMode>(
                  groupValue: _startMode,
                  thumbColor:
                      theme.cardTheme.color ?? theme.colorScheme.surface,
                  onValueChanged: (TorrentStartMode? value) {
                    if (value != null) setState(() => _startMode = value);
                  },
                  children: const <TorrentStartMode, Widget>{
                    TorrentStartMode.downloadAndSeed: Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                      child: Text('Download & seed'),
                    ),
                    TorrentStartMode.existingData: Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                      child: Text('I have the files'),
                    ),
                  },
                ),
                const SizedBox(height: 14),
                _ModeExplanation(existingData: usingExisting),
                const SizedBox(height: 22),
                Text('Torrent metadata', style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                CupertinoSlidingSegmentedControl<int>(
                  groupValue: _inputMode,
                  thumbColor:
                      theme.cardTheme.color ?? theme.colorScheme.surface,
                  onValueChanged: (int? value) {
                    if (value != null) setState(() => _inputMode = value);
                  },
                  children: const <int, Widget>{
                    0: Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 18),
                      child: Text('Magnet link'),
                    ),
                    1: Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 18),
                      child: Text('.torrent file'),
                    ),
                  },
                ),
                const SizedBox(height: 18),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _inputMode == 0
                      ? TextField(
                          key: const ValueKey<String>('magnet'),
                          controller: _magnetController,
                          minLines: 3,
                          maxLines: 6,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Magnet link',
                            hintText: 'magnet:?xt=urn:btih:…',
                            alignLabelWithHint: true,
                          ),
                        )
                      : _FilePickerCard(
                          fileName: _torrentName,
                          onPressed: _pickTorrent,
                        ),
                ),
                const SizedBox(height: 10),
                Text(
                  _storageMessage,
                  style: theme.textTheme.labelMedium,
                ),
                if (usingExisting) ...<Widget>[
                  const SizedBox(height: 18),
                  _FolderPickerCard(
                    path: _existingDataPath,
                    onPressed: _pickExistingDataFolder,
                  ),
                ],
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
                  'Tracker domains are marked as inferred, never as the original website.',
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: 24),
                Text('Sharing target', style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <double>[0.5, 1, 2, 3].map((double value) {
                    return ChoiceChip(
                      label: Text(
                        '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}:1',
                      ),
                      selected: _ratio == value,
                      onSelected: (_) => setState(() => _ratio = value),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                _SavePathCard(
                  title: usingExisting ? 'Verify files in' : 'Download to',
                  path: usingExisting
                      ? (_existingDataPath.isEmpty
                          ? 'Choose an existing content folder'
                          : _existingDataPath)
                      : widget.controller.settings.downloadPath,
                ),
                if (_error.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  Text(
                    _error,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: SeedexPalette.red),
                  ),
                ],
                const SizedBox(height: 18),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      usingExisting
                          ? 'Verify files & seed'
                          : 'Download & seed',
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String get _storageMessage {
    if (_metadataBytes > 0) {
      return 'Content size: ${formatBytes(_metadataBytes)}. Keep at least this '
          'much storage available.';
    }
    if (_inputMode == 0) {
      return 'A magnet contains metadata only. Content size appears after '
          'metadata is fetched.';
    }
    return 'A .torrent file contains metadata only. Content size will be '
        'checked during import.';
  }
}

class _ModeExplanation extends StatelessWidget {
  const _ModeExplanation({required this.existingData});

  final bool existingData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            existingData
                ? CupertinoIcons.checkmark_shield_fill
                : CupertinoIcons.arrow_down_circle_fill,
            color: theme.colorScheme.primary,
            size: 21,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              existingData
                  ? 'Metadata alone cannot seed. Seedex hash-checks the exact '
                      'files in your selected folder and starts seeding only '
                      'after verification reaches 100%.'
                  : 'Metadata alone cannot seed. Seedex downloads the real '
                      'pieces, can upload completed pieces while downloading, '
                      'and becomes a full seeder at 100%.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilePickerCard extends StatelessWidget {
  const _FilePickerCard({required this.fileName, required this.onPressed});

  final String fileName;
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
              fileName.isEmpty
                  ? CupertinoIcons.doc_fill
                  : CupertinoIcons.doc_checkmark_fill,
              color: fileName.isEmpty
                  ? theme.colorScheme.primary
                  : SeedexPalette.green,
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              fileName.isEmpty ? 'Choose a .torrent file' : fileName,
              style: theme.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              fileName.isEmpty ? 'Tap to browse this device' : 'Ready to import',
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderPickerCard extends StatelessWidget {
  const _FolderPickerCard({required this.path, required this.onPressed});

  final String path;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              path.isEmpty
                  ? CupertinoIcons.folder_badge_plus
                  : CupertinoIcons.folder_fill,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    path.isEmpty
                        ? 'Choose existing content folder'
                        : 'Existing content folder',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    path.isEmpty ? 'Required for verification' : path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_forward, size: 17),
          ],
        ),
      ),
    );
  }
}

class _SavePathCard extends StatelessWidget {
  const _SavePathCard({required this.title, required this.path});

  final String title;
  final String path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            CupertinoIcons.folder,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(
                  path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showCreateGoalSheet(
  BuildContext context,
  SeedexController controller,
) {
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
      setState(() {
        _error = 'Enter a title and a target greater than zero.';
      });
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
                DropdownMenuItem(
                  value: GoalMetric.uploadedBytes,
                  child: Text('Data uploaded'),
                ),
                DropdownMenuItem(
                  value: GoalMetric.overallRatio,
                  child: Text('Overall ratio'),
                ),
                DropdownMenuItem(
                  value: GoalMetric.torrentsAtOne,
                  child: Text('Torrents reaching 1:1'),
                ),
                DropdownMenuItem(
                  value: GoalMetric.seedingHours,
                  child: Text('Time spent seeding'),
                ),
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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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
                  initialDate: _deadline ??
                      DateTime.now().add(const Duration(days: 30)),
                );
                if (selected != null && mounted) {
                  setState(() => _deadline = selected);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Deadline · optional',
                  prefixIcon: Icon(CupertinoIcons.calendar, size: 20),
                ),
                child: Text(
                  _deadline == null ? 'No deadline' : compactDate(_deadline!),
                ),
              ),
            ),
            if (_error.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _error,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: SeedexPalette.red),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _create,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
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

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../domain/models.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.controller, super.key});

  final SeedexController controller;

  @override
  Widget build(BuildContext context) {
    final settings = controller.settings;
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: <Widget>[
          const SliverToBoxAdapter(
            child: PageHeader(title: 'Settings', subtitle: 'Control data, power, and privacy'),
          ),
          SliverToBoxAdapter(
            child: _SettingsSection(
              title: 'Network',
              children: <Widget>[
                _SettingsToggle(
                  icon: CupertinoIcons.wifi,
                  color: SeedexPalette.blue,
                  title: 'Wi-Fi only',
                  subtitle: 'Pause transfers when Wi-Fi is unavailable',
                  value: settings.wifiOnly,
                  onChanged: (bool value) => controller.updateSettings(
                    settings.copyWith(wifiOnly: value, cellularAllowed: value ? false : settings.cellularAllowed),
                  ),
                ),
                _SettingsToggle(
                  icon: CupertinoIcons.antenna_radiowaves_left_right,
                  color: SeedexPalette.green,
                  title: 'Allow cellular data',
                  subtitle: 'May use a large amount of mobile data',
                  value: settings.cellularAllowed,
                  onChanged: settings.wifiOnly
                      ? null
                      : (bool value) => controller.updateSettings(
                            settings.copyWith(cellularAllowed: value),
                          ),
                ),
                _SettingsAction(
                  icon: CupertinoIcons.speedometer,
                  color: SeedexPalette.orange,
                  title: 'Speed limits',
                  value: settings.downloadLimit == 0 && settings.uploadLimit == 0
                      ? 'Unlimited'
                      : '↓ ${formatSpeed(settings.downloadLimit)} · ↑ ${formatSpeed(settings.uploadLimit)}',
                  onTap: () => _showSpeedLimits(context, controller),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: _SettingsSection(
              title: 'Sharing',
              children: <Widget>[
                _SettingsToggle(
                  icon: CupertinoIcons.arrow_2_circlepath,
                  color: SeedexPalette.green,
                  title: 'Continue after goal',
                  subtitle: 'Keep seeding after the torrent reaches its ratio target',
                  value: settings.continueAfterGoal,
                  onChanged: (bool value) => controller.updateSettings(
                    settings.copyWith(continueAfterGoal: value),
                  ),
                ),
                _SettingsAction(
                  icon: CupertinoIcons.folder_fill,
                  color: SeedexPalette.blue,
                  title: 'Download folder',
                  value: settings.downloadPath,
                  onTap: () async {
                    final selected = await FilePicker.getDirectoryPath();
                    if (selected != null) await controller.chooseDownloadPath(selected);
                  },
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: _SettingsSection(
              title: 'Appearance',
              children: <Widget>[
                _SettingsToggle(
                  icon: CupertinoIcons.moon_fill,
                  color: const Color(0xFF7357B5),
                  title: 'Dark appearance',
                  subtitle: 'Use Seedex’s low-light color palette',
                  value: settings.darkMode,
                  onChanged: (bool value) => controller.updateSettings(
                    settings.copyWith(darkMode: value),
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: _SettingsSection(
              title: 'About',
              children: <Widget>[
                _SettingsAction(
                  icon: CupertinoIcons.doc_text_fill,
                  color: SeedexPalette.secondary,
                  title: 'Open-source licenses',
                  value: '',
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Seedex',
                    applicationVersion: '0.1.0',
                    applicationLegalese: 'GPL-3.0 · Built for lawful sharing',
                  ),
                ),
                const _SettingsInfo(
                  icon: CupertinoIcons.device_phone_portrait,
                  color: SeedexPalette.blue,
                  title: 'Seedex for Android',
                  value: 'Version 0.1.0',
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: SeedexPalette.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(CupertinoIcons.info_circle_fill, color: SeedexPalette.orange, size: 20),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'Android 15+ limits data-sync foreground services to six hours per 24-hour period. Opening Seedex resets the allowance. Force Stop always ends transfers.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSpeedLimits(BuildContext context, SeedexController controller) async {
    final down = TextEditingController(
      text: controller.settings.downloadLimit == 0
          ? ''
          : (controller.settings.downloadLimit / 1000000).toStringAsFixed(1),
    );
    final up = TextEditingController(
      text: controller.settings.uploadLimit == 0
          ? ''
          : (controller.settings.uploadLimit / 1000000).toStringAsFixed(1),
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Speed limits', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Leave a value empty for unlimited.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 18),
            TextField(
              controller: down,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Download limit · MB/s'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: up,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Upload limit · MB/s'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () {
                  final download = ((double.tryParse(down.text) ?? 0) * 1000000).round();
                  final upload = ((double.tryParse(up.text) ?? 0) * 1000000).round();
                  controller.updateSettings(controller.settings.copyWith(
                    downloadLimit: download,
                    uploadLimit: upload,
                  ));
                  Navigator.of(context).pop();
                },
                child: const Text('Save limits'),
              ),
            ),
          ],
        ),
      ),
    );
    down.dispose();
    up.dispose();
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(title.toUpperCase(), style: Theme.of(context).textTheme.labelMedium),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              children: List<Widget>.generate(children.length * 2 - 1, (int index) {
                if (index.isOdd) return const Padding(padding: EdgeInsets.only(left: 62), child: Divider());
                return children[index ~/ 2];
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  const _SettingsToggle({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsRow(
      icon: icon,
      color: color,
      title: title,
      subtitle: subtitle,
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

class _SettingsAction extends StatelessWidget {
  const _SettingsAction({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SettingsRow(
      icon: icon,
      color: color,
      title: title,
      subtitle: value,
      onTap: onTap,
      trailing: const Icon(CupertinoIcons.chevron_forward, size: 17),
    );
  }
}

class _SettingsInfo extends StatelessWidget {
  const _SettingsInfo({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _SettingsRow(icon: icon, color: color, title: title, subtitle: value);
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle = '',
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  if (subtitle.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.labelMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[const SizedBox(width: 10), trailing!],
          ],
        ),
      ),
    );
  }
}

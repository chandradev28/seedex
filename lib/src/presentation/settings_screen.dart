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
    final AppSettings settings = controller.settings;
    final telegramReady = controller.telegramConfigured;
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: <Widget>[
          const SliverToBoxAdapter(
            child: PageHeader(
              title: 'Settings',
              subtitle: 'Control data, power, and privacy',
            ),
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
                    settings.copyWith(
                      wifiOnly: value,
                      cellularAllowed: value ? false : settings.cellularAllowed,
                    ),
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
                  value:
                      settings.downloadLimit == 0 && settings.uploadLimit == 0
                      ? 'Unlimited'
                      : '↓ ${formatSpeed(settings.downloadLimit)} · '
                            '↑ ${formatSpeed(settings.uploadLimit)}',
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
                  subtitle:
                      'Keep seeding after the torrent reaches its ratio target',
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
                    if (selected != null) {
                      await controller.chooseDownloadPath(selected);
                    }
                  },
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: _SettingsSection(
              title: 'Telegram',
              children: <Widget>[
                _SettingsAction(
                  icon: CupertinoIcons.paperplane_fill,
                  color: SeedexPalette.blue,
                  title: 'Telegram bot',
                  value: telegramReady
                      ? (controller.telegramBotName.isEmpty
                            ? 'Credentials encrypted on this device'
                            : 'Connected to ${controller.telegramBotName}')
                      : 'Set up a private control bot',
                  onTap: () => _showTelegramSetup(context, controller),
                ),
                _SettingsToggle(
                  icon: CupertinoIcons.power,
                  color: SeedexPalette.green,
                  title: 'Enable Telegram',
                  subtitle: 'Keep the bot active with Seedex’s service',
                  value: telegramReady && settings.telegramEnabled,
                  onChanged: telegramReady
                      ? (bool value) => controller.updateSettings(
                          settings.copyWith(telegramEnabled: value),
                        )
                      : null,
                ),
                _SettingsToggle(
                  icon: CupertinoIcons.command,
                  color: SeedexPalette.secondary,
                  title: 'Remote commands',
                  subtitle: '/status, /add, /pauseall, /resumeall',
                  value: telegramReady && settings.telegramRemoteCommands,
                  onChanged: telegramReady && settings.telegramEnabled
                      ? (bool value) => controller.updateSettings(
                          settings.copyWith(telegramRemoteCommands: value),
                        )
                      : null,
                ),
                _SettingsToggle(
                  icon: CupertinoIcons.checkmark_circle_fill,
                  color: SeedexPalette.green,
                  title: 'Seeding notifications',
                  subtitle: 'Message the approved chat when seeding begins',
                  value:
                      telegramReady && settings.telegramCompletionNotifications,
                  onChanged: telegramReady && settings.telegramEnabled
                      ? (bool value) => controller.updateSettings(
                          settings.copyWith(
                            telegramCompletionNotifications: value,
                          ),
                        )
                      : null,
                ),
                _SettingsToggle(
                  icon: CupertinoIcons.flag_fill,
                  color: SeedexPalette.orange,
                  title: 'Goal notifications',
                  subtitle: 'Message the approved chat when a goal completes',
                  value: telegramReady && settings.telegramGoalNotifications,
                  onChanged: telegramReady && settings.telegramEnabled
                      ? (bool value) => controller.updateSettings(
                          settings.copyWith(telegramGoalNotifications: value),
                        )
                      : null,
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: SeedexPalette.blue.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      CupertinoIcons.lock_shield_fill,
                      color: SeedexPalette.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'The phone remains the BitTorrent peer and stores the '
                        'real files. Telegram is only a secure control and '
                        'notification channel. Only the approved chat ID is '
                        'accepted, and the bot works only while Android allows '
                        'Seedex’s foreground service to run.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
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
                    applicationVersion: '0.2.0',
                    applicationLegalese: 'GPL-3.0 · Built for lawful sharing',
                  ),
                ),
                const _SettingsInfo(
                  icon: CupertinoIcons.device_phone_portrait,
                  color: SeedexPalette.blue,
                  title: 'Seedex for Android',
                  value: 'Version 0.2.0',
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
                    const Icon(
                      CupertinoIcons.info_circle_fill,
                      color: SeedexPalette.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'Android 15+ limits data-sync foreground services to '
                        'six hours per 24-hour period. Opening Seedex resets '
                        'the allowance. Force Stop always ends transfers and '
                        'Telegram control.',
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

  Future<void> _showSpeedLimits(
    BuildContext context,
    SeedexController controller,
  ) async {
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
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Speed limits',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Leave a value empty for unlimited.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: down,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Download limit · MB/s',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: up,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Upload limit · MB/s',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () {
                  final download = ((double.tryParse(down.text) ?? 0) * 1000000)
                      .round();
                  final upload = ((double.tryParse(up.text) ?? 0) * 1000000)
                      .round();
                  controller.updateSettings(
                    controller.settings.copyWith(
                      downloadLimit: download,
                      uploadLimit: upload,
                    ),
                  );
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

  Future<void> _showTelegramSetup(
    BuildContext context,
    SeedexController controller,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) =>
          _TelegramSetupSheet(controller: controller),
    );
  }
}

class _TelegramSetupSheet extends StatefulWidget {
  const _TelegramSetupSheet({required this.controller});

  final SeedexController controller;

  @override
  State<_TelegramSetupSheet> createState() => _TelegramSetupSheetState();
}

class _TelegramSetupSheetState extends State<_TelegramSetupSheet> {
  final TextEditingController _token = TextEditingController();
  final TextEditingController _chatId = TextEditingController();
  bool _obscureToken = true;
  bool _busy = false;
  String _message = '';
  bool _messageIsError = false;

  @override
  void dispose() {
    _token.dispose();
    _chatId.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String> Function() operation) async {
    setState(() {
      _busy = true;
      _message = '';
      _messageIsError = false;
    });
    try {
      final result = await operation();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'Connected to $result. A test message was delivered.';
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _messageIsError = true;
        _message = error
            .toString()
            .replaceFirst('FormatException: ', '')
            .replaceFirst('TelegramApiException: ', '');
      });
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
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Telegram bot',
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(CupertinoIcons.xmark_circle_fill),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Create your own bot with @BotFather, message it once, then '
              'enter its token and the numeric ID of the only chat Seedex '
              'should trust. Never share or commit the token.',
              style: theme.textTheme.bodyMedium,
            ),
            if (widget.controller.telegramConfigured) ...<Widget>[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: SeedexPalette.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'A bot token and approved chat ID are encrypted on this '
                  'device. Enter new values below only to replace them.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
            const SizedBox(height: 18),
            TextField(
              controller: _token,
              obscureText: _obscureToken,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Bot token',
                hintText: '123456789:AA…',
                prefixIcon: const Icon(CupertinoIcons.lock_fill, size: 20),
                suffixIcon: IconButton(
                  tooltip: _obscureToken ? 'Show token' : 'Hide token',
                  onPressed: () {
                    setState(() => _obscureToken = !_obscureToken);
                  },
                  icon: Icon(
                    _obscureToken
                        ? CupertinoIcons.eye
                        : CupertinoIcons.eye_slash,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _chatId,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Approved chat ID',
                hintText: '-1001234567890',
                prefixIcon: Icon(
                  CupertinoIcons.person_crop_circle_badge_checkmark,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Seedex uses the official Bot API with long polling. No custom '
              'webhook server or hosted database is required. Telegram cloud '
              'is still an external service.',
              style: theme.textTheme.labelMedium,
            ),
            if (_message.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                _message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _messageIsError
                      ? SeedexPalette.red
                      : SeedexPalette.green,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => widget.controller.testTelegramCredentials(
                              botToken: _token.text,
                              chatId: _chatId.text,
                            ),
                          ),
                    child: const Text('Test'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => widget.controller.configureTelegram(
                              botToken: _token.text,
                              chatId: _chatId.text,
                            ),
                          ),
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save & enable'),
                  ),
                ),
              ],
            ),
            if (widget.controller.telegramConfigured) ...<Widget>[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          await widget.controller.disconnectTelegram();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: SeedexPalette.red,
                  ),
                  child: const Text('Disconnect and erase credentials'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              children: List<Widget>.generate(children.length * 2 - 1, (
                int index,
              ) {
                if (index.isOdd) {
                  return const Padding(
                    padding: EdgeInsets.only(left: 62),
                    child: Divider(),
                  );
                }
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
    return _SettingsRow(
      icon: icon,
      color: color,
      title: title,
      subtitle: value,
    );
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
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
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
            if (trailing != null) ...<Widget>[
              const SizedBox(width: 10),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

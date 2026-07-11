import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../cubit/settings_cubit.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/haptics_helper.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final settings = state.settings;
        final cubit = context.read<SettingsCubit>();
        final colorScheme = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('settings'), style: const TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              _buildSection(context, context.tr('management'), [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.withAlpha(20),
                    child: const Icon(Icons.playlist_play_rounded, color: Colors.teal, size: 20),
                  ),
                  title: Text(context.tr('select_source'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () async {
                    unawaited(HapticsHelper.light());
                    await cubit.setActivePlaylist(null);
                    if (context.mounted) context.go('/playlists');
                  },
                ),
                const Divider(indent: 72, endIndent: 20, height: 1),
                SwitchListTile(
                  secondary: CircleAvatar(
                    backgroundColor: Colors.blue.withAlpha(20),
                    child: const Icon(Icons.sync_rounded, color: Colors.blue, size: 20),
                  ),
                  title: Text(context.tr('auto_refresh'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(context.tr('auto_refresh_desc'), style: const TextStyle(fontSize: 12)),
                  value: settings.autoRefreshPlaylists,
                  onChanged: (v) async {
                    unawaited(HapticsHelper.light());
                    await cubit.updateSettings((s) => s.autoRefreshPlaylists = v);
                  },
                ),
              ]),
              const SizedBox(height: 12),
              _buildSection(context, context.tr('appearance'), [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primary.withAlpha(20),
                    child: Icon(Icons.palette_outlined, color: colorScheme.primary, size: 20),
                  ),
                  title: Text(context.tr('theme_mode'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(settings.themeMode.toUpperCase(), style: TextStyle(color: colorScheme.outline)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    unawaited(HapticsHelper.light());
                    _showThemePicker(context, settings.themeMode);
                  },
                ),
                const Divider(indent: 72, endIndent: 20, height: 1),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.withAlpha(20),
                    child: const Icon(Icons.language_rounded, color: Colors.orange, size: 20),
                  ),
                  title: Text(context.tr('language'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(settings.language == 'ar' ? 'العربية' : 'English', style: TextStyle(color: colorScheme.outline)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    unawaited(HapticsHelper.light());
                    _showLanguagePicker(context, settings.language);
                  },
                ),
              ]),
              const SizedBox(height: 12),
              _buildSection(context, context.tr('playback'), [
                SwitchListTile(
                  secondary: CircleAvatar(
                    backgroundColor: Colors.orange.withAlpha(20),
                    child: const Icon(Icons.bolt_rounded, color: Colors.orange, size: 20),
                  ),
                  title: Text(context.tr('hardware_accel'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  value: settings.hardwareAcceleration,
                  onChanged: (v) async {
                    unawaited(HapticsHelper.light());
                    await cubit.updateSettings((s) => s.hardwareAcceleration = v);
                  },
                ),
                const Divider(indent: 72, endIndent: 20, height: 1),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withAlpha(20),
                    child: const Icon(Icons.timer_outlined, color: Colors.blue, size: 20),
                  ),
                  title: Text(context.tr('buffer_size'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${settings.bufferMs} ms', style: TextStyle(color: colorScheme.outline, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    unawaited(HapticsHelper.light());
                    _showBufferPicker(context, settings.bufferMs);
                  },
                ),
              ]),
              const SizedBox(height: 12),
              _buildSection(context, context.tr('storage_privacy'), [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.withAlpha(20),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                  ),
                  title: Text(context.tr('clear_cache'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  onTap: () async {
                    unawaited(HapticsHelper.medium());
                    try {
                      final tempDir = await getTemporaryDirectory();
                      if (tempDir.existsSync()) {
                        final files = tempDir.listSync();
                        for (var file in files) {
                          try {
                            file.deleteSync(recursive: true);
                          } catch (_) {}
                        }
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.tr('clear_cache_success'))),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${context.tr('clear_cache_error')}: $e')),
                        );
                      }
                    }
                  },
                ),
              ]),
              const SizedBox(height: 12),
              _buildSection(context, context.tr('support'), [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.tertiary.withAlpha(20),
                    child: Icon(Icons.info_outline_rounded, color: colorScheme.tertiary, size: 20),
                  ),
                  title: Text(context.tr('version'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('1.0.0 (Release Build)'),
                ),
                const Divider(indent: 72, endIndent: 20, height: 1),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueGrey.withAlpha(20),
                    child: const Icon(Icons.gavel_rounded, color: Colors.blueGrey, size: 20),
                  ),
                  title: Text(context.tr('privacy_terms'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () => context.push('/settings/legal'),
                ),
              ]),
              const SizedBox(height: 60),
            ],
          ),
        );
      },
    );
  }

  void _showThemePicker(BuildContext context, String currentMode) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr('select_theme'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _themeOption(context, 'system', Icons.brightness_auto, currentMode),
            _themeOption(context, 'light', Icons.light_mode, currentMode),
            _themeOption(context, 'dark', Icons.dark_mode, currentMode),
          ],
        ),
      ),
    );
  }

  Widget _themeOption(BuildContext context, String mode, IconData icon, String currentMode) {
    return ListTile(
      leading: Icon(icon),
      title: Text(mode.toUpperCase()),
      trailing: currentMode == mode ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: () {
        HapticsHelper.light();
        context.read<SettingsCubit>().setThemeMode(mode);
        Navigator.pop(context);
      },
    );
  }

  void _showLanguagePicker(BuildContext context, String currentLang) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr('select_lang'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ListTile(
              title: const Text('العربية'),
              trailing: currentLang == 'ar' ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () {
                HapticsHelper.light();
                context.read<SettingsCubit>().updateSettings((s) => s.language = 'ar');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('English'),
              trailing: currentLang == 'en' ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () {
                HapticsHelper.light();
                context.read<SettingsCubit>().updateSettings((s) => s.language = 'en');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBufferPicker(BuildContext context, int currentBuffer) {
    showDialog(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(context.tr('buffer_size')),
        children: [1000, 2000, 5000, 10000].map((b) => SimpleDialogOption(
          onPressed: () {
            HapticsHelper.light();
            context.read<SettingsCubit>().updateSettings((s) => s.bufferMs = b);
            Navigator.pop(dialogContext);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$b ms'),
              if (currentBuffer == b) const Icon(Icons.check, size: 18, color: Colors.blue),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: colorScheme.outlineVariant.withAlpha(50)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

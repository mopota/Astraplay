import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../cubit/settings_cubit.dart';
import 'package:path_provider/path_provider.dart';

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
            title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              _buildSection(context, 'PLAYLIST MANAGEMENT', [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.withAlpha(20),
                    child: const Icon(Icons.playlist_play_rounded, color: Colors.teal, size: 20),
                  ),
                  title: const Text('Switch Source', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Change active playlist or add new ones', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () async {
                    await cubit.setActivePlaylist(null);
                    if (context.mounted) context.go('/playlists');
                  },
                ),
                const Divider(indent: 72, endIndent: 20, height: 1),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withAlpha(20),
                    child: const Icon(Icons.add_rounded, color: Colors.blue, size: 20),
                  ),
                  title: const Text('Add New Source', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () => context.push('/add-source'),
                ),
              ]),
              const SizedBox(height: 12),
              _buildSection(context, 'APPEARANCE', [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primary.withAlpha(20),
                    child: Icon(Icons.palette_outlined, color: colorScheme.primary, size: 20),
                  ),
                  title: const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(settings.themeMode.toUpperCase(), style: TextStyle(color: colorScheme.outline)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    _showThemePicker(context, settings.themeMode);
                  },
                ),
              ]),
              const SizedBox(height: 12),
              _buildSection(context, 'PLAYBACK', [
                SwitchListTile(
                  secondary: CircleAvatar(
                    backgroundColor: Colors.orange.withAlpha(20),
                    child: const Icon(Icons.bolt_rounded, color: Colors.orange, size: 20),
                  ),
                  title: const Text('Hardware Acceleration', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Better performance for HD streams', style: TextStyle(color: colorScheme.outline, fontSize: 12)),
                  value: settings.hardwareAcceleration,
                  onChanged: (v) {
                    cubit.updateSettings((s) => s.hardwareAcceleration = v);
                  },
                ),
                const Divider(indent: 72, endIndent: 20, height: 1),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withAlpha(20),
                    child: const Icon(Icons.timer_outlined, color: Colors.blue, size: 20),
                  ),
                  title: const Text('Buffer Size', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${settings.bufferMs} ms (Recommended for stable internet)', style: TextStyle(color: colorScheme.outline, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    _showBufferPicker(context, settings.bufferMs);
                  },
                ),
              ]),
              const SizedBox(height: 12),
              _buildSection(context, 'STORAGE & PRIVACY', [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.withAlpha(20),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                  ),
                  title: const Text('Clear Cache', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  subtitle: const Text('Removes stored logos and metadata', style: TextStyle(fontSize: 12)),
                  onTap: () async {
                    final dir = await getTemporaryDirectory();
                    if (dir.existsSync()) {
                      dir.deleteSync(recursive: true);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cache cleared successfully')),
                        );
                      }
                    }
                  },
                ),
              ]),
              const SizedBox(height: 12),
              _buildSection(context, 'SUPPORT', [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.tertiary.withAlpha(20),
                    child: Icon(Icons.info_outline_rounded, color: colorScheme.tertiary, size: 20),
                  ),
                  title: const Text('AstraPlay Version', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('1.0.0 (Release Build)'),
                ),
                const Divider(indent: 72, endIndent: 20, height: 1),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.outline.withAlpha(20),
                    child: Icon(Icons.description_outlined, color: colorScheme.outline, size: 20),
                  ),
                  title: const Text('Open Source Licenses', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () => showLicensePage(context: context),
                ),
                const Divider(indent: 72, endIndent: 20, height: 1),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueGrey.withAlpha(20),
                    child: const Icon(Icons.gavel_rounded, color: Colors.blueGrey, size: 20),
                  ),
                  title: const Text('Privacy & Terms', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Privacy policy and usage terms', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () => context.push('/settings/legal'),
                ),
              ]),
              const SizedBox(height: 60),
              const Center(
                child: Opacity(
                  opacity: 0.5,
                  child: Text('Made with ❤️ for IPTV Lovers', style: TextStyle(fontSize: 12)),
                ),
              ),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Theme',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
        context.read<SettingsCubit>().setThemeMode(mode);
        Navigator.pop(context);
      },
    );
  }

  void _showBufferPicker(BuildContext context, int currentBuffer) {
    showDialog(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Select Buffer Size (ms)'),
        children: [1000, 2000, 5000, 10000].map((b) => SimpleDialogOption(
          onPressed: () {
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

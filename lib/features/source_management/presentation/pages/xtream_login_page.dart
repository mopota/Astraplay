import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/presentation/widgets/progress_button.dart';
import '../../../playlist/presentation/bloc/playlist_bloc.dart';

class XtreamLoginPage extends StatefulWidget {
  const XtreamLoginPage({super.key});

  @override
  State<XtreamLoginPage> createState() => _XtreamLoginPageState();
}

class _XtreamLoginPageState extends State<XtreamLoginPage> {
  final _urlController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BlocListener<PlaylistBloc, PlaylistState>(
      listener: (context, state) {
        if (state.operationSuccess) {
          context.go('/playlists');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('xtream_success'))),
          );
        }
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${context.tr('error')}: ${state.error}')),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('xtream_login'), style: const TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.cloud_sync_rounded, size: 48, color: colorScheme.primary),
              ).animate().scale(duration: 500.ms),
              const SizedBox(height: 24),
              Text(
                context.tr('enter_details'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('xtream_login_desc'),
                style: TextStyle(color: colorScheme.outline, fontSize: 14),
              ),
              const SizedBox(height: 48),
              _buildField(_nameController, context.tr('profile_name'), Icons.badge_outlined, 'e.g. My Provider'),
              const SizedBox(height: 16),
              _buildField(_urlController, context.tr('server_url'), Icons.dns_outlined, 'http://server.com:8080'),
              const SizedBox(height: 16),
              _buildField(_userController, context.tr('username'), Icons.person_outline_rounded, 'Your username'),
              const SizedBox(height: 16),
              _buildField(_passController, context.tr('password'), Icons.lock_outline_rounded, 'Your password', isPassword: true),
              const SizedBox(height: 48),
              BlocBuilder<PlaylistBloc, PlaylistState>(
                builder: (context, state) {
                  return ProgressButton(
                    isLoading: state.isLoading,
                    progress: state.progress,
                    statusMessage: state.statusMessage,
                    label: context.tr('authenticate_import'),
                    onPressed: _login,
                  );
                },
              ),
            ],
          ).animate().fadeIn(duration: 500.ms),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, String hint, {bool isPassword = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: colorScheme.primary),
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh.withAlpha(100),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.outlineVariant.withAlpha(50)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
    );
  }

  void _login() {
    if (_nameController.text.isEmpty || 
        _urlController.text.isEmpty || 
        _userController.text.isEmpty || 
        _passController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('fill_all_fields'))),
      );
      return;
    }

    context.read<PlaylistBloc>().add(AddXtreamPlaylistEvent(
      name: _nameController.text,
      url: _urlController.text,
      username: _userController.text,
      password: _passController.text,
    ));
  }
}

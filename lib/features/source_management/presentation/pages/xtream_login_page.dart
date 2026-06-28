import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Xtream source added successfully')),
          );
        }
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${state.error}')),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Xtream Login', style: TextStyle(fontWeight: FontWeight.bold)),
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
              const Text(
                'Enter Provider Details',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Connect to your Xtream Codes API provider',
                style: TextStyle(color: colorScheme.outline, fontSize: 14),
              ),
              const SizedBox(height: 48),
              _buildField(_nameController, 'Profile Name', Icons.badge_outlined, 'e.g. My Provider'),
              const SizedBox(height: 16),
              _buildField(_urlController, 'Server URL', Icons.dns_outlined, 'http://server.com:8080'),
              const SizedBox(height: 16),
              _buildField(_userController, 'Username', Icons.person_outline_rounded, 'Your username'),
              const SizedBox(height: 16),
              _buildField(_passController, 'Password', Icons.lock_outline_rounded, 'Your password', isPassword: true),
              const SizedBox(height: 48),
              BlocBuilder<PlaylistBloc, PlaylistState>(
                builder: (context, state) {
                  return SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: state.isLoading ? null : _login,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: state.isLoading 
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('AUTHENTICATE & IMPORT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    ),
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
        const SnackBar(content: Text('Please fill all fields')),
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

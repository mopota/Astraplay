import 'package:flutter/material.dart';
import '../../../../core/utils/haptics_helper.dart';
import '../../../player/presentation/widgets/native_video_player.dart';

class SubtitleSettingsSheet extends StatefulWidget {
  final NativePlayerController controller;

  const SubtitleSettingsSheet({super.key, required this.controller});

  @override
  State<SubtitleSettingsSheet> createState() => _SubtitleSettingsSheetState();
}

class _SubtitleSettingsSheetState extends State<SubtitleSettingsSheet> {
  int _offset = 0;
  double _fontSize = 18;
  String _color = 'White';
  String _bgColor = 'Black Transparent';

  final List<String> _colors = ['White', 'Yellow', 'Green', 'Cyan'];
  final List<String> _bgColors = ['None', 'Black Transparent', 'Black'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Text('Subtitle Settings', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          _buildSyncControl(theme),
          const Divider(height: 32, color: Colors.white10),
          _buildStyleControl(theme),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSyncControl(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.sync_rounded, size: 20),
            const SizedBox(width: 8),
            Text('Synchronization', style: theme.textTheme.titleMedium),
            const Spacer(),
            Text('${_offset > 0 ? '+' : ''}${_offset}ms', 
              style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildOffsetButton(Icons.remove_rounded, -500),
            const SizedBox(width: 12),
            _buildOffsetButton(Icons.remove_rounded, -100, isSmall: true),
            const SizedBox(width: 24),
            TextButton(
              onPressed: () {
                setState(() => _offset = 0);
                widget.controller.setSubtitleOffset(0);
              },
              child: const Text('Reset'),
            ),
            const SizedBox(width: 24),
            _buildOffsetButton(Icons.add_rounded, 100, isSmall: true),
            const SizedBox(width: 12),
            _buildOffsetButton(Icons.add_rounded, 500),
          ],
        ),
      ],
    );
  }

  Widget _buildOffsetButton(IconData icon, int delta, {bool isSmall = false}) {
    return IconButton.filledTonal(
      onPressed: () {
        HapticsHelper.light();
        setState(() => _offset += delta);
        widget.controller.setSubtitleOffset(_offset);
      },
      icon: Icon(icon, size: isSmall ? 20 : 24),
      style: IconButton.styleFrom(
        padding: EdgeInsets.all(isSmall ? 8 : 12),
      ),
    );
  }

  Widget _buildStyleControl(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.style_rounded, size: 20),
            const SizedBox(width: 8),
            Text('Visual Styling', style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 20),
        
        // Font Size
        const Text('Font Size', style: TextStyle(fontSize: 12, color: Colors.white60)),
        Slider(
          value: _fontSize,
          min: 12,
          max: 32,
          onChanged: (val) {
            setState(() => _fontSize = val);
            _updateStyle();
          },
        ),
        
        // Color
        const SizedBox(height: 12),
        const Text('Text Color', style: TextStyle(fontSize: 12, color: Colors.white60)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _colors.map((c) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(c),
                selected: _color == c,
                onSelected: (selected) {
                  if (selected) setState(() => _color = c);
                  _updateStyle();
                },
              ),
            )).toList(),
          ),
        ),
        
        // Background
        const SizedBox(height: 12),
        const Text('Background', style: TextStyle(fontSize: 12, color: Colors.white60)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _bgColors.map((c) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(c),
                selected: _bgColor == c,
                onSelected: (selected) {
                  if (selected) setState(() => _bgColor = c);
                  _updateStyle();
                },
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  void _updateStyle() {
    widget.controller.setSubtitleStyle(
      fontSize: _fontSize,
      color: _color,
      backgroundColor: _bgColor,
    );
  }
}

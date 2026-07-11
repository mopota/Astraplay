import 'package:flutter/material.dart';

class ProgressButton extends StatelessWidget {
  final bool isLoading;
  final double progress;
  final String? statusMessage;
  final String label;
  final VoidCallback? onPressed;

  const ProgressButton({
    super.key,
    required this.isLoading,
    required this.progress,
    this.statusMessage,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: 64,
          child: Stack(
            children: [
              // Background / Border
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isLoading ? colorScheme.surfaceContainerHighest : colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              
              // Progress Fill
              if (isLoading)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      color: colorScheme.primary.withAlpha(100),
                    ),
                  ),
                ),

              // Button Content
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isLoading ? null : onPressed,
                    borderRadius: BorderRadius.circular(20),
                    child: Center(
                      child: isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                label,
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            label,
                            style: TextStyle(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              fontSize: 16,
                            ),
                          ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isLoading && statusMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            statusMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.primary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

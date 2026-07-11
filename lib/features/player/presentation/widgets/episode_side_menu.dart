import 'package:flutter/material.dart';
import '../../../../core/utils/haptics_helper.dart';
import '../../../../core/localization/app_localizations.dart';

class EpisodeSideMenu extends StatelessWidget {
  final List<Map<String, String>> episodes;
  final int currentIndex;
  final Function(int) onEpisodeSelected;
  final VoidCallback onClose;

  const EpisodeSideMenu({
    super.key,
    required this.episodes,
    required this.currentIndex,
    required this.onEpisodeSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(200),
        border: Border(
          left: BorderSide(color: colorScheme.primary.withAlpha(50)),
        ),
      ),
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Text(
                    context.tr('episodes'),
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: Colors.white10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: episodes.length,
              itemBuilder: (context, index) {
                final ep = episodes[index];
                final isSelected = index == currentIndex;
                final epNumber = ep['number'] ?? '${index + 1}';
                final epName = ep['name'] ?? '${context.tr('episode')} $epNumber';

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticsHelper.light();
                      onEpisodeSelected(index);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: isSelected ? colorScheme.primary.withAlpha(40) : null,
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: isSelected ? colorScheme.primary : Colors.white10,
                            ),
                            child: Center(
                              child: Text(
                                epNumber,
                                style: TextStyle(
                                  color: isSelected ? colorScheme.onPrimary : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  epName,
                                  style: TextStyle(
                                    color: isSelected ? colorScheme.primary : Colors.white,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (ep['season'] != null)
                                  Text(
                                    '${context.tr('season')} ${ep['season']}',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.play_arrow_rounded, color: colorScheme.primary, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

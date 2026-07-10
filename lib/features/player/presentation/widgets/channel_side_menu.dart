import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/haptics_helper.dart';

class ChannelSideMenu extends StatelessWidget {
  final List<AppStream> streams;
  final AppStream currentStream;
  final Function(AppStream) onStreamSelected;
  final VoidCallback onClose;

  const ChannelSideMenu({
    super.key,
    required this.streams,
    required this.currentStream,
    required this.onStreamSelected,
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
                    'Channels',
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
              itemCount: streams.length,
              itemBuilder: (context, index) {
                final stream = streams[index];
                final isSelected = stream.id == currentStream.id;

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticsHelper.light();
                      onStreamSelected(stream);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: isSelected ? colorScheme.primary.withAlpha(40) : null,
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white10,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: stream.data.logoUrl ?? '',
                                fit: BoxFit.contain,
                                errorWidget: (_, __, ___) => const Icon(Icons.live_tv, size: 20, color: Colors.white30),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stream.name,
                                  style: TextStyle(
                                    color: isSelected ? colorScheme.primary : Colors.white,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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

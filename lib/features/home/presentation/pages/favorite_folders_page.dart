import 'dart:async';
import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import '../../../../core/database/app_database.dart';
import '../../../../injection_container.dart';
import '../../../../core/utils/haptics_helper.dart';

class FavoriteFoldersPage extends StatefulWidget {
  const FavoriteFoldersPage({super.key});

  @override
  State<FavoriteFoldersPage> createState() => _FavoriteFoldersPageState();
}

class _FavoriteFoldersPageState extends State<FavoriteFoldersPage> {
  List<FavoriteFolder> _folders = [];

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final db = sl<AppDatabase>();
    final folders = await db.isar.favoriteFolders.where().findAll();
    if (mounted) setState(() => _folders = folders);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorite Folders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_rounded),
            onPressed: _showCreateFolderDialog,
          ),
        ],
      ),
      body: _folders.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _folders.length,
              itemBuilder: (context, index) {
                final folder = _folders[index];
                return _buildFolderCard(folder);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, size: 80, color: Colors.grey.withAlpha(50)),
          const SizedBox(height: 16),
          const Text('No favorite folders yet'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _showCreateFolderDialog,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Folder'),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderCard(FavoriteFolder folder) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(Icons.folder_rounded, color: Theme.of(context).colorScheme.primary),
        title: Text(folder.name),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          // Open folder content logic
        },
        onLongPress: () => _showDeleteFolderConfirm(folder),
      ),
    );
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Folder Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final db = sl<AppDatabase>();
                await db.isar.writeTxn(() async {
                  await db.isar.favoriteFolders.put(FavoriteFolder()
                    ..name = controller.text
                    ..iconName = 'folder');
                });
                await HapticsHelper.success();
                if (mounted) {
                   Navigator.pop(context);
                   _loadFolders();
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showDeleteFolderConfirm(FavoriteFolder folder) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Folder?'),
        content: Text('Are you sure you want to delete "${folder.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final db = sl<AppDatabase>();
              await db.isar.writeTxn(() async {
                await db.isar.favoriteFolders.delete(folder.id);
                // Manually update streams
                final streams = await db.isar.appStreams.filter().favoriteFolderIdEqualTo(folder.id).findAll();
                for (var s in streams) {
                  s.favoriteFolderId = null;
                }
                await db.isar.appStreams.putAll(streams);
              });
              await HapticsHelper.medium();
              if (mounted) {
                Navigator.pop(dialogContext);
                _loadFolders();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

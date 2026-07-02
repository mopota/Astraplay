import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import '../../features/home/presentation/pages/favorites_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/playlist/presentation/pages/playlist_page.dart';
import '../../features/category/presentation/pages/category_page.dart';
import '../../features/category/presentation/pages/movie_details_page.dart';
import '../../features/category/presentation/pages/series_details_page.dart';
import '../../features/category/presentation/pages/stream_list_page.dart';
import '../../features/player/presentation/pages/video_player_page.dart';
import '../../features/playlist/domain/entities/playlist.entity.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/settings/presentation/pages/legal_page.dart';
import '../../features/source_management/presentation/pages/add_source_page.dart';
import '../../features/source_management/presentation/pages/direct_stream_page.dart';
import '../../features/source_management/presentation/pages/playlist_url_page.dart';
import '../../features/source_management/presentation/pages/xtream_login_page.dart';
import '../../features/source_management/presentation/pages/local_file_page.dart';
import '../database/app_database.dart';
import '../presentation/pages/error_page.dart';
import '../../injection_container.dart' as di;

import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    navigatorKey: _rootNavigatorKey,
    errorBuilder: (context, state) => RouteErrorPage(message: state.error?.toString() ?? 'Page not found'),
    redirect: (context, state) async {
      final prefs = await SharedPreferences.getInstance();
      final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
      
      if (!onboardingCompleted && state.uri.path != '/onboarding') {
        return '/onboarding';
      }

      // Check for active playlist from SharedPreferences
      final activePlaylistId = prefs.getInt('active_playlist_id');
      final hasActivePlaylist = activePlaylistId != null;

      if (onboardingCompleted) {
        // If we are trying to go home/root without a playlist
        if (!hasActivePlaylist && 
            state.uri.path != '/playlists' && 
            !state.uri.path.startsWith('/add-source')) {
          return '/playlists';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return ScaffoldWithNavbar(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomePage(),
            routes: [
              GoRoute(
                path: 'favorites',
                builder: (context, state) => const FavoritesPage(),
              ),
            ],
          ),
          GoRoute(
            path: '/playlists',
            builder: (context, state) => const PlaylistPage(),
            routes: [
              GoRoute(
                path: 'categories',
                builder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  final playlist = extra?['playlist'] as PlaylistEntity?;
                  final type = extra?['type'] as StreamType? ?? StreamType.live;
                  
                  if (playlist == null) {
                    return const InvalidArgumentPage(message: 'No playlist selected');
                  }
                  return CategoryPage(playlist: playlist, type: type);
                },
                routes: [
                  GoRoute(
                    path: 'streams',
                    builder: (context, state) {
                      final extra = state.extra as Map<String, dynamic>?;
                      if (extra == null) {
                        return const InvalidArgumentPage(message: 'Missing category details');
                      }

                      final playlistId = extra['playlistId'] as int;
                      final category = extra['category'] as String;
                      final typeStr = extra['type'] as String;

                      StreamType sType = StreamType.live;
                      if (typeStr == 'movie') sType = StreamType.movie;
                      if (typeStr == 'series') sType = StreamType.series;

                      return StreamListPage(
                        playlistId: playlistId,
                        category: category,
                        type: sType,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/movie-details',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>;
              return MovieDetailsPage(
                stream: extra['stream'] as AppStream,
              );
            },
          ),
          GoRoute(
            path: '/series-details',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>;
              return SeriesDetailsPage(
                stream: extra['stream'] as AppStream,
                m3uEpisodes: extra['m3uEpisodes'] as List<AppStream>?,
              );
            },
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
            routes: [
              GoRoute(
                path: 'legal',
                builder: (context, state) => const LegalPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/add-source',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddSourcePage(),
        routes: [
          GoRoute(
            path: 'direct',
            builder: (context, state) => const DirectStreamPage(),
          ),
          GoRoute(
            path: 'playlist',
            builder: (context, state) => const PlaylistUrlPage(),
          ),
          GoRoute(
            path: 'xtream',
            builder: (context, state) => const XtreamLoginPage(),
          ),
          GoRoute(
            path: 'local',
            builder: (context, state) => const LocalFilePage(),
          ),
        ],
      ),
      // Removed top-level /streams as it is now a sub-route of /playlists
      GoRoute(
        path: '/player',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! Map<String, dynamic>) {
            return const InvalidArgumentPage(message: 'Missing video details');
          }
          
          final streamUrl = extra['streamUrl'];
          final title = extra['title'];
          final streamId = extra['streamId'] as int?;
          final headers = extra['headers'] as Map<String, String>?;
          final episodeMetadata = extra['episodeMetadata'] as String?;
          final playlist = extra['playlist'] as List<Map<String, String>>?;
          final initialIndex = extra['initialIndex'] as int?;

          if (streamUrl is! String || title is! String) {
            return const InvalidArgumentPage(message: 'Invalid video details');
          }

          return VideoPlayerPage(
            streamUrl: streamUrl,
            title: title,
            streamId: streamId,
            headers: headers,
            episodeMetadata: episodeMetadata,
            playlist: playlist,
            initialIndex: initialIndex,
          );
        },
      ),
    ],
  );
}

class ScaffoldWithNavbar extends StatelessWidget {
  const ScaffoldWithNavbar({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
    );
  }
}

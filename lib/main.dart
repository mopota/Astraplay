import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/localization/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'injection_container.dart' as di;
import 'core/database/app_database.dart';
import 'features/playlist/presentation/bloc/playlist_bloc.dart';
import 'features/settings/presentation/cubit/settings_cubit.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize Dependency Injection
    await di.init();

    // Initialize Database
    final db = di.sl<AppDatabase>();
    await db.init();
    
    // Load Settings before running the app
    await di.sl<SettingsCubit>().loadSettings();
    
    runApp(
      MultiBlocProvider(
        providers: [
          BlocProvider<PlaylistBloc>(
            create: (context) => di.sl<PlaylistBloc>()..add(GetPlaylistsEvent()),
          ),
          BlocProvider<SettingsCubit>(
            create: (context) => di.sl<SettingsCubit>(),
          ),
        ],
        child: const AstraPlayApp(),
      ),
    );
  } catch (e) {
    debugPrint('Fatal Startup Error: $e');
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Failed to initialize app: $e'),
        ),
      ),
    ));
  }
}

class AstraPlayApp extends StatelessWidget {
  const AstraPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        ThemeMode themeMode;
        switch (state.settings.themeMode) {
          case 'light':
            themeMode = ThemeMode.light;
            break;
          case 'dark':
            themeMode = ThemeMode.dark;
            break;
          default:
            themeMode = ThemeMode.system;
        }

        return MaterialApp.router(
          title: 'AstraPlay',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          routerConfig: AppRouter.router,
          debugShowCheckedModeBanner: false,
          locale: Locale(state.settings.language),
          supportedLocales: const [
            Locale('en', ''),
            Locale('ar', ''),
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          localeResolutionCallback: (locale, supportedLocales) {
            for (var supportedLocale in supportedLocales) {
              if (supportedLocale.languageCode == locale?.languageCode) {
                return supportedLocale;
              }
            }
            return supportedLocales.first;
          },
        );
      },
    );
  }
}


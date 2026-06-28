import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:forui/forui.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/localization/locales.dart';
import 'core/routing/app_router.dart';
import 'core/services/offline_storage.dart';
import 'core/services/settings_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  await OfflineStorage.init();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(
    EasyLocalization(
      supportedLocales: AppLocales.supported,
      path: AppLocales.path,
      fallbackLocale: AppLocales.fallback,
      useOnlyLangCode: true,
      child: const ProviderScope(child: AkiliApp()),
    ),
  );
}

class AkiliApp extends ConsumerWidget {
  const AkiliApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme    = ref.watch(themeControllerProvider);
    final router   = ref.watch(appRouterProvider);
    final settings = ref.watch(settingsProvider);

    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      child: MaterialApp.router(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(accent: theme.accent),
        darkTheme: AppTheme.dark(accent: theme.accent),
        themeMode: theme.mode,
        routerConfig: router,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        builder: (ctx, child) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          Widget w = FTheme(
            data: isDark ? FThemes.zinc.dark : FThemes.zinc.light,
            child: ResponsiveBreakpoints.builder(
              breakpoints: const [
                Breakpoint(start: 0,    end: 480,             name: MOBILE),
                Breakpoint(start: 481,  end: 900,             name: TABLET),
                Breakpoint(start: 901,  end: 1920,            name: DESKTOP),
                Breakpoint(start: 1921, end: double.infinity, name: '4K'),
              ],
              child: child!,
            ),
          );

          // Échelle de texte : curseur d'accessibilité × bonus « grande police ».
          final effectiveScale =
              settings.textScale * (settings.grandePolice ? 1.2 : 1.0);
          if (effectiveScale != 1.0) {
            final mq = MediaQuery.of(ctx);
            w = MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(
                  (mq.textScaler.scale(1.0) * effectiveScale).clamp(0.8, 2.0),
                ),
              ),
              child: w,
            );
          }

          // Réduire les animations
          if (settings.reduireAnimations) {
            w = Theme(
              data: Theme.of(ctx).copyWith(
                pageTransitionsTheme: const PageTransitionsTheme(
                  builders: {
                    TargetPlatform.android: _NoAnimPageTransition(),
                    TargetPlatform.iOS:     _NoAnimPageTransition(),
                    TargetPlatform.linux:   _NoAnimPageTransition(),
                    TargetPlatform.macOS:   _NoAnimPageTransition(),
                    TargetPlatform.windows: _NoAnimPageTransition(),
                  },
                ),
              ),
              child: w,
            );
          }

          // Contraste élevé
          if (settings.contrasteEleve) {
            final base    = Theme.of(ctx);
            final isDarkMode = base.brightness == Brightness.dark;
            w = Theme(
              data: base.copyWith(
                scaffoldBackgroundColor: isDarkMode ? Colors.black : Colors.white,
                colorScheme: base.colorScheme.copyWith(
                  surface:              isDarkMode ? const Color(0xFF0A0A0A) : Colors.white,
                  surfaceContainer:     isDarkMode ? const Color(0xFF111111) : const Color(0xFFF0F0F0),
                  surfaceContainerHigh: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFE0E0E0),
                  onSurface:            isDarkMode ? Colors.white : Colors.black,
                  onSurfaceVariant:     isDarkMode ? const Color(0xFFCCCCCC) : const Color(0xFF333333),
                  outline:              isDarkMode ? const Color(0xFF444444) : const Color(0xFF888888),
                  primary:              isDarkMode ? const Color(0xFFFF6B6B) : const Color(0xFF5C0000),
                  onPrimary:            Colors.white,
                ),
                textTheme: base.textTheme.apply(
                  bodyColor:    isDarkMode ? Colors.white : Colors.black,
                  displayColor: isDarkMode ? Colors.white : Colors.black,
                ),
                cardColor:   isDarkMode ? const Color(0xFF111111) : Colors.white,
                dividerColor: isDarkMode ? const Color(0xFF333333) : const Color(0xFF999999),
              ),
              child: w,
            );
          }

          return w;
        },
      ),
    );
  }
}

// ── Page transition sans animation ──────────────────────────────────────────
class _NoAnimPageTransition extends PageTransitionsBuilder {
  const _NoAnimPageTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}

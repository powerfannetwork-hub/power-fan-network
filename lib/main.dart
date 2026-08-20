import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

import 'globals/app_state.dart';
import 'globals/router.dart';
import 'l10n/app_localizations.dart';

/// Global SharedPreferences instance.
///
/// This is initialized before runApp() so that AppState and other
/// services can safely use locally persisted data from the beginning.
late final SharedPreferences sharedPrefs;

/// POWER FAN NETWORK
/// AFAM
///
/// Main application entry point.
///
/// This file is intentionally responsible only for:
/// - Flutter initialization
/// - Firebase initialization
/// - SharedPreferences initialization
/// - Global Provider setup
/// - Theme
/// - Localization
/// - Router
///
/// Mining, referral, KYC, wallet and security business logic
/// should stay inside their dedicated files.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capture Flutter framework errors.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);

    if (kDebugMode) {
      debugPrint(
        'Flutter framework error:',
      );
      debugPrint(
        details.exceptionAsString(),
      );
      debugPrint(
        details.stack?.toString() ?? 'No stack trace available.',
      );
    }
  };

  // Initialize all services required by the application.
  await _initializeApplication();

  // Capture asynchronous errors outside the Flutter framework.
  runZonedGuarded(
    () {
      runApp(
        const PowerFanNetworkApp(),
      );
    },
    (
      Object error,
      StackTrace stackTrace,
    ) {
      if (kDebugMode) {
        debugPrint(
          'Unhandled application error: $error',
        );
        debugPrint(
          stackTrace.toString(),
        );
      }
    },
  );
}

/// Initializes application dependencies before the UI starts.
Future<void> _initializeApplication() async {
  // Local persistence.
  sharedPrefs = await SharedPreferences.getInstance();

  // Firebase.
  await _initializeFirebase();
}

/// Initializes Firebase safely.
Future<void> _initializeFirebase() async {
  try {
    // Prevent duplicate Firebase initialization.
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } on FirebaseException catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint(
        'Firebase initialization error.',
      );
      debugPrint(
        'Code: ${error.code}',
      );
      debugPrint(
        'Message: ${error.message}',
      );
      debugPrint(
        'Stack: $stackTrace',
      );
    }

    rethrow;
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint(
        'Unexpected Firebase initialization error: $error',
      );
      debugPrint(
        stackTrace.toString(),
      );
    }

    rethrow;
  }
}

/// Root application widget.
class PowerFanNetworkApp extends StatelessWidget {
  const PowerFanNetworkApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>(
          create: (_) => AppState(),
        ),
      ],
      child: const PowerFanNetworkRoot(),
    );
  }
}

/// Root widget connected to AppState.
class PowerFanNetworkRoot extends StatelessWidget {
  const PowerFanNetworkRoot({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final AppState appState = AppState.of(
      context,
      listen: true,
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,

      title: 'POWER FAN NETWORK',

      theme: _buildPowerFanTheme(),

      themeMode: ThemeMode.light,

      locale: appState.locale,

      supportedLocales: const [
        Locale('en'),
        Locale('zh'),
        Locale('hi'),
        Locale('es'),
        Locale('ru'),
        Locale('tr'),
        Locale('id'),
        Locale('ko'),
        Locale('vi'),
        Locale('pt'),
      ],

      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      routerConfig: appRouter,

      builder: (
        BuildContext context,
        Widget? child,
      ) {
        return _ApplicationShell(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Application-wide shell.
///
/// This keeps the visual behavior consistent across all pages.
class _ApplicationShell extends StatelessWidget {
  final Widget child;

  const _ApplicationShell({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1.0),
      ),
      child: child,
    );
  }
}/// POWER FAN NETWORK global theme.
///
/// The design follows the approved interface direction:
/// - Clean white background
/// - Deep purple branding
/// - Rounded cards
/// - Premium mining dashboard appearance
/// - Strong typography
/// - Soft shadows
ThemeData _buildPowerFanTheme() {
  const Color primaryPurple = Color(0xFF5E17EB);
  const Color darkPurple = Color(0xFF1E1B4B);
  const Color backgroundColor = Color(0xFFF7F9FC);

  return ThemeData(
    useMaterial3: true,

    brightness: Brightness.light,

    scaffoldBackgroundColor: backgroundColor,

    primaryColor: primaryPurple,

    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryPurple,
      brightness: Brightness.light,
      primary: primaryPurple,
      secondary: darkPurple,
      surface: Colors.white,
    ),

    fontFamily: 'Roboto',

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: darkPurple,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: darkPurple,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    ),

    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(
          double.infinity,
          52,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryPurple,
        side: const BorderSide(
          color: primaryPurple,
          width: 1.4,
        ),
        minimumSize: const Size(
          double.infinity,
          52,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryPurple,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFE5E7EB),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: primaryPurple,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.red,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.5,
        ),
      ),
      labelStyle: const TextStyle(
        color: Color(0xFF64748B),
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontWeight: FontWeight.w500,
      ),
    ),

    bottomNavigationBarTheme:
        const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: primaryPurple,
      unselectedItemColor: Color(0xFF94A3B8),
      selectedLabelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
      unselectedLabelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      type: BottomNavigationBarType.fixed,
      elevation: 10,
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 8,
      indicatorColor: primaryPurple.withValues(
        alpha: 0.12,
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: primaryPurple,
            );
          }

          return const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF94A3B8),
          );
        },
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: Color(0xFFE5E7EB),
      thickness: 1,
      space: 1,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: darkPurple,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      titleTextStyle: const TextStyle(
        color: darkPurple,
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
      contentTextStyle: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFF1F5F9),
      selectedColor: primaryPurple.withValues(
        alpha: 0.12,
      ),
      labelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: darkPurple,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      side: BorderSide.none,
    ),
  );
}

/// Small helper used by future pages/components.
///
/// Keeps the primary brand purple in one place at UI level.
class PowerFanColors {
  PowerFanColors._();

  static const Color primary = Color(0xFF5E17EB);
  static const Color dark = Color(0xFF1E1B4B);
  static const Color background = Color(0xFFF7F9FC);
  static const Color text = Color(0xFF1E293B);
  static const Color muted = Color(0xFF64748B);
  static const Color lightMuted = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE5E7EB);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);
}/// Common dimensions used by the POWER FAN NETWORK interface.
///
/// Keeping these values centralized makes it easier to maintain
/// the same visual language throughout Home, Referral, KYC,
/// Wallet, Settings and other pages.
class PowerFanDimensions {
  PowerFanDimensions._();

  static const double pageHorizontalPadding = 16.0;

  static const double pageVerticalPadding = 20.0;

  static const double cardRadius = 20.0;

  static const double largeCardRadius = 24.0;

  static const double smallRadius = 12.0;

  static const double buttonRadius = 16.0;

  static const double sectionSpacing = 18.0;

  static const double itemSpacing = 12.0;

  static const double smallSpacing = 8.0;
}

/// Global application strings that are safe to keep in the
/// entry point because they describe the application itself.
///
/// Business values such as mining rate, referral rewards,
/// social-task rewards and ad limits belong in AppConstants.
class PowerFanAppInfo {
  PowerFanAppInfo._();

  static const String name = 'POWER FAN NETWORK';

  static const String shortName = 'PFN';

  static const String tokenName = 'FAN';

  static const String futureTokenName = 'AFAM';

  static const String versionName = '1.0.0';
}

/// Application lifecycle observer.
///
/// This gives us a clean place to handle app foreground/background
/// transitions later without putting mining business logic inside
/// main().
class PowerFanLifecycleObserver
    with WidgetsBindingObserver {
  PowerFanLifecycleObserver._();

  static final PowerFanLifecycleObserver instance =
      PowerFanLifecycleObserver._();

  bool _registered = false;

  void register() {
    if (_registered) {
      return;
    }

    WidgetsBinding.instance.addObserver(this);
    _registered = true;
  }

  void unregister() {
    if (!_registered) {
      return;
    }

    WidgetsBinding.instance.removeObserver(this);
    _registered = false;
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (kDebugMode) {
      debugPrint(
        'POWER FAN NETWORK lifecycle: ${state.name}',
      );
    }

    // Mining calculations should NOT depend on this callback.
    //
    // The mining engine should calculate elapsed time using
    // persisted start/end timestamps. This allows mining to
    // continue correctly even when the application is closed.
  }
}

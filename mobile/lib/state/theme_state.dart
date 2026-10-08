import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// App appearance: System, Light or Dark. The choice is remembered on this phone.
///
/// The screens were drawn with fixed light colours, so dark mode is produced by
/// one colour transform over the whole app: lightness is flipped (white becomes
/// near-black, dark text becomes light) while every hue stays what it was
/// (greens stay green, amber stays amber). Pictures that must keep their true
/// colours (logo, avatars, web pages) are wrapped in [KeepColors].
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

const _themeStore = FlutterSecureStorage();
const _themeKey = 'app_theme_mode';

Future<void> loadAppThemeMode() async {
  try {
    final saved = await _themeStore.read(key: _themeKey);
    appThemeMode.value = saved == 'dark'
        ? ThemeMode.dark
        : saved == 'light'
            ? ThemeMode.light
            : ThemeMode.system;
  } catch (_) {
    appThemeMode.value = ThemeMode.system;
  }
}

Future<void> setAppThemeMode(ThemeMode mode) async {
  appThemeMode.value = mode;
  try {
    if (mode == ThemeMode.system) {
      await _themeStore.delete(key: _themeKey);
    } else {
      await _themeStore.write(key: _themeKey, value: mode == ThemeMode.dark ? 'dark' : 'light');
    }
  } catch (_) {
    // The choice still applies until the app is closed.
  }
}

/// Whether the app should look dark right now, for this mode and device setting.
bool isAppDark(BuildContext context, [ThemeMode? mode]) {
  final m = mode ?? appThemeMode.value;
  if (m == ThemeMode.dark) return true;
  if (m == ThemeMode.light) return false;
  return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
}

const List<double> _identity = <double>[
  1, 0, 0, 0, 0,
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 1, 0,
];

/// Flip lightness, keep hue, and lift pure black to a deep navy (#0E131E).
const List<double> _darkMatrix = <double>[
  0.3, -0.6, -0.6, 0, 243.5,
  -0.6, 0.3, -0.6, 0, 248.5,
  -0.6, -0.6, 0.3, 0, 259.5,
  0, 0, 0, 1, 0,
];

/// Exact opposite of [_darkMatrix]: applied first, the two cancel out.
const List<double> _keepMatrix = <double>[
  0.3704, -0.7407, -0.7407, 0, 286.11,
  -0.7407, 0.3704, -0.7407, 0, 280.56,
  -0.7407, -0.7407, 0.3704, 0, 268.33,
  0, 0, 0, 1, 0,
];

/// Wraps the whole app. Always present (with a do-nothing filter in light mode)
/// so switching appearance never rebuilds the screens underneath.
class AppDarkLayer extends StatelessWidget {
  final Widget child;

  const AppDarkLayer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      child: child,
      builder: (context, mode, child) {
        return ColorFiltered(
          colorFilter: ColorFilter.matrix(isAppDark(context, mode) ? _darkMatrix : _identity),
          child: child,
        );
      },
    );
  }
}

/// Keeps a picture's real colours in dark mode (logo, avatars, web pages).
class KeepColors extends StatelessWidget {
  final Widget child;

  const KeepColors({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      child: child,
      builder: (context, mode, child) {
        return ColorFiltered(
          colorFilter: ColorFilter.matrix(isAppDark(context, mode) ? _keepMatrix : _identity),
          child: child,
        );
      },
    );
  }
}

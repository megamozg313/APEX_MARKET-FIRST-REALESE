// lib/theme.dart
// APEX Market — дизайн-система: APEX Obsidian (dark) + APEX Light.

import 'dart:io';
import 'dart:ui' show FontFeature;
import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

// ════════════════════════════════════════════════════════════════════
//  КОНТРОЛЛЕР ТЕМЫ
// ════════════════════════════════════════════════════════════════════

/// Управляет режимом темы и плотностью сетки каталога.
/// Использование:
/// ```dart
/// ListenableBuilder(
///   listenable: themeController,
///   builder: (_, __) => MaterialApp(
///     theme: ApexTheme.light(),
///     darkTheme: ApexTheme.dark(),
///     themeMode: themeController.mode,
///   ),
/// )
/// ```
class ApexThemeController extends ChangeNotifier {
  ApexThemeController({
    ThemeMode mode = ThemeMode.dark,
    bool compactGrid = false,
  })  : _mode = mode,
        _compactGrid = compactGrid;

  ThemeMode _mode;
  bool _compactGrid;

  ThemeMode get mode => _mode;
  bool get compactGrid => _compactGrid;

  void setThemeMode(ThemeMode value) {
    if (_mode == value) return;
    _mode = value;
    notifyListeners();
  }

  void setCompactGrid(bool value) {
    if (_compactGrid == value) return;
    _compactGrid = value;
    notifyListeners();
  }
}

// ════════════════════════════════════════════════════════════════════
//  ПАЛИТРА
// ════════════════════════════════════════════════════════════════════

@immutable
class ApexPalette {
  const ApexPalette({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.muted,
    required this.soft,
    required this.isDark,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color text;
  final Color muted;
  final Color soft;
  final bool isDark;

  // ── Фирменные акценты (одинаковы в обеих темах) ──
  static const Color accent = Color(0xFF9D4EDD);
  static const Color accentDeep = Color(0xFF7B2CBF);
  static const Color lime = Color(0xFFCCFF00);
  static const Color green = Color(0xFF22C55E);
  static const Color danger = Color(0xFFEF4444);
  static const Color amber = Color(0xFFF59E0B);

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentDeep],
  );

  // ── APEX Obsidian ──
  static const ApexPalette dark = ApexPalette(
    bg: Color(0xFF08080B),
    surface: Color(0xFF121217),
    surfaceAlt: Color(0xFF1A1A22),
    border: Color(0xFF23232E),
    text: Color(0xFFFFFFFF),
    muted: Color(0xFF8E8E9E),
    soft: Color(0xFFD4D4DF),
    isDark: true,
  );

  // ── APEX Light ──
  static const ApexPalette light = ApexPalette(
    bg: Color(0xFFF5F5F8),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFECECF2),
    border: Color(0xFFE2E2EC),
    text: Color(0xFF0E0E14),
    muted: Color(0xFF6B6B7B),
    soft: Color(0xFF2A2A36),
    isDark: false,
  );

  /// Палитра по текущей яркости темы.
  static ApexPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  // ── Производные токены ──
  /// Цвет акцентного текста с нормальным контрастом в обеих темах.
  Color get accentText => isDark ? const Color(0xFFB878F0) : accentDeep;

  /// Цвет цен: лайм на тёмном, глубокий фиолетовый на светлом.
  Color get priceColor => isDark ? lime : accentDeep;

  Color get skeletonHighlight =>
      isDark ? const Color(0xFF272733) : const Color(0xFFF9F9FC);

  Color get shadow => isDark ? Colors.black : const Color(0xFF1B1B2E);
}

// ════════════════════════════════════════════════════════════════════
//  ТИПОГРАФИКА
// ════════════════════════════════════════════════════════════════════

/// Заголовки, логотип, крупные акценты — Syne.
TextStyle displayStyle(
  double size, {
  Color? color,
  FontWeight weight = FontWeight.w800,
  double letterSpacing = -0.6,
}) =>
    GoogleFonts.syne(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      color: color,
      height: 1.1,
    );

/// Цены, скидки, оценки состояния — JetBrains Mono с табличными цифрами.
TextStyle monoStyle(
  double size, {
  Color? color,
  FontWeight weight = FontWeight.w700,
}) =>
    GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Основной текст — Plus Jakarta Sans.
TextStyle bodyStyle(
  double size, {
  Color? color,
  FontWeight weight = FontWeight.w500,
  double? height,
}) =>
    GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );

/// 1 249 990 ₽ — с неразрывными пробелами (цена не переносится на 2 строки).
String formatRub(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('\u00A0');
    buf.write(digits[i]);
  }
  return '${negative ? '−' : ''}$buf\u00A0₽';
}

// ════════════════════════════════════════════════════════════════════
//  ThemeData
// ════════════════════════════════════════════════════════════════════

class ApexTheme {
  const ApexTheme._();

  static ThemeData dark() => _build(ApexPalette.dark, Brightness.dark);
  static ThemeData light() => _build(ApexPalette.light, Brightness.light);

  static ThemeData _build(ApexPalette p, Brightness b) {
    final base = ThemeData(brightness: b, useMaterial3: true);
    final scheme = ColorScheme(
      brightness: b,
      primary: ApexPalette.accent,
      onPrimary: Colors.white,
      secondary: ApexPalette.lime,
      onSecondary: const Color(0xFF08080B),
      error: ApexPalette.danger,
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.text,
      outline: p.border,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      dividerColor: p.border,
      splashColor: ApexPalette.accent.withOpacity(0.08),
      highlightColor: Colors.transparent,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
          .apply(bodyColor: p.text, displayColor: p.text),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: IconThemeData(color: p.text),
        titleTextStyle: displayStyle(20, color: p.text),
        systemOverlayStyle: b == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        modalBackgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.surfaceAlt,
        contentTextStyle: bodyStyle(13.5, color: p.text, weight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceAlt,
        hintStyle: bodyStyle(14, color: p.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ApexPalette.accent, width: 1.4),
        ),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  ЛОГОТИП
// ════════════════════════════════════════════════════════════════════

/// Монолитный шеврон-вершина ▲ с фиолетовым градиентом и лаймовым ядром.
class ApexMarkPainter extends CustomPainter {
  const ApexMarkPainter({this.glow = true});

  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // Острый шеврон с вырезом снизу.
    final body = Path()
      ..moveTo(w * 0.50, h * 0.02)
      ..lineTo(w * 0.98, h * 0.98)
      ..lineTo(w * 0.73, h * 0.98)
      ..lineTo(w * 0.50, h * 0.54)
      ..lineTo(w * 0.27, h * 0.98)
      ..lineTo(w * 0.02, h * 0.98)
      ..close();

    if (glow) {
      canvas.drawPath(
        body,
        Paint()
          ..color = ApexPalette.accent.withOpacity(0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.16),
      );
    }

    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC77DFF), ApexPalette.accent, ApexPalette.accentDeep],
          stops: [0.0, 0.45, 1.0],
        ).createShader(rect),
    );

    // Левая грань — световой блик для объёма.
    final facet = Path()
      ..moveTo(w * 0.50, h * 0.02)
      ..lineTo(w * 0.02, h * 0.98)
      ..lineTo(w * 0.27, h * 0.98)
      ..lineTo(w * 0.50, h * 0.54)
      ..close();
    canvas.drawPath(facet, Paint()..color = Colors.white.withOpacity(0.15));

    // Лаймовое ядро в вырезе.
    final core = Path()
      ..moveTo(w * 0.50, h * 0.50)
      ..lineTo(w * 0.585, h * 0.76)
      ..lineTo(w * 0.415, h * 0.76)
      ..close();
    if (glow) {
      canvas.drawPath(
        core,
        Paint()
          ..color = ApexPalette.lime.withOpacity(0.7)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.07),
      );
    }
    canvas.drawPath(core, Paint()..color = ApexPalette.lime);
  }

  @override
  bool shouldRepaint(ApexMarkPainter old) => old.glow != glow;
}

/// Только знак (без надписи).
class ApexMark extends StatelessWidget {
  const ApexMark({super.key, this.size = 28, this.glow = true});

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: ApexMarkPainter(glow: glow)),
      );
}

/// Знак + надпись APEX (Syne) + микро-бейдж MKT.
class ApexBrandLogo extends StatelessWidget {
  const ApexBrandLogo({
    super.key,
    this.height = 30,
    this.showBadge = true,
    this.showWordmark = true,
    this.textColor,
  });

  final double height;
  final bool showBadge;
  final bool showWordmark;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final p = ApexPalette.of(context);
    final tc = textColor ?? p.text;

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ApexMark(size: height),
          if (showWordmark) ...[
            SizedBox(width: height * 0.28),
            Text(
              'APEX',
              maxLines: 1,
              style: displayStyle(
                height * 0.74,
                color: tc,
                letterSpacing: height * 0.04,
              ),
            ),
          ],
          if (showWordmark && showBadge) ...[
            SizedBox(width: height * 0.16),
            Transform.translate(
              offset: Offset(0, -height * 0.12),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: height * 0.17,
                  vertical: height * 0.05,
                ),
                decoration: BoxDecoration(
                  color: ApexPalette.lime,
                  borderRadius: BorderRadius.circular(height * 0.14),
                ),
                child: Text(
                  'MKT',
                  style: monoStyle(
                    height * 0.27,
                    color: const Color(0xFF08080B),
                    weight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  КНОПКИ
// ════════════════════════════════════════════════════════════════════

/// Градиентная кнопка с мягким неоновым свечением и спиннером загрузки.
class ApexPrimaryButton extends StatefulWidget {
  const ApexPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = true,
    this.height = 54,
    this.gradient,
    this.glow = true,
  });

  final String label;

  /// null → кнопка выключена.
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expanded;
  final double height;
  final Gradient? gradient;
  final bool glow;

  @override
  State<ApexPrimaryButton> createState() => _ApexPrimaryButtonState();
}

class _ApexPrimaryButtonState extends State<ApexPrimaryButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    final enabled = !disabled && !widget.loading;
    final gradient = widget.gradient ?? ApexPalette.accentGradient;
    final glowColor =
        gradient is LinearGradient ? gradient.colors.first : ApexPalette.accent;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: AnimatedScale(
        scale: _pressed && enabled ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: disabled ? 0.45 : 1,
          duration: const Duration(milliseconds: 200),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled ? (_) => _setPressed(true) : null,
            onTapUp: enabled ? (_) => _setPressed(false) : null,
            onTapCancel: enabled ? () => _setPressed(false) : null,
            onTap: enabled
                ? () {
                    HapticFeedback.lightImpact();
                    widget.onPressed!();
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: widget.expanded ? double.infinity : null,
              height: widget.height,
              padding: EdgeInsets.symmetric(
                horizontal: widget.expanded ? 16 : 24,
              ),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(widget.height * 0.32),
                border: Border.all(color: Colors.white.withOpacity(0.14)),
                boxShadow: widget.glow && !disabled
                    ? [
                        BoxShadow(
                          color: glowColor.withOpacity(_pressed ? 0.28 : 0.45),
                          blurRadius: _pressed ? 14 : 26,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: widget.loading
                      ? const SizedBox(
                          key: ValueKey('spinner'),
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Row(
                          key: const ValueKey('label'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(widget.icon, size: 18, color: Colors.white),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Text(
                                widget.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: bodyStyle(
                                  15,
                                  color: Colors.white,
                                  weight: FontWeight.w800,
                                ).copyWith(letterSpacing: 0.1),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Контурная кнопка в стиле карточки.
class ApexOutlineButton extends StatefulWidget {
  const ApexOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = true,
    this.height = 54,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;
  final double height;

  /// Цвет текста/иконки (по умолчанию — text палитры).
  final Color? color;

  @override
  State<ApexOutlineButton> createState() => _ApexOutlineButtonState();
}

class _ApexOutlineButtonState extends State<ApexOutlineButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final p = ApexPalette.of(context);
    final enabled = widget.onPressed != null;
    final fg = widget.color ?? p.text;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: AnimatedScale(
        scale: _pressed && enabled ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.45,
          duration: const Duration(milliseconds: 200),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled ? (_) => _setPressed(true) : null,
            onTapUp: enabled ? (_) => _setPressed(false) : null,
            onTapCancel: enabled ? () => _setPressed(false) : null,
            onTap: enabled
                ? () {
                    HapticFeedback.selectionClick();
                    widget.onPressed!();
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: widget.expanded ? double.infinity : null,
              height: widget.height,
              padding: EdgeInsets.symmetric(horizontal: widget.expanded ? 16 : 24),
              decoration: BoxDecoration(
                color: _pressed ? p.surfaceAlt : p.surface,
                borderRadius: BorderRadius.circular(widget.height * 0.32),
                border: Border.all(
                  color: _pressed
                      ? ApexPalette.accent.withOpacity(0.7)
                      : p.border,
                  width: 1.3,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 18, color: fg),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: bodyStyle(15, color: fg, weight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  БЕЙДЖИ
// ════════════════════════════════════════════════════════════════════

/// Статусный бейдж: 🔥 ВЫГОДНО, AI 9.4/10, НОВОЕ, Б/У, ТОП.
class ApexPillBadge extends StatelessWidget {
  const ApexPillBadge({
    super.key,
    required this.label,
    this.color = ApexPalette.accent,
    this.icon,
    this.solid = false,
    this.dense = false,
  });

  /// 🔥 ВЫГОДНО
  const ApexPillBadge.profitable({super.key, this.dense = false})
      : label = '🔥 ВЫГОДНО',
        color = ApexPalette.lime,
        icon = null,
        solid = true;

  /// AI 9.4/10
  ApexPillBadge.ai(double score, {super.key, this.dense = false})
      : label = 'AI ${score.toStringAsFixed(1)}/10',
        color = ApexPalette.accent,
        icon = LucideIcons.sparkles,
        solid = false;

  /// НОВОЕ
  const ApexPillBadge.fresh({super.key, this.dense = false})
      : label = 'НОВОЕ',
        color = ApexPalette.green,
        icon = null,
        solid = false;

  /// Б/У
  const ApexPillBadge.used({super.key, this.dense = false})
      : label = 'Б/У',
        color = const Color(0xFF8E8E9E),
        icon = null,
        solid = false;

  /// ТОП
  const ApexPillBadge.top({super.key, this.dense = false})
      : label = 'ТОП',
        color = ApexPalette.amber,
        icon = LucideIcons.crown,
        solid = false;

  final String label;
  final Color color;
  final IconData? icon;
  final bool solid;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final p = ApexPalette.of(context);
    final fontSize = dense ? 9.5 : 11.0;

    Color fg;
    Color bg;
    Color? border;
    if (solid) {
      bg = color;
      fg = color.computeLuminance() > 0.5 ? const Color(0xFF08080B) : Colors.white;
    } else {
      bg = color.withOpacity(p.isDark ? 0.14 : 0.12);
      border = color.withOpacity(0.38);
      if (p.isDark) {
        fg = color;
      } else {
        final hsl = HSLColor.fromColor(color);
        fg = hsl.withLightness(hsl.lightness.clamp(0.0, 0.36)).toColor();
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: border == null ? null : Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 1.5, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: monoStyle(fontSize, color: fg, weight: FontWeight.w800)
                  .copyWith(letterSpacing: 0.3, height: 1.1),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  ФОТО ТОВАРА
// ════════════════════════════════════════════════════════════════════

/// Анимированный скелетон-заглушка (shimmer).
class ApexSkeleton extends StatefulWidget {
  const ApexSkeleton({super.key, this.borderRadius = BorderRadius.zero});

  final BorderRadius borderRadius;

  @override
  State<ApexSkeleton> createState() => _ApexSkeletonState();
}

class _ApexSkeletonState extends State<ApexSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ApexPalette.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          gradient: LinearGradient(
            colors: [p.surfaceAlt, p.skeletonHighlight, p.surfaceAlt],
            stops: const [0.25, 0.5, 0.75],
            transform: _SlideGradient(_c.value),
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.t);

  final double t;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 2 - 1), 0, 0);
}

/// Фото товара: локальный файл (Image.file) или сеть (Image.network),
/// плавное появление поверх скелетона, аккуратная заглушка при ошибке.
///
/// Если width/height не заданы — виджет заполняет доступное место родителя
/// (используйте внутри SizedBox / AspectRatio / Expanded).
class ItemThumb extends StatelessWidget {
  const ItemThumb({
    super.key,
    required this.source,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.fit = BoxFit.cover,
    this.heroTag,
  });

  /// URL (http/https) или путь к локальному файлу. null/пусто → заглушка.
  final String? source;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final Object? heroTag;

  bool get _isNetwork {
    final s = source ?? '';
    return s.startsWith('http://') || s.startsWith('https://');
  }

  Widget _placeholder(BuildContext context, IconData icon) {
    final p = ApexPalette.of(context);
    return Container(
      color: p.surfaceAlt,
      alignment: Alignment.center,
      child: Icon(icon, size: 26, color: p.muted.withOpacity(0.7)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final src = source;
    Widget child;

    if (src == null || src.trim().isEmpty) {
      child = _placeholder(context, LucideIcons.image);
    } else {
      Widget frame(BuildContext ctx, Widget img, int? frameNo, bool sync) {
        if (sync) return img;
        return Stack(
          fit: StackFit.expand,
          children: [
            ApexSkeleton(borderRadius: borderRadius),
            AnimatedOpacity(
              opacity: frameNo == null ? 0 : 1,
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              child: img,
            ),
          ],
        );
      }

      Widget onError(BuildContext ctx, Object e, StackTrace? s) =>
          _placeholder(ctx, LucideIcons.imageOff);

      child = _isNetwork
          ? Image.network(
              src,
              fit: fit,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
              frameBuilder: frame,
              errorBuilder: onError,
            )
          : Image.file(
              File(src),
              fit: fit,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
              frameBuilder: frame,
              errorBuilder: onError,
            );
    }

    Widget result = ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(width: width, height: height, child: child),
    );

    if (heroTag != null) result = Hero(tag: heroTag!, child: result);
    return result;
  }
}
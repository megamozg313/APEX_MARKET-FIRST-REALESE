// lib/screens_explore.dart
// APEX Market — Вкладки «Главная/Поиск» и «Каталог», экран выдачи и карточка товара.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'data.dart';
import 'theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  АДАПТЕР
// ═══════════════════════════════════════════════════════════════════════════

class _C {
  const _C({
    required this.bg,
    required this.card,
    required this.card2,
    required this.border,
    required this.text,
    required this.dim,
    required this.accent,
    required this.onAccent,
    required this.ok,
    required this.danger,
    required this.warn,
  });

  final Color bg, card, card2, border, text, dim, accent, onAccent, ok, danger, warn;
}

Color _a(Color c, double o) => c.withAlpha((o.clamp(0.0, 1.0) * 255).round());

_C _pal(BuildContext context) {
  final p = ApexPalette.of(context);
  const accent = ApexPalette.accent;
  final onAcc = ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
      ? Colors.white
      : Colors.black;
  return _C(
    bg: p.bg,
    card: p.surface,
    card2: p.surfaceAlt,
    border: p.border,
    text: p.text,
    dim: p.muted,
    accent: accent,
    onAccent: onAcc,
    ok: ApexPalette.green,
    danger: ApexPalette.danger,
    warn: ApexPalette.amber,
  );
}

TextStyle _disp(double size, Color color, {FontWeight w = FontWeight.w800, double? h}) =>
    displayStyle(size, color: color, weight: w).copyWith(height: h);
TextStyle _mono(double size, Color color, {FontWeight w = FontWeight.w800}) =>
    monoStyle(size, color: color, weight: w);
TextStyle _body(double size, Color color, {FontWeight w = FontWeight.w500, double? h}) =>
    bodyStyle(size, color: color, weight: w, height: h);

String _rub(num v) => formatRub(v.round());

Widget _thumb(MarketItem item) =>
    ItemThumb(source: item.imagePath, borderRadius: BorderRadius.zero);

final ChangeNotifier _fallbackThemeNotifier = ChangeNotifier();
ApexThemeController? _boundThemeController;

void bindExploreThemeController(ApexThemeController controller) {
  _boundThemeController = controller;
}

Listenable get _themeListenable => _boundThemeController ?? _fallbackThemeNotifier;
bool get _compactGrid => _boundThemeController?.compactGrid ?? false;

List<String> get _cities =>
    AppConfig.cities.isEmpty ? const <String>['Москва'] : AppConfig.cities;

List<String> get _realCategoryNames => AppConfig.realCategories;

extension _ItemView on MarketItem {
  num get rubPrice => price;
  double get discount => discountPercent.toDouble();
  num? get rubOld => oldPrice;
  String get titleText => title;
  String get cityLabel => city;
  String get categoryLabel => category;
  bool get fresh => isNew;
  bool get ship => hasDelivery;
  double get aiValue => conditionScore;
  String get aiComment => aiNote;
  String get sellerLabel => sellerName;
  String get sellerPhoneText => sellerPhone;
  bool get sellerVerified => sellerTgVerified;
  String get sellerHandle => cleanUsername;
  String get haystack => '$titleText $categoryLabel $aiComment'.toLowerCase();
}

Future<T?> _safe<T>(FutureOr<T> Function() f) async {
  try {
    return await f();
  } catch (_) {
    return null;
  }
}

Future<List<String>> _loadHistory() async {
  final h = await _safe(() => ApexStorage().loadSearchHistory());
  if (h == null) return <String>[];
  return h.where((e) => e.trim().isNotEmpty).toList();
}

Future<void> _sendToSeller(MarketItem item, String text) async {
  final peerUser =
      item.cleanUsername.isNotEmpty ? item.cleanUsername : 'seller_${item.id}';
  final peerTitle = item.sellerName.isNotEmpty ? item.sellerName : item.title;
  await ApexStorage().sendSellerMessage(peerUser, peerTitle, text);
}

class _CityStore {
  static const String _key = 'apex_selected_city';

  static Future<String?> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getString(_key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String city) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, city);
    } catch (_) {}
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Общие модели, поиск, фильтры
// ═══════════════════════════════════════════════════════════════════════════

enum ItemCondition { all, fresh, used }

enum SearchSort { byDefault, cheaper, pricier, aiDeal }

class SearchFilters {
  const SearchFilters({
    this.minPrice,
    this.maxPrice,
    this.category,
    this.condition = ItemCondition.all,
    this.deliveryOnly = false,
    this.aiOnly = false,
  });

  final double? minPrice;
  final double? maxPrice;
  final String? category;
  final ItemCondition condition;
  final bool deliveryOnly;
  final bool aiOnly;

  int get activeCount {
    var n = 0;
    if (minPrice != null || maxPrice != null) n++;
    if (category != null) n++;
    if (condition != ItemCondition.all) n++;
    if (deliveryOnly) n++;
    if (aiOnly) n++;
    return n;
  }

  SearchFilters withoutCategory() => SearchFilters(
        minPrice: minPrice,
        maxPrice: maxPrice,
        condition: condition,
        deliveryOnly: deliveryOnly,
        aiOnly: aiOnly,
      );
}

class _CatalogGroup {
  const _CatalogGroup({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.keywords,
    required this.subs,
  });

  final String title;
  final IconData icon;
  final List<Color> gradient;
  final List<String> keywords;
  final List<String> subs;
}

final List<_CatalogGroup> _groups = <_CatalogGroup>[
  _CatalogGroup(
    title: 'Одежда и обувь',
    icon: LucideIcons.shirt,
    gradient: const [Color(0xFFFF4F8B), Color(0xFF9B3DFF)],
    keywords: const ['одежд', 'обув', 'кроссов', 'худи', 'куртк', 'мода', 'аксессуар'],
    subs: const ['Кроссовки', 'Худи', 'Куртки', 'Джинсы', 'Сумки'],
  ),
  _CatalogGroup(
    title: 'Техника и ПК',
    icon: LucideIcons.laptop,
    gradient: const [Color(0xFF2563EB), Color(0xFF06B6D4)],
    keywords: const ['техник', 'электрон', 'гаджет', 'компьют', 'ноутбук', 'телефон', 'смартфон', 'видеокарт'],
    subs: const ['Айфон', 'RTX', 'Ноутбуки', 'Наушники', 'PlayStation'],
  ),
  _CatalogGroup(
    title: 'Авто и запчасти',
    icon: LucideIcons.car,
    gradient: const [Color(0xFFF97316), Color(0xFFE11D48)],
    keywords: const ['авто', 'запчаст', 'машин', 'транспорт', 'мото'],
    subs: const ['BMW', 'Шины', 'Диски', 'Автозвук', 'Масла'],
  ),
  _CatalogGroup(
    title: 'Для дома',
    icon: LucideIcons.home,
    gradient: const [Color(0xFF16A34A), Color(0xFF0D9488)],
    keywords: const ['для дома', 'мебел', 'интерьер', 'быт', 'кухн', 'декор'],
    subs: const ['Мебель', 'Освещение', 'Посуда', 'Декор', 'Инструменты'],
  ),
  _CatalogGroup(
    title: 'Услуги',
    icon: LucideIcons.wrench,
    gradient: const [Color(0xFFEAB308), Color(0xFFEA580C)],
    keywords: const ['услуг', 'ремонт', 'мастер', 'работ'],
    subs: const ['Ремонт', 'Дизайн', 'Репетиторы', 'Уборка', 'Перевозки'],
  ),
  _CatalogGroup(
    title: 'Недвижимость',
    icon: LucideIcons.building2,
    gradient: const [Color(0xFF4F46E5), Color(0xFF7C3AED)],
    keywords: const ['недвиж', 'квартир', 'аренд', 'жиль', 'комнат'],
    subs: const ['Квартиры', 'Аренда', 'Комнаты', 'Гаражи', 'Дома'],
  ),
];

const Map<String, List<String>> _synonyms = {
  'айфон': ['айфон', 'iphone'],
  'iphone': ['iphone', 'айфон'],
  'кроссовки': ['кроссов', 'sneaker', 'nike', 'jordan', 'adidas'],
  'rtx': ['rtx', 'geforce', 'видеокарт'],
  'bmw': ['bmw', 'бмв'],
  'худи': ['худи', 'hoodie'],
};

const List<String> _popularTags = ['Кроссовки', 'RTX', 'BMW', 'Айфон', 'Худи'];

const List<List<Color>> _tileGradients = [
  [Color(0xFFFF4F8B), Color(0xFF9B3DFF)],
  [Color(0xFF2563EB), Color(0xFF06B6D4)],
  [Color(0xFFF97316), Color(0xFFE11D48)],
  [Color(0xFF16A34A), Color(0xFF0D9488)],
  [Color(0xFFEAB308), Color(0xFFEA580C)],
  [Color(0xFF4F46E5), Color(0xFF7C3AED)],
  [Color(0xFF0EA5E9), Color(0xFF6366F1)],
  [Color(0xFFEC4899), Color(0xFFF59E0B)],
];

IconData _iconForCategory(String name) {
  final n = name.toLowerCase();
  bool has(List<String> k) => k.any((e) => n.contains(e));
  if (has(['одежд', 'обув', 'мод', 'кроссов'])) return LucideIcons.shirt;
  if (has(['техник', 'электрон', 'гаджет', 'компьют', 'ноут', 'телефон'])) return LucideIcons.laptop;
  if (has(['авто', 'запчаст', 'машин', 'транспорт'])) return LucideIcons.car;
  if (has(['дом', 'мебел', 'интерьер', 'быт'])) return LucideIcons.home;
  if (has(['услуг', 'ремонт', 'мастер'])) return LucideIcons.wrench;
  if (has(['недвиж', 'квартир', 'аренд'])) return LucideIcons.building2;
  if (has(['игр', 'хобби', 'спорт'])) return LucideIcons.flame;
  return LucideIcons.tag;
}

bool _matchesCategory(MarketItem it, String selected) {
  final s = selected.toLowerCase();
  final cat = it.categoryLabel.toLowerCase();
  if (cat == s) return true;
  for (final g in _groups) {
    if (g.title == selected) {
      final hay = '$cat ${it.titleText.toLowerCase()}';
      return g.keywords.any((k) => hay.contains(k));
    }
  }
  return cat.isNotEmpty && (cat.contains(s) || s.contains(cat));
}

List<MarketItem> _runSearch({
  required List<MarketItem> source,
  required String query,
  required SearchFilters filters,
  required SearchSort sort,
  required String city,
}) {
  final tokens =
      query.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

  var res = source.where((it) {
    if (tokens.isNotEmpty) {
      final hay = it.haystack;
      for (final t in tokens) {
        final alts = _synonyms[t] ?? <String>[t];
        if (!alts.any((a) => hay.contains(a))) return false;
      }
    }
    final p = it.rubPrice;
    if (filters.minPrice != null && p < filters.minPrice!) return false;
    if (filters.maxPrice != null && p > filters.maxPrice!) return false;
    if (filters.category != null && !_matchesCategory(it, filters.category!)) return false;
    if (filters.condition == ItemCondition.fresh && !it.fresh) return false;
    if (filters.condition == ItemCondition.used && it.fresh) return false;
    if (filters.deliveryOnly && !it.ship) return false;
    if (filters.aiOnly && it.aiValue <= 0) return false;
    return true;
  }).toList();

  switch (sort) {
    case SearchSort.byDefault:
      final inCity = res.where((e) => e.cityLabel == city).toList();
      final other = res.where((e) => e.cityLabel != city).toList();
      res = [...inCity, ...other];
      break;
    case SearchSort.cheaper:
      res.sort((a, b) => a.rubPrice.compareTo(b.rubPrice));
      break;
    case SearchSort.pricier:
      res.sort((a, b) => b.rubPrice.compareTo(a.rubPrice));
      break;
    case SearchSort.aiDeal:
      double score(MarketItem e) => e.aiValue * 10 + e.discount;
      res.sort((a, b) => score(b).compareTo(score(a)));
      break;
  }
  return res;
}

String _plural(int n, String one, String few, String many) {
  final m10 = n % 10;
  final m100 = n % 100;
  if (m10 == 1 && m100 != 11) return one;
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few;
  return many;
}

String _lots(int n) => '$n ${_plural(n, 'лот', 'лота', 'лотов')}';

double _textScale(BuildContext context) {
  final s = MediaQuery.textScalerOf(context).scale(14) / 14;
  return s.clamp(1.0, 1.5).toDouble();
}

// ═══════════════════════════════════════════════════════════════════════════
//  Навигация и общие зависимости
// ═══════════════════════════════════════════════════════════════════════════

class _Deps {
  const _Deps({
    required this.items,
    required this.fav,
    required this.cart,
    required this.onFav,
    required this.onCart,
    required this.city,
  });

  final List<MarketItem> items;
  final Set<String> fav;
  final Set<String> cart;
  final ValueChanged<String> onFav;
  final ValueChanged<String> onCart;
  final String city;
}

Future<void> _goResults(
  BuildContext context,
  _Deps d, {
  String query = '',
  SearchFilters filters = const SearchFilters(),
}) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => SearchResultsScreen(
      items: d.items,
      favorites: d.fav,
      cart: d.cart,
      onToggleFavorite: d.onFav,
      onToggleCart: d.onCart,
      city: d.city,
      initialQuery: query,
      initialFilters: filters,
    ),
  ));
}

Future<void> _goItem(BuildContext context, _Deps d, MarketItem item) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => ItemDetailScreen(
      item: item,
      isFavorite: d.fav.contains(item.id),
      inCart: d.cart.contains(item.id),
      onToggleFavorite: d.onFav,
      onToggleCart: d.onCart,
    ),
  ));
}

void _toast(BuildContext context, String text) {
  final m = ScaffoldMessenger.maybeOf(context);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(SnackBar(
    content: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 2),
  ));
}

// ═══════════════════════════════════════════════════════════════════════════
//  Мелкие общие виджеты
// ═══════════════════════════════════════════════════════════════════════════

enum _BtnKind { primary, outline, tonal }

class _Btn extends StatelessWidget {
  const _Btn({
    required this.label,
    required this.onTap,
    this.icon,
    this.kind = _BtnKind.outline,
    this.height = 48,
    this.active = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final _BtnKind kind;
  final double height;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = _pal(context);
    Color bg;
    Color fg;
    BorderSide side = BorderSide.none;
    switch (kind) {
      case _BtnKind.primary:
        bg = c.accent;
        fg = c.onAccent;
        break;
      case _BtnKind.tonal:
        bg = active ? _a(c.ok, 0.16) : c.card2;
        fg = active ? c.ok : c.text;
        side = BorderSide(color: active ? _a(c.ok, 0.5) : c.border);
        break;
      case _BtnKind.outline:
        bg = Colors.transparent;
        fg = active ? c.ok : c.text;
        side = BorderSide(color: active ? _a(c.ok, 0.6) : c.border, width: 1.2);
        break;
    }
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: side),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 17, color: fg),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(label, maxLines: 1, style: _body(14, fg, w: FontWeight.w800)),
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

class _Tag extends StatelessWidget {
  const _Tag(this.text, {required this.bg, required this.fg, this.icon});

  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: fg),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body(9.5, fg, w: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.icon,
    this.maxWidth = 220,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final IconData? icon;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final c = _pal(context);
    final fg = selected ? c.onAccent : c.text;
    return Material(
      color: selected ? c.accent : c.card,
      shape: StadiumBorder(side: BorderSide(color: selected ? c.accent : c.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, minHeight: 36),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: selected ? c.onAccent : c.dim),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _body(13, fg, w: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = _pal(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: i == index ? c.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      style: _body(12.5, i == index ? c.onAccent : c.dim, w: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = _pal(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 46,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? c.accent : c.card2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: value ? c.accent : c.border),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: value ? c.onAccent : c.dim,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.child, this.footer});

  final String title;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = _pal(context);
    final mq = MediaQuery.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(4)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _disp(20, c.text)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(LucideIcons.x, size: 20, color: c.dim),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: child,
              ),
            ),
            if (footer != null)
              Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 14), child: footer),
          ],
        ),
      ),
    );
  }
}

Future<T?> _openSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: builder,
  );
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onSubmitted,
    this.focusNode,
    this.onCamera,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onCamera;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final c = _pal(context);
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[controller, if (focusNode != null) focusNode!]),
      builder: (context, _) {
        final focused = focusNode?.hasFocus ?? false;
        final hasText = controller.text.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 50,
          padding: const EdgeInsets.only(left: 14, right: 8),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: focused ? c.accent : c.border, width: focused ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.search, size: 19, color: focused ? c.accent : c.dim),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: autofocus,
                  cursorColor: c.accent,
                  textInputAction: TextInputAction.search,
                  onSubmitted: onSubmitted,
                  style: _body(15, c.text, w: FontWeight.w600),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: _body(15, c.dim),
                  ),
                ),
              ),
              if (hasText)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: controller.clear,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(LucideIcons.x, size: 18, color: c.dim),
                  ),
                ),
              if (onCamera != null) ...[
                const SizedBox(width: 2),
                GestureDetector(
                  onTap: onCamera,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [c.accent, _a(c.accent, 0.65)]),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(LucideIcons.camera, size: 18, color: c.onAccent),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Карточка товара в сетке + сетка
// ═══════════════════════════════════════════════════════════════════════════

class ProductGridCard extends StatelessWidget {
  const ProductGridCard({
    super.key,
    required this.item,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final MarketItem item;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final c = _pal(context);
    final old = item.rubOld;
    final hot = item.discount > 0;
    final ai = item.aiValue;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRect(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _thumb(item),
                      Positioned(
                        left: 6,
                        top: 6,
                        right: 44,
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            if (hot)
                              const _Tag('🔥 ВЫГОДНО', bg: Color(0xFFFF4D1F), fg: Colors.white),
                            item.fresh
                                ? _Tag('НОВОЕ', bg: c.ok, fg: Colors.white)
                                : const _Tag('Б/У', bg: Color(0xFF475569), fg: Colors.white),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: _LikeButton(active: isFavorite, onTap: onToggleFavorite),
                      ),
                      if (ai > 0)
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: _Tag(
                            'AI ${ai.toStringAsFixed(1)}',
                            bg: const Color(0xCC0B0F1A),
                            fg: c.accent,
                            icon: LucideIcons.sparkles,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            _rub(item.rubPrice),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _mono(15, c.text),
                          ),
                        ),
                        if (old != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _rub(old),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _body(11, c.dim).copyWith(
                                decoration: TextDecoration.lineThrough,
                                decorationColor: c.dim,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.titleText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _body(12.5, c.text, w: FontWeight.w600, h: 1.25),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(LucideIcons.mapPin, size: 11, color: c.dim),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            item.cityLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _body(10.5, c.dim),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          item.ship ? LucideIcons.truck : LucideIcons.store,
                          size: 11,
                          color: item.ship ? c.ok : c.dim,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            item.ship ? 'Доставка' : 'Самовывоз',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _body(10.5, item.ship ? c.ok : c.dim, w: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({required this.active, required this.onTap, this.size = 32});

  final bool active;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = _pal(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: Color(0x73000000), shape: BoxShape.circle),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: Icon(
            active ? Icons.favorite : Icons.favorite_border,
            key: ValueKey<bool>(active),
            size: size * 0.56,
            color: active ? c.danger : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ProductSliverGrid extends StatelessWidget {
  const _ProductSliverGrid({
    required this.items,
    required this.favorites,
    required this.onOpen,
    required this.onToggleFavorite,
  });

  final List<MarketItem> items;
  final Set<String> favorites;
  final ValueChanged<MarketItem> onOpen;
  final ValueChanged<String> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final ts = _textScale(context);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      sliver: ListenableBuilder(
        listenable: _themeListenable,
        builder: (context, _) {
          final compact = _compactGrid;
          return SliverLayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              final cell = (constraints.crossAxisExtent - gap) / 2;
              final imageH = cell * (compact ? 0.80 : 1.10);
              final infoH = 102.0 * ts;
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: gap,
                  crossAxisSpacing: gap,
                  mainAxisExtent: imageH + infoH,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final it = items[i];
                    return ProductGridCard(
                      key: ValueKey<String>('card_${it.id}'),
                      item: it,
                      isFavorite: favorites.contains(it.id),
                      onTap: () => onOpen(it),
                      onToggleFavorite: () => onToggleFavorite(it.id),
                    );
                  },
                  childCount: items.length,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle, this.actionLabel, this.onAction});

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = _pal(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: c.card, shape: BoxShape.circle, border: Border.all(color: c.border)),
            child: Icon(LucideIcons.search, size: 30, color: c.dim),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: _disp(18, c.text)),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center, style: _body(13.5, c.dim, h: 1.35)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: 220,
              child: _Btn(label: actionLabel!, onTap: onAction, kind: _BtnKind.primary),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ВКЛАДКА 1: ГЛАВНАЯ И ПОИСК
// ═══════════════════════════════════════════════════════════════════════════

class ExploreTab extends StatefulWidget {
  const ExploreTab({
    super.key,
    required this.items,
    required this.favorites,
    required this.cart,
    required this.onToggleFavorite,
    required this.onToggleCart,
    this.onAiPhotoSearch,
  });

  final List<MarketItem> items;
  final Set<String> favorites;
  final Set<String> cart;
  final ValueChanged<String> onToggleFavorite;
  final ValueChanged<String> onToggleCart;
  final VoidCallback? onAiPhotoSearch;

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  List<String> _history = <String>[];
  String _city = _cities.first;
  int _seg = 0;
  late Set<String> _fav = {...widget.favorites};
  late Set<String> _cart = {...widget.cart};

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    _ctrl.addListener(_onText);
    _loadCity();
    _reloadHistory();
  }

  @override
  void didUpdateWidget(covariant ExploreTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fav = {...widget.favorites};
    _cart = {...widget.cart};
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ctrl.removeListener(_onText);
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  void _onText() {
    if (mounted && _focus.hasFocus) setState(() {});
  }

  Future<void> _loadCity() async {
    final saved = await _CityStore.load();
    if (!mounted) return;
    if (saved != null && _cities.contains(saved)) setState(() => _city = saved);
  }

  Future<void> _reloadHistory() async {
    final h = await _loadHistory();
    if (mounted) setState(() => _history = h);
  }

  _Deps get _deps => _Deps(
        items: widget.items,
        fav: _fav,
        cart: _cart,
        onFav: _toggleFav,
        onCart: _toggleCart,
        city: _city,
      );

  void _toggleFav(String id) {
    setState(() => _fav.contains(id) ? _fav.remove(id) : _fav.add(id));
    widget.onToggleFavorite(id);
  }

  void _toggleCart(String id) {
    setState(() => _cart.contains(id) ? _cart.remove(id) : _cart.add(id));
    widget.onToggleCart(id);
  }

  void _resync() {
    if (!mounted) return;
    setState(() {
      _fav = {...widget.favorites};
      _cart = {...widget.cart};
    });
  }

  Future<void> _submit(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) return;
    _focus.unfocus();
    await _safe(() => ApexStorage().addSearchQuery(q));
    if (!mounted) return;
    await _goResults(context, _deps, query: q);
    if (!mounted) return;
    _ctrl.clear();
    _resync();
    _reloadHistory();
  }

  Future<void> _openCategory(String name) async {
    await _goResults(context, _deps, filters: SearchFilters(category: name));
    _resync();
    _reloadHistory();
  }

  Future<void> _openItem(MarketItem it) async {
    await _goItem(context, _deps, it);
    _resync();
  }

  Future<void> _clearHistory() async {
    await _safe(() => ApexStorage().clearSearchHistory());
    await _reloadHistory();
  }

  Future<void> _pickCity() async {
    final picked = await _openSheet<String>(
      context,
      (_) => _CitySheet(cities: _cities, selected: _city),
    );
    if (picked == null || !mounted) return;
    setState(() => _city = picked);
    await _CityStore.save(picked);
  }

  void _onCamera() {
    if (widget.onAiPhotoSearch != null) {
      widget.onAiPhotoSearch!();
      return;
    }
    _focus.unfocus();
    _openSheet<String>(context, (_) => const _AiPhotoSheet()).then((q) {
      if (q != null && mounted) _submit(q);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _pal(context);
    final ts = _textScale(context);
    final searching = _focus.hasFocus;

    final cond = _seg == 1
        ? ItemCondition.fresh
        : _seg == 2
            ? ItemCondition.used
            : ItemCondition.all;
    final feed = _runSearch(
      source: widget.items,
      query: '',
      filters: SearchFilters(condition: cond),
      sort: SearchSort.byDefault,
      city: _city,
    );

    return ColoredBox(
      color: c.bg,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    const ApexBrandLogo(height: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Align(alignment: Alignment.centerRight, child: _cityButton(c)),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: _SearchField(
                        controller: _ctrl,
                        focusNode: _focus,
                        hint: 'Искать на APEX Market',
                        onSubmitted: _submit,
                        onCamera: _onCamera,
                      ),
                    ),
                    if (searching) ...[
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: () {
                          _ctrl.clear();
                          _focus.unfocus();
                        },
                        child: Text('Отмена', style: _body(14, c.accent, w: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (searching)
              SliverToBoxAdapter(child: _historyPanel(c))
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Text('Категории', style: _disp(17, c.text)),
                ),
              ),
              SliverToBoxAdapter(child: _quickCategories(c, ts)),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _Segment(
                    labels: const ['Все', 'Новое (Маркет)', 'Б/у (Барахолка)'],
                    index: _seg,
                    onChanged: (i) => setState(() => _seg = i),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              if (feed.isEmpty)
                SliverToBoxAdapter(
                  child: _EmptyState(
                    title: 'Здесь пока пусто',
                    subtitle: 'В этой ленте нет товаров. Переключите вкладку или попробуйте позже.',
                    actionLabel: _seg == 0 ? null : 'Показать все',
                    onAction: _seg == 0 ? null : () => setState(() => _seg = 0),
                  ),
                )
              else
                _ProductSliverGrid(
                  items: feed,
                  favorites: _fav,
                  onOpen: _openItem,
                  onToggleFavorite: _toggleFav,
                ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }

  Widget _cityButton(_C c) {
    return Material(
      color: c.card,
      shape: StadiumBorder(side: BorderSide(color: c.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: _pickCity,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180, minHeight: 36),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 7, 9, 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.mapPin, size: 15, color: c.accent),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    _city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _body(13, c.text, w: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 3),
                Icon(LucideIcons.chevronDown, size: 15, color: c.dim),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _historyPanel(_C c) {
    final typed = _ctrl.text.trim().toLowerCase();
    final shown = _history
        .where((h) => typed.isEmpty || h.toLowerCase().contains(typed))
        .take(10)
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (typed.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Material(
                color: c.card,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _submit(_ctrl.text),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    child: Row(
                      children: [
                        Icon(LucideIcons.search, size: 17, color: c.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Искать «${_ctrl.text.trim()}»',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _body(14, c.text, w: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(child: Text('История поиска', style: _disp(16, c.text))),
              if (_history.isNotEmpty)
                TextButton(
                  onPressed: _clearHistory,
                  child: Text('Очистить', style: _body(13, c.accent, w: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (shown.isEmpty)
            Text(
              _history.isEmpty ? 'Пока пусто. Ваши запросы появятся здесь.' : 'Совпадений в истории нет.',
              style: _body(13, c.dim),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final h in shown)
                  _Chip(label: h, icon: LucideIcons.history, onTap: () => _submit(h), maxWidth: 260),
              ],
            ),
          const SizedBox(height: 22),
          Text('Популярное', style: _disp(16, c.text)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _popularTags)
                _Chip(label: t, icon: LucideIcons.flame, onTap: () => _submit(t)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickCategories(_C c, double ts) {
    final names = _realCategoryNames;
    if (names.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 100 * ts,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: names.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final name = names[i];
          final g = _tileGradients[i % _tileGradients.length];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openCategory(name),
            child: SizedBox(
              width: 76,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: g,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(19),
                      boxShadow: [BoxShadow(color: _a(g.last, 0.35), blurRadius: 12, offset: const Offset(0, 5))],
                    ),
                    child: Icon(_iconForCategory(name), color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: _body(11, c.text, w: FontWeight.w700, h: 1.15),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CitySheet extends StatelessWidget {
  const _CitySheet({required this.cities, required this.selected});

  final List<String> cities;
  final String selected;

  @override
  Widget build(BuildContext context) {
    final c = _pal(context);
    return _SheetFrame(
      title: 'Ваш город',
      child: Column(
        children: [
          for (final city in cities)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).pop(city),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
                  child: Row(
                    children: [
                      Icon(LucideIcons.mapPin, size: 18, color: city == selected ? c.accent : c.dim),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          city,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _body(15, c.text, w: city == selected ? FontWeight.w800 : FontWeight.w600),
                        ),
                      ),
                      if (city == selected) Icon(LucideIcons.check, size: 18, color: c.accent),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AiPhotoSheet extends StatelessWidget {
  const _AiPhotoSheet();

  @override
  Widget build(BuildContext context) {
    final c = _pal(context);
    return _SheetFrame(
      title: 'AI-поиск по фото',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_a(c.accent, 0.22), _a(c.accent, 0.06)]),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _a(c.accent, 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.sparkles, color: c.accent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AI определит вещь по фото и найдёт похожие лоты. Сканер появится после подключения камеры в приложении, а пока выберите быстрый запрос:',
                    style: _body(13.5, c.text, h: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _popularTags)
                _Chip(label: t, icon: LucideIcons.search, onTap: () => Navigator.of(context).pop(t)),
            ],
          ),
        ],
      ),
    );
  }
}
// ═══════════════════════════════════════════════════════════════════════════
//  ЭКРАН ВЫДАЧИ
// ═══════════════════════════════════════════════════════════════════════════

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({
    super.key,
    required this.items,
    required this.favorites,
    required this.cart,
    required this.onToggleFavorite,
    required this.onToggleCart,
    this.city = '',
    this.initialQuery = '',
    this.initialFilters = const SearchFilters(),
  });

  final List<MarketItem> items;
  final Set<String> favorites;
  final Set<String> cart;
  final ValueChanged<String> onToggleFavorite;
  final ValueChanged<String> onToggleCart;
  final String city;
  final String initialQuery;
  final SearchFilters initialFilters;

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initialQuery);
  late String _query = widget.initialQuery;
  late SearchFilters _filters = widget.initialFilters;
  SearchSort _sort = SearchSort.byDefault;
  late Set<String> _fav = {...widget.favorites};
  late Set<String> _cart = {...widget.cart};

  static const Map<SearchSort, String> _sortLabels = {
    SearchSort.byDefault: 'По умолчанию',
    SearchSort.cheaper: 'Дешевле',
    SearchSort.pricier: 'Дороже',
    SearchSort.aiDeal: 'Выгодно по AI',
  };

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  _Deps get _deps => _Deps(
        items: widget.items,
        fav: _fav,
        cart: _cart,
        onFav: _toggleFav,
        onCart: _toggleCart,
        city: widget.city,
      );

  void _toggleFav(String id) {
    setState(() => _fav.contains(id) ? _fav.remove(id) : _fav.add(id));
    widget.onToggleFavorite(id);
  }

  void _toggleCart(String id) {
    setState(() => _cart.contains(id) ? _cart.remove(id) : _cart.add(id));
    widget.onToggleCart(id);
  }

  Future<void> _submit(String raw) async {
    final q = raw.trim();
    FocusScope.of(context).unfocus();
    setState(() => _query = q);
    if (q.isNotEmpty) await _safe(() => ApexStorage().addSearchQuery(q));
  }

  Future<void> _openFilters() async {
    FocusScope.of(context).unfocus();
    final options = [..._realCategoryNames];
    final res = await _openSheet<SearchFilters>(
      context,
      (_) => _FilterSheet(initial: _filters, categories: options),
    );
    if (res != null && mounted) setState(() => _filters = res);
  }

  @override
  Widget build(BuildContext context) {
    final c = _pal(context);
    final results = _runSearch(
      source: widget.items,
      query: _query,
      filters: _filters,
      sort: _sort,
      city: widget.city,
    );
    final active = _filters.activeCount;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(LucideIcons.arrowLeft, size: 22, color: c.text),
                  ),
                  Expanded(
                    child: _SearchField(
                      controller: _ctrl,
                      hint: 'Искать на APEX Market',
                      onSubmitted: _submit,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 0, 0),
              child: Row(
                children: [
                  _filterButton(c, active),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(right: 16),
                        itemCount: SearchSort.values.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final s = SearchSort.values[i];
                          return _Chip(
                            label: _sortLabels[s]!,
                            selected: _sort == s,
                            icon: s == SearchSort.aiDeal ? LucideIcons.sparkles : null,
                            onTap: () => setState(() => _sort = s),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      results.isEmpty ? 'Ничего не найдено' : 'Найдено: ${_lots(results.length)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _body(13, c.dim, w: FontWeight.w700),
                    ),
                  ),
                  if (_filters.category != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: GestureDetector(
                        onTap: () => setState(() => _filters = _filters.withoutCategory()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _a(c.accent, 0.14),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _a(c.accent, 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  _filters.category!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _body(12, c.accent, w: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(LucideIcons.x, size: 13, color: c.accent),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: CustomScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  if (results.isEmpty)
                    SliverToBoxAdapter(
                      child: _EmptyState(
                        title: 'Ничего не нашлось',
                        subtitle: 'Измените запрос или ослабьте фильтры: цена, состояние, доставка.',
                        actionLabel: (active > 0 || _query.isNotEmpty) ? 'Сбросить всё' : null,
                        onAction: (active > 0 || _query.isNotEmpty)
                            ? () => setState(() {
                                  _filters = const SearchFilters();
                                  _query = '';
                                  _ctrl.clear();
                                })
                            : null,
                      ),
                    )
                  else
                    _ProductSliverGrid(
                      items: results,
                      favorites: _fav,
                      onOpen: (it) async {
                        await _goItem(context, _deps, it);
                        if (mounted) {
                          setState(() {
                            _fav = {..._fav};
                            _cart = {..._cart};
                          });
                        }
                      },
                      onToggleFavorite: _toggleFav,
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterButton(_C c, int active) {
    final on = active > 0;
    return Material(
      color: on ? _a(c.accent, 0.14) : c.card,
      shape: StadiumBorder(side: BorderSide(color: on ? c.accent : c.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: _openFilters,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 38),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.slidersHorizontal, size: 15, color: on ? c.accent : c.text),
                const SizedBox(width: 6),
                Text('Фильтры', maxLines: 1, style: _body(13, on ? c.accent : c.text, w: FontWeight.w800)),
                if (on) ...[
                  const SizedBox(width: 6),
                  Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(9)),
                    child: Text('$active', style: _body(11, c.onAccent, w: FontWeight.w900)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial, required this.categories});

  final SearchFilters initial;
  final List<String> categories;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final TextEditingController _from = TextEditingController(text: _fmt(widget.initial.minPrice));
  late final TextEditingController _to = TextEditingController(text: _fmt(widget.initial.maxPrice));
  late String? _cat = widget.initial.category;
  late ItemCondition _cond = widget.initial.condition;
  late bool _delivery = widget.initial.deliveryOnly;
  late bool _ai = widget.initial.aiOnly;

  static String _fmt(double? v) => v == null ? '' : v.round().toString();

  static double? _parse(String s) {
    final clean = s.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.isEmpty) return null;
    return double.tryParse(clean);
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  SearchFilters _build() {
    var lo = _parse(_from.text);
    var hi = _parse(_to.text);
    if (lo != null && hi != null && lo > hi) {
      final t = lo;
      lo = hi;
      hi = t;
    }
    return SearchFilters(
      minPrice: lo,
      maxPrice: hi,
      category: _cat,
      condition: _cond,
      deliveryOnly: _delivery,
      aiOnly: _ai,
    );
  }

  void _reset() {
    setState(() {
      _from.clear();
      _to.clear();
      _cat = null;
      _cond = ItemCondition.all;
      _delivery = false;
      _ai = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _pal(context);
    final cats = [...widget.categories];
    if (_cat != null && !cats.contains(_cat)) cats.insert(0, _cat!);

    return _SheetFrame(
      title: 'Фильтры',
      footer: Row(
        children: [
          Expanded(child: _Btn(label: 'Сбросить', onTap: _reset)),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _Btn(
              label: 'Показать результаты',
              kind: _BtnKind.primary,
              onTap: () => Navigator.of(context).pop(_build()),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Цена, ₽', c),
          Row(
            children: [
              Expanded(child: _priceField(_from, 'От', c)),
              const SizedBox(width: 10),
              Expanded(child: _priceField(_to, 'До', c)),
            ],
          ),
          const SizedBox(height: 20),
          if (cats.isNotEmpty) ...[
            _label('Категория', c),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(label: 'Все', selected: _cat == null, onTap: () => setState(() => _cat = null)),
                for (final n in cats)
                  _Chip(label: n, selected: _cat == n, onTap: () => setState(() => _cat = n)),
              ],
            ),
            const SizedBox(height: 20),
          ],
          _label('Состояние', c),
          _Segment(
            labels: const ['Все', 'Новое', 'Б/у с рук'],
            index: _cond.index,
            onChanged: (i) => setState(() => _cond = ItemCondition.values[i]),
          ),
          const SizedBox(height: 18),
          _switchRow(c, LucideIcons.truck, 'Только с доставкой', 'Продавец отправит по России', _delivery,
              (v) => setState(() => _delivery = v)),
          const SizedBox(height: 10),
          _switchRow(c, LucideIcons.sparkles, 'Только с проверкой AI', 'Лоты с AI-оценкой состояния', _ai,
              (v) => setState(() => _ai = v)),
        ],
      ),
    );
  }

  Widget _label(String t, _C c) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t, style: _body(13, c.dim, w: FontWeight.w800)),
      );

  Widget _priceField(TextEditingController ctrl, String hint, _C c) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Text(hint, style: _body(13, c.dim, w: FontWeight.w700)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              cursorColor: c.accent,
              style: _mono(15, c.text, w: FontWeight.w700),
              decoration: const InputDecoration(isCollapsed: true, border: InputBorder.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchRow(_C c, IconData icon, String title, String sub, bool v, ValueChanged<bool> on) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: v ? c.accent : c.dim),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _body(14, c.text, w: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: _body(11.5, c.dim)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _MiniSwitch(value: v, onChanged: on),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ВКЛАДКА 2: КАТАЛОГ
// ═══════════════════════════════════════════════════════════════════════════

class CatalogTab extends StatefulWidget {
  const CatalogTab({
    super.key,
    required this.items,
    required this.favorites,
    required this.cart,
    required this.onToggleFavorite,
    required this.onToggleCart,
  });

  final List<MarketItem> items;
  final Set<String> favorites;
  final Set<String> cart;
  final ValueChanged<String> onToggleFavorite;
  final ValueChanged<String> onToggleCart;

  @override
  State<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<CatalogTab> {
  String _city = _cities.first;
  late Set<String> _fav = {...widget.favorites};
  late Set<String> _cart = {...widget.cart};

  @override
  void initState() {
    super.initState();
    _CityStore.load().then((saved) {
      if (mounted && saved != null && _cities.contains(saved)) setState(() => _city = saved);
    });
  }

  @override
  void didUpdateWidget(covariant CatalogTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fav = {...widget.favorites};
    _cart = {...widget.cart};
  }

  _Deps get _deps => _Deps(
        items: widget.items,
        fav: _fav,
        cart: _cart,
        onFav: (id) {
          setState(() => _fav.contains(id) ? _fav.remove(id) : _fav.add(id));
          widget.onToggleFavorite(id);
        },
        onCart: (id) {
          setState(() => _cart.contains(id) ? _cart.remove(id) : _cart.add(id));
          widget.onToggleCart(id);
        },
        city: _city,
      );

  int _count(_CatalogGroup g) =>
      widget.items.where((it) => _matchesCategory(it, g.title)).length;

  Future<void> _open(BuildContext context, {String? category, String query = ''}) async {
    await _goResults(
      context,
      _deps,
      query: query,
      filters: SearchFilters(category: category),
    );
    if (!mounted) return;
    setState(() {
      _fav = {...widget.favorites};
      _cart = {...widget.cart};
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _pal(context);
    return ColoredBox(
      color: c.bg,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Каталог', style: _disp(26, c.text)),
                    const SizedBox(height: 4),
                    Text('Выберите раздел или сразу популярную подкатегорию',
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: _body(13.5, c.dim)),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
              sliver: SliverList.separated(
                itemCount: _groups.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _groupCard(context, _groups[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupCard(BuildContext context, _CatalogGroup g) {
    final n = _count(g);
    final base = g.gradient;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            Color.alphaBlend(const Color(0x33000000), base.first),
            Color.alphaBlend(const Color(0x33000000), base.last),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: _a(base.last, 0.30), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -14,
            bottom: -18,
            child: Icon(g.icon, size: 120, color: const Color(0x1FFFFFFF)),
          ),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => _open(context, category: g.title),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0x2EFFFFFF),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: const Color(0x40FFFFFF)),
                          ),
                          child: Icon(g.icon, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                g.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: _disp(19, Colors.white, h: 1.1),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                n == 0 ? 'Скоро появятся лоты' : _lots(n),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _body(12.5, const Color(0xDDFFFFFF), w: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        const Icon(LucideIcons.chevronRight, color: Colors.white, size: 22),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final s in g.subs)
                          GestureDetector(
                            onTap: () => _open(context, query: s),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 200, minHeight: 34),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: const Color(0x2EFFFFFF),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0x40FFFFFF)),
                                ),
                                child: Text(
                                  s,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _body(12.5, Colors.white, w: FontWeight.w800),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  КАРТОЧКА ТОВАРА
// ═══════════════════════════════════════════════════════════════════════════

const double _guarantorRate = 0.04;

class ItemDetailScreen extends StatefulWidget {
  const ItemDetailScreen({
    super.key,
    required this.item,
    required this.onToggleFavorite,
    required this.onToggleCart,
    this.isFavorite = false,
    this.inCart = false,
  });

  final MarketItem item;
  final bool isFavorite;
  final bool inCart;
  final ValueChanged<String> onToggleFavorite;
  final ValueChanged<String> onToggleCart;

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late bool _fav = widget.isFavorite;
  late bool _inCart = widget.inCart;

  MarketItem get item => widget.item;

  @override
  void initState() {
    super.initState();
    _safe(() => ApexStorage().markViewed(item.id));
  }

  void _toggleFav() {
    setState(() => _fav = !_fav);
    widget.onToggleFavorite(item.id);
  }

  void _toggleCart() {
    setState(() => _inCart = !_inCart);
    widget.onToggleCart(item.id);
  }

  Future<void> _call() async {
    final phone = item.sellerPhoneText.replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.isEmpty) {
      _toast(context, 'Продавец не указал телефон');
      return;
    }
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse('tel:$phone'));
    } catch (_) {}
    if (!ok && mounted) _toast(context, 'Не удалось открыть звонилку');
  }

  Future<void> _write() async {
    await _openSheet<void>(context, (_) => _WriteSheet(item: item));
  }

  Future<void> _buy() async {
    await _openSheet<void>(context, (_) => _CheckoutSheet(item: item));
  }

  @override
  Widget build(BuildContext context) {
    final c = _pal(context);
    final top = MediaQuery.of(context).padding.top;
    final old = item.rubOld;
    final ai = item.aiValue;
    final fee = (item.rubPrice * _guarantorRate).round();
    final total = item.rubPrice.round() + fee;

    return Scaffold(
      backgroundColor: c.bg,
      bottomNavigationBar: _bottomBar(c),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            children: [
              AspectRatio(aspectRatio: 1, child: _thumb(item)),
              Positioned(
                left: 12,
                top: top + 8,
                child: _roundButton(LucideIcons.arrowLeft, () => Navigator.of(context).maybePop()),
              ),
              Positioned(
                right: 12,
                top: top + 8,
                child: _LikeButton(active: _fav, onTap: _toggleFav, size: 42),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    item.fresh
                        ? _Tag('НОВОЕ', bg: c.ok, fg: Colors.white)
                        : const _Tag('Б/У', bg: Color(0xFF475569), fg: Colors.white),
                    if (item.discount > 0)
                      const _Tag('🔥 Ниже рынка', bg: Color(0xFFFF4D1F), fg: Colors.white),
                    if (ai > 0)
                      _Tag(
                        'AI-оценка: ${ai.toStringAsFixed(1)} / 10',
                        bg: const Color(0xDD0B0F1A),
                        fg: c.accent,
                        icon: LucideIcons.sparkles,
                      ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    Text(_rub(item.rubPrice), style: _mono(30, c.text)),
                    if (old != null)
                      Text(
                        _rub(old),
                        style: _body(16, c.dim).copyWith(
                          decoration: TextDecoration.lineThrough,
                          decorationColor: c.dim,
                        ),
                      ),
                    if (item.discount > 0)
                      _Tag('−${item.discount.round()}%', bg: _a(c.danger, 0.16), fg: c.danger),
                  ],
                ),
                const SizedBox(height: 8),
                Text(item.titleText, style: _disp(20, c.text, w: FontWeight.w700, h: 1.25)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _meta(LucideIcons.mapPin, item.cityLabel, c.dim, c),
                    _meta(
                      item.ship ? LucideIcons.truck : LucideIcons.store,
                      item.ship ? 'Доставка по России' : 'Самовывоз',
                      item.ship ? c.ok : c.dim,
                      c,
                    ),
                    if (item.categoryLabel.isNotEmpty) _meta(LucideIcons.tag, item.categoryLabel, c.dim, c),
                  ],
                ),
                if (ai > 0) ...[
                  const SizedBox(height: 18),
                  _aiBlock(c, ai),
                ],
                const SizedBox(height: 18),
                _safeDealBlock(c, fee, total),
                const SizedBox(height: 18),
                _sellerBlock(c),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(color: Color(0x73000000), shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }

  Widget _meta(IconData icon, String text, Color color, _C c) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(text,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: _body(13, color, w: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _aiBlock(_C c, double ai) {
    final note = item.aiComment.trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_a(c.accent, 0.18), _a(c.accent, 0.05)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _a(c.accent, 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(14)),
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(ai.toStringAsFixed(1), style: _mono(18, c.onAccent)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI-оценка состояния: ${ai.toStringAsFixed(1)} / 10',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _body(14, c.text, w: FontWeight.w800),
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(note, style: _body(13, c.dim, h: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _safeDealBlock(_C c, int fee, int total) {
    Widget row(String l, String r, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(l,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _body(13.5, bold ? c.text : c.dim, w: bold ? FontWeight.w800 : FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              Text(r, style: _mono(bold ? 16 : 13.5, c.text, w: bold ? FontWeight.w800 : FontWeight.w600)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.shieldCheck, size: 20, color: c.ok),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Безопасная сделка',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: _body(15, c.text, w: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Деньги хранятся у Гаранта, пока вы не получите и не проверите товар.',
            style: _body(12.5, c.dim, h: 1.4),
          ),
          const SizedBox(height: 10),
          row('Цена товара', _rub(item.rubPrice)),
          row('Гарант (+${(_guarantorRate * 100).round()}%)', _rub(fee)),
          Divider(height: 14, color: c.border),
          row('Итого через Гарант', _rub(total), bold: true),
        ],
      ),
    );
  }

  Widget _sellerBlock(_C c) {
    final name = item.sellerLabel.trim();
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final handle = item.sellerHandle;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c.accent, _a(c.accent, 0.55)]),
              shape: BoxShape.circle,
            ),
            child: Text(initial, style: _disp(22, c.onAccent)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Продавец' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _body(15.5, c.text, w: FontWeight.w800),
                ),
                if (handle.isNotEmpty)
                  Text('@$handle',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: _body(13, c.dim, w: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (item.sellerVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _a(c.ok, 0.16),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _a(c.ok, 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.badgeCheck, size: 13, color: c.ok),
                            const SizedBox(width: 4),
                            Text('Telegram подтверждён', style: _body(11.5, c.ok, w: FontWeight.w800)),
                          ],
                        ),
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.mapPin, size: 12, color: c.dim),
                        const SizedBox(width: 3),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(item.cityLabel,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: _body(12, c.dim)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(_C c) {
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Btn(
                      label: _inCart ? 'В корзине ✓' : 'В корзину',
                      icon: LucideIcons.shoppingCart,
                      kind: _BtnKind.tonal,
                      active: _inCart,
                      onTap: _toggleCart,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Btn(
                      label: 'Купить с доставкой',
                      icon: LucideIcons.truck,
                      kind: _BtnKind.primary,
                      onTap: _buy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _Btn(label: 'Написать', icon: LucideIcons.messageCircle, height: 42, onTap: _write),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Btn(label: 'Позвонить', icon: LucideIcons.phone, height: 42, onTap: _call),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── «Написать продавцу» ───────────────────────────

class _WriteSheet extends StatefulWidget {
  const _WriteSheet({required this.item});

  final MarketItem item;

  @override
  State<_WriteSheet> createState() => _WriteSheetState();
}

class _WriteSheetState extends State<_WriteSheet> {
  final TextEditingController _text = TextEditingController();
  bool _sending = false;
  String? _error;

  static const List<String> _quick = [
    'Здравствуйте! Товар ещё в продаже?',
    'Возможен торг?',
    'Можно посмотреть вживую?',
    'Готов купить через Безопасную сделку',
  ];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty) {
      setState(() => _error = 'Введите сообщение');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _sendToSeller(widget.item, t);
      nav.pop();
      messenger.showSnackBar(SnackBar(
        content: Text(
          widget.item.sellerHandle.isEmpty
              ? 'Сообщение отправлено продавцу'
              : 'Сообщение отправлено @${widget.item.sellerHandle}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = 'Не удалось отправить. Проверьте соединение и повторите.';
        });
      }
    }
  }

  Future<void> _telegram() async {
    final h = widget.item.sellerHandle;
    if (h.isEmpty) return;
    final text = _text.text.trim().isEmpty ? 'Здравствуйте! Пишу по товару «${widget.item.titleText}»' : _text.text.trim();
    final uri = Uri.parse('https://t.me/$h?text=${Uri.encodeComponent(text)}');
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && mounted) setState(() => _error = 'Не удалось открыть Telegram');
  }

  @override
  Widget build(BuildContext context) {
    final c = _pal(context);
    final hasTg = widget.item.sellerHandle.isNotEmpty;
    return _SheetFrame(
      title: 'Написать продавцу',
      footer: Row(
        children: [
          if (hasTg) ...[
            Expanded(
              child: _Btn(label: 'В Telegram', icon: LucideIcons.send, onTap: _sending ? null : _telegram),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 2,
            child: _Btn(
              label: _sending ? 'Отправка…' : 'Отправить',
              icon: LucideIcons.messageCircle,
              kind: _BtnKind.primary,
              onTap: _sending ? null : _send,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.item.titleText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _body(13, c.dim, w: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in _quick)
                _Chip(
                  label: q,
                  maxWidth: 300,
                  onTap: () => setState(() {
                    _text.text = q;
                    _text.selection = TextSelection.collapsed(offset: q.length);
                    _error = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _error != null ? c.danger : c.border),
            ),
            child: TextField(
              controller: _text,
              minLines: 3,
              maxLines: 6,
              cursorColor: c.accent,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              style: _body(15, c.text, h: 1.35),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Ваше сообщение продавцу',
                hintStyle: _body(15, c.dim),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: _body(12.5, c.danger, w: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

// ────────────────────────── Быстрое оформление заказа ──────────────────────

class _DeliveryOption {
  const _DeliveryOption(this.id, this.title, this.subtitle, this.price, this.icon, this.addressHint);

  final String id;
  final String title;
  final String subtitle;
  final int price;
  final IconData icon;
  final String addressHint;
}

const List<_DeliveryOption> _deliveryOptions = [
  _DeliveryOption('pvz', 'Пункт выдачи (ПВЗ)', 'Boxberry, 5Post, Магнит · 3–5 дней', 149,
      LucideIcons.package, 'Адрес или номер пункта выдачи'),
  _DeliveryOption('cdek', 'СДЭК', 'До пункта или двери · 2–4 дня', 249, LucideIcons.truck,
      'Город и адрес пункта СДЭК'),
  _DeliveryOption('courier', 'Курьер', 'Доставка до двери · 1–2 дня', 399, LucideIcons.home,
      'Улица, дом, квартира'),
];

class _CheckoutSheet extends StatefulWidget {
  const _CheckoutSheet({required this.item});

  final MarketItem item;

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  int _method = 0;
  bool _guarantee = true;
  bool _sending = false;
  bool _done = false;
  String? _error;
  final TextEditingController _address = TextEditingController();

  _DeliveryOption get _opt => _deliveryOptions[_method];
  int get _price => widget.item.rubPrice.round();
  int get _fee => _guarantee ? (_price * _guarantorRate).round() : 0;
  int get _total => _price + _opt.price + _fee;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final addr = _address.text.trim();
    if (addr.isEmpty) {
      setState(() => _error = 'Укажите ${_opt.addressHint.toLowerCase()}');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final msg = 'Здравствуйте! Хочу купить «${widget.item.titleText}» за ${_rub(_price)}.\n'
        'Доставка: ${_opt.title} (${_rub(_opt.price)}), адрес: $addr.\n'
        'Безопасная сделка: ${_guarantee ? 'да (+${_rub(_fee)})' : 'нет'}.\n'
        'Итого: ${_rub(_total)}.';
    try {
      await _sendToSeller(widget.item, msg);
      if (mounted) {
        setState(() {
          _sending = false;
          _done = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = 'Не удалось отправить заявку. Повторите попытку.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _pal(context);
    if (_done) return _doneView(c);

    return _SheetFrame(
      title: 'Оформление заказа',
      footer: _Btn(
        label: _sending ? 'Отправка…' : 'Оформить · ${_rub(_total)}',
        icon: LucideIcons.shieldCheck,
        kind: _BtnKind.primary,
        height: 52,
        onTap: _sending ? null : _confirm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.item.titleText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _body(14, c.text, w: FontWeight.w700),
          ),
          if (!widget.item.ship) ...[
            const SizedBox(height: 8),
            Text(
              'Продавец не отметил доставку: заявка уйдёт ему сообщением, способ согласуете в чате.',
              style: _body(12.5, c.warn, w: FontWeight.w700, h: 1.35),
            ),
          ],
          const SizedBox(height: 16),
          Text('Способ доставки', style: _body(13, c.dim, w: FontWeight.w800)),
          const SizedBox(height: 10),
          for (var i = 0; i < _deliveryOptions.length; i++) ...[
            _optionTile(c, i),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 6),
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _error != null ? c.danger : c.border),
            ),
            child: Row(
              children: [
                Icon(_opt.icon, size: 17, color: c.dim),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _address,
                    cursorColor: c.accent,
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    style: _body(14.5, c.text, w: FontWeight.w600),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: _opt.addressHint,
                      hintStyle: _body(14.5, c.dim),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: _body(12.5, c.danger, w: FontWeight.w700)),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _guarantee ? _a(c.ok, 0.55) : c.border),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.shieldCheck, size: 20, color: _guarantee ? c.ok : c.dim),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Безопасная сделка (Гарант +${(_guarantorRate * 100).round()}%)',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _body(14, c.text, w: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('Продавец получит деньги после вашего подтверждения',
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: _body(11.5, c.dim)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _MiniSwitch(value: _guarantee, onChanged: (v) => setState(() => _guarantee = v)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sumRow(c, 'Товар', _rub(_price)),
          _sumRow(c, _opt.title, _rub(_opt.price)),
          if (_guarantee) _sumRow(c, 'Гарант', _rub(_fee)),
          Divider(height: 18, color: c.border),
          _sumRow(c, 'Итого', _rub(_total), bold: true),
        ],
      ),
    );
  }

  Widget _optionTile(_C c, int i) {
    final o = _deliveryOptions[i];
    final sel = i == _method;
    return Material(
      color: sel ? _a(c.accent, 0.10) : c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: sel ? c.accent : c.border, width: sel ? 1.6 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() {
          _method = i;
          _error = null;
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(o.icon, size: 22, color: sel ? c.accent : c.dim),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: _body(14.5, c.text, w: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(o.subtitle,
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: _body(11.5, c.dim, h: 1.3)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(_rub(o.price), style: _mono(13.5, c.text, w: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sumRow(_C c, String l, String r, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(l,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _body(bold ? 15 : 13.5, bold ? c.text : c.dim, w: bold ? FontWeight.w800 : FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Text(r, style: _mono(bold ? 18 : 13.5, c.text, w: bold ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _doneView(_C c) {
    return _SheetFrame(
      title: 'Заявка отправлена',
      footer: _Btn(
        label: 'Готово',
        kind: _BtnKind.primary,
        height: 52,
        onTap: () => Navigator.of(context).pop(),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(color: _a(c.ok, 0.16), shape: BoxShape.circle),
            child: Icon(LucideIcons.check, size: 38, color: c.ok),
          ),
          const SizedBox(height: 16),
          Text('Продавец получил ваш заказ',
              textAlign: TextAlign.center, style: _disp(18, c.text)),
          const SizedBox(height: 8),
          Text(
            '${_opt.title} · ${_rub(_total)}${_guarantee ? ' · Безопасная сделка' : ''}.\nОтвет придёт в чат с продавцом.',
            textAlign: TextAlign.center,
            style: _body(13.5, c.dim, h: 1.4),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
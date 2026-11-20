import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ai_orb.dart';
import 'config.dart';
import 'data.dart';
import 'screens_account.dart';
import 'screens_explore.dart';
import 'theme.dart';

/// Глобальный ключ навигатора для переходов из плавающей сферы APEX AI.
final GlobalKey<NavigatorState> apexNavigatorKey = GlobalKey<NavigatorState>();

/// Начальный снимок данных, загружаемый при старте приложения.
class _InitialAppState {
  const _InitialAppState({
    required this.items,
    required this.favorites,
    required this.cart,
    required this.account,
    required this.settings,
    required this.notifications,
    required this.chats,
  });

  final List<MarketItem> items;
  final Set<String> favorites;
  final Set<String> cart;
  final UserAccount account;
  final AppSettings settings;
  final List<AppNotification> notifications;
  final List<ChatMessage> chats;
}

/// Адаптер интеграции с data.dart, theme.dart и screens_explore.dart.
class _MainAdapter {
  static final ApexStorage storage = ApexStorage();

  static Future<_InitialAppState> loadAll() async {
    final results = await Future.wait<dynamic>([
      storage.loadItems(),
      storage.loadFavoriteIds(),
      storage.loadCartIds(),
      storage.loadAccount(),
      storage.loadSettings(),
      storage.loadNotifications(),
      storage.loadChats(),
    ]);

    return _InitialAppState(
      items: List<MarketItem>.from(results[0] as List<MarketItem>),
      favorites: Set<String>.from(results[1] as List<String>),
      cart: Set<String>.from(results[2] as List<String>),
      account: results[3] as UserAccount,
      settings: results[4] as AppSettings,
      notifications:
          List<AppNotification>.from(results[5] as List<AppNotification>),
      chats: List<ChatMessage>.from(results[6] as List<ChatMessage>),
    );
  }

  static ThemeMode parseThemeMode(String raw) {
    switch (raw.toLowerCase()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static void applyTheme(ApexThemeController controller, AppSettings settings) {
    controller.setThemeMode(parseThemeMode(settings.themeMode));
    controller.setCompactGrid(settings.compactGrid);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final initialState = await _MainAdapter.loadAll();
  final themeController = ApexThemeController();
  _MainAdapter.applyTheme(themeController, initialState.settings);
  bindExploreThemeController(themeController);

  runApp(
    ApexMarketApp(
      initialState: initialState,
      themeController: themeController,
    ),
  );
}

class ApexMarketApp extends StatefulWidget {
  const ApexMarketApp({
    super.key,
    required this.initialState,
    required this.themeController,
  });

  final _InitialAppState initialState;
  final ApexThemeController themeController;

  @override
  State<ApexMarketApp> createState() => _ApexMarketAppState();
}

class _ApexMarketAppState extends State<ApexMarketApp> {
  late List<MarketItem> _items;
  late Set<String> _favorites;
  late Set<String> _cart;
  late UserAccount _account;
  late AppSettings _settings;
  late List<AppNotification> _notifications;
  late List<ChatMessage> _chats;

  @override
  void initState() {
    super.initState();
    _items = widget.initialState.items;
    _favorites = widget.initialState.favorites;
    _cart = widget.initialState.cart;
    _account = widget.initialState.account;
    _settings = widget.initialState.settings;
    _notifications = widget.initialState.notifications;
    _chats = widget.initialState.chats;
  }

  Future<void> _reloadAll() async {
    final fresh = await _MainAdapter.loadAll();
    if (!mounted) return;
    setState(() {
      _items = fresh.items;
      _favorites = fresh.favorites;
      _cart = fresh.cart;
      _account = fresh.account;
      _settings = fresh.settings;
      _notifications = fresh.notifications;
      _chats = fresh.chats;
    });
  }

  Future<void> _toggleFavorite(String itemId) async {
    final updatedIds = await _MainAdapter.storage.toggleFavorite(itemId);
    if (!mounted) return;
    setState(() => _favorites = updatedIds.toSet());
  }

  Future<void> _toggleCart(String itemId) async {
    final updatedIds = await _MainAdapter.storage.toggleCart(itemId);
    if (!mounted) return;
    setState(() => _cart = updatedIds.toSet());
  }

  void _openItemDetail(MarketItem item) {
    final nav = apexNavigatorKey.currentState;
    if (nav == null) return;

    nav
        .push(
          MaterialPageRoute<void>(
            builder: (_) => ItemDetailScreen(
              item: item,
              isFavorite: _favorites.contains(item.id),
              inCart: _cart.contains(item.id),
              onToggleFavorite: _toggleFavorite,
              onToggleCart: _toggleCart,
            ),
          ),
        )
        .then((_) => _reloadAll());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.themeController,
      builder: (context, _) {
        final mode = widget.themeController.mode;
        final isDark = mode == ThemeMode.dark ||
            (mode == ThemeMode.system &&
                WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                    Brightness.dark);

        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
          ),
        );

        return MaterialApp(
          title: AppConfig.appName,
          debugShowCheckedModeBanner: false,
          navigatorKey: apexNavigatorKey,
          theme: ApexTheme.light(),
          darkTheme: ApexTheme.dark(),
          themeMode: mode,
          builder: (context, child) {
            return Stack(
              children: [
                if (child != null) child,
                ApexFloatingOrb(
                  navigatorKey: apexNavigatorKey,
                  items: _items,
                  onOpenItem: _openItemDetail,
                ),
              ],
            );
          },
          home: ApexShell(
            items: _items,
            favorites: _favorites,
            cart: _cart,
            account: _account,
            settings: _settings,
            notifications: _notifications,
            chats: _chats,
            themeController: widget.themeController,
            onRefreshAll: _reloadAll,
            onToggleFavorite: _toggleFavorite,
            onToggleCart: _toggleCart,
            onOpenItem: _openItemDetail,
            onAccountChanged: (nextAccount) {
              setState(() => _account = nextAccount);
              _reloadAll();
            },
            onSettingsChanged: (nextSettings) {
              setState(() => _settings = nextSettings);
              _MainAdapter.applyTheme(widget.themeController, nextSettings);
            },
          ),
        );
      },
    );
  }
}

class ApexShell extends StatefulWidget {
  const ApexShell({
    super.key,
    required this.items,
    required this.favorites,
    required this.cart,
    required this.account,
    required this.settings,
    required this.notifications,
    required this.chats,
    required this.themeController,
    required this.onRefreshAll,
    required this.onToggleFavorite,
    required this.onToggleCart,
    required this.onOpenItem,
    required this.onAccountChanged,
    required this.onSettingsChanged,
  });

  final List<MarketItem> items;
  final Set<String> favorites;
  final Set<String> cart;
  final UserAccount account;
  final AppSettings settings;
  final List<AppNotification> notifications;
  final List<ChatMessage> chats;
  final ApexThemeController themeController;
  final Future<void> Function() onRefreshAll;
  final Future<void> Function(String itemId) onToggleFavorite;
  final Future<void> Function(String itemId) onToggleCart;
  final void Function(MarketItem item) onOpenItem;
  final ValueChanged<UserAccount> onAccountChanged;
  final ValueChanged<AppSettings> onSettingsChanged;

  @override
  State<ApexShell> createState() => _ApexShellState();
}

class _ApexShellState extends State<ApexShell> {
  int _currentIndex = 0;

  int get _unreadInboxCount {
    final unreadNotifs = widget.notifications.where((n) => !n.isRead).length;
    final incomingMessages = widget.chats.where((m) => !m.isMe).length;
    return unreadNotifs + incomingMessages;
  }

  void _selectTab(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
    if (index == 3 || index == 4 || index == 5) {
      widget.onRefreshAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      ExploreTab(
        items: widget.items,
        favorites: widget.favorites,
        cart: widget.cart,
        onToggleFavorite: widget.onToggleFavorite,
        onToggleCart: widget.onToggleCart,
      ),
      CatalogTab(
        items: widget.items,
        favorites: widget.favorites,
        cart: widget.cart,
        onToggleFavorite: widget.onToggleFavorite,
        onToggleCart: widget.onToggleCart,
      ),
      SellTab(
        account: widget.account,
        settings: widget.settings,
        onAccountChanged: widget.onAccountChanged,
        onPublished: () async {
          await widget.onRefreshAll();
          if (mounted) {
            setState(() => _currentIndex = 0);
          }
        },
      ),
      InboxTab(
        chats: widget.chats,
        notifications: widget.notifications,
        account: widget.account,
        onRefresh: widget.onRefreshAll,
      ),
      CartTab(
        items: widget.items,
        cart: widget.cart,
        favorites: widget.favorites,
        account: widget.account,
        onToggleCart: widget.onToggleCart,
        onToggleFavorite: widget.onToggleFavorite,
        onOpenItem: widget.onOpenItem,
        onOrderCompleted: widget.onRefreshAll,
      ),
      ProfileTab(
        account: widget.account,
        items: widget.items,
        settings: widget.settings,
        themeController: widget.themeController,
        onAccountChanged: widget.onAccountChanged,
        onSettingsChanged: widget.onSettingsChanged,
        onOpenItem: widget.onOpenItem,
        onRefresh: widget.onRefreshAll,
      ),
    ];

    return Scaffold(
      extendBody: false,
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: _ApexBottomBar(
        currentIndex: _currentIndex,
        unreadInboxCount: _unreadInboxCount,
        cartCount: widget.cart.length,
        isVerified: widget.account.isLoggedIn && widget.account.tgVerified,
        onTap: _selectTab,
      ),
    );
  }
}

class _ApexBottomBar extends StatelessWidget {
  const _ApexBottomBar({
    required this.currentIndex,
    required this.unreadInboxCount,
    required this.cartCount,
    required this.isVerified,
    required this.onTap,
  });

  final int currentIndex;
  final int unreadInboxCount;
  final int cartCount;
  final bool isVerified;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final p = ApexPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(
          top: BorderSide(
            color: p.border.withOpacity(isDark ? 0.7 : 0.9),
            width: 0.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.28 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _NavItem(
                label: 'Главная',
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                label: 'Каталог',
                icon: Icons.grid_view_outlined,
                activeIcon: Icons.grid_view_rounded,
                selected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _SellNavButton(
                selected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                label: 'Чаты',
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                selected: currentIndex == 3,
                badgeCount: unreadInboxCount,
                onTap: () => onTap(3),
              ),
              _NavItem(
                label: 'Корзина',
                icon: Icons.shopping_bag_outlined,
                activeIcon: Icons.shopping_bag_rounded,
                selected: currentIndex == 4,
                badgeCount: cartCount,
                onTap: () => onTap(4),
              ),
              _NavItem(
                label: 'Профиль',
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                selected: currentIndex == 5,
                showVerifiedDot: isVerified,
                onTap: () => onTap(5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
    this.showVerifiedDot = false,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;
  final bool showVerifiedDot;

  @override
  Widget build(BuildContext context) {
    final p = ApexPalette.of(context);
    final color = selected ? ApexPalette.accent : p.muted;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: ApexPalette.accent.withOpacity(0.12),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedScale(
                    scale: selected ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      selected ? activeIcon : icon,
                      size: 22,
                      color: color,
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -8,
                      top: -5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.5,
                          vertical: 1,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B5C),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: p.surface, width: 1.5),
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  if (showVerifiedDot && badgeCount == 0)
                    Positioned(
                      right: -2,
                      top: -1,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: ApexPalette.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: p.surface, width: 1.4),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: bodyStyle(
                  10.5,
                  weight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SellNavButton extends StatelessWidget {
  const _SellNavButton({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = ApexPalette.of(context);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 38,
              height: 30,
              decoration: BoxDecoration(
                gradient: ApexPalette.accentGradient,
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: ApexPalette.accent.withOpacity(selected ? 0.48 : 0.28),
                    blurRadius: selected ? 12 : 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Продать',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bodyStyle(
                10.5,
                weight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? ApexPalette.accent : p.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
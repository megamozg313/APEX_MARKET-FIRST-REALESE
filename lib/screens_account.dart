import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'data.dart';
import 'theme.dart';

// =============================================================================
// АДАПТЕР ДЛЯ data.dart И theme.dart
// =============================================================================
class _AccountAdapter {
  static final ApexStorage storage = ApexStorage();
  static const String _cityKey = 'apex_selected_city';

  static Future<Map<String, dynamic>> analyzeItemPhoto(String path) =>
      storage.analyzeItemPhoto(path);

  static Future<void> addItem(MarketItem item) => storage.addItem(item);

  static Future<void> deleteItem(String itemId) => storage.deleteItem(itemId);

  static Future<void> toggleBoost(String itemId) => storage.toggleBoost(itemId);

  static Future<void> saveAccount(UserAccount account) =>
      storage.saveAccount(account);

  static Future<UserAccount> logout() => storage.logout();

  static Future<void> saveSettings(AppSettings settings) =>
      storage.saveSettings(settings);

  static Future<void> clearCart() => storage.clearCart();

  static Future<void> addNotification(AppNotification notif) =>
      storage.addNotification(notif);

  static Future<void> markAllNotificationsRead() =>
      storage.markAllNotificationsRead();

  static Future<ChatMessage> sendChatMessage(
    String peerUsername,
    String peerTitle,
    String text,
  ) =>
      storage.sendSellerMessage(peerUsername, peerTitle, text);

  static Future<List<String>> loadViewedIds() => storage.loadViewedIds();

  static Future<void> clearViewedHistory() => storage.clearViewedHistory();

  static Future<void> clearSearchHistory() => storage.clearSearchHistory();

  static Future<String> loadRegionCity() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_cityKey);
    if (saved != null && AppConfig.realCities.contains(saved)) return saved;
    return AppConfig.realCities.first;
  }

  static Future<void> saveRegionCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cityKey, city);
  }

  static String nowTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  static ThemeMode themeModeFromString(String mode) {
    switch (mode.toLowerCase()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static void applyTheme(ApexThemeController controller, AppSettings settings) {
    controller.setThemeMode(themeModeFromString(settings.themeMode));
    controller.setCompactGrid(settings.compactGrid);
  }
}

TextStyle _body(BuildContext context) =>
    bodyStyle(14, color: ApexPalette.of(context).text);

TextStyle _display(BuildContext context) =>
    displayStyle(20, color: ApexPalette.of(context).text);

TextStyle _mono(BuildContext context) =>
    monoStyle(14, color: ApexPalette.of(context).text);

// =============================================================================
// ОБЩИЕ UI-ПОМОЩНИКИ
// =============================================================================
class _SegmentBar extends StatelessWidget {
  const _SegmentBar({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.badges = const [0, 0],
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final List<int> badges;

  @override
  Widget build(BuildContext context) {
    final p = ApexPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i == selectedIndex;
          final badge = i < badges.length ? badges[i] : 0;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  color: active ? ApexPalette.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _body(context).copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white : p.muted,
                        ),
                      ),
                    ),
                    if (badge > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white.withOpacity(0.24)
                              : ApexPalette.accent.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badge > 99 ? '99+' : '$badge',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.white : ApexPalette.accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

InputDecoration _fieldDecoration(
  BuildContext context, {
  required String label,
  String? hint,
  Widget? prefixIcon,
}) {
  final p = ApexPalette.of(context);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: p.surfaceAlt,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: p.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: p.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: ApexPalette.accent, width: 1.6),
    ),
  );
}

Future<void> _openTelegramAuthSheet(
  BuildContext context, {
  required UserAccount currentAccount,
  required ValueChanged<UserAccount> onAuthorized,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TelegramAuthSheet(
      initialCity: currentAccount.city.isNotEmpty
          ? currentAccount.city
          : AppConfig.realCities.first,
      onAuthorized: onAuthorized,
    ),
  );
}

// =============================================================================
// 1. SELL TAB — ВКЛАДКА 3: ВЫЛОЖИТЬ ОБЪЯВЛЕНИЕ
// =============================================================================
class SellTab extends StatefulWidget {
  const SellTab({
    super.key,
    required this.account,
    required this.settings,
    required this.onAccountChanged,
    required this.onPublished,
  });

  final UserAccount account;
  final AppSettings settings;
  final ValueChanged<UserAccount> onAccountChanged;
  final Future<void> Function() onPublished;

  @override
  State<SellTab> createState() => _SellTabState();
}

class _SellTabState extends State<SellTab> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _oldPriceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _picker = ImagePicker();

  int _lotTypeIndex = 0; // 0: Б/у (Барахолка), 1: Новый (Маркет)
  late String _category;
  late String _city;
  bool _deliveryAvailable = true;
  int _conditionRating = 9;
  String? _photoPath;
  bool _analyzingAi = false;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _category = AppConfig.realCategories.first;
    _city = widget.account.city.isNotEmpty &&
            AppConfig.realCities.contains(widget.account.city)
        ? widget.account.city
        : AppConfig.realCities.first;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _oldPriceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _photoPath = picked.path);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось выбрать фотографию')),
        );
      }
    }
  }

  Future<void> _fillWithApexAi() async {
    if (_photoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала выберите фото товара')),
      );
      return;
    }
    setState(() => _analyzingAi = true);
    try {
      final data = await _AccountAdapter.analyzeItemPhoto(_photoPath!);
      if (!mounted) return;
      setState(() {
        final title = data['title']?.toString() ?? '';
        final cat = data['category']?.toString() ?? '';
        final price = data['price'];
        final oldPrice = data['oldPrice'];
        final desc = data['description']?.toString() ?? '';
        final cond = data['conditionScore'];

        if (title.isNotEmpty) _titleCtrl.text = title;
        if (AppConfig.realCategories.contains(cat)) _category = cat;
        if (price != null) _priceCtrl.text = price.toString();
        if (oldPrice != null && oldPrice.toString() != '0') {
          _oldPriceCtrl.text = oldPrice.toString();
        }
        if (desc.isNotEmpty) _descCtrl.text = desc;
        if (cond is num) _conditionRating = cond.round().clamp(1, 10);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('APEX AI заполнил карточку по фото')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка анализа фото через APEX AI')),
        );
      }
    } finally {
      if (mounted) setState(() => _analyzingAi = false);
    }
  }

  Future<void> _publish() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _publishing = true);
    try {
      final price = int.tryParse(_priceCtrl.text.trim()) ?? 0;
      final oldPrice = int.tryParse(_oldPriceCtrl.text.trim());
      final nowId = 'item_${DateTime.now().millisecondsSinceEpoch}';
      final isNew = _lotTypeIndex == 1;

      final item = MarketItem(
        id: nowId,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: price,
        oldPrice: (oldPrice != null && oldPrice > price) ? oldPrice : null,
        category: _category,
        city: _city,
        imagePath: _photoPath ?? '',
        isLocalImage: _photoPath != null && _photoPath!.isNotEmpty,
        isNew: isNew,
        hasDelivery: _deliveryAvailable,
        conditionScore: isNew ? 10.0 : _conditionRating.toDouble(),
        aiVerified: false,
        aiNote: '',
        isBoosted: false,
        sellerName: widget.account.name.isNotEmpty
            ? widget.account.name
            : 'Продавец APEX',
        sellerUsername: widget.account.cleanUsername.isNotEmpty
            ? widget.account.cleanUsername
            : 'apex_user',
        sellerPhone: '',
        sellerTgVerified: widget.account.tgVerified,
        createdAt: DateTime.now().toIso8601String(),
      );

      await _AccountAdapter.addItem(item);
      await _AccountAdapter.addNotification(
        AppNotification(
          id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          type: 'deal',
          title: 'Объявление опубликовано',
          body: '«${item.title}» за ${formatRub(item.price)} уже в ленте.',
          time: _AccountAdapter.nowTime(),
          isRead: false,
        ),
      );

      _titleCtrl.clear();
      _priceCtrl.clear();
      _oldPriceCtrl.clear();
      _descCtrl.clear();
      setState(() {
        _photoPath = null;
        _conditionRating = 9;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Объявление успешно опубликовано!')),
        );
      }
      await widget.onPublished();
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ApexPalette.of(context);

    if (!widget.account.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: Text('Выложить товар', style: _display(context))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: p.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: ApexPalette.accent.withOpacity(0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_business_rounded,
                        color: ApexPalette.accent, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Войдите, чтобы продавать',
                    textAlign: TextAlign.center,
                    style: _display(context).copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Мы проверяем продавцов через Telegram-бота, чтобы в APEX Market не было фейков и ботов.',
                    textAlign: TextAlign.center,
                    style: _body(context).copyWith(color: p.muted),
                  ),
                  const SizedBox(height: 20),
                  ApexPrimaryButton(
                    label: 'Войти через Telegram-бот',
                    icon: Icons.send_rounded,
                    onPressed: () => _openTelegramAuthSheet(
                      context,
                      currentAccount: widget.account,
                      onAuthorized: widget.onAccountChanged,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Новое объявление', style: _display(context)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
          children: [
            _SegmentBar(
              labels: const ['Б/у с рук (Барахолка)', 'Новый товар (Маркет)'],
              selectedIndex: _lotTypeIndex,
              onChanged: (i) => setState(() => _lotTypeIndex = i),
            ),
            const SizedBox(height: 16),

            // Блок фото + APEX AI
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: p.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 86,
                          height: 86,
                          color: p.surfaceAlt,
                          child: _photoPath != null
                              ? Image.file(File(_photoPath!), fit: BoxFit.cover)
                              : Icon(Icons.photo_camera_outlined,
                                  color: p.muted, size: 30),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ApexOutlineButton(
                              label: 'Камера',
                              icon: Icons.camera_alt_outlined,
                              onPressed: () => _pickPhoto(ImageSource.camera),
                            ),
                            const SizedBox(height: 8),
                            ApexOutlineButton(
                              label: 'Галерея',
                              icon: Icons.photo_library_outlined,
                              onPressed: () => _pickPhoto(ImageSource.gallery),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _analyzingAi ? null : _fillWithApexAi,
                      icon: _analyzingAi
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: Text(
                        _analyzingAi
                            ? 'APEX AI анализирует фото...'
                            : 'Заполнить через APEX AI',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _titleCtrl,
              decoration: _fieldDecoration(
                context,
                label: 'Название товара',
                hint: 'Например: iPhone 15 Pro 256GB Natural Titanium',
              ),
              validator: (v) => (v == null || v.trim().length < 3)
                  ? 'Введите название (минимум 3 символа)'
                  : null,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _fieldDecoration(
                      context,
                      label: 'Цена (₽)',
                      hint: '59990',
                    ),
                    validator: (v) {
                      final n = int.tryParse(v?.trim() ?? '');
                      if (n == null || n <= 0) return 'Укажите цену';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _oldPriceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _fieldDecoration(
                      context,
                      label: 'Старая цена (₽)',
                      hint: 'Необязательно',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _category,
              decoration: _fieldDecoration(context, label: 'Категория'),
              items: AppConfig.realCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: AppConfig.realCities.contains(_city)
                  ? _city
                  : AppConfig.realCities.first,
              decoration: _fieldDecoration(context, label: 'Город'),
              items: AppConfig.realCities
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _city = v);
              },
            ),
            const SizedBox(height: 12),

            if (_lotTypeIndex == 0) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Оценка состояния', style: _body(context)),
                        ApexPillBadge(label: '$_conditionRating / 10'),
                      ],
                    ),
                    Slider(
                      value: _conditionRating.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      onChanged: (v) =>
                          setState(() => _conditionRating = v.round()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            Container(
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.border),
              ),
              child: SwitchListTile(
                title: const Text('Отправлю доставкой'),
                subtitle: const Text('ПВЗ, СДЭК или курьер по РФ'),
                value: _deliveryAvailable,
                onChanged: (v) => setState(() => _deliveryAvailable = v),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: _fieldDecoration(
                context,
                label: 'Описание',
                hint: 'Комплект, состояние, причина продажи...',
              ),
              validator: (v) => (v == null || v.trim().length < 5)
                  ? 'Добавьте краткое описание'
                  : null,
            ),
            const SizedBox(height: 20),

            ApexPrimaryButton(
              label: _publishing
                  ? 'Публикуем...'
                  : 'Опубликовать объявление',
              icon: Icons.rocket_launch_rounded,
              onPressed: _publishing ? null : _publish,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 2. INBOX TAB — ВКЛАДКА 4: СООБЩЕНИЯ И УВЕДОМЛЕНИЯ
// =============================================================================
class InboxTab extends StatefulWidget {
  const InboxTab({
    super.key,
    required this.chats,
    required this.notifications,
    required this.account,
    required this.onRefresh,
  });

  final List<ChatMessage> chats;
  final List<AppNotification> notifications;
  final UserAccount account;
  final Future<void> Function() onRefresh;

  @override
  State<InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<InboxTab> {
  int _subTab = 0; // 0: Сообщения, 1: Уведомления

  int get _unreadChats => widget.chats.where((m) => !m.isMe).length;

  int get _unreadNotifs =>
      widget.notifications.where((n) => !n.isRead).length;

  Map<String, List<ChatMessage>> _groupDialogs() {
    final map = <String, List<ChatMessage>>{};
    for (final msg in widget.chats) {
      final key =
          msg.peerUsername.isNotEmpty ? msg.peerUsername : msg.peerTitle;
      map.putIfAbsent(key, () => []).add(msg);
    }
    return map;
  }

  void _openChatSheet(
    String peerUsername,
    String peerTitle,
    List<ChatMessage> initialMessages,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChatDialogSheet(
        peerUsername: peerUsername,
        peerTitle: peerTitle,
        messages: initialMessages,
        onSend: (text) async {
          await _AccountAdapter.sendChatMessage(peerUsername, peerTitle, text);
          await widget.onRefresh();
        },
      ),
    );
  }

  IconData _notifIcon(String type) {
    switch (type) {
      case 'deal':
        return Icons.verified_rounded;
      case 'message':
        return Icons.chat_bubble_rounded;
      case 'ai':
        return Icons.auto_awesome_rounded;
      case 'promo':
        return Icons.local_offer_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _notifColor(String type, ApexPalette p) {
    switch (type) {
      case 'deal':
        return ApexPalette.green;
      case 'message':
        return ApexPalette.accent;
      case 'ai':
        return const Color(0xFF8B5CF6);
      case 'promo':
        return ApexPalette.amber;
      default:
        return p.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ApexPalette.of(context);
    final dialogs = _groupDialogs();
    final peerKeys = dialogs.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Входящие', style: _display(context)),
        actions: [
          if (_subTab == 1 && _unreadNotifs > 0)
            TextButton(
              onPressed: () async {
                await _AccountAdapter.markAllNotificationsRead();
                await widget.onRefresh();
              },
              child: const Text('Прочитать все'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _SegmentBar(
              labels: const ['Сообщения', 'Уведомления'],
              badges: [_unreadChats, _unreadNotifs],
              selectedIndex: _subTab,
              onChanged: (i) => setState(() => _subTab = i),
            ),
          ),
          Expanded(
            child: _subTab == 0
                ? (peerKeys.isEmpty
                    ? Center(
                        child: Text(
                          'Диалогов пока нет',
                          style: _body(context).copyWith(color: p.muted),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: widget.onRefresh,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: peerKeys.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, idx) {
                            final peerKey = peerKeys[idx];
                            final msgs = dialogs[peerKey]!;
                            final last = msgs.last;
                            final displayPeer = last.peerTitle.isNotEmpty
                                ? last.peerTitle
                                : '@$peerKey';
                            final unread = msgs.where((m) => !m.isMe).length;

                            return InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () =>
                                  _openChatSheet(peerKey, displayPeer, msgs),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: p.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: p.border),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor:
                                          ApexPalette.accent.withOpacity(0.15),
                                      child: Text(
                                        displayPeer.isNotEmpty
                                            ? displayPeer[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: ApexPalette.accent,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  displayPeer,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style:
                                                      _body(context).copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              if (last.isAiGenerated) ...[
                                                const SizedBox(width: 6),
                                                const ApexPillBadge(
                                                    label: 'AI'),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            last.text,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: _body(context).copyWith(
                                              color: p.muted,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (unread > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: ApexPalette.accent,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '$unread',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ))
                : (widget.notifications.isEmpty
                    ? Center(
                        child: Text(
                          'Уведомлений пока нет',
                          style: _body(context).copyWith(color: p.muted),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: widget.onRefresh,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: widget.notifications.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, idx) {
                            final n = widget.notifications[idx];
                            final color = _notifColor(n.type, p);
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: p.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: n.isRead
                                      ? p.border
                                      : ApexPalette.accent.withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(_notifIcon(n.type),
                                        color: color, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          n.title,
                                          style: _body(context).copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          n.body,
                                          style: _body(context).copyWith(
                                            color: p.muted,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      )),
          ),
        ],
      ),
    );
  }
}

class _ChatDialogSheet extends StatefulWidget {
  const _ChatDialogSheet({
    required this.peerUsername,
    required this.peerTitle,
    required this.messages,
    required this.onSend,
  });

  final String peerUsername;
  final String peerTitle;
  final List<ChatMessage> messages;
  final Future<void> Function(String text) onSend;

  @override
  State<_ChatDialogSheet> createState() => _ChatDialogSheetState();
}

class _ChatDialogSheetState extends State<_ChatDialogSheet> {
  final _ctrl = TextEditingController();
  late List<ChatMessage> _localMessages;

  @override
  void initState() {
    super.initState();
    _localMessages = List<ChatMessage>.from(widget.messages);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    setState(() {
      _localMessages.add(
        ChatMessage(
          id: 'local_${DateTime.now().millisecondsSinceEpoch}',
          peerUsername: widget.peerUsername,
          peerTitle: widget.peerTitle,
          text: text,
          isMe: true,
          isAiGenerated: false,
          time: _AccountAdapter.nowTime(),
        ),
      );
    });
    await widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final p = ApexPalette.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: p.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.peerTitle,
                    style: _display(context).copyWith(fontSize: 18),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _localMessages.length,
              itemBuilder: (_, i) {
                final m = _localMessages[i];
                return Align(
                  alignment:
                      m.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: m.isMe ? ApexPalette.accent : p.surfaceAlt,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (m.isAiGenerated)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'APEX AI',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: m.isMe
                                    ? Colors.white70
                                    : ApexPalette.accent,
                              ),
                            ),
                          ),
                        Text(
                          m.text,
                          style: _body(context).copyWith(
                            color: m.isMe ? Colors.white : p.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSend(),
                      decoration: _fieldDecoration(
                        context,
                        label: 'Сообщение...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _handleSend,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 3. CART TAB — ВКЛАДКА 5: КОРЗИНА И ИЗБРАННОЕ
// =============================================================================
class CartTab extends StatefulWidget {
  const CartTab({
    super.key,
    required this.items,
    required this.cart,
    required this.favorites,
    required this.account,
    required this.onToggleCart,
    required this.onToggleFavorite,
    required this.onOpenItem,
    required this.onOrderCompleted,
  });

  final List<MarketItem> items;
  final Set<String> cart;
  final Set<String> favorites;
  final UserAccount account;
  final Future<void> Function(String itemId) onToggleCart;
  final Future<void> Function(String itemId) onToggleFavorite;
  final void Function(MarketItem item) onOpenItem;
  final Future<void> Function() onOrderCompleted;

  @override
  State<CartTab> createState() => _CartTabState();
}

class _CartTabState extends State<CartTab> {
  int _subTab = 0; // 0: Корзина, 1: Избранное
  int _deliveryIndex = 0; // 0: ПВЗ 149, 1: СДЭК 249, 2: Курьер 399
  bool _safeDeal = true;

  static const _deliveryNames = ['ПВЗ', 'СДЭК', 'Курьер'];
  static const _deliveryPrices = [149, 249, 399];

  Future<void> _checkout(List<MarketItem> cartItems, int total) async {
    await _AccountAdapter.clearCart();
    await _AccountAdapter.addNotification(
      AppNotification(
        id: 'order_${DateTime.now().millisecondsSinceEpoch}',
        type: 'deal',
        title: 'Заказ оформлен',
        body:
            'Оплачено ${formatRub(total)} (${cartItems.length} шт., ${_deliveryNames[_deliveryIndex]}).',
        time: _AccountAdapter.nowTime(),
        isRead: false,
      ),
    );
    await widget.onOrderCompleted();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: ApexPalette.green),
            SizedBox(width: 8),
            Text('Заказ оформлен!'),
          ],
        ),
        content: Text(
          'Сумма: ${formatRub(total)}\n'
          'Доставка: ${_deliveryNames[_deliveryIndex]}\n'
          '${_safeDeal ? 'Средства защищены APEX Гарантом до получения.' : 'Прямая оплата продавцу.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отлично'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = ApexPalette.of(context);
    final cartItems =
        widget.items.where((e) => widget.cart.contains(e.id)).toList();
    final favItems =
        widget.items.where((e) => widget.favorites.contains(e.id)).toList();

    final subtotal = cartItems.fold<int>(0, (sum, e) => sum + e.price);
    final deliveryCost = cartItems.isEmpty ? 0 : _deliveryPrices[_deliveryIndex];
    final escrowFee =
        (_safeDeal && cartItems.isNotEmpty) ? (subtotal * 0.04).round() : 0;
    final total = subtotal + deliveryCost + escrowFee;

    return Scaffold(
      appBar: AppBar(
        title: Text('Покупки', style: _display(context)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _SegmentBar(
              labels: const ['Корзина', 'Избранное'],
              badges: [cartItems.length, favItems.length],
              selectedIndex: _subTab,
              onChanged: (i) => setState(() => _subTab = i),
            ),
          ),
          Expanded(
            child: _subTab == 0
                ? (cartItems.isEmpty
                    ? Center(
                        child: Text(
                          'Корзина пуста',
                          style: _body(context).copyWith(color: p.muted),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                        children: [
                          ...cartItems.map((item) => Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: p.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: p.border),
                                ),
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => widget.onOpenItem(item),
                                      child: SizedBox(
                                        width: 66,
                                        height: 66,
                                        child: ItemThumb(source: item.imagePath),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: _body(context).copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            formatRub(item.price),
                                            style: _mono(context).copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: ApexPalette.accent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          widget.onToggleCart(item.id),
                                      icon: const Icon(
                                          Icons.delete_outline_rounded),
                                    ),
                                  ],
                                ),
                              )),
                          const SizedBox(height: 8),
                          Text('Способ доставки',
                              style: _body(context)
                                  .copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Row(
                            children: List.generate(3, (i) {
                              final selected = _deliveryIndex == i;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () =>
                                        setState(() => _deliveryIndex = i),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10, horizontal: 6),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? ApexPalette.accent
                                                .withOpacity(0.14)
                                            : p.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: selected
                                              ? ApexPalette.accent
                                              : p.border,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            _deliveryNames[i],
                                            style: _body(context).copyWith(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            formatRub(_deliveryPrices[i]),
                                            style: _mono(context).copyWith(
                                              fontSize: 12,
                                              color: p.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: p.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: p.border),
                            ),
                            child: SwitchListTile(
                              title:
                                  const Text('Безопасная сделка (Гарант +4%)'),
                              subtitle: const Text(
                                  'Деньги хранятся в Гаранте до проверки товара'),
                              value: _safeDeal,
                              onChanged: (v) => setState(() => _safeDeal = v),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: p.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: p.border),
                            ),
                            child: Column(
                              children: [
                                _SummaryRow('Товары', formatRub(subtotal)),
                                const SizedBox(height: 6),
                                _SummaryRow(
                                    'Доставка (${_deliveryNames[_deliveryIndex]})',
                                    formatRub(deliveryCost)),
                                if (_safeDeal) ...[
                                  const SizedBox(height: 6),
                                  _SummaryRow(
                                      'Гарант (+4%)', formatRub(escrowFee)),
                                ],
                                const Divider(height: 20),
                                _SummaryRow(
                                  'Итого',
                                  formatRub(total),
                                  bold: true,
                                ),
                                const SizedBox(height: 16),
                                ApexPrimaryButton(
                                  label: 'Оформить заказ · ${formatRub(total)}',
                                  icon: Icons.shopping_bag_rounded,
                                  onPressed: () => _checkout(cartItems, total),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ))
                : (favItems.isEmpty
                    ? Center(
                        child: Text(
                          'В избранном пока пусто',
                          style: _body(context).copyWith(color: p.muted),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.74,
                        ),
                        itemCount: favItems.length,
                        itemBuilder: (_, idx) {
                          final item = favItems[idx];
                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => widget.onOpenItem(item),
                            child: Container(
                              decoration: BoxDecoration(
                                color: p.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: p.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                            top: Radius.circular(16),
                                          ),
                                          child:
                                              ItemThumb(source: item.imagePath),
                                        ),
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: CircleAvatar(
                                            radius: 16,
                                            backgroundColor:
                                                Colors.black.withOpacity(0.5),
                                            child: IconButton(
                                              padding: EdgeInsets.zero,
                                              iconSize: 18,
                                              icon: const Icon(
                                                Icons.favorite_rounded,
                                                color: Color(0xFFFF3B5C),
                                              ),
                                              onPressed: () => widget
                                                  .onToggleFavorite(item.id),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          formatRub(item.price),
                                          style: _mono(context).copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: _body(context)
                                              .copyWith(fontSize: 12.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      )),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? _display(context).copyWith(fontSize: 17)
        : _body(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}

// =============================================================================
// 4. PROFILE TAB — ВКЛАДКА 6: ПРОФИЛЬ, TELEGRAM-АВТОРИЗАЦИЯ И НАСТРОЙКИ
// =============================================================================
class ProfileTab extends StatefulWidget {
  const ProfileTab({
    super.key,
    required this.account,
    required this.items,
    required this.settings,
    required this.themeController,
    required this.onAccountChanged,
    required this.onSettingsChanged,
    required this.onOpenItem,
    required this.onRefresh,
  });

  final UserAccount account;
  final List<MarketItem> items;
  final AppSettings settings;
  final ApexThemeController themeController;
  final ValueChanged<UserAccount> onAccountChanged;
  final ValueChanged<AppSettings> onSettingsChanged;
  final void Function(MarketItem item) onOpenItem;
  final Future<void> Function() onRefresh;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  List<String> _viewedIds = const [];

  @override
  void initState() {
    super.initState();
    _loadViewed();
  }

  Future<void> _loadViewed() async {
    final ids = await _AccountAdapter.loadViewedIds();
    if (mounted) setState(() => _viewedIds = ids);
  }

  void _openSettings() {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => SettingsScreen(
              account: widget.account,
              settings: widget.settings,
              themeController: widget.themeController,
              onAccountChanged: widget.onAccountChanged,
              onSettingsChanged: widget.onSettingsChanged,
            ),
          ),
        )
        .then((_) => _loadViewed());
  }

  Future<void> _topUpDemo() async {
    final updated = widget.account.copyWith(
      walletBalance: widget.account.walletBalance + 1000,
    );
    await _AccountAdapter.saveAccount(updated);
    widget.onAccountChanged(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Кошелёк пополнен на +1 000 ₽ (демо)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ApexPalette.of(context);

    if (!widget.account.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: const ApexBrandLogo(),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: _openSettings,
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: p.border),
                  ),
                  child: Column(
                    children: [
                      const ApexBrandLogo(),
                      const SizedBox(height: 16),
                      Text(
                        'Безопасный вход через Telegram',
                        textAlign: TextAlign.center,
                        style: _display(context).copyWith(fontSize: 21),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Без SMS-спама и фейковых аккаунтов. Одноразовый код от бота @${AppConfig.authBotUsername} защищает сделки и кошелёк.',
                        textAlign: TextAlign.center,
                        style: _body(context).copyWith(color: p.muted),
                      ),
                      const SizedBox(height: 22),
                      ApexPrimaryButton(
                        label: 'Войти через Telegram',
                        icon: Icons.send_rounded,
                        onPressed: () => _openTelegramAuthSheet(
                          context,
                          currentAccount: widget.account,
                          onAuthorized: widget.onAccountChanged,
                        ),
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

    final myUser = widget.account.cleanUsername.toLowerCase();
    final myItems = myUser.isEmpty
        ? const <MarketItem>[]
        : widget.items
            .where((e) => e.cleanUsername.toLowerCase() == myUser)
            .toList();
    final viewedItems = widget.items
        .where((e) => _viewedIds.contains(e.id))
        .take(10)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Профиль', style: _display(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await widget.onRefresh();
          await _loadViewed();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // Шапка профиля
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: ApexPalette.accent,
                    child: Text(
                      widget.account.name.isNotEmpty
                          ? widget.account.name[0].toUpperCase()
                          : 'A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.account.name,
                          style: _display(context).copyWith(fontSize: 18),
                        ),
                        Text(
                          '@${widget.account.cleanUsername} · ${widget.account.city}',
                          style: _body(context)
                              .copyWith(color: p.muted, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: ApexPalette.green.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Telegram подтверждён',
                                style: TextStyle(
                                  color: ApexPalette.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.star_rounded,
                                color: ApexPalette.amber, size: 16),
                            const SizedBox(width: 2),
                            const Text('5.0',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // APEX Кошелёк
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: ApexPalette.accentGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'APEX Кошелёк',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatRub(widget.account.walletBalance),
                        style: _mono(context).copyWith(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: ApexPalette.accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _topUpDemo,
                        child: const Text('Пополнить',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Заморожено в Гаранте: ${formatRub(widget.account.frozenBalance)}',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Вы смотрели
            if (viewedItems.isNotEmpty) ...[
              Text('Вы смотрели',
                  style: _display(context).copyWith(fontSize: 17)),
              const SizedBox(height: 10),
              SizedBox(
                height: 148,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: viewedItems.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, idx) {
                    final item = viewedItems[idx];
                    return GestureDetector(
                      onTap: () => widget.onOpenItem(item),
                      child: Container(
                        width: 120,
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: p.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(14)),
                                child: ItemThumb(source: item.imagePath),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    formatRub(item.price),
                                    style: _mono(context).copyWith(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _body(context)
                                        .copyWith(fontSize: 11.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Мои объявления
            Text('Мои объявления (${myItems.length})',
                style: _display(context).copyWith(fontSize: 17)),
            const SizedBox(height: 10),
            if (myItems.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.border),
                ),
                child: Text(
                  'У вас пока нет активных объявлений. Нажмите «+» внизу, чтобы разместить первый товар.',
                  style: _body(context).copyWith(color: p.muted),
                ),
              )
            else
              ...myItems.map((item) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: p.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 58,
                              height: 58,
                              child: ItemThumb(source: item.imagePath),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _body(context)
                                        .copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    formatRub(item.price),
                                    style: _mono(context)
                                        .copyWith(color: ApexPalette.accent),
                                  ),
                                ],
                              ),
                            ),
                            if (item.isBoosted)
                              const ApexPillBadge(label: 'ТОП'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await _AccountAdapter.toggleBoost(item.id);
                                  await widget.onRefresh();
                                },
                                icon: const Icon(Icons.bolt_rounded, size: 18),
                                label: Text(item.isBoosted
                                    ? 'В топе'
                                    : 'Буст в топ (39 ₽)'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              color: Colors.redAccent,
                              onPressed: () async {
                                await _AccountAdapter.deleteItem(item.id);
                                await widget.onRefresh();
                              },
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// TELEGRAM AUTH SHEET — ВХОД ЧЕРЕЗ TELEGRAM-БОТА
// =============================================================================
class TelegramAuthSheet extends StatefulWidget {
  const TelegramAuthSheet({
    super.key,
    required this.initialCity,
    required this.onAuthorized,
  });

  final String initialCity;
  final ValueChanged<UserAccount> onAuthorized;

  @override
  State<TelegramAuthSheet> createState() => _TelegramAuthSheetState();
}

class _TelegramAuthSheetState extends State<TelegramAuthSheet> {
  final _tgCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  late String _city;
  late String _generatedCode;
  int _step = 1;

  @override
  void initState() {
    super.initState();
    _city = AppConfig.realCities.contains(widget.initialCity)
        ? widget.initialCity
        : AppConfig.realCities.first;
    _generatedCode = (1000 + Random().nextInt(9000)).toString();
  }

  @override
  void dispose() {
    _tgCtrl.dispose();
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _openBot() async {
    final uri = Uri.parse(
      'https://t.me/${AppConfig.authBotUsername}?start=auth_$_generatedCode',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (mounted) setState(() => _step = 2);
  }

  Future<void> _completeAuth() async {
    if (_codeCtrl.text.trim() != _generatedCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Неверный код. Тестовый код: $_generatedCode'),
        ),
      );
      return;
    }
    final cleanUsername = _tgCtrl.text.trim().replaceFirst('@', '');
    final account = UserAccount(
      isLoggedIn: true,
      tgVerified: true,
      name: _nameCtrl.text.trim().isNotEmpty
          ? _nameCtrl.text.trim()
          : (cleanUsername.isNotEmpty ? cleanUsername : 'Пользователь APEX'),
      username: cleanUsername.isNotEmpty ? cleanUsername : 'apex_user',
      city: _city,
      walletBalance: 5000,
      frozenBalance: 0,
    );
    await _AccountAdapter.saveAccount(account);
    widget.onAuthorized(account);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = ApexPalette.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, bottomInset + 24),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _step == 1
                  ? 'Шаг 1 · Вход через Telegram'
                  : 'Шаг 2 · Подтверждение',
              style: _display(context).copyWith(fontSize: 20),
            ),
            const SizedBox(height: 12),
            if (_step == 1) ...[
              TextField(
                controller: _tgCtrl,
                decoration: _fieldDecoration(
                  context,
                  label: 'Ваш @username в Telegram',
                  hint: '@username',
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ApexPalette.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ApexPalette.accent.withOpacity(0.3)),
                ),
                child: Text(
                  'Демо-режим (бот скоро): ваш тестовый код — $_generatedCode',
                  style: _body(context).copyWith(
                    color: ApexPalette.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ApexPrimaryButton(
                label: 'Открыть @${AppConfig.authBotUsername}',
                icon: Icons.send_rounded,
                onPressed: _openBot,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _step = 2),
                child: const Text('У меня уже есть код →'),
              ),
            ] else ...[
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: _fieldDecoration(
                  context,
                  label: '4-значный код из бота',
                  hint: _generatedCode,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                decoration: _fieldDecoration(
                  context,
                  label: 'Ваше имя',
                  hint: 'Алексей',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _city,
                decoration: _fieldDecoration(context, label: 'Город'),
                items: AppConfig.realCities
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _city = v);
                },
              ),
              const SizedBox(height: 18),
              ApexPrimaryButton(
                label: 'Подтвердить и войти',
                icon: Icons.verified_user_rounded,
                onPressed: _completeAuth,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SETTINGS SCREEN — ПОЛНЫЕ НАСТРОЙКИ ПРИЛОЖЕНИЯ
// =============================================================================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.account,
    required this.settings,
    required this.themeController,
    required this.onAccountChanged,
    required this.onSettingsChanged,
  });

  final UserAccount account;
  final AppSettings settings;
  final ApexThemeController themeController;
  final ValueChanged<UserAccount> onAccountChanged;
  final ValueChanged<AppSettings> onSettingsChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _s;
  late TextEditingController _apiKeyCtrl;
  String _selectedCity = AppConfig.realCities.first;

  @override
  void initState() {
    super.initState();
    _s = widget.settings;
    _apiKeyCtrl = TextEditingController(text: _s.customGeminiApiKey);
    _AccountAdapter.loadRegionCity().then((city) {
      if (mounted) setState(() => _selectedCity = city);
    });
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _update(AppSettings next) async {
    setState(() => _s = next);
    await _AccountAdapter.saveSettings(next);
    widget.onSettingsChanged(next);
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(
          text,
          style: _display(context).copyWith(fontSize: 15),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = ApexPalette.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Настройки', style: _display(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _sectionTitle('Тема оформления'),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border),
            ),
            child: Row(
              children: [
                _ThemeChip(
                  label: 'Тёмная',
                  selected: _s.themeMode == 'dark',
                  onTap: () {
                    final next = _s.copyWith(themeMode: 'dark');
                    _AccountAdapter.applyTheme(widget.themeController, next);
                    _update(next);
                  },
                ),
                _ThemeChip(
                  label: 'Светлая',
                  selected: _s.themeMode == 'light',
                  onTap: () {
                    final next = _s.copyWith(themeMode: 'light');
                    _AccountAdapter.applyTheme(widget.themeController, next);
                    _update(next);
                  },
                ),
                _ThemeChip(
                  label: 'Система',
                  selected: _s.themeMode == 'system',
                  onTap: () {
                    final next = _s.copyWith(themeMode: 'system');
                    _AccountAdapter.applyTheme(widget.themeController, next);
                    _update(next);
                  },
                ),
              ],
            ),
          ),

          _sectionTitle('Лента и регион'),
          Container(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Компактная сетка карточек'),
                  value: _s.compactGrid,
                  onChanged: (v) {
                    widget.themeController.setCompactGrid(v);
                    _update(_s.copyWith(compactGrid: v));
                  },
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: DropdownButtonFormField<String>(
                    value: AppConfig.realCities.contains(_selectedCity)
                        ? _selectedCity
                        : AppConfig.realCities.first,
                    decoration:
                        _fieldDecoration(context, label: 'Регион поиска'),
                    items: AppConfig.realCities
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _selectedCity = v);
                      _AccountAdapter.saveRegionCity(v);
                    },
                  ),
                ),
              ],
            ),
          ),

          _sectionTitle('APEX AI и Нейросеть'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border),
            ),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: AppConfig.availableAiModels
                          .contains(_s.selectedAiModel)
                      ? _s.selectedAiModel
                      : AppConfig.availableAiModels.first,
                  decoration: _fieldDecoration(context, label: 'Модель AI'),
                  items: AppConfig.availableAiModels
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) _update(_s.copyWith(selectedAiModel: v));
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKeyCtrl,
                  decoration: _fieldDecoration(
                    context,
                    label: 'Свой Gemini API-ключ (бесплатный)',
                    hint: 'AIza...',
                  ),
                ),
                const SizedBox(height: 10),
                ApexOutlineButton(
                  label: 'Сохранить ключ',
                  icon: Icons.key_rounded,
                  onPressed: () async {
                    await _update(
                      _s.copyWith(customGeminiApiKey: _apiKeyCtrl.text.trim()),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('API-ключ сохранён')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          _sectionTitle('Уведомления и Приватность'),
          Container(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Сообщения в чатах'),
                  value: _s.notifyMessages,
                  onChanged: (v) => _update(_s.copyWith(notifyMessages: v)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Статусы сделок и Гаранта'),
                  value: _s.notifyDeals,
                  onChanged: (v) => _update(_s.copyWith(notifyDeals: v)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Снижение цен в избранном'),
                  value: _s.notifyPriceDrop,
                  onChanged: (v) => _update(_s.copyWith(notifyPriceDrop: v)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Скрыть номер телефона'),
                  subtitle: const Text('Показывать только Telegram'),
                  value: _s.hidePhoneShowTgOnly,
                  onChanged: (v) =>
                      _update(_s.copyWith(hidePhoneShowTgOnly: v)),
                ),
              ],
            ),
          ),

          _sectionTitle('Данные и Поддержка'),
          Container(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.visibility_off_outlined),
                  title: const Text('Очистить историю просмотров'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    await _AccountAdapter.clearViewedHistory();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('История просмотров очищена')),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.history_toggle_off_rounded),
                  title: const Text('Очистить историю поиска'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    await _AccountAdapter.clearSearchHistory();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('История поиска очищена')),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.support_agent_rounded),
                  title: const Text('Написать в поддержку Telegram'),
                  subtitle: Text(
                    AppConfig.supportBotLink,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () async {
                    final ok = await launchUrl(
                      Uri.parse(AppConfig.supportBotLink),
                      mode: LaunchMode.externalApplication,
                    );
                    if (!ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Не удалось открыть Telegram')),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.gavel_rounded),
                  title: const Text('Правила APEX Market'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Правила APEX Market'),
                      content: const SingleChildScrollView(
                        child: Text(
                          '1. Публикуйте только реальные товары с достоверными фото.\n\n'
                          '2. Верификация через Telegram защищает площадку от ботов.\n\n'
                          '3. В Безопасной сделке средства хранятся в Гаранте до получения товара.\n\n'
                          '4. Запрещён спам и публикация запрещённых товаров.',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Понятно'),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('О приложении'),
                  subtitle: Text('Версия ${AppConfig.appVersion}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('APEX Market'),
                      content: Text(
                        'Версия: ${AppConfig.appVersion}\n\n'
                        'Маркетплейс и барахолка с AI-помощником APEX AI, '
                        'Telegram-верификацией и безопасными сделками.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Закрыть'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (widget.account.isLoggedIn) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text(
                  'Выйти из аккаунта',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Выйти из аккаунта?'),
                      content: const Text(
                        'Вы сможете снова войти в любой момент через Telegram-бота.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Отмена'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                          ),
                          child: const Text('Выйти'),
                        ),
                      ],
                    ),
                  );
                  if (confirm != true) return;
                  final guest = await _AccountAdapter.logout();
                  widget.onAccountChanged(guest);
                  if (mounted) Navigator.pop(context);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = ApexPalette.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? ApexPalette.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: _body(context).copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: selected ? Colors.white : p.muted,
            ),
          ),
        ),
      ),
    );
  }
}

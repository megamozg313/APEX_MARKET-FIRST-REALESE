import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

// =============================================================================
// Безопасные парсеры JSON-значений
// =============================================================================

int _asInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is bool) return value ? 1 : 0;
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }
  return null;
}

double _asDouble(dynamic value, [double fallback = 0.0]) {
  if (value == null) return fallback;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) {
    final String normalized = value.trim().replaceAll(',', '.');
    return double.tryParse(normalized) ?? fallback;
  }
  return fallback;
}

bool _asBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final String normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes' || normalized == 'да') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no' || normalized == 'нет') {
      return false;
    }
  }
  return fallback;
}

String _asString(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    final Map<String, dynamic> result = <String, dynamic>{};
    value.forEach((dynamic key, dynamic val) {
      result[key.toString()] = val;
    });
    return result;
  }
  return <String, dynamic>{};
}
  

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is List) {
    return value.map((dynamic e) => _asMap(e)).toList();
  }
  return <Map<String, dynamic>>[];
}

String _nowIso() => DateTime.now().toIso8601String();

String _nowTimeLabel() {
  final DateTime now = DateTime.now();
  final String hh = now.hour.toString().padLeft(2, '0');
  final String mm = now.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

String _formatRub(int amount) {
  final String digits = amount.abs().toString();
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return '${amount < 0 ? '-' : ''}$buffer ₽';
}

// =============================================================================
// MarketItem — товар каталога
// =============================================================================

class MarketItem {
  final String id;
  final String title;
  final String description;
  final int price;
  final int? oldPrice;
  final String category;
  final String city;
  final String imagePath;
  final bool isLocalImage;
  final bool isNew;
  final bool hasDelivery;
  final double conditionScore;
  final bool aiVerified;
  final String aiNote;
  final bool isBoosted;
  final String sellerName;
  final String sellerUsername;
  final String sellerPhone;
  final bool sellerTgVerified;
  final String createdAt;

  const MarketItem({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.oldPrice,
    required this.category,
    required this.city,
    required this.imagePath,
    this.isLocalImage = false,
    this.isNew = false,
    this.hasDelivery = false,
    this.conditionScore = 0.0,
    this.aiVerified = false,
    this.aiNote = '',
    this.isBoosted = false,
    required this.sellerName,
    required this.sellerUsername,
    required this.sellerPhone,
    this.sellerTgVerified = false,
    required this.createdAt,
  });

  MarketItem copyWith({
    String? id,
    String? title,
    String? description,
    int? price,
    int? oldPrice,
    bool clearOldPrice = false,
    String? category,
    String? city,
    String? imagePath,
    bool? isLocalImage,
    bool? isNew,
    bool? hasDelivery,
    double? conditionScore,
    bool? aiVerified,
    String? aiNote,
    bool? isBoosted,
    String? sellerName,
    String? sellerUsername,
    String? sellerPhone,
    bool? sellerTgVerified,
    String? createdAt,
  }) {
    return MarketItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      oldPrice: clearOldPrice ? null : (oldPrice ?? this.oldPrice),
      category: category ?? this.category,
      city: city ?? this.city,
      imagePath: imagePath ?? this.imagePath,
      isLocalImage: isLocalImage ?? this.isLocalImage,
      isNew: isNew ?? this.isNew,
      hasDelivery: hasDelivery ?? this.hasDelivery,
      conditionScore: conditionScore ?? this.conditionScore,
      aiVerified: aiVerified ?? this.aiVerified,
      aiNote: aiNote ?? this.aiNote,
      isBoosted: isBoosted ?? this.isBoosted,
      sellerName: sellerName ?? this.sellerName,
      sellerUsername: sellerUsername ?? this.sellerUsername,
      sellerPhone: sellerPhone ?? this.sellerPhone,
      sellerTgVerified: sellerTgVerified ?? this.sellerTgVerified,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Скидка в процентах (0, если старой цены нет).
  int get discountPercent {
    final int? old = oldPrice;
    if (old == null || old <= price) return 0;
    return (((old - price) / old) * 100).round();
  }

  /// Цена с учётом Гаранта 4%.
  int get priceWithGarant {
    final int fee = (price * AppConfig.garantFeePercent / 100).round();
    final int clamped = fee < AppConfig.garantMinDealRub ? fee : fee;
    return price + (clamped <= 0 ? 1 : clamped);
  }

  /// Юзернейм без ведущей "@".
  String get cleanUsername =>
      sellerUsername.startsWith('@') ? sellerUsername.substring(1) : sellerUsername;

  /// Строка для AI-контекста.
  String toAiLine() {
    return '$id | $title | $category | $city | $price ₽ | '
        'состояние ${conditionScore.toStringAsFixed(1)}/10 | '
        '@$cleanUsername | верифицирован ${sellerTgVerified ? "да" : "нет"}';
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'oldPrice': oldPrice,
      'category': category,
      'city': city,
      'imagePath': imagePath,
      'isLocalImage': isLocalImage,
      'isNew': isNew,
      'hasDelivery': hasDelivery,
      'conditionScore': conditionScore,
      'aiVerified': aiVerified,
      'aiNote': aiNote,
      'isBoosted': isBoosted,
      'sellerName': sellerName,
      'sellerUsername': sellerUsername,
      'sellerPhone': sellerPhone,
      'sellerTgVerified': sellerTgVerified,
      'createdAt': createdAt,
    };
  }

  factory MarketItem.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> data = _asMap(json);
    return MarketItem(
      id: _asString(data['id']),
      title: _asString(data['title']),
      description: _asString(data['description']),
      price: _asInt(data['price']),
      oldPrice: _asNullableInt(data['oldPrice']),
      category: _asString(data['category'], AppConfig.categories.first),
      city: _asString(data['city']),
      imagePath: _asString(data['imagePath']),
      isLocalImage: _asBool(data['isLocalImage']),
      isNew: _asBool(data['isNew']),
      hasDelivery: _asBool(data['hasDelivery']),
      conditionScore: _asDouble(data['conditionScore']),
      aiVerified: _asBool(data['aiVerified']),
      aiNote: _asString(data['aiNote']),
      isBoosted: _asBool(data['isBoosted']),
      sellerName: _asString(data['sellerName']),
      sellerUsername: _asString(data['sellerUsername']),
      sellerPhone: _asString(data['sellerPhone']),
      sellerTgVerified: _asBool(data['sellerTgVerified']),
      createdAt: _asString(data['createdAt'], _nowIso()),
    );
  }
}

// =============================================================================
// UserAccount — аккаунт пользователя
// =============================================================================

class UserAccount {
  final bool isLoggedIn;
  final String name;
  final String username;
  final String city;
  final bool tgVerified;
  final int walletBalance;
  final int frozenBalance;
  final double rating;
  final int dealsCount;

  const UserAccount({
    this.isLoggedIn = false,
    this.name = '',
    this.username = '',
    this.city = '',
    this.tgVerified = false,
    this.walletBalance = 0,
    this.frozenBalance = 0,
    this.rating = 0.0,
    this.dealsCount = 0,
  });

  /// Гостевой (неавторизованный) аккаунт.
  const UserAccount.guest()
      : isLoggedIn = false,
        name = '',
        username = '',
        city = '',
        tgVerified = false,
        walletBalance = 0,
        frozenBalance = 0,
        rating = 0.0,
        dealsCount = 0;

  String get displayName => name.isEmpty ? 'Гость APEX' : name;

  String get cleanUsername =>
      username.startsWith('@') ? username.substring(1) : username;

  int get totalBalance => walletBalance + frozenBalance;

  UserAccount copyWith({
    bool? isLoggedIn,
    String? name,
    String? username,
    String? city,
    bool? tgVerified,
    int? walletBalance,
    int? frozenBalance,
    double? rating,
    int? dealsCount,
  }) {
    return UserAccount(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      name: name ?? this.name,
      username: username ?? this.username,
      city: city ?? this.city,
      tgVerified: tgVerified ?? this.tgVerified,
      walletBalance: walletBalance ?? this.walletBalance,
      frozenBalance: frozenBalance ?? this.frozenBalance,
      rating: rating ?? this.rating,
      dealsCount: dealsCount ?? this.dealsCount,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'isLoggedIn': isLoggedIn,
      'name': name,
      'username': username,
      'city': city,
      'tgVerified': tgVerified,
      'walletBalance': walletBalance,
      'frozenBalance': frozenBalance,
      'rating': rating,
      'dealsCount': dealsCount,
    };
  }

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> data = _asMap(json);
    return UserAccount(
      isLoggedIn: _asBool(data['isLoggedIn']),
      name: _asString(data['name']),
      username: _asString(data['username']),
      city: _asString(data['city']),
      tgVerified: _asBool(data['tgVerified']),
      walletBalance: _asInt(data['walletBalance']),
      frozenBalance: _asInt(data['frozenBalance']),
      rating: _asDouble(data['rating']),
      dealsCount: _asInt(data['dealsCount']),
    );
  }
}

// =============================================================================
// AppSettings — настройки приложения
// =============================================================================

class AppSettings {
  final String themeMode; // 'dark' | 'light' | 'system'
  final bool compactGrid;
  final bool notifyMessages;
  final bool notifyDeals;
  final bool notifyPriceDrop;
  final bool hidePhoneShowTgOnly;
  final String selectedAiModel;
  final String customGeminiApiKey;

  const AppSettings({
    this.themeMode = 'dark',
    this.compactGrid = false,
    this.notifyMessages = true,
    this.notifyDeals = true,
    this.notifyPriceDrop = true,
    this.hidePhoneShowTgOnly = false,
    this.selectedAiModel = AppConfig.defaultAiModel,
    this.customGeminiApiKey = '',
  });

  bool get isDark => themeMode == 'dark';
  bool get isLight => themeMode == 'light';
  bool get isSystem => themeMode == 'system';
  bool get hasCustomApiKey => customGeminiApiKey.trim().isNotEmpty;

  AppSettings copyWith({
    String? themeMode,
    bool? compactGrid,
    bool? notifyMessages,
    bool? notifyDeals,
    bool? notifyPriceDrop,
    bool? hidePhoneShowTgOnly,
    String? selectedAiModel,
    String? customGeminiApiKey,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      compactGrid: compactGrid ?? this.compactGrid,
      notifyMessages: notifyMessages ?? this.notifyMessages,
      notifyDeals: notifyDeals ?? this.notifyDeals,
      notifyPriceDrop: notifyPriceDrop ?? this.notifyPriceDrop,
      hidePhoneShowTgOnly: hidePhoneShowTgOnly ?? this.hidePhoneShowTgOnly,
      selectedAiModel: selectedAiModel ?? this.selectedAiModel,
      customGeminiApiKey: customGeminiApiKey ?? this.customGeminiApiKey,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'themeMode': themeMode,
      'compactGrid': compactGrid,
      'notifyMessages': notifyMessages,
      'notifyDeals': notifyDeals,
      'notifyPriceDrop': notifyPriceDrop,
      'hidePhoneShowTgOnly': hidePhoneShowTgOnly,
      'selectedAiModel': selectedAiModel,
      'customGeminiApiKey': customGeminiApiKey,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> data = _asMap(json);
    final String model = _asString(data['selectedAiModel'], AppConfig.defaultAiModel);
    final String theme = _asString(data['themeMode'], 'dark');
    return AppSettings(
      themeMode: <String>['dark', 'light', 'system'].contains(theme) ? theme : 'dark',
      compactGrid: _asBool(data['compactGrid']),
      notifyMessages: _asBool(data['notifyMessages'], true),
      notifyDeals: _asBool(data['notifyDeals'], true),
      notifyPriceDrop: _asBool(data['notifyPriceDrop'], true),
      hidePhoneShowTgOnly: _asBool(data['hidePhoneShowTgOnly']),
      selectedAiModel:
          AppConfig.availableAiModels.contains(model) ? model : AppConfig.defaultAiModel,
      customGeminiApiKey: _asString(data['customGeminiApiKey']),
    );
  }
}

// =============================================================================
// ChatMessage — сообщение в чате
// =============================================================================

class ChatMessage {
  final String id;
  final String peerUsername;
  final String peerTitle;
  final String text;
  final bool isMe;
  final bool isAiGenerated;
  final String time;

  const ChatMessage({
    required this.id,
    required this.peerUsername,
    required this.peerTitle,
    required this.text,
    this.isMe = false,
    this.isAiGenerated = false,
    required this.time,
  });

  ChatMessage copyWith({
    String? id,
    String? peerUsername,
    String? peerTitle,
    String? text,
    bool? isMe,
    bool? isAiGenerated,
    String? time,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      peerUsername: peerUsername ?? this.peerUsername,
      peerTitle: peerTitle ?? this.peerTitle,
      text: text ?? this.text,
      isMe: isMe ?? this.isMe,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      time: time ?? this.time,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'peerUsername': peerUsername,
      'peerTitle': peerTitle,
      'text': text,
      'isMe': isMe,
      'isAiGenerated': isAiGenerated,
      'time': time,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> data = _asMap(json);
    return ChatMessage(
      id: _asString(data['id']),
      peerUsername: _asString(data['peerUsername']),
      peerTitle: _asString(data['peerTitle']),
      text: _asString(data['text']),
      isMe: _asBool(data['isMe']),
      isAiGenerated: _asBool(data['isAiGenerated']),
      time: _asString(data['time'], _nowTimeLabel()),
    );
  }
}

// =============================================================================
// AppNotification — уведомление
// =============================================================================

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // 'deal' | 'message' | 'ai' | 'promo'
  final bool isRead;
  final String time;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.isRead = false,
    required this.time,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    bool? isRead,
    String? time,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      time: time ?? this.time,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'isRead': isRead,
      'time': time,
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> data = _asMap(json);
    return AppNotification(
      id: _asString(data['id']),
      title: _asString(data['title']),
      body: _asString(data['body']),
      type: _asString(data['type'], 'ai'),
      isRead: _asBool(data['isRead']),
      time: _asString(data['time'], _nowTimeLabel()),
    );
  }
}

// =============================================================================
// AiAssistantReply — ответ APEX AI
// =============================================================================

class AiAssistantReply {
  final String text;
  final List<MarketItem> matchedItems;
  final Map<String, String>? suggestedSellerAction;

  const AiAssistantReply({
    required this.text,
    this.matchedItems = const <MarketItem>[],
    this.suggestedSellerAction,
  });

  bool get hasMatches => matchedItems.isNotEmpty;
  bool get hasSellerAction => suggestedSellerAction != null;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'text': text,
      'matchedItems': matchedItems.map((MarketItem e) => e.toJson()).toList(),
      'suggestedSellerAction': suggestedSellerAction,
    };
  }

  factory AiAssistantReply.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> data = _asMap(json);
    final Map<String, String>? action = data['suggestedSellerAction'] == null
        ? null
        : _asMap(data['suggestedSellerAction'])
            .map((String key, dynamic value) => MapEntry<String, String>(key, _asString(value)));
    return AiAssistantReply(
      text: _asString(data['text']),
      matchedItems:
          _asMapList(data['matchedItems']).map((Map<String, dynamic> e) => MarketItem.fromJson(e)).toList(),
      suggestedSellerAction: action,
    );
  }
}

// =============================================================================
// ApexStorage — слой хранения на shared_preferences + движок APEX AI
// =============================================================================

class ApexStorage {
  // --- Ключи хранилища ---
  static const String _kItems = 'apex_items_v1';
  static const String _kSearch = 'apex_search_history_v1';
  static const String _kCart = 'apex_cart_v1';
  static const String _kFavorites = 'apex_favorites_v1';
  static const String _kViewed = 'apex_viewed_v1';
  static const String _kAccount = 'apex_account_v1';
  static const String _kSettings = 'apex_settings_v1';
  static const String _kChats = 'apex_chats_v1';
  static const String _kNotifications = 'apex_notifications_v1';

  static const int _searchHistoryLimit = 10;
  static const int _viewedHistoryLimit = 30;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // ===========================================================================
  // КАТАЛОГ ТОВАРОВ
  // ===========================================================================

  /// Загружает каталог. При первом пустом запуске генерирует 14 демо-товаров.
  Future<List<MarketItem>> loadItems() async {
    final SharedPreferences prefs = await _prefs;
    final String? raw = prefs.getString(_kItems);

    if (raw == null || raw.isEmpty) {
      final List<MarketItem> demo = _demoItems();
      await _saveItems(demo);
      return demo;
    }

    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) {
        final List<MarketItem> demo = _demoItems();
        await _saveItems(demo);
        return demo;
      }
      final List<MarketItem> items =
          decoded.map((dynamic e) => MarketItem.fromJson(_asMap(e))).toList();
      if (items.isEmpty) {
        final List<MarketItem> demo = _demoItems();
        await _saveItems(demo);
        return demo;
      }
      return items;
    } catch (_) {
      final List<MarketItem> demo = _demoItems();
      await _saveItems(demo);
      return demo;
    }
  }

  Future<void> _saveItems(List<MarketItem> items) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setString(
      _kItems,
      jsonEncode(items.map((MarketItem e) => e.toJson()).toList()),
    );
  }

  /// Добавляет товар в начало каталога и возвращает обновлённый список.
  Future<List<MarketItem>> addItem(MarketItem item) async {
    final List<MarketItem> items = await loadItems();
    final MarketItem normalized = item.id.isEmpty
        ? item.copyWith(id: 'apex-${DateTime.now().microsecondsSinceEpoch}')
        : item;
    final List<MarketItem> updated = <MarketItem>[normalized, ...items];
    await _saveItems(updated);
    return updated;
  }

  /// Переключает буст объявления. Возвращает обновлённый товар или null.
  Future<MarketItem?> toggleBoost(String id) async {
    final List<MarketItem> items = await loadItems();
    MarketItem? updatedItem;
    final List<MarketItem> updated = items.map((MarketItem e) {
      if (e.id != id) return e;
      updatedItem = e.copyWith(isBoosted: !e.isBoosted);
      return updatedItem!;
    }).toList();
    if (updatedItem == null) return null;
    await _saveItems(updated);
    return updatedItem;
  }

  /// Удаляет товар из каталога и из корзины/избранного/просмотров.
  Future<List<MarketItem>> deleteItem(String id) async {
    final List<MarketItem> items = await loadItems();
    final List<MarketItem> updated =
        items.where((MarketItem e) => e.id != id).toList(growable: false);
    await _saveItems(updated);

    final List<String> cart = await loadCartIds();
    if (cart.contains(id)) {
      await _saveStringList(_kCart, cart.where((String e) => e != id).toList());
    }
    final List<String> favorites = await loadFavoriteIds();
    if (favorites.contains(id)) {
      await _saveStringList(_kFavorites, favorites.where((String e) => e != id).toList());
    }
    final List<String> viewed = await loadViewedIds();
    if (viewed.contains(id)) {
      await _saveStringList(_kViewed, viewed.where((String e) => e != id).toList());
    }
    return updated;
  }

  // ===========================================================================
  // ИСТОРИЯ ПОИСКА
  // ===========================================================================

  Future<List<String>> loadSearchHistory() async {
    final SharedPreferences prefs = await _prefs;
    return prefs.getStringList(_kSearch) ?? <String>[];
  }

  /// Добавляет запрос в историю (до 10 последних уникальных, новые сверху).
  Future<List<String>> addSearchQuery(String q) async {
    final String query = q.trim();
    if (query.isEmpty) return loadSearchHistory();

    final List<String> history = await loadSearchHistory();
    final List<String> updated = <String>[
      query,
      ...history.where((String e) => e.toLowerCase() != query.toLowerCase()),
    ];
    final List<String> limited = updated.take(_searchHistoryLimit).toList();
    await _saveStringList(_kSearch, limited);
    return limited;
  }

  Future<void> clearSearchHistory() async {
    final SharedPreferences prefs = await _prefs;
    await prefs.remove(_kSearch);
  }

  // ===========================================================================
  // КОРЗИНА / ИЗБРАННОЕ / ИСТОРИЯ ПРОСМОТРОВ
  // ===========================================================================

  Future<List<String>> loadCartIds() async {
    final SharedPreferences prefs = await _prefs;
    return prefs.getStringList(_kCart) ?? <String>[];
  }

  /// Добавляет/убирает товар в корзине. Возвращает обновлённый список id.
  Future<List<String>> toggleCart(String id) async {
    final List<String> cart = await loadCartIds();
    final List<String> updated = cart.contains(id)
        ? cart.where((String e) => e != id).toList()
        : <String>[id, ...cart];
    await _saveStringList(_kCart, updated);
    return updated;
  }

  Future<void> clearCart() async {
    final SharedPreferences prefs = await _prefs;
    await prefs.remove(_kCart);
  }

  Future<List<String>> loadFavoriteIds() async {
    final SharedPreferences prefs = await _prefs;
    return prefs.getStringList(_kFavorites) ?? <String>[];
  }

  /// Добавляет/убирает товар в избранном. Возвращает обновлённый список id.
  Future<List<String>> toggleFavorite(String id) async {
    final List<String> favorites = await loadFavoriteIds();
    final List<String> updated = favorites.contains(id)
        ? favorites.where((String e) => e != id).toList()
        : <String>[id, ...favorites];
    await _saveStringList(_kFavorites, updated);
    return updated;
  }

  Future<List<String>> loadViewedIds() async {
    final SharedPreferences prefs = await _prefs;
    return prefs.getStringList(_kViewed) ?? <String>[];
  }

  /// Отмечает товар просмотренным (новые сверху, до 30 позиций).
  Future<List<String>> markViewed(String id) async {
    final List<String> viewed = await loadViewedIds();
    final List<String> updated = <String>[
      id,
      ...viewed.where((String e) => e != id),
    ].take(_viewedHistoryLimit).toList();
    await _saveStringList(_kViewed, updated);
    return updated;
  }

  Future<void> clearViewedHistory() async {
    final SharedPreferences prefs = await _prefs;
    await prefs.remove(_kViewed);
  }

  // ===========================================================================
  // АККАУНТ (авторизация через Telegram-бота)
  // ===========================================================================

  Future<UserAccount> loadAccount() async {
    final SharedPreferences prefs = await _prefs;
    final String? raw = prefs.getString(_kAccount);
    if (raw == null || raw.isEmpty) return const UserAccount.guest();
    try {
      return UserAccount.fromJson(_asMap(jsonDecode(raw)));
    } catch (_) {
      return const UserAccount.guest();
    }
  }

  Future<UserAccount> saveAccount(UserAccount account) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setString(_kAccount, jsonEncode(account.toJson()));
    return account;
  }

  Future<UserAccount> logout() async {
    final SharedPreferences prefs = await _prefs;
    await prefs.remove(_kAccount);
    return const UserAccount.guest();
  }

  // ===========================================================================
  // НАСТРОЙКИ
  // ===========================================================================

  Future<AppSettings> loadSettings() async {
    final SharedPreferences prefs = await _prefs;
    final String? raw = prefs.getString(_kSettings);
    if (raw == null || raw.isEmpty) return const AppSettings();
    try {
      return AppSettings.fromJson(_asMap(jsonDecode(raw)));
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<AppSettings> saveSettings(AppSettings settings) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setString(_kSettings, jsonEncode(settings.toJson()));
    return settings;
  }

  // ===========================================================================
  // ЧАТЫ
  // ===========================================================================

  Future<List<ChatMessage>> loadChats() async {
    final SharedPreferences prefs = await _prefs;
    final String? raw = prefs.getString(_kChats);
    if (raw == null || raw.isEmpty) return <ChatMessage>[];
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) return <ChatMessage>[];
      return decoded.map((dynamic e) => ChatMessage.fromJson(_asMap(e))).toList();
    } catch (_) {
      return <ChatMessage>[];
    }
  }

  /// Отправляет сообщение продавцу и сохраняет его в истории чатов.
  Future<ChatMessage> sendSellerMessage(
    String peerUsername,
    String peerTitle,
    String text, {
    bool isAiGenerated = false,
  }) async {
    final List<ChatMessage> chats = await loadChats();
    final ChatMessage message = ChatMessage(
      id: 'msg-${DateTime.now().microsecondsSinceEpoch}',
      peerUsername: peerUsername.startsWith('@') ? peerUsername.substring(1) : peerUsername,
      peerTitle: peerTitle,
      text: text.trim(),
      isMe: true,
      isAiGenerated: isAiGenerated,
      time: _nowTimeLabel(),
    );
    final List<ChatMessage> updated = <ChatMessage>[...chats, message];
    final SharedPreferences prefs = await _prefs;
    await prefs.setString(
      _kChats,
      jsonEncode(updated.map((ChatMessage e) => e.toJson()).toList()),
    );
    return message;
  }

  // ===========================================================================
  // УВЕДОМЛЕНИЯ
  // ===========================================================================

  Future<List<AppNotification>> loadNotifications() async {
    final SharedPreferences prefs = await _prefs;
    final String? raw = prefs.getString(_kNotifications);

    if (raw == null || raw.isEmpty) {
      final List<AppNotification> seeded = _demoNotifications();
      await _saveNotifications(seeded);
      return seeded;
    }

    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) return <AppNotification>[];
      return decoded.map((dynamic e) => AppNotification.fromJson(_asMap(e))).toList();
    } catch (_) {
      return _demoNotifications();
    }
  }

  Future<void> _saveNotifications(List<AppNotification> list) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setString(
      _kNotifications,
      jsonEncode(list.map((AppNotification e) => e.toJson()).toList()),
    );
  }

  /// Добавляет уведомление в начало списка.
  Future<List<AppNotification>> addNotification(AppNotification notification) async {
    final List<AppNotification> list = await loadNotifications();
    final AppNotification normalized = notification.id.isEmpty
        ? notification.copyWith(id: 'ntf-${DateTime.now().microsecondsSinceEpoch}')
        : notification;
    final List<AppNotification> updated = <AppNotification>[normalized, ...list];
    await _saveNotifications(updated);
    return updated;
  }

  /// Помечает все уведомления прочитанными.
  Future<List<AppNotification>> markAllNotificationsRead() async {
    final List<AppNotification> list = await loadNotifications();
    final List<AppNotification> updated =
        list.map((AppNotification e) => e.isRead ? e : e.copyWith(isRead: true)).toList();
    await _saveNotifications(updated);
    return updated;
  }

  // ===========================================================================
  // ДВИЖОК APEX AI
  // ===========================================================================

  /// AI-оценка фото товара.
  ///
  /// Возвращает карту с ключами:
  /// `title`, `category`, `price`, `oldPrice`, `conditionScore`, `isNew`,
  /// `description`, `aiNote`.
  ///
  /// Если в настройках задан `customGeminiApiKey` — используется Gemini
  /// (с inline-изображением для локальных файлов). Если ключ пустой или
  /// запрос не удался — работает реалистичный локальный движок.
  Future<Map<String, dynamic>> analyzeItemPhoto(String imagePath) async {
    final AppSettings settings = await loadSettings();

    if (settings.hasCustomApiKey) {
      final String? remote = await _geminiAnalyzePhoto(imagePath, settings);
      if (remote != null) {
        try {
          final Map<String, dynamic> parsed = _parseJsonObject(remote);
          final Map<String, dynamic> normalized = _normalizePhotoAnalysis(parsed, imagePath);
          if (normalized['title'].toString().isNotEmpty) return normalized;
        } catch (_) {
          // Падаем в локальный движок.
        }
      }
    }

    return _localPhotoAnalysis(imagePath);
  }

  /// Запрос к APEX AI.
  ///
  /// Ищет товары по каталогу, объясняет Гарант 4%, проверяет сделки на
  /// анти-скам и предлагает черновик сообщения продавцу.
  Future<AiAssistantReply> askApexOrb(String prompt, List<MarketItem> catalog) async {
    final String cleanPrompt = prompt.trim();
    if (cleanPrompt.isEmpty) {
      return const AiAssistantReply(
        text: 'Напишите запрос — например: «найди видеокарту до 60 000 ₽ в Ставрополе».',
      );
    }

    final List<MarketItem> matched = _matchCatalog(cleanPrompt, catalog);
    final bool wantsSellerMessage = _wantsSellerMessage(cleanPrompt);
    final MarketItem? target = matched.isNotEmpty
        ? matched.first
        : (wantsSellerMessage && catalog.isNotEmpty ? catalog.first : null);

    Map<String, String>? sellerAction;
    if (wantsSellerMessage && target != null) {
      sellerAction = <String, String>{
        'peerUsername': target.cleanUsername,
        'peerTitle': target.title,
        'draftText': _buildSellerDraft(cleanPrompt, target),
      };
    }

    final AppSettings settings = await loadSettings();
    if (settings.hasCustomApiKey) {
      final String? remote = await _geminiAssistant(cleanPrompt, catalog, matched, settings);
      if (remote != null && remote.trim().isNotEmpty) {
        return AiAssistantReply(
          text: remote.trim(),
          matchedItems: matched,
          suggestedSellerAction: sellerAction,
        );
      }
    }

    return AiAssistantReply(
      text: _buildLocalReply(cleanPrompt, matched, sellerAction),
      matchedItems: matched,
      suggestedSellerAction: sellerAction,
    );
  }

  // ---------------------------------------------------------------------------
  // APEX AI — локальный движок
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _localPhotoAnalysis(String imagePath) {
    final String path = imagePath.trim();
    final int seed = path.isEmpty ? 42 : (path.hashCode & 0x7fffffff);
    final Random rnd = Random(seed);

    final List<String> categories = AppConfig.realCategories;
    final String category = categories[rnd.nextInt(categories.length)];
    final List<String> titles = _photoTitleTemplates[category] ?? const <String>['Товар в хорошем состоянии'];
    final String title = titles[rnd.nextInt(titles.length)];

    final List<int> range = _photoPriceRanges[category] ?? const <int>[3000, 30000];
    final int basePrice = range[0] + rnd.nextInt(range[1] - range[0]);
    final int price = (basePrice / 100).round() * 100;
    final bool hasOldPrice = rnd.nextDouble() > 0.35;
    final int? oldPrice = hasOldPrice ? ((price * (1.15 + rnd.nextDouble() * 0.35)).round() / 100).round() * 100 : null;

    final bool isNew = rnd.nextDouble() > 0.55;
    final double conditionScore = isNew
        ? 9.0 + rnd.nextDouble() * 0.9
        : 7.0 + rnd.nextDouble() * 2.0;

    final String conditionText = isNew
        ? 'состояние нового, без следов использования'
        : 'лёгкие следы эксплуатации, всё работает';

    final String description =
        'Состояние: $conditionText. Комплектность полная, дефектов не выявлено. '
        'Готов к встрече в городе или к отправке доставкой. '
        'По запросу пришлю дополнительные фото и видео.';

    final String aiNote =
        'APEX AI: распознано «$title» (${category}). Состояние оценено в '
        '${conditionScore.toStringAsFixed(1)}/10, рекомендованная цена — ${_formatRub(price)}'
        '${oldPrice != null ? ', старая цена ${_formatRub(oldPrice)} (выгода ${(((oldPrice - price) / oldPrice) * 100).round()}%)' : ''}. '
        'Проверьте комплектность и серийный номер перед публикацией.';

    return <String, dynamic>{
      'title': title,
      'category': category,
      'price': price,
      'oldPrice': oldPrice,
      'conditionScore': double.parse(conditionScore.toStringAsFixed(1)),
      'isNew': isNew,
      'description': description,
      'aiNote': aiNote,
    };
  }

  Map<String, dynamic> _normalizePhotoAnalysis(Map<String, dynamic> raw, String imagePath) {
    final Map<String, dynamic> fallback = _localPhotoAnalysis(imagePath);
    final String category = _asString(raw['category'], _asString(fallback['category']));
    final List<String> categories = AppConfig.realCategories;
    final String safeCategory =
        categories.contains(category) ? category : _asString(fallback['category']);

    final int price = _asInt(raw['price'], _asInt(fallback['price']));
    final int? oldPrice = _asNullableInt(raw['oldPrice']);
    final double condition = _asDouble(raw['conditionScore'], _asDouble(fallback['conditionScore']));

    return <String, dynamic>{
      'title': _asString(raw['title'], _asString(fallback['title'])),
      'category': safeCategory,
      'price': price <= 0 ? _asInt(fallback['price']) : price,
      'oldPrice': oldPrice != null && oldPrice > price ? oldPrice : _asNullableInt(fallback['oldPrice']),
      'conditionScore': double.parse(condition.clamp(1.0, 10.0).toStringAsFixed(1)),
      'isNew': _asBool(raw['isNew'], _asBool(fallback['isNew'])),
      'description': _asString(raw['description'], _asString(fallback['description'])),
      'aiNote': _asString(raw['aiNote'], _asString(fallback['aiNote'])),
    };
  }

  List<MarketItem> _matchCatalog(String prompt, List<MarketItem> catalog) {
    final List<String> tokens = _tokenize(prompt);
    if (tokens.isEmpty || catalog.isEmpty) return <MarketItem>[];

    final Map<String, int> scores = <String, int>{};
    for (final MarketItem item in catalog) {
      final String haystack =
          '${item.title} ${item.description} ${item.category} ${item.city} ${item.sellerName}'
              .toLowerCase();
      int score = 0;
      for (final String token in tokens) {
        if (haystack.contains(token)) {
          score += 2;
        } else if (token.length > 5 && haystack.contains(token.substring(0, token.length - 2))) {
          score += 1;
        }
      }
      if (score > 0) scores[item.id] = score;
    }

    if (scores.isEmpty) return <MarketItem>[];

    final List<MarketItem> result = catalog.where((MarketItem e) => scores.containsKey(e.id)).toList()
      ..sort((MarketItem a, MarketItem b) => (scores[b.id] ?? 0).compareTo(scores[a.id] ?? 0));

    return result.take(3).toList();
  }

  bool _wantsSellerMessage(String prompt) {
    final String q = prompt.toLowerCase();
    const List<String> markers = <String>[
      'напиши',
      'написать',
      'напишите',
      'сообщение продавцу',
      'черновик',
      'свяжись',
      'связаться',
      'торг',
      'поторг',
      'скидк',
      'предложи продавцу',
    ];
    return markers.any((String m) => q.contains(m));
  }

  String _buildSellerDraft(String prompt, MarketItem item) {
    final String q = prompt.toLowerCase();
    final bool bargaining = q.contains('торг') || q.contains('скидк');
    final int suggested =
        bargaining ? max((item.price * 0.92).round(), 1) : item.price;

    final StringBuffer draft = StringBuffer();
    draft.write('Здравствуйте! Интересует «${item.title}» за ${_formatRub(item.price)}. ');
    draft.write('Подскажите, пожалуйста, объявление ещё актуально и в каком состоянии товар? ');
    if (bargaining) {
      draft.write('Готов забрать сегодня за ${_formatRub(suggested)} — сумма на руках. ');
    }
    draft.write('Комфортно ли вам провести сделку через Гарант 4% или встретиться лично?');
    return draft.toString();
  }

  String _buildLocalReply(
    String prompt,
    List<MarketItem> matched,
    Map<String, String>? sellerAction,
  ) {
    final String q = prompt.toLowerCase();
    final StringBuffer buffer = StringBuffer();
    final bool asksGarant = q.contains('гарант') || q.contains('сделк') || q.contains('безопасн') || q.contains('комисси');
    final bool asksScam = q.contains('скам') || q.contains('мошен') || q.contains('обман') || q.contains('кидок') || q.contains('риск');
    final bool asksSeller = sellerAction != null;

    if (asksScam) {
      final bool risky = matched.any((MarketItem e) => !e.sellerTgVerified);
      buffer.writeln(risky
          ? 'Риск: СРЕДНИЙ. В найденных объявлениях есть продавцы без Telegram-верификации.'
          : 'Риск: НИЗКИЙ. Все найденные продавцы прошли Telegram-верификацию.');
      buffer.writeln('• Не переводите предоплату на карту вне APEX.');
      buffer.writeln('• Слишком низкая цена (>30% от рынка) — повод насторожиться.');
      buffer.writeln('• Проводите сделку только через Гарант ${AppConfig.garantFeePercent.toStringAsFixed(0)}%.');
      if (matched.isNotEmpty) {
        buffer.writeln('Следующий шаг: откройте «${matched.first.title}» и нажмите «Купить через Гарант».');
      }
      return buffer.toString().trim();
    }

    if (asksGarant) {
      buffer.writeln('Гарант APEX — ${AppConfig.garantFeePercent.toStringAsFixed(0)}% от суммы сделки.');
      buffer.writeln('• Деньги замораживаются в защищённом кошельке APEX.');
      buffer.writeln('• Продавец получает оплату только после вашего подтверждения получения.');
      buffer.writeln('• Если товар не соответствует описанию — открывается спор, средства остаются замороженными.');
      buffer.writeln('Лимиты: ${_formatRub(AppConfig.garantMinDealRub)} — ${_formatRub(AppConfig.garantMaxDealRub)}.');
      return buffer.toString().trim();
    }

    if (asksSeller && matched.isNotEmpty) {
      final MarketItem item = matched.first;
      buffer.writeln('Готов черновик сообщения продавцу «${item.title}» (@${item.cleanUsername}).');
      buffer.writeln('Черновик: «${sellerAction!['draftText']}»');
      buffer.writeln('Следующий шаг: откройте чат с продавцом и отправьте или отредактируйте текст.');
      return buffer.toString().trim();
    }

    if (matched.isEmpty) {
      buffer.writeln('По запросу «${prompt.trim()}» в каталоге ничего не нашлось.');
      buffer.writeln('• Попробуйте расширить бюджет или снять фильтр категории.');
      buffer.writeln('• Проверьте, не указан ли город, в котором пока нет объявлений.');
      buffer.writeln('Следующий шаг: измените формулировку — например, «видеокарта до 60 000 ₽».');
      return buffer.toString().trim();
    }

    buffer.writeln('Нашёл ${matched.length} ${matched.length == 1 ? "вариант" : "варианта"} по запросу:');
    for (final MarketItem item in matched) {
      buffer.writeln(
        '• ${item.title} — ${_formatRub(item.price)}'
        '${item.oldPrice != null ? ' (было ${_formatRub(item.oldPrice!)})' : ''}, '
        '${item.city}, состояние ${item.conditionScore.toStringAsFixed(1)}/10'
        '${item.sellerTgVerified ? ', продавец верифицирован' : ''}.',
      );
    }
    buffer.writeln('Совет: сделку через Гарант ${AppConfig.garantFeePercent.toStringAsFixed(0)}% '
        'можно оформить прямо из карточки товара.');
    return buffer.toString().trim();
  }

  List<String> _tokenize(String input) {
    final String normalized = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zа-яё0-9\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) return <String>[];
    const List<String> stopWords = <String>[
      'найди', 'найти', 'покажи', 'хочу', 'нужно', 'можно', 'есть', 'для', 'или',
      'что', 'как', 'мне', 'пожалуйста', 'товар', 'товары', 'купить', 'продай',
      'чем', 'это', 'про', 'все', 'всё', 'мне', 'где', 'когда', 'почему',
    ];
    return normalized
        .split(' ')
        .where((String t) => t.length >= 3 && !stopWords.contains(t))
        .toSet()
        .toList();
  }

  // ---------------------------------------------------------------------------
  // APEX AI — удалённый движок Gemini
  // ---------------------------------------------------------------------------

  Future<String?> _geminiAnalyzePhoto(String imagePath, AppSettings settings) async {
    final String path = imagePath.trim();
    if (path.isEmpty) return null;

    final List<Map<String, dynamic>> parts = <Map<String, dynamic>>[];

    if (!path.startsWith('http://') && !path.startsWith('https://')) {
      try {
        final File file = File(path);
        if (await file.exists()) {
          final List<int> bytes = await file.readAsBytes();
          parts.add(<String, dynamic>{
            'inline_data': <String, dynamic>{
              'mime_type': _guessMime(path),
              'data': base64Encode(bytes),
            },
          });
        }
      } catch (_) {
        // Игнорируем — отправим только текстовый промпт.
      }
    }

    parts.add(<String, dynamic>{
      'text': 'Оцени товар на фото для публикации на APEX Market. '
          'Верни СТРОГО валидный JSON без markdown и пояснений: '
          '{"title": "строка", "category": "одна из: ${AppConfig.realCategories.join(", ")}", '
          '"price": число, "oldPrice": число или null, "conditionScore": число от 1 до 10, '
          '"isNew": true/false, "description": "строка", "aiNote": "строка"}. '
          'Цены — в рублях, реалистичные для российского рынка.',
    });

    final String? raw = await _geminiRequest(parts, settings);
    return raw;
  }

  Future<String?> _geminiAssistant(
    String prompt,
    List<MarketItem> catalog,
    List<MarketItem> matched,
    AppSettings settings,
  ) async {
    final StringBuffer context = StringBuffer()
      ..writeln('КАТАЛОГ APEX (${catalog.length} объявлений):');
    for (final MarketItem item in catalog.take(40)) {
      context.writeln(item.toAiLine());
    }
    if (matched.isNotEmpty) {
      context.writeln();
      context.writeln('ПРЕДВАРИТЕЛЬНО НАЙДЕНО ЛОКАЛЬНЫМ ПОИСКОМ:');
      for (final MarketItem item in matched) {
        context.writeln('• ${item.title} — ${_formatRub(item.price)} (${item.city})');
      }
    }
    context.writeln();
    context.writeln('ЗАПРОС ПОЛЬЗОВАТЕЛЯ: $prompt');

    final List<Map<String, dynamic>> parts = <Map<String, dynamic>>[
      <String, dynamic>{'text': context.toString()},
    ];

    return _geminiRequest(parts, settings);
  }

  Future<String?> _geminiRequest(List<Map<String, dynamic>> parts, AppSettings settings) async {
    final String apiKey = settings.customGeminiApiKey.trim();
    if (apiKey.isEmpty) return null;

    final String model = settings.selectedAiModel.isEmpty
        ? AppConfig.defaultAiModel
        : settings.selectedAiModel;

    final Uri uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );

    final Map<String, dynamic> body = <String, dynamic>{
      'system_instruction': <String, dynamic>{
        'parts': <Map<String, String>>[
          <String, String>{'text': AppConfig.aiSystemPrompt},
        ],
      },
      'contents': <Map<String, dynamic>>[
        <String, dynamic>{
          'role': 'user',
          'parts': parts,
        },
      ],
      'generationConfig': <String, dynamic>{
        'temperature': 0.7,
        'maxOutputTokens': 1024,
        'topP': 0.95,
      },
    };

    try {
      final http.Response response = await http
          .post(
            uri,
            headers: <String, String>{'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) return null;

      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final Map<String, dynamic> data = _asMap(decoded);
      final List<Map<String, dynamic>> candidates = _asMapList(data['candidates']);
      if (candidates.isEmpty) return null;

      final Map<String, dynamic> content = _asMap(candidates.first['content']);
      final List<Map<String, dynamic>> responseParts = _asMapList(content['parts']);
      final StringBuffer text = StringBuffer();
      for (final Map<String, dynamic> part in responseParts) {
        final String chunk = _asString(part['text']);
        if (chunk.isNotEmpty) text.write(chunk);
      }
      final String result = text.toString().trim();
      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _parseJsonObject(String raw) {
    String cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceAll(RegExp(r'^```[a-zA-Z]*\s*'), '').replaceAll(RegExp(r'\s*```$'), '');
    }
    final int start = cleaned.indexOf('{');
    final int end = cleaned.lastIndexOf('}');
    if (start >= 0 && end > start) {
      cleaned = cleaned.substring(start, end + 1);
    }
    return _asMap(jsonDecode(cleaned));
  }

  String _guessMime(String path) {
    final String lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  // ---------------------------------------------------------------------------
  // Вспомогательные методы хранения
  // ---------------------------------------------------------------------------

  Future<void> _saveStringList(String key, List<String> values) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setStringList(key, values);
  }

  // ===========================================================================
  // ДЕМО-ДАННЫЕ
  // ===========================================================================

  static const Map<String, List<String>> _photoTitleTemplates = <String, List<String>>{
    'Одежда и обувь': <String>['Кроссовки уличного стиля', 'Худи оверсайз', 'Зимняя куртка'],
    'Техника и ПК': <String>['Смартфон флагманский', 'Видеокарта игровая', 'Ноутбук для работы'],
    'Авто и запчасти': <String>['Комплект автозапчастей', 'Литые диски R17', 'Автомагнитола'],
    'Для дома': <String>['Диван-кровать', 'Кухонный гарнитур', 'Робот-пылесос'],
    'Услуги': <String>['Услуга: ремонт под ключ', 'Услуга: грузоперевозки', 'Услуга: видеосъёмка'],
    'Недвижимость': <String>['Аренда 1-комнатной квартиры', 'Аренда студии', 'Продажа гаража'],
  };

  static const Map<String, List<int>> _photoPriceRanges = <String, List<int>>{
    'Одежда и обувь': <int>[2500, 20000],
    'Техника и ПК': <int>[15000, 90000],
    'Авто и запчасти': <int>[4000, 60000],
    'Для дома': <int>[3000, 45000],
    'Услуги': <int>[1500, 30000],
    'Недвижимость': <int>[15000, 80000],
  };

  static List<MarketItem> _demoItems() {
    const String cdn = 'https://picsum.photos/seed';
    return <MarketItem>[
      MarketItem(
        id: 'apex-1',
        title: 'Кроссовки Nike Air Max 90',
        description:
            'Оригинал, размер 43. Носились пару месяцев, подошва без критичного износа. '
            'Полный комплект: коробка, сменные шнурки, фирменный пакет.',
        price: 7900,
        oldPrice: 11900,
        category: 'Одежда и обувь',
        city: 'Пятигорск',
        imagePath: '$cdn/apex1/500/500',
        isLocalImage: false,
        isNew: false,
        hasDelivery: true,
        conditionScore: 8.7,
        aiVerified: true,
        aiNote: 'APEX AI: состояние 8.7/10 — лёгкие следы носки на подошве, цена ниже рынка на 12%.',
        isBoosted: true,
        sellerName: 'Артём К.',
        sellerUsername: 'artem_sneakers',
        sellerPhone: '+7 988 700-11-22',
        sellerTgVerified: true,
        createdAt: '2025-01-18T09:24:00.000',
      ),
      MarketItem(
        id: 'apex-2',
        title: 'Худи Stone Island оверсайз',
        description:
            'Новое, с бирками. Размер L, цвет графит. Плотный футер, компас на рукаве. '
            'Отправлю СДЭКом или отдам лично в Москве.',
        price: 12500,
        oldPrice: 18900,
        category: 'Одежда и обувь',
        city: 'Москва',
        imagePath: '$cdn/apex2/500/500',
        isLocalImage: false,
        isNew: true,
        hasDelivery: true,
        conditionScore: 9.5,
        aiVerified: true,
        aiNote: 'APEX AI: состояние 9.5/10 — новое с бирками, выгода 34% от розницы.',
        isBoosted: false,
        sellerName: 'Динара М.',
        sellerUsername: 'dinara_style',
        sellerPhone: '+7 926 314-55-08',
        sellerTgVerified: true,
        createdAt: '2025-01-19T12:05:00.000',
      ),
      MarketItem(
        id: 'apex-3',
        title: 'Видеокарта NVIDIA RTX 4070 Super 12GB',
        description:
            'Не майнилась, использовалась для работы в 3D. Гарантия от магазина до 2026 года, '
            'чеки на месте. Полный комплект коробки и переходников.',
        price: 54000,
        oldPrice: 68000,
        category: 'Техника и ПК',
        city: 'Ставрополь',
        imagePath: '$cdn/apex3/500/500',
        isLocalImage: false,
        isNew: false,
        hasDelivery: true,
        conditionScore: 9.1,
        aiVerified: true,
        aiNote: 'APEX AI: состояние 9.1/10 — следов перегрева не выявлено, цена ниже рынка на 9%.',
        isBoosted: true,
        sellerName: 'Игорь П.',
        sellerUsername: 'igor_pc_build',
        sellerPhone: '+7 962 445-77-31',
        sellerTgVerified: true,
        createdAt: '2025-01-20T15:40:00.000',
      ),
      MarketItem(
        id: 'apex-4',
        title: 'iPhone 15 Pro 256GB, Natural Titanium',
        description:
            'Батарея 94%, всегда в чехле и с защитным стеклом. Face ID и все модули работают. '
            'Полный комплект: кабель, коробка, чек. Возможен обмен на 14 Pro с доплатой.',
        price: 89900,
        oldPrice: 105000,
        category: 'Техника и ПК',
        city: 'Краснодар',
        imagePath: '$cdn/apex4/500/500',
        isLocalImage: false,
        isNew: false,
        hasDelivery: true,
        conditionScore: 9.2,
        aiVerified: true,
        aiNote: 'APEX AI: состояние 9.2/10 — царапин на корпусе не найдено, аккумулятор 94%.',
        isBoosted: false,
        sellerName: 'Максим Л.',
        sellerUsername: 'maxim_devices',
        sellerPhone: '+7 918 220-64-19',
        sellerTgVerified: true,
        createdAt: '2025-01-21T08:12:00.000',
      ),
      MarketItem(
        id: 'apex-5',
        title: 'Комплект запчастей BMW E90',
        description:
            'Оригинальные фары, решётка радиатора и оба зеркала после рестайлинга. '
            'Снято с донора, всё рабочее. Продаю комплектом, по отдельности — дороже.',
        price: 18500,
        oldPrice: 24000,
        category: 'Авто и запчасти',
        city: 'Ессентуки',
        imagePath: '$cdn/apex5/500/500',
        isLocalImage: false,
        isNew: false,
        hasDelivery: false,
        conditionScore: 7.8,
        aiVerified: true,
        aiNote: 'APEX AI: состояние 7.8/10 — есть потёртости на одном зеркале, стекло целое.',
        isBoosted: false,
        sellerName: 'Руслан А.',
        sellerUsername: 'ruslan_bmw',
        sellerPhone: '+7 928 881-02-47',
        sellerTgVerified: false,
        createdAt: '2025-01-15T11:30:00.000',
      ),
      MarketItem(
        id: 'apex-6',
        title: 'Диван-кровать IKEA FRIHETEN',
        description:
            'Угловой, с механизмом и ящиком для белья. Обшивка чистая, без пятен и затяжек. '
            'Самовывоз из Пятигорска, помогу спустить и загрузить.',
        price: 22000,
        oldPrice: 34990,
        category: 'Для дома',
        city: 'Пятигорск',
        imagePath: '$cdn/apex6/500/500',
        isLocalImage: false,
        isNew: false,
        hasDelivery: false,
        conditionScore: 8.2,
        aiVerified: true,
        aiNote: 'APEX AI: состояние 8.2/10 — механизм раскладывания проверен, выгода 37%.',
        isBoosted: false,
        sellerName: 'Ольга Т.',
        sellerUsername: 'olga_home',
        sellerPhone: '+7 909 456-18-73',
        sellerTgVerified: true,
        createdAt: '2025-01-17T17:50:00.000',
      ),
      MarketItem(
        id: 'apex-7',
        title: 'Ремонт квартир под ключ',
        description:
            'Бригада из 4 человек, опыт 9 лет. Смета и договор, оплата по этапам. '
            'Работаем по Пятигорску и КМВ. Цена указана за квадратный метр черновых работ.',
        price: 1500,
        oldPrice: 1900,
        category: 'Услуги',
        city: 'Пятигорск',
        imagePath: '$cdn/apex7/500/500',
        isLocalImage: false,
        isNew: false,
        hasDelivery: false,
        conditionScore: 9.0,
        aiVerified: true,
        aiNote: 'APEX AI: услуга с портфолио, 46 закрытых объектов, рейтинг продавца 4.9.',
        isBoosted: false,
        sellerName: 'Сергей В.',
        sellerUsername: 'sergey_remont',
        sellerPhone: '+7 961 800-25-14',
        sellerTgVerified: true,
        createdAt: '2025-01-12T10:00:00.000',
      ),
      MarketItem(
        id: 'apex-8',
        title: 'Аренда 1-комнатной квартиры, 38 м²',
        description:
            'Свежий ремонт, вся техника и мебель. 5 минут до центра, парковка во дворе. '
            'Сдаётся на длительный срок, коммунальные платежи по счётчикам.',
        price: 25000,
        oldPrice: 28000,
        category: 'Недвижимость',
        city: 'Пятигорск',
        imagePath: '$cdn/apex8/500/500',
        isLocalImage: false,
        isNew: true,
        hasDelivery: false,
        conditionScore: 9.4,
        aiVerified: true,
        aiNote: 'APEX AI: состояние 9.4/10 — ремонт 2024 года, цена ниже средней по району на 7%.',
        isBoosted: true,
        sellerName: 'Кирилл Ж.',
        sellerUsername: 'kirill_rent',
        sellerPhone: '+7 988 115-40-62',
        sellerTgVerified: true,
        createdAt: '2025-01-22T09:45:00.000',
      ),
      MarketItem(
        id: 'apex-9',
        title: 'Sony PlayStation 5 Slim Digital',
        description:
            'Куплена в декабре, наиграно меньше 30 часов. Два геймпада DualSense, '
            'коробка и все кабели. Продаю из-за переезда.',
        price: 42000,
        oldPrice: 54990,
        category: 'Техника и ПК',
        city: 'Ставрополь',
        imagePath: '$cdn/apex9/500/500',
        isLocalImage: false,
        isNew: true,
        hasDelivery: true,
        conditionScore: 9.6,
        aiVerified: true,
        aiNote: 'APEX AI: состояние 9.6/10 — практически новая, выгода 24% от розницы.',
        isBoosted: false,
        sellerName: 'Никита Б.',
        sellerUsername: 'nikita_console',
        sellerPhone: '+7 963 227-91-05',
        sellerTgVerified: true,
        createdAt: '2025-01-23T19:10:00.000',
      ),
      MarketItem(
        id: 'apex-10',
        title: 'Куртка The North Face 1996 Nuptse',
        description:
            'Оригинал, размер M. Пух не сбит, молнии родные, капюшон съёмный. '
            'Есть небольшой след на манжете, на фото видно. Торг небольшой.',
        price: 9800,
        oldPrice: 15900,
        category: 'Одежда и обувь',
        city: 'Краснодар',
        imagePath: '$cdn/apex10/500/500',
        isLocalImage: false,
        isNew: false,
        hasDelivery: true,
        conditionScore: 8.0,
        aiVerified: false,
        aiNote: 'APEX AI: состояние 8.0/10 — есть потёртость на манжете, требуется доп. фото.',
        isBoosted: false,
        sellerName: 'Алина Ш.',
        sellerUsername: 'alina_wear',
        sellerPhone: '+7 918 664-30-87',
        sellerTgVerified: false,
        createdAt: '2025-01-16T14:20:00.000',
      ),
      MarketItem(
        id: 'apex-11',
        title: 'MacBook Air M2 13", 8/256GB',
        description:
            'Пробег батареи 74 цикла. Использовался для текстов и браузера, '
            'без ремонтов и вскрытий. Комплект: зарядка MagSafe, коробка.',
        price: 74000,
        oldPrice: 89000,
        category: 'Техника и ПК',
        city: 'Москва',
        imagePath: '$cdn/apex11/500/500',
        isLocalImage: false,
        isNew: false,
        hasDelivery: true,
        conditionScore: 9.0,
        aiVerified: true,
        aiNote: 'APEX AI: состояние 9.0/10 — аккумулятор 97%, следов вскрытия нет.',
        isBoosted: false,
        sellerName: 'Павел Д.',
        sellerUsername: 'pavel_mac',
        sellerPhone: '+7 925 330-77-41',
        sellerTgVerified: true,
        createdAt: '2025-01-14T13:05:00.000',
      ),
      MarketItem(
        id: 'apex-12',
        title: 'Кресло Herman Miller Aeron, размер B',
        description:
            'Оригинал, сетка без провисаний, все регулировки работают. '
            'Привезено из офиса после расформирования. Самовывоз из Ессентуков.',
        price: 48000,
        oldPrice: 62000,
        category: 'Для дома',
        city: 'Ессентуки',
        imagePath: '$cdn/apex12/500/500',
        isLocalImage: false,
        isNew: false,
        hasDelivery: false,
        conditionScore: 8.5,
        aiVerified: true,
        aiNote: 'APEX AI: состояние 8.5/10 — газлифт держит, потёртости на подлокотниках.',
        isBoosted: false,
        sellerName: 'Владислав Н.',
        sellerUsername: 'vlad_office',
        sellerPhone: '+7 988 902-13-66',
        sellerTgVerified: true,
        createdAt: '2025-01-11T16:35:00.000',
      ),
      MarketItem(
        id: 'apex-13',
        title: 'Видеосъёмка мероприятий',
        description:
            'Свадьбы, корпоративы, выпускные. Съёмка на две камеры, монтаж за 7 дней, '
            'цветокоррекция и звук. Портфолио пришлю в Telegram.',
        price: 12000,
        oldPrice: 17000,
        category: 'Услуги',
        city: 'Пятигорск',
        imagePath: '$cdn/apex13/500/500',
        isLocalImage: false,
        isNew: true,
        hasDelivery: false,
        conditionScore: 9.3,
        aiVerified: true,
        aiNote: 'APEX AI: услуга с портфолио из 60+ проектов, средний рейтинг 4.9/5.',
        isBoosted: false,
        sellerName: 'Егор Ф.',
        sellerUsername: 'egor_film',
        sellerPhone: '+7 962 118-52-90',
        sellerTgVerified: true,
        createdAt: '2025-01-24T11:15:00.000',
      ),
      MarketItem(
        id: 'apex-14',
        title: 'Шины Michelin X-Ice 225/45 R17, 4 шт.',
        description:
            'Остаток протектора 7 мм, шипы на месте. Отбалансированы, хранились в гараже '
            'стоя. Продаю комплектом, торг возможен при быстром выкупе.',
        price: 32000,
        oldPrice: 44000,
        category: 'Авто и запчасти',
        city: 'Ставрополь',
        imagePath: '$cdn/apex14/500/500',
        isLocalImage: false,
        isNew: false,
        hasDelivery: true,
        conditionScore: 8.3,
        aiVerified: true,
        aiNote: 'APEX AI: состояние 8.3/10 — протектор 7 мм, выгода 27% от новой резины.',
        isBoosted: false,
        sellerName: 'Тимур Г.',
        sellerUsername: 'timur_tyres',
        sellerPhone: '+7 919 447-08-23',
        sellerTgVerified: true,
        createdAt: '2025-01-13T10:45:00.000',
      ),
    ];
  }

  static List<AppNotification> _demoNotifications() {
    return const <AppNotification>[
      AppNotification(
        id: 'ntf-demo-1',
        title: 'Добро пожаловать в APEX Market',
        body: 'Подтвердите аккаунт через @apex_verify_bot, чтобы получить доступ к Гаранту 4% и сделкам.',
        type: 'promo',
        isRead: false,
        time: '09:00',
      ),
      AppNotification(
        id: 'ntf-demo-2',
        title: 'APEX AI оценил фото',
        body: 'AI-оценка товара «Кроссовки Nike Air Max 90»: состояние 8.7/10, рекомендованная цена 7 900 ₽.',
        type: 'ai',
        isRead: false,
        time: '10:24',
      ),
      AppNotification(
        id: 'ntf-demo-3',
        title: 'Сделка через Гарант',
        body: 'Средства за «Видеокарта NVIDIA RTX 4070 Super» заморожены в защищённом кошельке. Подтвердите получение.',
        type: 'deal',
        isRead: true,
        time: '12:47',
      ),
    ];
  }
}
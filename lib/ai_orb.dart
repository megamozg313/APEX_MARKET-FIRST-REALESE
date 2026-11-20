// lib/ai_orb.dart
// APEX AI — плавающая сфера + шторка ассистента.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'config.dart';
import 'data.dart';
import 'theme.dart';

// ════════════════════════════════════════════════════════════════════
//  АДАПТЕР К data.dart
// ════════════════════════════════════════════════════════════════════

String? _itemCover(MarketItem i) => i.imagePath;
String _itemTitle(MarketItem i) => i.title;
int _itemPrice(MarketItem i) => i.price;
String _itemCity(MarketItem i) => i.city;
String _replyText(AiAssistantReply r) => r.text;
List<MarketItem> _replyItems(AiAssistantReply r) => r.matchedItems;

String _actionUsername(Map<String, String> a) => a['peerUsername'] ?? '';
String _actionTitle(Map<String, String> a) => a['peerTitle'] ?? '';
String _actionDraft(Map<String, String> a) => a['draftText'] ?? '';

Future<void> _sendSellerDraftAction(Map<String, String> a) async {
  final now = DateTime.now();
  final time =
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  final storage = ApexStorage();
  await storage.sendSellerMessage(
    _actionUsername(a),
    _actionTitle(a),
    _actionDraft(a),
    isAiGenerated: true,
  );
  await storage.addNotification(
    AppNotification(
      id: '',
      title: 'Сообщение отправлено',
      body: 'Продавец ${_actionTitle(a)} получил ваш запрос',
      type: 'message',
      isRead: false,
      time: time,
    ),
  );
}

// ════════════════════════════════════════════════════════════════════
//  ПЛАВАЮЩАЯ СФЕРА
// ════════════════════════════════════════════════════════════════════

class ApexFloatingOrb extends StatefulWidget {
  const ApexFloatingOrb({
    super.key,
    required this.items,
    required this.onOpenItem,
    this.navigatorKey,
  });

  /// Каталог, по которому ассистент ищет товары.
  final List<MarketItem> items;

  /// Тап по мини-карточке в чате (шторка закрывается автоматически).
  final ValueChanged<MarketItem> onOpenItem;

  /// Нужен, если сфера размещена в MaterialApp.builder (выше Navigator).
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<ApexFloatingOrb> createState() => _ApexFloatingOrbState();
}

class _ApexFloatingOrbState extends State<ApexFloatingOrb>
    with TickerProviderStateMixin {
  static const double _size = 56;
  static const double _margin = 10;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  late final AnimationController _snap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  Animation<Offset>? _snapAnim;
  Offset? _pos;
  Rect _bounds = Rect.zero;
  bool _dragging = false;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    _snap.addListener(() {
      final a = _snapAnim;
      if (a != null && mounted) setState(() => _pos = a.value);
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _snap.dispose();
    super.dispose();
  }

  Offset _clamp(Offset o) => Offset(
        o.dx.clamp(_bounds.left, _bounds.right).toDouble(),
        o.dy.clamp(_bounds.top, _bounds.bottom).toDouble(),
      );

  void _onPanStart(DragStartDetails d) {
    _snap.stop();
    HapticFeedback.selectionClick();
    setState(() => _dragging = true);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final cur = _pos;
    if (cur == null) return;
    setState(() => _pos = _clamp(cur + d.delta));
  }

  void _onPanEnd(DragEndDetails d) {
    final cur = _pos;
    if (cur == null) return;
    final v = d.velocity.pixelsPerSecond;
    final mid = (_bounds.left + _bounds.right) / 2;
    final goRight = v.dx.abs() > 380 ? v.dx > 0 : cur.dx > mid;
    final target = _clamp(Offset(
      goRight ? _bounds.right : _bounds.left,
      cur.dy + v.dy * 0.08,
    ));

    _snapAnim = Tween<Offset>(begin: cur, end: target).animate(
      CurvedAnimation(parent: _snap, curve: Curves.easeOutCubic),
    );
    setState(() => _dragging = false);
    HapticFeedback.lightImpact();
    _snap
      ..reset()
      ..forward();
  }

  Future<void> _open() async {
    if (_sheetOpen) return;
    HapticFeedback.mediumImpact();
    final ctx = widget.navigatorKey?.currentContext ?? context;
    setState(() => _sheetOpen = true);
    try {
      await showModalBottomSheet<void>(
        context: ctx,
        isScrollControlled: true,
        useSafeArea: false,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withOpacity(0.55),
        builder: (sheetCtx) => _ApexAiSheet(
          items: widget.items,
          onOpenItem: (item) {
            Navigator.of(sheetCtx).pop();
            widget.onOpenItem(item);
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _sheetOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.hasBoundedWidth ? c.maxWidth : mq.size.width;
        final h = c.hasBoundedHeight ? c.maxHeight : mq.size.height;

        final minX = _margin;
        final maxX = math.max(minX, w - _size - _margin);
        final minY = mq.padding.top + _margin;
        final maxY = math.max(minY, h - _size - mq.padding.bottom - _margin);
        _bounds = Rect.fromLTRB(minX, minY, maxX, maxY);

        _pos ??= Offset(maxX, minY + (maxY - minY) * 0.62);
        final pos = _clamp(_pos!);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: pos.dx,
              top: pos.dy,
              width: _size,
              height: _size,
              child: IgnorePointer(
                ignoring: _sheetOpen,
                child: AnimatedOpacity(
                  opacity: _sheetOpen ? 0 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: Semantics(
                    button: true,
                    label: 'APEX AI ассистент',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _open,
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: _OrbBody(pulse: _pulse, dragging: _dragging),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OrbBody extends StatelessWidget {
  const _OrbBody({required this.pulse, required this.dragging});

  final Animation<double> pulse;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: pulse,
        builder: (_, __) {
          final t = pulse.value;
          final breathe = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
          final scale = (dragging ? 1.1 : 1.0) + 0.045 * breathe;

          return Transform.scale(
            scale: scale,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                IgnorePointer(
                  child: Transform.scale(
                    scale: 1 + 0.75 * t,
                    child: Opacity(
                      opacity: ((1 - t) * 0.4).clamp(0.0, 1.0),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ApexPalette.lime,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: ApexPalette.accentGradient,
                    border: Border.all(
                      color: ApexPalette.lime.withOpacity(0.7 + 0.3 * breathe),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ApexPalette.accent
                            .withOpacity(0.35 + 0.25 * breathe),
                        blurRadius: 18 + 14 * breathe,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: const Alignment(-0.45, -0.6),
                                radius: 0.9,
                                colors: [
                                  Colors.white.withOpacity(0.32),
                                  Colors.white.withOpacity(0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const ApexMark(size: 26, glow: false),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  ШТОРКА APEX AI
// ════════════════════════════════════════════════════════════════════

enum _SendState { idle, sending, sent }

class _ChatMsg {
  _ChatMsg.user(this.text)
      : isUser = true,
        reply = null,
        isError = false;

  _ChatMsg.ai(this.text, {this.reply, this.isError = false}) : isUser = false;

  final String text;
  final bool isUser;
  final bool isError;
  final AiAssistantReply? reply;
  _SendState sendState = _SendState.idle;
}

class _ApexAiSheet extends StatefulWidget {
  const _ApexAiSheet({required this.items, required this.onOpenItem});

  final List<MarketItem> items;
  final ValueChanged<MarketItem> onOpenItem;

  @override
  State<_ApexAiSheet> createState() => _ApexAiSheetState();
}

class _ApexAiSheetState extends State<_ApexAiSheet> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_ChatMsg> _msgs = [
    _ChatMsg.ai(
      'Привет! Я APEX AI. Помогу найти выгодный товар, оценю цену и '
      'подготовлю сообщение продавцу. Что ищем?',
    ),
  ];

  bool _full = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _ask(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _loading) return;
    HapticFeedback.selectionClick();
    _input.clear();
    setState(() {
      _msgs.add(_ChatMsg.user(text));
      _loading = true;
    });
    _scrollDown();

    try {
      final reply = await ApexStorage().askApexOrb(text, widget.items);
      if (!mounted) return;
      setState(() {
        _msgs.add(_ChatMsg.ai(_replyText(reply), reply: reply));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _msgs.add(_ChatMsg.ai(
          'Не удалось получить ответ. Проверьте соединение и попробуйте ещё раз.',
          isError: true,
        ));
        _loading = false;
      });
    }
    _scrollDown();
  }

  Future<void> _sendDraft(_ChatMsg msg) async {
    final a = msg.reply?.suggestedSellerAction;
    if (a == null || msg.sendState != _SendState.idle) return;
    setState(() => msg.sendState = _SendState.sending);

    try {
      await _sendSellerDraftAction(a);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => msg.sendState = _SendState.sent);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        msg.sendState = _SendState.idle;
        _msgs.add(_ChatMsg.ai(
          'Не получилось отправить сообщение продавцу. Попробуйте ещё раз.',
          isError: true,
        ));
      });
      _scrollDown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ApexPalette.of(context);
    final mq = MediaQuery.of(context);
    final avail = mq.size.height - mq.viewInsets.bottom - mq.padding.top;
    final target = mq.size.height * (_full ? 0.94 : 0.55);
    final h = math.min(target, avail);
    final prompts = AppConfig.aiQuickPrompts;
    final bottomSafe = mq.viewInsets.bottom > 0 ? 0.0 : mq.padding.bottom;

    return MediaQuery(
      data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.15)),
      child: Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeOutCubic,
          height: h,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: p.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: ApexPalette.accent.withOpacity(0.55),
                width: 1.2,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: ApexPalette.accent.withOpacity(0.22),
                blurRadius: 40,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              _buildHeader(p),
              if (prompts.isNotEmpty) _buildChips(p, prompts),
              Divider(height: 1, color: p.border),
              Expanded(child: _buildChat(p)),
              _buildInput(p, bottomSafe),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ApexPalette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 12, 10),
      child: Row(
        children: [
          const ApexMark(size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text('APEX',
                        style: displayStyle(18,
                            color: p.text, letterSpacing: 0.8)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: ApexPalette.lime,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'AI',
                        style: monoStyle(11,
                            color: const Color(0xFF08080B),
                            weight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const _PulseDot(),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        AppConfig.defaultAiModel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: monoStyle(11,
                            color: p.muted, weight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _HeaderButton(
            icon: _full ? LucideIcons.minimize2 : LucideIcons.maximize2,
            tooltip: _full ? 'Пол-экрана' : 'Во весь экран',
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _full = !_full);
            },
          ),
          const SizedBox(width: 8),
          _HeaderButton(
            icon: LucideIcons.x,
            tooltip: 'Закрыть',
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  Widget _buildChips(ApexPalette p, List<String> prompts) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        itemCount: prompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _QuickChip(
          label: prompts[i],
          onTap: _loading ? null : () => _ask(prompts[i]),
        ),
      ),
    );
  }

  Widget _buildChat(ApexPalette p) {
    final count = _msgs.length + (_loading ? 1 : 0);
    return ListView.builder(
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      itemCount: count,
      itemBuilder: (context, i) {
        if (i >= _msgs.length) return const _TypingBubble();
        final m = _msgs[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: m.isUser ? _UserBubble(text: m.text) : _buildAiBlock(m),
        );
      },
    );
  }

  Widget _buildAiBlock(_ChatMsg m) {
    final items =
        m.reply == null ? const <MarketItem>[] : _replyItems(m.reply!);
    final action = m.reply?.suggestedSellerAction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AiBubble(text: m.text, isError: m.isError),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ItemsCarousel(items: items, onOpen: widget.onOpenItem),
        ],
        if (action != null) ...[
          const SizedBox(height: 12),
          _SellerDraftCard(
            peerUsername: _actionUsername(action),
            peerTitle: _actionTitle(action),
            draftText: _actionDraft(action),
            state: m.sendState,
            onSend: () => _sendDraft(m),
          ),
        ],
      ],
    );
  }

  Widget _buildInput(ApexPalette p, double bottomSafe) {
    final canSend = _input.text.trim().isNotEmpty && !_loading;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 12 + bottomSafe),
      decoration: BoxDecoration(
        color: p.bg,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: p.surfaceAlt,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: p.border),
              ),
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: _ask,
                cursorColor: ApexPalette.accent,
                style: bodyStyle(14.5, color: p.text, height: 1.35),
                decoration: InputDecoration(
                  hintText: 'Спросите APEX AI…',
                  hintStyle: bodyStyle(14.5, color: p.muted),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SendButton(
            enabled: canSend,
            loading: _loading,
            onTap: () => _ask(_input.text),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  МЕЛКИЕ КОМПОНЕНТЫ ШАПКИ И ВВОДА
// ════════════════════════════════════════════════════════════════════

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = ApexPalette.of(context);
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: p.surfaceAlt,
            shape: BoxShape.circle,
            border: Border.all(color: p.border),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Icon(icon, key: ValueKey(icon), size: 17, color: p.soft),
          ),
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: ApexPalette.green,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: ApexPalette.green.withOpacity(0.3 + 0.4 * _c.value),
              blurRadius: 4 + 5 * _c.value,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChip extends StatefulWidget {
  const _QuickChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  State<_QuickChip> createState() => _QuickChipState();
}

class _QuickChipState extends State<_QuickChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = ApexPalette.of(context);
    final enabled = widget.onTap != null;
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.5,
      duration: const Duration(milliseconds: 150),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1,
        duration: const Duration(milliseconds: 110),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _pressed
                    ? ApexPalette.accent
                    : ApexPalette.accent.withOpacity(0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.sparkles, size: 13, color: p.accentText),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        bodyStyle(12.5, color: p.soft, weight: FontWeight.w600),
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

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = ApexPalette.of(context);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: enabled ? ApexPalette.accentGradient : null,
          color: enabled ? null : p.surfaceAlt,
          shape: BoxShape.circle,
          border: Border.all(color: enabled ? Colors.white24 : p.border),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: ApexPalette.accent.withOpacity(0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation(p.muted),
                  ),
                )
              : Icon(
                  LucideIcons.arrowUp,
                  size: 20,
                  color: enabled ? Colors.white : p.muted,
                ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  ПУЗЫРИ СООБЩЕНИЙ
// ════════════════════════════════════════════════════════════════════

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width * 0.78;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            gradient: ApexPalette.accentGradient,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
            boxShadow: [
              BoxShadow(
                color: ApexPalette.accent.withOpacity(0.32),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            text,
            style: bodyStyle(14.5,
                color: Colors.white, weight: FontWeight.w600, height: 1.4),
          ),
        ),
      ),
    );
  }
}

class _AiAvatar extends StatelessWidget {
  const _AiAvatar();

  @override
  Widget build(BuildContext context) {
    final p = ApexPalette.of(context);
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        shape: BoxShape.circle,
        border: Border.all(color: p.border),
      ),
      alignment: Alignment.center,
      child: const ApexMark(size: 15, glow: false),
    );
  }
}

class _AiBubble extends StatelessWidget {
  const _AiBubble({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final p = ApexPalette.of(context);
    final maxW = MediaQuery.of(context).size.width * 0.74;
    final bar = isError ? ApexPalette.danger : ApexPalette.lime;
    const r = BorderRadius.only(
      topLeft: Radius.circular(6),
      topRight: Radius.circular(20),
      bottomLeft: Radius.circular(20),
      bottomRight: Radius.circular(20),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AiAvatar(),
        const SizedBox(width: 8),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Container(
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: r,
                border: Border.all(color: p.border),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  topRight: Radius.circular(19),
                  bottomLeft: Radius.circular(19),
                  bottomRight: Radius.circular(19),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 3,
                      child: ColoredBox(color: bar),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 11, 14, 11),
                      child: Text(
                        text,
                        style: bodyStyle(
                          14.5,
                          color: isError ? ApexPalette.danger : p.text,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ApexPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          const _AiAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.border),
            ),
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final phase = (_c.value - i * 0.16) % 1.0;
                  final k = math.max(0.0, math.sin(phase * math.pi));
                  return Container(
                    width: 7,
                    height: 7,
                    margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(p.muted, ApexPalette.lime, k),
                    ),
                    transform: Matrix4.translationValues(0, -4 * k, 0),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  КАРУСЕЛЬ ТОВАРОВ
// ════════════════════════════════════════════════════════════════════

class _ItemsCarousel extends StatelessWidget {
  const _ItemsCarousel({required this.items, required this.onOpen});

  final List<MarketItem> items;
  final ValueChanged<MarketItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final p = ApexPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.search, size: 14, color: p.accentText),
            const SizedBox(width: 6),
            Text(
              'НАЙДЕНО · ${items.length}',
              style: monoStyle(11, color: p.muted, weight: FontWeight.w700)
                  .copyWith(letterSpacing: 0.8),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 212,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _MiniItemCard(
              item: items[i],
              onTap: () => onOpen(items[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniItemCard extends StatefulWidget {
  const _MiniItemCard({required this.item, required this.onTap});

  final MarketItem item;
  final VoidCallback onTap;

  @override
  State<_MiniItemCard> createState() => _MiniItemCardState();
}

class _MiniItemCardState extends State<_MiniItemCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = ApexPalette.of(context);
    final it = widget.item;

    return AnimatedScale(
      scale: _pressed ? 0.96 : 1,
      duration: const Duration(milliseconds: 110),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: Container(
          width: 152,
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _pressed ? ApexPalette.accent : p.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ItemThumb(
                source: _itemCover(it),
                height: 104,
                width: double.infinity,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(17)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _itemTitle(it),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: bodyStyle(12.5,
                            color: p.text, weight: FontWeight.w700, height: 1.25),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatRub(_itemPrice(it)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: monoStyle(13.5,
                                color: p.priceColor, weight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(LucideIcons.mapPin,
                                  size: 11, color: p.muted),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  _itemCity(it),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: bodyStyle(11,
                                      color: p.muted, weight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  КАРТОЧКА ЧЕРНОВИКА ДЛЯ ПРОДАВЦА
// ════════════════════════════════════════════════════════════════════

class _SellerDraftCard extends StatelessWidget {
  const _SellerDraftCard({
    required this.peerUsername,
    required this.peerTitle,
    required this.draftText,
    required this.state,
    required this.onSend,
  });

  final String peerUsername;
  final String peerTitle;
  final String draftText;
  final _SendState state;
  final VoidCallback onSend;

  static const LinearGradient _greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF34D673), ApexPalette.green],
  );

  @override
  Widget build(BuildContext context) {
    final p = ApexPalette.of(context);
    final sent = state == _SendState.sent;
    final initial = peerTitle.trim().isEmpty
        ? '?'
        : peerTitle.trim().characters.first.toUpperCase();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              (sent ? ApexPalette.green : ApexPalette.accent).withOpacity(0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (sent ? ApexPalette.green : ApexPalette.accent)
                .withOpacity(0.12),
            blurRadius: 22,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.fileText, size: 14, color: p.accentText),
              const SizedBox(width: 6),
              Text(
                'ЧЕРНОВИК СООБЩЕНИЯ',
                style: monoStyle(11, color: p.muted, weight: FontWeight.w700)
                    .copyWith(letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: ApexPalette.accentGradient,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initial,
                  style: displayStyle(15, color: Colors.white, letterSpacing: 0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      peerTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          bodyStyle(14, color: p.text, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '@$peerUsername',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: monoStyle(11.5,
                          color: p.muted, weight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.border),
            ),
            child: Text(
              draftText,
              style: bodyStyle(13.5, color: p.soft, height: 1.45),
            ),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            child: sent
                ? ApexPrimaryButton(
                    key: const ValueKey('sent'),
                    label: 'Отправлено ✓',
                    height: 48,
                    gradient: _greenGradient,
                    onPressed: _noop,
                  )
                : ApexPrimaryButton(
                    key: ValueKey('send-${state.name}'),
                    label: 'Отправить продавцу сейчас',
                    icon: LucideIcons.send,
                    height: 48,
                    loading: state == _SendState.sending,
                    onPressed: onSend,
                  ),
          ),
        ],
      ),
    );
  }

  static void _noop() {}
}
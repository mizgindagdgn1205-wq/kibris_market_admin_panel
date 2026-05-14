import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/listing.dart';
import '../providers/listing_provider.dart';
import '../theme/app_theme.dart';

class WebAdminMessages extends StatefulWidget {
  const WebAdminMessages({super.key});

  @override
  State<WebAdminMessages> createState() => _WebAdminMessagesState();
}

class _WebAdminMessagesState extends State<WebAdminMessages>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _db = FirebaseFirestore.instance;

  String? _selId;
  bool _selIsSupport = false;
  String _selTitle = '';
  String _selSubtitle = '';

  final _replyCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  String _search = '';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      if (_tab.indexIsChanging) setState(() { _selId = null; _selTitle = ''; _selSubtitle = ''; });
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _replyCtrl.dispose();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _select(String id, bool isSupport, String title, String subtitle) =>
      setState(() { _selId = id; _selIsSupport = isSupport; _selTitle = title; _selSubtitle = subtitle; });

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty || _selId == null || _sending) return;
    setState(() => _sending = true);
    _replyCtrl.clear();
    final col = _selIsSupport ? 'support' : 'chats';
    await _db.collection(col).doc(_selId).collection('messages').add({
      'senderId': 'admin',
      'senderName': 'Admin',
      'text': text,
      'sentAt': FieldValue.serverTimestamp(),
      'isAdmin': true,
    });
    await _db.collection(col).doc(_selId).update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      if (_selIsSupport) 'unreadByAdmin': false,
      if (_selIsSupport) 'unreadByUser': true,
    });
    setState(() => _sending = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _markRead(String id) async {
    await _db.collection('support').doc(id).update({'unreadByAdmin': false});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Üst istatistik bar ───────────────────────────────────────────
        _StatsBar(db: _db),

        Expanded(
          child: Row(
            children: [
              // ── Sol: konuşma listesi ───────────────────────────────────
              Container(
                width: 320,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(right: BorderSide(color: AppColors.divider)),
                ),
                child: Column(
                  children: [
                    // Arama
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _search = v.toLowerCase()),
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Kullanıcı veya ilan ara...',
                          hintStyle: const TextStyle(fontSize: 13),
                          prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textLight),
                          suffixIcon: _search.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); },
                                )
                              : null,
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    // Tab bar
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.divider)),
                      ),
                      child: TabBar(
                        controller: _tab,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: AppColors.textLight,
                        indicatorColor: AppColors.primary,
                        indicatorWeight: 2,
                        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        unselectedLabelStyle: const TextStyle(fontSize: 12),
                        tabs: const [
                          Tab(text: 'Destek'),
                          Tab(text: 'Kullanıcı Sohbetleri'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tab,
                        children: [
                          _SupportList(db: _db, search: _search, selId: _selId, onSelect: _select, onMarkRead: _markRead),
                          _ChatList(db: _db, search: _search, selId: _selId, onSelect: _select),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Sağ: mesaj paneli ─────────────────────────────────────
              Expanded(
                child: _selId == null
                    ? const _EmptyPane()
                    : _ChatPane(
                        db: _db,
                        chatId: _selId!,
                        isSupport: _selIsSupport,
                        title: _selTitle,
                        subtitle: _selSubtitle,
                        replyCtrl: _replyCtrl,
                        scrollCtrl: _scrollCtrl,
                        onSend: _sendReply,
                        sending: _sending,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── İstatistik Bar ────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final FirebaseFirestore db;
  const _StatsBar({required this.db});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          const Text('Mesajlar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(width: 20),
          StreamBuilder<QuerySnapshot>(
            stream: db.collection('support').snapshots(),
            builder: (ctx, snap) {
              final total = snap.data?.docs.length ?? 0;
              final unread = snap.data?.docs.where((d) {
                return (d.data() as Map)['unreadByAdmin'] == true;
              }).length ?? 0;
              final today = snap.data?.docs.where((d) {
                final t = ((d.data() as Map)['lastMessageTime'] as Timestamp?)?.toDate();
                if (t == null) return false;
                final now = DateTime.now();
                return t.year == now.year && t.month == now.month && t.day == now.day;
              }).length ?? 0;
              return Row(children: [
                _StatChip(label: 'Toplam Destek', value: '$total', color: AppColors.primary),
                const SizedBox(width: 8),
                _StatChip(label: 'Bekleyen Yanıt', value: '$unread', color: unread > 0 ? AppColors.error : AppColors.success),
                const SizedBox(width: 8),
                _StatChip(label: 'Bugün Aktif', value: '$today', color: AppColors.warning),
              ]);
            },
          ),
          const Spacer(),
          StreamBuilder<QuerySnapshot>(
            stream: db.collection('chats').snapshots(),
            builder: (ctx, snap) {
              final count = snap.data?.docs.length ?? 0;
              return _StatChip(label: 'Kullanıcı Sohbeti', value: '$count', color: const Color(0xFF0891B2));
            },
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
      ]),
    );
  }
}

// ── Destek listesi ────────────────────────────────────────────────────────────

class _SupportList extends StatelessWidget {
  final FirebaseFirestore db;
  final String search;
  final String? selId;
  final void Function(String, bool, String, String) onSelect;
  final Future<void> Function(String) onMarkRead;
  const _SupportList({required this.db, required this.search, required this.selId, required this.onSelect, required this.onMarkRead});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('support').orderBy('lastMessageTime', descending: true).snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snap.data!.docs;
        if (search.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return (data['userName'] as String? ?? '').toLowerCase().contains(search);
          }).toList();
        }
        if (docs.isEmpty) {
          return const _ListEmpty(text: 'Henüz destek mesajı yok', icon: Icons.support_agent_outlined);
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (c, i) => const Divider(height: 1, indent: 16, endIndent: 16),
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final id = docs[i].id;
            final name = d['userName'] as String? ?? 'Kullanıcı';
            final last = d['lastMessage'] as String? ?? '';
            final unread = d['unreadByAdmin'] as bool? ?? false;
            final time = (d['lastMessageTime'] as Timestamp?)?.toDate();
            return _ConvTile(
              id: id,
              isSelected: selId == id,
              avatarText: name.isNotEmpty ? name[0].toUpperCase() : '?',
              avatarColor: AppColors.primary,
              title: name,
              subtitle: last.isEmpty ? 'Mesaj başlatıldı' : last,
              tag: 'Destek',
              tagColor: AppColors.primary,
              time: time,
              unread: unread,
              onTap: () {
                if (unread) onMarkRead(id);
                onSelect(id, true, name, 'Kullanıcı Destek Konuşması');
              },
            );
          },
        );
      },
    );
  }
}

// ── Kullanıcı sohbet listesi ──────────────────────────────────────────────────

class _ChatList extends StatelessWidget {
  final FirebaseFirestore db;
  final String search;
  final String? selId;
  final void Function(String, bool, String, String) onSelect;
  const _ChatList({required this.db, required this.search, required this.selId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('chats').orderBy('lastMessageTime', descending: true).snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snap.data!.docs;
        if (search.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final names = (data['participantNames'] as Map?)?.values.join(' ').toLowerCase() ?? '';
            final title = (data['listingTitle'] as String? ?? '').toLowerCase();
            return names.contains(search) || title.contains(search);
          }).toList();
        }
        if (docs.isEmpty) {
          return const _ListEmpty(text: 'Henüz kullanıcı sohbeti yok', icon: Icons.people_outline);
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (c, i) => const Divider(height: 1, indent: 16, endIndent: 16),
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final id = docs[i].id;
            final names = (d['participantNames'] as Map?)?.values.cast<String>().join(' & ') ?? 'Kullanıcılar';
            final listing = d['listingTitle'] as String? ?? '';
            final last = d['lastMessage'] as String? ?? '';
            final time = (d['lastMessageTime'] as Timestamp?)?.toDate();
            final initials = names.isNotEmpty ? names[0].toUpperCase() : '?';
            return _ConvTile(
              id: id,
              isSelected: selId == id,
              avatarText: initials,
              avatarColor: const Color(0xFF0891B2),
              title: names,
              subtitle: last.isEmpty ? 'Sohbet başlatıldı' : last,
              tag: listing.isNotEmpty ? listing : null,
              tagColor: const Color(0xFF0891B2),
              time: time,
              unread: false,
              onTap: () => onSelect(id, false, names, listing.isNotEmpty ? '📌 $listing' : 'Kullanıcı Sohbeti'),
            );
          },
        );
      },
    );
  }
}

// ── Konuşma listesi öğesi ─────────────────────────────────────────────────────

class _ConvTile extends StatelessWidget {
  final String id, avatarText, title, subtitle;
  final String? tag;
  final Color avatarColor;
  final Color? tagColor;
  final bool isSelected, unread;
  final DateTime? time;
  final VoidCallback onTap;

  const _ConvTile({
    required this.id, required this.avatarText, required this.title,
    required this.subtitle, required this.avatarColor, required this.isSelected,
    required this.unread, required this.time, required this.onTap,
    this.tag, this.tagColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isSelected
        ? AppColors.primary.withValues(alpha: 0.06)
        : Colors.white;
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(children: [
          // Avatar
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: avatarColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(avatarText,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: avatarColor)),
              ),
              if (unread)
                Positioned(
                  top: -3, right: -3,
                  child: Container(
                    width: 14, height: 14,
                    decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Text('!', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13,
                          fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary)),
                ),
                if (time != null)
                  Text(_timeLabel(time!), style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
              ]),
              const SizedBox(height: 3),
              if (tag != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('📌 $tag',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: tagColor ?? AppColors.primary, fontWeight: FontWeight.w500)),
                ),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11,
                      color: unread ? AppColors.primary : AppColors.textLight,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.normal)),
            ]),
          ),
        ]),
      ),
    );
  }

  String _timeLabel(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk';
    if (diff.inHours < 24) return '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
    if (diff.inDays < 7) return '${diff.inDays}g önce';
    return '${t.day}.${t.month}';
  }
}

// ── Mesaj paneli ──────────────────────────────────────────────────────────────

class _ChatPane extends StatefulWidget {
  final FirebaseFirestore db;
  final String chatId, title, subtitle;
  final bool isSupport;
  final TextEditingController replyCtrl;
  final ScrollController scrollCtrl;
  final VoidCallback onSend;
  final bool sending;
  const _ChatPane({required this.db, required this.chatId, required this.title,
    required this.subtitle, required this.isSupport, required this.replyCtrl,
    required this.scrollCtrl, required this.onSend, required this.sending});

  @override
  State<_ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<_ChatPane> {
  final List<String> _quickReplies = [
    'Merhaba! Size nasıl yardımcı olabiliriz?',
    'Talebinizi inceliyoruz, kısa sürede dönüş yapacağız.',
    'Sorunuz için teşekkürler. İlanınız onaylanmıştır.',
    'Daha fazla bilgi için lütfen iletişimde kalın.',
    'Bu konuda yardımcı olmaktan memnuniyet duyarız.',
  ];

  void _applyQuickReply(String text) {
    widget.replyCtrl.text = text;
    widget.replyCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final col = widget.isSupport ? 'support' : 'chats';

    return Column(children: [
      // ── Header ──────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: (widget.isSupport ? AppColors.primary : const Color(0xFF0891B2)).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.isSupport ? Icons.support_agent : Icons.people_outline,
                size: 20, color: widget.isSupport ? AppColors.primary : const Color(0xFF0891B2)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            Text(widget.subtitle,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
          ])),
          if (!widget.isSupport)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.visibility_outlined, size: 13, color: AppColors.warning),
                SizedBox(width: 5),
                Text('Sadece İzleme', style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600)),
              ]),
            ),
        ]),
      ),

      // ── Kullanıcı ilanları şeridi (sadece destek sohbetinde) ────────
      if (widget.isSupport)
        _UserListingsBar(db: widget.db, userId: widget.chatId),

      // ── Mesajlar ────────────────────────────────────────────────────
      Expanded(
        child: Container(
          color: const Color(0xFFF8FAFC),
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.db.collection(col).doc(widget.chatId).collection('messages')
                .orderBy('sentAt').snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final msgs = snap.data!.docs;
              if (msgs.isEmpty) {
                return const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.chat_bubble_outline, size: 40, color: AppColors.textLight),
                    SizedBox(height: 10),
                    Text('Henüz mesaj yok', style: TextStyle(fontSize: 13, color: AppColors.textLight)),
                  ]),
                );
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (widget.scrollCtrl.hasClients) {
                  widget.scrollCtrl.jumpTo(widget.scrollCtrl.position.maxScrollExtent);
                }
              });
              return ListView.builder(
                controller: widget.scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                itemCount: msgs.length,
                itemBuilder: (_, i) {
                  final d = msgs[i].data() as Map<String, dynamic>;
                  final isAdmin = d['isAdmin'] as bool? ?? false;
                  final text = d['text'] as String? ?? '';
                  final sender = d['senderName'] as String? ?? (isAdmin ? 'Admin' : 'Kullanıcı');
                  final time = (d['sentAt'] as Timestamp?)?.toDate();

                  // Tarih ayırıcı
                  Widget? dateSep;
                  if (i == 0 && time != null) {
                    dateSep = _DateDivider(date: time);
                  } else if (i > 0 && time != null) {
                    final prevTime = (msgs[i - 1].data() as Map)['sentAt'] as Timestamp?;
                    final prev = prevTime?.toDate();
                    if (prev != null &&
                        (time.day != prev.day || time.month != prev.month || time.year != prev.year)) {
                      dateSep = _DateDivider(date: time);
                    }
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (dateSep case final sep?) sep,
                      _Bubble(text: text, sender: sender, isAdmin: isAdmin, time: time),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),

      // ── Yanıt alanı ─────────────────────────────────────────────────
      if (widget.isSupport)
        Column(children: [
          // Hızlı yanıtlar
          Container(
            height: 36,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _quickReplies.length,
              separatorBuilder: (c, i) => const SizedBox(width: 6),
              itemBuilder: (_, i) => Center(
                child: InkWell(
                  onTap: () => _applyQuickReply(_quickReplies[i]),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Text(_quickReplies[i],
                        maxLines: 1,
                        style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          // Input
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            color: Colors.white,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: (e) {
                    if (e is KeyDownEvent &&
                        e.logicalKey == LogicalKeyboardKey.enter &&
                        HardwareKeyboard.instance.isShiftPressed) {
                      // yeni satır — varsayılan davranış
                    }
                  },
                  child: TextField(
                    controller: widget.replyCtrl,
                    onSubmitted: (_) => widget.onSend(),
                    maxLines: 4,
                    minLines: 1,
                    style: const TextStyle(fontSize: 13),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Kullanıcıya yanıt yaz... (Enter = Gönder)',
                      hintStyle: const TextStyle(fontSize: 12, color: AppColors.textLight),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: widget.sending ? null : widget.onSend,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: widget.sending ? AppColors.textLight : AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: widget.sending
                      ? const Padding(padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                ),
              ),
            ]),
          ),
        ])
      else
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.lock_outline, size: 14, color: AppColors.textLight.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            const Text('Bu sohbet sadece izleme modundadır — kullanıcılar arası konuşmaya müdahale edilemez.',
                style: TextStyle(fontSize: 12, color: AppColors.textLight)),
          ]),
        ),
    ]);
  }
}

// ── Tarih ayırıcı ─────────────────────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  String _label() {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Bugün';
    if (diff.inDays == 1) return 'Dün';
    return '${date.day}.${date.month.toString().padLeft(2,'0')}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(_label(), style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
          ),
        ),
        const Expanded(child: Divider()),
      ]),
    );
  }
}

// ── Mesaj balonu ──────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final String text, sender;
  final bool isAdmin;
  final DateTime? time;
  const _Bubble({required this.text, required this.sender, required this.isAdmin, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isAdmin)
            Padding(
              padding: const EdgeInsets.only(left: 44, bottom: 4),
              child: Text(sender,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            ),
          Row(
            mainAxisAlignment: isAdmin ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isAdmin) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(sender.isNotEmpty ? sender[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
                const SizedBox(width: 8),
              ],
              if (isAdmin) ...[
                Text(time != null ? _fmt(time!) : '',
                    style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: const BoxConstraints(maxWidth: 520),
                  decoration: BoxDecoration(
                    color: isAdmin ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isAdmin ? 16 : 4),
                      bottomRight: Radius.circular(isAdmin ? 4 : 16),
                    ),
                    border: isAdmin ? null : Border.all(color: AppColors.divider),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Text(text,
                      style: TextStyle(fontSize: 13, color: isAdmin ? Colors.white : AppColors.textPrimary, height: 1.45)),
                ),
              ),
            ],
          ),
          if (!isAdmin)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 3),
              child: Text(time != null ? _fmt(time!) : '',
                  style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
            ),
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 4, top: 3),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.done_all, size: 12, color: AppColors.primary),
                SizedBox(width: 3),
                Text('Admin', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w500)),
              ]),
            ),
        ],
      ),
    );
  }

  String _fmt(DateTime t) {
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
    }
    return '${t.day}.${t.month}  ${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
  }
}

// ── Boş ekran ─────────────────────────────────────────────────────────────────

class _EmptyPane extends StatelessWidget {
  const _EmptyPane();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.mark_chat_read_outlined, size: 64, color: AppColors.textLight),
          SizedBox(height: 16),
          Text('Konuşma Seçin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          SizedBox(height: 6),
          Text('Sol panelden bir destek veya kullanıcı sohbeti açın.',
              style: TextStyle(fontSize: 12, color: AppColors.textLight)),
        ]),
      ),
    );
  }
}

// ── Kullanıcı ilanları yatay şeridi ──────────────────────────────────────────

class _UserListingsBar extends StatelessWidget {
  final FirebaseFirestore db;
  final String userId;
  const _UserListingsBar({required this.db, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('listings').where('sellerId', isEqualTo: userId).snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox.shrink();
        final listings = snap.data!.docs.map(Listing.fromFirestore).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF0F4FF),
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  const Icon(Icons.storefront_outlined, size: 14, color: AppColors.primary),
                  const SizedBox(width: 5),
                  Text('Kullanıcının ${listings.length} ilanı',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ]),
              ),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: listings.length,
                  separatorBuilder: (c, i) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _ListingCard(
                    listing: listings[i],
                    onTap: () => _showDetail(context, listings[i]),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDetail(BuildContext context, Listing listing) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _ListingQuickDialog(listing: listing),
    );
  }
}

// ── İlan kart (yatay şerit) ───────────────────────────────────────────────────

class _ListingCard extends StatelessWidget {
  final Listing listing;
  final VoidCallback onTap;
  const _ListingCard({required this.listing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imgUrl = listing.imageUrls.isNotEmpty ? listing.imageUrls.first : null;
    final statusColor = switch (listing.status) {
      ListingStatus.active  => AppColors.success,
      ListingStatus.pending => AppColors.warning,
      ListingStatus.sold    => AppColors.error,
      ListingStatus.expired => AppColors.textLight,
    };
    final statusLabel = switch (listing.status) {
      ListingStatus.active  => 'Aktif',
      ListingStatus.pending => 'Bekliyor',
      ListingStatus.sold    => 'Satıldı',
      ListingStatus.expired => 'Süresi Doldu',
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            // Kapak resmi
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
              child: SizedBox(
                width: 60, height: 90,
                child: imgUrl != null
                    ? Image.network(imgUrl, fit: BoxFit.cover,
                        errorBuilder: (ctx, e, s) => const _NoImage())
                    : const _NoImage(),
              ),
            ),
            // Bilgi
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(listing.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(listing.formattedPrice,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(statusLabel,
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: statusColor)),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoImage extends StatelessWidget {
  const _NoImage();
  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.background,
    child: const Icon(Icons.image_not_supported_outlined, size: 22, color: AppColors.textLight),
  );
}

// ── İlan hızlı detay dialogu ──────────────────────────────────────────────────

class _ListingQuickDialog extends StatefulWidget {
  final Listing listing;
  const _ListingQuickDialog({required this.listing});

  @override
  State<_ListingQuickDialog> createState() => _ListingQuickDialogState();
}

class _ListingQuickDialogState extends State<_ListingQuickDialog> {
  int _imgIdx = 0;
  late Listing _listing;

  @override
  void initState() {
    super.initState();
    _listing = widget.listing;
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}  '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _typeLabel(ListingType t) => switch (t) {
    ListingType.sell   => 'Satılık',
    ListingType.rent   => 'Kiralık',
    ListingType.wanted => 'Aranıyor',
  };

  Future<void> _doAction(BuildContext context, Future<void> Function() action) async {
    await action();
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('İlanı Sil'),
        content: Text('"${_listing.title}" ilanını silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<ListingProvider>().deleteListing(_listing.id);
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _listing;
    final prov = context.read<ListingProvider>();
    final screenW = MediaQuery.of(context).size.width;
    final dialogW = (screenW * 0.82).clamp(760.0, 1100.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: Colors.white,
      child: SizedBox(
        width: dialogW,
        height: 590,
        child: Row(
          children: [
            // ── Sol: koyu resim paneli ────────────────────────────────
            Container(
              width: dialogW * 0.42,
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.horizontal(left: Radius.circular(14)),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: l.imageUrls.isEmpty
                        ? const Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.image_outlined, size: 56, color: Color(0xFF334155)),
                              SizedBox(height: 8),
                              Text('Resim yok', style: TextStyle(color: Color(0xFF475569), fontSize: 13)),
                            ]),
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(14)),
                                child: CachedNetworkImage(
                                  imageUrl: l.imageUrls[_imgIdx],
                                  fit: BoxFit.contain,
                                  errorWidget: (c, u, e) => const Center(
                                      child: Icon(Icons.broken_image_outlined, color: Color(0xFF475569), size: 48)),
                                ),
                              ),
                              if (l.imageUrls.length > 1)
                                Positioned(
                                  top: 12, right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text('${_imgIdx + 1} / ${l.imageUrls.length}',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              if (l.imageUrls.length > 1) ...[
                                Positioned(
                                  left: 8, top: 0, bottom: 0,
                                  child: Center(child: _MsgArrowBtn(
                                    Icons.chevron_left,
                                    _imgIdx > 0,
                                    () => setState(() => _imgIdx--),
                                  )),
                                ),
                                Positioned(
                                  right: 8, top: 0, bottom: 0,
                                  child: Center(child: _MsgArrowBtn(
                                    Icons.chevron_right,
                                    _imgIdx < l.imageUrls.length - 1,
                                    () => setState(() => _imgIdx++),
                                  )),
                                ),
                              ],
                            ],
                          ),
                  ),
                  // Thumbnail şeridi
                  if (l.imageUrls.length > 1)
                    Container(
                      height: 72,
                      color: const Color(0xFF1E293B),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        itemCount: l.imageUrls.length,
                        itemBuilder: (c, i) => GestureDetector(
                          onTap: () => setState(() => _imgIdx = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 7),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: i == _imgIdx ? AppColors.primary : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: i == _imgIdx
                                  ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 6)]
                                  : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: CachedNetworkImage(
                                imageUrl: l.imageUrls[i], width: 52, height: 52, fit: BoxFit.cover,
                                errorWidget: (c, u, e) => Container(width: 52, height: 52, color: const Color(0xFF334155)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Sağ: bilgi + aksiyonlar ───────────────────────────────
            Expanded(
              child: Column(
                children: [
                  // Başlık bar
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 16, 14),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.divider)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.title,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              const SizedBox(height: 6),
                              Row(children: [
                                _MsgStatusChip(l.status),
                                if (l.isFeatured) ...[
                                  const SizedBox(width: 8),
                                  const StatusBadge(label: 'Öne Çıkan', color: Color(0xFFD97706), bg: Color(0xFFFFFBEB)),
                                ],
                              ]),
                            ],
                          ),
                        ),
                        // Öne çıkar
                        Tooltip(
                          message: l.isFeatured ? 'Öne çıkarmayı kaldır' : 'Öne çıkar',
                          child: IconButton(
                            icon: Icon(
                              l.isFeatured ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 22,
                              color: l.isFeatured ? AppColors.accent : AppColors.textLight,
                            ),
                            onPressed: () => _doAction(context, () => prov.toggleFeatured(l.id)),
                            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Sil
                        Tooltip(
                          message: 'İlanı Sil',
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 21, color: AppColors.error),
                            onPressed: () => _confirmDelete(context),
                            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Kapat
                        IconButton(
                          icon: const Icon(Icons.close, size: 20, color: AppColors.textLight),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  // İçerik
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Fiyat kutusu
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(children: [
                              const Icon(Icons.sell_outlined, size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text('${l.price.toStringAsFixed(0)} ${l.currency}',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ]),
                          ),
                          const SizedBox(height: 16),

                          // Bilgi tablosu
                          _MsgInfoTable(rows: [
                            ('Satıcı',        l.sellerName?.isNotEmpty == true ? l.sellerName! : l.sellerId),
                            ('Şehir',         l.location),
                            ('İlçe',          l.district.isNotEmpty ? l.district : '-'),
                            ('Kategori',      l.categoryId.isNotEmpty ? l.categoryId : '-'),
                            ('Alt Kategori',  l.subcategoryId.isNotEmpty ? l.subcategoryId : '-'),
                            ('İlan Türü',     _typeLabel(l.type)),
                            ('Tarih',         _fmt(l.createdAt)),
                            ('Görüntülenme',  '${l.viewCount}'),
                          ]),

                          if (l.attributes.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            const Text('Özellikler',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            _MsgInfoTable(rows: l.attributes.entries.map((e) => (e.key, e.value)).toList()),
                          ],

                          if (l.description.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            const Text('Açıklama',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(l.description,
                                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // Alt aksiyonlar (onay bekleyen ilanlar için)
                  if (l.status == ListingStatus.pending)
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.divider)),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: ABtn(
                            label: 'Onayla', icon: Icons.check_circle_outline,
                            color: AppColors.success,
                            onTap: () => _doAction(context,
                                () => prov.setListingStatus(l.id, ListingStatus.active)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ABtn(
                            label: 'Reddet', icon: Icons.cancel_outlined,
                            color: AppColors.error,
                            onTap: () => _doAction(context,
                                () => prov.setListingStatus(l.id, ListingStatus.expired)),
                          ),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Yardımcı: ok butonu ───────────────────────────────────────────────────────

class _MsgArrowBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _MsgArrowBtn(this.icon, this.enabled, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1.0 : 0.2,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    ),
  );
}

// ── Yardımcı: durum chip ──────────────────────────────────────────────────────

class _MsgStatusChip extends StatelessWidget {
  final ListingStatus status;
  const _MsgStatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      ListingStatus.active  => ('Aktif',          AppColors.success, const Color(0xFFECFDF5)),
      ListingStatus.pending => ('Onay Bekliyor',  AppColors.warning, const Color(0xFFFFFBEB)),
      ListingStatus.sold    => ('Satıldı',         AppColors.error,   const Color(0xFFFEF2F2)),
      ListingStatus.expired => ('Süresi Doldu',   AppColors.textLight, AppColors.background),
    };
    return StatusBadge(label: label, color: color, bg: bg);
  }
}

// ── Yardımcı: bilgi tablosu ───────────────────────────────────────────────────

class _MsgInfoTable extends StatelessWidget {
  final List<(String, String)> rows;
  const _MsgInfoTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final i = entry.key;
          final (k, v) = entry.value;
          return Container(
            decoration: BoxDecoration(
              color: i.isEven ? Colors.white : AppColors.background,
              borderRadius: BorderRadius.vertical(
                top: i == 0 ? const Radius.circular(8) : Radius.zero,
                bottom: i == rows.length - 1 ? const Radius.circular(8) : Radius.zero,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 110,
                child: Text(k,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              ),
              Expanded(
                child: Text(v.isNotEmpty ? v : '-',
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ── Liste boş durumu ──────────────────────────────────────────────────────────

class _ListEmpty extends StatelessWidget {
  final String text;
  final IconData icon;
  const _ListEmpty({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 40, color: AppColors.textLight),
        const SizedBox(height: 10),
        Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
      ]),
    );
  }
}

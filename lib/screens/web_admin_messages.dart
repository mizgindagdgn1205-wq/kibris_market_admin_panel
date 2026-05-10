import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class _Msg {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime sentAt;
  final bool isAdmin;

  const _Msg({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.sentAt,
    this.isAdmin = false,
  });
}

class _Conversation {
  final String id;
  final String participantA;
  final String participantB;
  final List<_Msg> messages;
  final bool isAdminChat;

  const _Conversation({
    required this.id,
    required this.participantA,
    required this.participantB,
    required this.messages,
    this.isAdminChat = false,
  });

  String get lastMessage => messages.isNotEmpty ? messages.last.text : '';
  DateTime? get lastTime => messages.isNotEmpty ? messages.last.sentAt : null;
}

final _kConversations = [
  _Conversation(
    id: 'conv_admin_1',
    participantA: 'Admin',
    participantB: 'Ali Yılmaz',
    isAdminChat: true,
    messages: [
      _Msg(id: 'm1', senderId: 'user1', senderName: 'Ali Yılmaz',
          text: 'Merhaba, ilanım neden onaylanmadı?',
          sentAt: DateTime.now().subtract(const Duration(hours: 2))),
      _Msg(id: 'm2', senderId: 'admin', senderName: 'Admin', isAdmin: true,
          text: 'Merhaba Ali Bey, ilanınızda fiyat bilgisi eksik. Lütfen güncelleyin.',
          sentAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 45))),
      _Msg(id: 'm3', senderId: 'user1', senderName: 'Ali Yılmaz',
          text: 'Tamam, şimdi güncelledim teşekkürler.',
          sentAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 30))),
    ],
  ),
  _Conversation(
    id: 'conv_admin_2',
    participantA: 'Admin',
    participantB: 'Fatma Kaya',
    isAdminChat: true,
    messages: [
      _Msg(id: 'm4', senderId: 'user3', senderName: 'Fatma Kaya',
          text: 'İlanımı premium yapabilir misiniz?',
          sentAt: DateTime.now().subtract(const Duration(hours: 5))),
    ],
  ),
  _Conversation(
    id: 'conv_users_1',
    participantA: 'Mehmet Demir',
    participantB: 'Ayşe Şahin',
    messages: [
      _Msg(id: 'm5', senderId: 'user2', senderName: 'Mehmet Demir',
          text: 'Merhaba, araba hâlâ satılık mı?',
          sentAt: DateTime.now().subtract(const Duration(hours: 3))),
      _Msg(id: 'm6', senderId: 'user4', senderName: 'Ayşe Şahin',
          text: 'Evet, hâlâ satılık. Görüşmek ister misiniz?',
          sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 50))),
      _Msg(id: 'm7', senderId: 'user2', senderName: 'Mehmet Demir',
          text: 'Evet, hafta sonu müsait misiniz?',
          sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 40))),
    ],
  ),
  _Conversation(
    id: 'conv_users_2',
    participantA: 'Hasan Arslan',
    participantB: 'Zeynep Çelik',
    messages: [
      _Msg(id: 'm8', senderId: 'user5', senderName: 'Hasan Arslan',
          text: 'Mobilyalar ne zaman teslim edilebilir?',
          sentAt: DateTime.now().subtract(const Duration(days: 1))),
      _Msg(id: 'm9', senderId: 'user6', senderName: 'Zeynep Çelik',
          text: 'Yarın öğleden sonra uygun.',
          sentAt: DateTime.now().subtract(const Duration(hours: 20))),
    ],
  ),
];

class WebAdminMessages extends StatefulWidget {
  const WebAdminMessages({super.key});

  @override
  State<WebAdminMessages> createState() => _WebAdminMessagesState();
}

class _WebAdminMessagesState extends State<WebAdminMessages> with SingleTickerProviderStateMixin {
  late TabController _tab;
  _Conversation? _selected;
  final _replyCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_Conversation> _conversations = List.from(_kConversations);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() => _selected = null));
  }

  @override
  void dispose() {
    _tab.dispose();
    _replyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  List<_Conversation> get _adminChats =>
      _conversations.where((c) => c.isAdminChat).toList();
  List<_Conversation> get _userChats =>
      _conversations.where((c) => !c.isAdminChat).toList();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left: conversation list
        SizedBox(
          width: 320,
          child: Column(
            children: [
              // Tab bar
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tab,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Kullanıcı-Admin'),
                          const SizedBox(width: 6),
                          if (_adminChats.isNotEmpty)
                            _CountBadge(count: _adminChats.length),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Kullanıcılar Arası'),
                          const SizedBox(width: 6),
                          if (_userChats.isNotEmpty)
                            _CountBadge(count: _userChats.length),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _ConversationList(
                      convs: _adminChats,
                      selected: _selected,
                      onSelect: (c) => setState(() => _selected = c),
                    ),
                    _ConversationList(
                      convs: _userChats,
                      selected: _selected,
                      onSelect: (c) => setState(() => _selected = c),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1, color: AppColors.divider),
        // Right: chat window
        Expanded(
          child: _selected == null
              ? const _EmptyChat()
              : _ChatWindow(
                  conversation: _selected!,
                  replyCtrl: _replyCtrl,
                  scrollCtrl: _scrollCtrl,
                  isAdminMode: _selected!.isAdminChat,
                  onSend: _sendReply,
                ),
        ),
      ],
    );
  }

  void _sendReply(String text) {
    if (text.trim().isEmpty) return;
    final conv = _selected!;
    final idx = _conversations.indexWhere((c) => c.id == conv.id);
    if (idx == -1) return;

    final updated = _Conversation(
      id: conv.id,
      participantA: conv.participantA,
      participantB: conv.participantB,
      isAdminChat: conv.isAdminChat,
      messages: [
        ...conv.messages,
        _Msg(
          id: 'reply_${DateTime.now().millisecondsSinceEpoch}',
          senderId: 'admin',
          senderName: 'Admin',
          text: text.trim(),
          sentAt: DateTime.now(),
          isAdmin: true,
        ),
      ],
    );

    setState(() {
      _conversations[idx] = updated;
      _selected = updated;
    });
    _replyCtrl.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

class _ConversationList extends StatelessWidget {
  final List<_Conversation> convs;
  final _Conversation? selected;
  final void Function(_Conversation) onSelect;

  const _ConversationList({required this.convs, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (convs.isEmpty) {
      return const Center(
        child: Text('Konuşma yok', style: TextStyle(color: AppColors.textLight)),
      );
    }
    return ListView.separated(
      itemCount: convs.length,
      separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (_, i) {
        final c = convs[i];
        final isSelected = selected?.id == c.id;
        final other = c.isAdminChat ? c.participantB : '${c.participantA} & ${c.participantB}';
        return InkWell(
          onTap: () => onSelect(c),
          child: Container(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.07) : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: (c.isAdminChat ? AppColors.primary : Colors.teal).withValues(alpha: 0.1),
                  child: Icon(
                    c.isAdminChat ? Icons.support_agent : Icons.people,
                    size: 18,
                    color: c.isAdminChat ? AppColors.primary : Colors.teal,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(other,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(c.lastMessage,
                          style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (c.lastTime != null)
                  Text(_timeLabel(c.lastTime!),
                      style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
              ],
            ),
          ),
        );
      },
    );
  }

  String _timeLabel(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk';
    if (diff.inHours < 24) return '${diff.inHours}sa';
    return '${diff.inDays}g';
  }
}

class _ChatWindow extends StatelessWidget {
  final _Conversation conversation;
  final TextEditingController replyCtrl;
  final ScrollController scrollCtrl;
  final bool isAdminMode;
  final void Function(String) onSend;

  const _ChatWindow({
    required this.conversation,
    required this.replyCtrl,
    required this.scrollCtrl,
    required this.isAdminMode,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final other = conversation.isAdminChat
        ? conversation.participantB
        : '${conversation.participantA} ↔ ${conversation.participantB}';

    return Column(
      children: [
        // Chat header
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Icon(
                  conversation.isAdminChat ? Icons.person : Icons.people,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(other,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ),
              if (!isAdminMode)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.visibility, size: 14, color: Colors.orange),
                      SizedBox(width: 4),
                      Text('İzleme Modu', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // Messages
        Expanded(
          child: ListView.builder(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: conversation.messages.length,
            itemBuilder: (_, i) => _BubbleRow(
              msg: conversation.messages[i],
              isAdminMode: isAdminMode,
            ),
          ),
        ),
        // Reply bar (only for admin chats)
        if (isAdminMode)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: replyCtrl,
                    onSubmitted: onSend,
                    decoration: InputDecoration(
                      hintText: 'Mesaj yaz…',
                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.textLight),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => onSend(replyCtrl.text),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.send, size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.visibility, size: 14, color: AppColors.textLight),
                  SizedBox(width: 6),
                  Text('Bu konuşmayı yalnızca izleyebilirsiniz',
                      style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _BubbleRow extends StatelessWidget {
  final _Msg msg;
  final bool isAdminMode;

  const _BubbleRow({required this.msg, required this.isAdminMode});

  @override
  Widget build(BuildContext context) {
    final isMe = msg.isAdmin && isAdminMode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(msg.senderName,
                  style: const TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w600)),
            ),
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe)
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    msg.senderName.isNotEmpty ? msg.senderName[0] : '?',
                    style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
              if (!isMe) const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  constraints: const BoxConstraints(maxWidth: 420),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: Radius.circular(isMe ? 14 : 2),
                      bottomRight: Radius.circular(isMe ? 2 : 14),
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 13,
                      color: isMe ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              if (isMe) const SizedBox(width: 6),
            ],
          ),
          const SizedBox(height: 3),
          Padding(
            padding: EdgeInsets.only(left: isMe ? 0 : 34, right: isMe ? 6 : 0),
            child: Text(_timeLabel(msg.sentAt),
                style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    return '${t.day}.${t.month}.${t.year}';
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.textLight),
          SizedBox(height: 12),
          Text('Konuşma seçin', style: TextStyle(fontSize: 15, color: AppColors.textLight)),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

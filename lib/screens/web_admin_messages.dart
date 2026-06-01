import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ── Firestore modelleri ────────────────────────────────────────────────────────

class _ChatMsg {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime sentAt;
  final bool isAdmin;

  const _ChatMsg({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.sentAt,
    this.isAdmin = false,
  });

  factory _ChatMsg.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _ChatMsg(
      id: doc.id,
      senderId: d['senderId'] as String? ?? '',
      senderName: d['senderName'] as String? ?? '',
      text: d['text'] as String? ?? '',
      sentAt: (d['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isAdmin: d['isAdmin'] as bool? ?? false,
    );
  }
}

class _SupportChat {
  final String id; // = userId
  final String userName;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final bool unreadByAdmin;

  const _SupportChat({
    required this.id,
    required this.userName,
    required this.lastMessage,
    this.lastMessageTime,
    this.unreadByAdmin = false,
  });

  factory _SupportChat.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _SupportChat(
      id: doc.id,
      userName: d['userName'] as String? ?? 'Kullanıcı',
      lastMessage: d['lastMessage'] as String? ?? '',
      lastMessageTime: (d['lastMessageTime'] as Timestamp?)?.toDate(),
      unreadByAdmin: d['unreadByAdmin'] as bool? ?? false,
    );
  }
}

class _UserChat {
  final String id;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final String listingTitle;
  final String lastMessage;
  final DateTime? lastMessageTime;

  const _UserChat({
    required this.id,
    required this.participantIds,
    required this.participantNames,
    required this.listingTitle,
    required this.lastMessage,
    this.lastMessageTime,
  });

  factory _UserChat.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _UserChat(
      id: doc.id,
      participantIds: List<String>.from(d['participantIds'] ?? []),
      participantNames: Map<String, String>.from(
        (d['participantNames'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {},
      ),
      listingTitle: d['listingTitle'] as String? ?? '',
      lastMessage: d['lastMessage'] as String? ?? '',
      lastMessageTime: (d['lastMessageTime'] as Timestamp?)?.toDate(),
    );
  }

  String get participantLabel => participantNames.values.join(' & ');
}

// ── Ana ekran ─────────────────────────────────────────────────────────────────

class WebAdminMessages extends StatefulWidget {
  const WebAdminMessages({super.key});

  @override
  State<WebAdminMessages> createState() => _WebAdminMessagesState();
}

class _WebAdminMessagesState extends State<WebAdminMessages> with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  late TabController _tab;

  _SupportChat? _selectedSupport;
  _UserChat? _selectedUserChat;

  final _replyCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {
          _selectedSupport = null;
          _selectedUserChat = null;
        }));
  }

  @override
  void dispose() {
    _tab.dispose();
    _replyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Firestore streams ──────────────────────────────────────────────────────

  Stream<List<_SupportChat>> get _supportStream => _db
      .collection('support')
      .orderBy('lastMessageTime', descending: true)
      .snapshots()
      .map((s) => s.docs.map(_SupportChat.fromDoc).toList());

  Stream<List<_ChatMsg>> supportMessages(String userId) => _db
      .collection('support')
      .doc(userId)
      .collection('messages')
      .orderBy('sentAt')
      .snapshots()
      .map((s) => s.docs.map(_ChatMsg.fromDoc).toList());

  Stream<List<_UserChat>> get _userChatsStream => _db
      .collection('chats')
      .orderBy('lastMessageTime', descending: true)
      .snapshots()
      .map((s) => s.docs.map(_UserChat.fromDoc).toList());

  Stream<List<_ChatMsg>> userChatMessages(String chatId) => _db
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('sentAt')
      .snapshots()
      .map((s) => s.docs.map(_ChatMsg.fromDoc).toList());

  // ── Admin yanıt gönder (sadece support) ───────────────────────────────────

  Future<void> _sendAdminReply(String text) async {
    if (text.trim().isEmpty || _selectedSupport == null) return;
    final userId = _selectedSupport!.id;
    final batch = _db.batch();
    final msgRef = _db.collection('support').doc(userId).collection('messages').doc();
    batch.set(msgRef, {
      'senderId': 'admin',
      'senderName': 'Admin',
      'text': text.trim(),
      'sentAt': FieldValue.serverTimestamp(),
      'isAdmin': true,
    });
    batch.update(_db.collection('support').doc(userId), {
      'lastMessage': text.trim(),
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadByAdmin': false,
      'unreadByUser': true,
    });
    await batch.commit();
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

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Sol: konuşma listesi
        SizedBox(
          width: 320,
          child: Column(
            children: [
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tab,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  tabs: const [
                    Tab(text: 'Destek Talepleri'),
                    Tab(text: 'Kullanıcılar Arası'),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    // Tab 1: Support
                    StreamBuilder<List<_SupportChat>>(
                      stream: _supportStream,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snap.hasError) {
                          return Center(child: Text('Hata: ${snap.error}', style: const TextStyle(color: Colors.red)));
                        }
                        final list = snap.data ?? [];
                        if (list.isEmpty) {
                          return const Center(
                            child: Text('Destek talebi yok', style: TextStyle(color: AppColors.textLight)),
                          );
                        }
                        return ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, i) => const Divider(height: 1, color: AppColors.divider),
                          itemBuilder: (_, i) {
                            final c = list[i];
                            final isSelected = _selectedSupport?.id == c.id;
                            return InkWell(
                              onTap: () => setState(() => _selectedSupport = c),
                              child: Container(
                                color: isSelected ? AppColors.primary.withValues(alpha: 0.07) : Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                          child: Text(
                                            c.userName.isNotEmpty ? c.userName[0].toUpperCase() : '?',
                                            style: const TextStyle(
                                                fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                                          ),
                                        ),
                                        if (c.unreadByAdmin)
                                          Positioned(
                                            right: 0,
                                            top: 0,
                                            child: Container(
                                              width: 10,
                                              height: 10,
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(c.userName,
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: c.unreadByAdmin ? FontWeight.bold : FontWeight.w600,
                                                  color: AppColors.textPrimary),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 2),
                                          Text(c.lastMessage,
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: c.unreadByAdmin ? AppColors.textPrimary : AppColors.textLight,
                                                  fontWeight: c.unreadByAdmin ? FontWeight.w500 : FontWeight.normal),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                    if (c.lastMessageTime != null)
                                      Text(_timeLabel(c.lastMessageTime!),
                                          style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    // Tab 2: Kullanıcılar arası
                    StreamBuilder<List<_UserChat>>(
                      stream: _userChatsStream,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snap.hasError) {
                          return Center(child: Text('Hata: ${snap.error}', style: const TextStyle(color: Colors.red)));
                        }
                        final list = snap.data ?? [];
                        if (list.isEmpty) {
                          return const Center(
                            child: Text('Kullanıcı mesajı yok', style: TextStyle(color: AppColors.textLight)),
                          );
                        }
                        return ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, i) => const Divider(height: 1, color: AppColors.divider),
                          itemBuilder: (_, i) {
                            final c = list[i];
                            final isSelected = _selectedUserChat?.id == c.id;
                            return InkWell(
                              onTap: () => setState(() => _selectedUserChat = c),
                              child: Container(
                                color: isSelected ? AppColors.primary.withValues(alpha: 0.07) : Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.teal.withValues(alpha: 0.1),
                                      child: const Icon(Icons.people, size: 18, color: Colors.teal),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(c.participantLabel,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textPrimary),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 2),
                                          Text(
                                            c.listingTitle.isNotEmpty ? '📦 ${c.listingTitle}' : c.lastMessage,
                                            style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (c.lastMessageTime != null)
                                      Text(_timeLabel(c.lastMessageTime!),
                                          style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1, color: AppColors.divider),
        // Sağ: mesaj paneli
        Expanded(
          child: _buildChatPanel(),
        ),
      ],
    );
  }

  Widget _buildChatPanel() {
    if (_tab.index == 0) {
      if (_selectedSupport == null) return const _EmptyChat();
      return _SupportChatPanel(
        chat: _selectedSupport!,
        messagesStream: supportMessages(_selectedSupport!.id),
        replyCtrl: _replyCtrl,
        scrollCtrl: _scrollCtrl,
        onSend: _sendAdminReply,
      );
    } else {
      if (_selectedUserChat == null) return const _EmptyChat();
      return _UserChatPanel(
        chat: _selectedUserChat!,
        messagesStream: userChatMessages(_selectedUserChat!.id),
        scrollCtrl: _scrollCtrl,
      );
    }
  }

  String _timeLabel(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk';
    if (diff.inHours < 24) return '${diff.inHours}sa';
    return '${diff.inDays}g';
  }
}

// ── Destek Chat Paneli ─────────────────────────────────────────────────────────

class _SupportChatPanel extends StatelessWidget {
  final _SupportChat chat;
  final Stream<List<_ChatMsg>> messagesStream;
  final TextEditingController replyCtrl;
  final ScrollController scrollCtrl;
  final Future<void> Function(String) onSend;

  const _SupportChatPanel({
    required this.chat,
    required this.messagesStream,
    required this.replyCtrl,
    required this.scrollCtrl,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
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
                child: Text(
                  chat.userName.isNotEmpty ? chat.userName[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(chat.userName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.support_agent, size: 14, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text('Destek', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Mesajlar
        Expanded(
          child: StreamBuilder<List<_ChatMsg>>(
            stream: messagesStream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final msgs = snap.data ?? [];
              if (msgs.isEmpty) {
                return const Center(
                  child: Text('Henüz mesaj yok', style: TextStyle(color: AppColors.textLight)),
                );
              }
              return ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                itemCount: msgs.length,
                itemBuilder: (_, i) => _BubbleRow(msg: msgs[i], isAdminMsg: msgs[i].isAdmin),
              );
            },
          ),
        ),
        // Yanıt kutusu
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
                    hintText: 'Kullanıcıya mesaj yaz…',
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
        ),
      ],
    );
  }
}

// ── Kullanıcılar Arası Chat Paneli (izleme) ───────────────────────────────────

class _UserChatPanel extends StatelessWidget {
  final _UserChat chat;
  final Stream<List<_ChatMsg>> messagesStream;
  final ScrollController scrollCtrl;

  const _UserChatPanel({
    required this.chat,
    required this.messagesStream,
    required this.scrollCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFE0F2F1),
                child: Icon(Icons.people, size: 16, color: Colors.teal),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(chat.participantLabel,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    if (chat.listingTitle.isNotEmpty)
                      Text(chat.listingTitle,
                          style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
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
        // Mesajlar
        Expanded(
          child: StreamBuilder<List<_ChatMsg>>(
            stream: messagesStream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final msgs = snap.data ?? [];
              if (msgs.isEmpty) {
                return const Center(
                  child: Text('Henüz mesaj yok', style: TextStyle(color: AppColors.textLight)),
                );
              }
              return ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                itemCount: msgs.length,
                itemBuilder: (_, i) {
                  final m = msgs[i];
                  final isFirst = m.senderId == msgs[0].senderId;
                  return _BubbleRow(msg: m, isAdminMsg: isFirst);
                },
              );
            },
          ),
        ),
        // Sadece izleme - yanıt yok
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

// ── Mesaj balonu ──────────────────────────────────────────────────────────────

class _BubbleRow extends StatelessWidget {
  final _ChatMsg msg;
  final bool isAdminMsg;

  const _BubbleRow({required this.msg, required this.isAdminMsg});

  @override
  Widget build(BuildContext context) {
    final isMe = msg.isAdmin;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(msg.senderName,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w600)),
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
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
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
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 2)),
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

// ── Boş panel ─────────────────────────────────────────────────────────────────

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

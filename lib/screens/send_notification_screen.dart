import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final _db = FirebaseFirestore.instance;

  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController();
  String _type     = 'system';
  String _target   = 'all'; // all | uid
  final _uidCtrl   = TextEditingController();

  bool _sending = false;

  static const _types = [
    ('system',   'Sistem',    Icons.notifications),
    ('approved', 'Onay',      Icons.check_circle),
    ('message',  'Mesaj',     Icons.message_rounded),
    ('promo',    'Kampanya',  Icons.star_rounded),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _uidCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body  = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      _snack('Başlık ve içerik boş bırakılamaz.', Colors.red);
      return;
    }

    setState(() => _sending = true);
    try {
      if (_target == 'all') {
        // Tüm kullanıcılara gönder
        final users = await _db.collection('users').get();
        final batch = _db.batch();
        for (final user in users.docs) {
          final ref = _db
              .collection('users')
              .doc(user.id)
              .collection('notifications')
              .doc();
          batch.set(ref, {
            'title': title,
            'body': body,
            'type': _type,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
        _snack('${users.docs.length} kullanıcıya gönderildi.', Colors.green);
      } else {
        final uid = _uidCtrl.text.trim();
        if (uid.isEmpty) {
          _snack('Kullanıcı UID giriniz.', Colors.red);
          setState(() => _sending = false);
          return;
        }
        await _db
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .add({
          'title': title,
          'body': body,
          'type': _type,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        _snack('Bildirim gönderildi.', Colors.green);
      }
      _titleCtrl.clear();
      _bodyCtrl.clear();
      _uidCtrl.clear();
    } catch (e) {
      _snack('Hata: $e', Colors.red);
    } finally {
      setState(() => _sending = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2035),
        foregroundColor: Colors.white,
        title: const Text('Bildirim Gönder'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bildirim tipi
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bildirim Tipi',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: _types.map((t) {
                        final selected = _type == t.$1;
                        return ChoiceChip(
                          avatar: Icon(t.$3,
                              size: 16,
                              color: selected ? Colors.white : const Color(0xFF1A2035)),
                          label: Text(t.$2),
                          selected: selected,
                          selectedColor: const Color(0xFF1A2035),
                          labelStyle: TextStyle(
                              color: selected ? Colors.white : Colors.black87),
                          onSelected: (_) => setState(() => _type = t.$1),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Hedef
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Hedef Kitle',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    _TargetTile(
                      title: 'Tüm Kullanıcılar',
                      value: 'all',
                      groupValue: _target,
                      onTap: () => setState(() => _target = 'all'),
                    ),
                    _TargetTile(
                      title: 'Belirli Kullanıcı (UID)',
                      value: 'uid',
                      groupValue: _target,
                      onTap: () => setState(() => _target = 'uid'),
                    ),
                    if (_target == 'uid') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _uidCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Kullanıcı UID',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // İçerik
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Başlık',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bodyCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Mesaj İçeriği',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
                label: Text(_sending ? 'Gönderiliyor...' : 'Bildirim Gönder'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2035),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _sending ? null : _send,
              ),
            ),

            const SizedBox(height: 24),

            // Gönderilen bildirimler listesi
            const Text('Son Gönderilen Bildirimler',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            _SentNotificationsList(),
          ],
        ),
      ),
    );
  }
}

// Radio tile yardımcısı
class _TargetTile extends StatelessWidget {
  final String title;
  final String value;
  final String groupValue;
  final VoidCallback onTap;
  const _TargetTile({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Radio<String>(
            value: value,
            // ignore: deprecated_member_use
            groupValue: groupValue,
            activeColor: const Color(0xFF1A2035),
            // ignore: deprecated_member_use
            onChanged: (_) => onTap(),
          ),
          Text(title, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _SentNotificationsList extends StatelessWidget {
  final _db = FirebaseFirestore.instance;

  _SentNotificationsList();

  @override
  Widget build(BuildContext context) {
    // "tüm kullanıcıya gönderilen" bildirimleri takip etmek için
    // bir broadcast_notifications koleksiyonu kullanıyoruz
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('broadcast_notifications')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text('Henüz toplu bildirim gönderilmedi.',
                  style: TextStyle(color: Colors.grey)),
            ),
          );
        }
        return Column(
          children: docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final ts = (d['createdAt'] as Timestamp?)?.toDate();
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF1A2035),
                  child: Icon(Icons.notifications, color: Colors.white, size: 18),
                ),
                title: Text(d['title'] ?? '',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(d['body'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
                trailing: ts != null
                    ? Text(
                        '${ts.day}/${ts.month}\n${ts.hour}:${ts.minute.toString().padLeft(2, '0')}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 10, color: Colors.grey))
                    : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

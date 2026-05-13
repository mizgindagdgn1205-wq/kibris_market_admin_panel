import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class PendingListingsScreen extends StatefulWidget {
  const PendingListingsScreen({super.key});

  @override
  State<PendingListingsScreen> createState() => _PendingListingsScreenState();
}

class _PendingListingsScreenState extends State<PendingListingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _service = FirestoreService();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2035),
        foregroundColor: Colors.white,
        title: const Text('İlan Yönetimi'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.pending_actions), text: 'Onay Bekleyen'),
            Tab(icon: Icon(Icons.check_circle_outline), text: 'Yayındaki İlanlar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ListingsTab(
            stream: _service.pendingListings(),
            service: _service,
            isPending: true,
          ),
          _ListingsTab(
            stream: _service.activeListings(),
            service: _service,
            isPending: false,
          ),
        ],
      ),
    );
  }
}

// ── Tab içeriği ───────────────────────────────────────────────────────────────

class _ListingsTab extends StatelessWidget {
  final Stream<List<Map<String, dynamic>>> stream;
  final FirestoreService service;
  final bool isPending;

  const _ListingsTab({
    required this.stream,
    required this.service,
    required this.isPending,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}'));
        }
        final listings = snapshot.data ?? [];
        if (listings.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPending ? Icons.check_circle_outline : Icons.inbox_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  isPending ? 'Onay bekleyen ilan yok' : 'Yayında ilan yok',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: listings.length,
          separatorBuilder: (context, i) => const SizedBox(height: 10),
          itemBuilder: (context, i) => isPending
              ? _PendingCard(listing: listings[i], service: service)
              : _ActiveCard(listing: listings[i], service: service),
        );
      },
    );
  }
}

// ── Onay bekleyen kart ────────────────────────────────────────────────────────

class _PendingCard extends StatelessWidget {
  final Map<String, dynamic> listing;
  final FirestoreService service;

  const _PendingCard({required this.listing, required this.service});

  @override
  Widget build(BuildContext context) {
    final docId    = listing['docId'] as String;
    final title    = listing['title'] ?? '-';
    final price    = listing['price']?.toString() ?? '0';
    final currency = listing['currency'] ?? '£';
    final location = listing['location'] ?? '-';
    final category = listing['categoryId'] ?? '-';
    final subcat   = listing['subcategoryId'] ?? '-';
    final seller   = listing['sellerName'] ?? '-';
    final phone    = listing['phone'] ?? '-';
    final desc     = listing['description'] ?? '';
    final type     = listing['type'] ?? '-';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                Text('$price $currency',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A73E8))),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _Info(Icons.category_outlined, '$category › $subcat'),
                _Info(Icons.location_on_outlined, location),
                _Info(Icons.sell_outlined, type),
                _Info(Icons.person_outline, seller),
                _Info(Icons.phone_outlined, phone),
              ],
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.black54)),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reddet'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    onPressed: () => _reject(context, docId),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Onayla'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _approve(context, docId),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _approve(BuildContext context, String docId) async {
    await service.approveListing(docId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('İlan onaylandı'), backgroundColor: Colors.green),
      );
    }
  }

  void _reject(BuildContext context, String docId) async {
    await service.rejectListing(docId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('İlan reddedildi'), backgroundColor: Colors.red),
      );
    }
  }
}

// ── Yayındaki ilan kartı ──────────────────────────────────────────────────────

class _ActiveCard extends StatelessWidget {
  final Map<String, dynamic> listing;
  final FirestoreService service;

  const _ActiveCard({required this.listing, required this.service});

  @override
  Widget build(BuildContext context) {
    final docId    = listing['docId'] as String;
    final title    = listing['title'] ?? '-';
    final price    = listing['price']?.toString() ?? '0';
    final currency = listing['currency'] ?? '£';
    final location = listing['location'] ?? '-';
    final category = listing['categoryId'] ?? '-';
    final subcat   = listing['subcategoryId'] ?? '-';
    final seller   = listing['sellerName'] ?? '-';
    final sellerId = listing['sellerId'] ?? '-';
    final phone    = listing['phone'] ?? '-';
    final type     = listing['type'] ?? '-';
    final desc     = listing['description'] ?? '';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık + fiyat
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                Text('$price $currency',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A73E8))),
              ],
            ),
            const SizedBox(height: 10),

            // Kullanıcı bilgileri kutusu
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD0D9FF)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF1A2035),
                    child: Text(
                      seller.isNotEmpty ? seller[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(seller,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('ID: $sellerId',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.black45)),
                        Text(phone,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                  // Mesaj ikonu (işlevsiz)
                  IconButton(
                    icon: const Icon(Icons.message_outlined,
                        color: Color(0xFF1A2035)),
                    tooltip: 'Mesaj Gönder',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // İlan bilgileri
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _Info(Icons.category_outlined, '$category › $subcat'),
                _Info(Icons.location_on_outlined, location),
                _Info(Icons.sell_outlined, type),
              ],
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.black54)),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // İşlem butonları
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Düzenle'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1A2035),
                      side: const BorderSide(color: Color(0xFF1A2035)),
                    ),
                    onPressed: () => _showEditDialog(context, docId, listing),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Sil'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    onPressed: () => _confirmDelete(context, docId, title),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, String docId,
      Map<String, dynamic> listing) {
    final titleCtrl = TextEditingController(text: listing['title'] ?? '');
    final priceCtrl = TextEditingController(
        text: listing['price']?.toString() ?? '');
    final descCtrl =
        TextEditingController(text: listing['description'] ?? '');
    final phoneCtrl =
        TextEditingController(text: listing['phone'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İlanı Düzenle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(titleCtrl, 'Başlık'),
              const SizedBox(height: 10),
              _dialogField(priceCtrl, 'Fiyat',
                  type: TextInputType.number),
              const SizedBox(height: 10),
              _dialogField(phoneCtrl, 'Telefon',
                  type: TextInputType.phone),
              const SizedBox(height: 10),
              _dialogField(descCtrl, 'Açıklama', maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              await service.updateListing(docId, {
                'title': titleCtrl.text.trim(),
                'price': double.tryParse(priceCtrl.text) ?? 0,
                'description': descCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('İlan güncellendi'),
                      backgroundColor: Colors.green),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A2035),
              foregroundColor: Colors.white,
            ),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, String docId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İlanı Sil'),
        content: Text('"$title" kalıcı olarak silinecek. Emin misiniz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await service.deleteListing(docId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('İlan silindi'),
                      backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  TextField _dialogField(TextEditingController ctrl, String label,
      {TextInputType type = TextInputType.text, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

// ── Yardımcı ─────────────────────────────────────────────────────────────────

class _Info extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Info(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey),
        const SizedBox(width: 3),
        Text(text,
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }
}

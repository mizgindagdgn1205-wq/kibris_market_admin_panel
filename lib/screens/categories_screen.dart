// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const Map<String, IconData> _iconMap = {
  'accessible': Icons.accessible,
  'account_balance': Icons.account_balance,
  'agriculture': Icons.agriculture,
  'air': Icons.air,
  'apartment': Icons.apartment,
  'bed': Icons.bed,
  'blender': Icons.blender,
  'bolt': Icons.bolt,
  'brush': Icons.brush,
  'build': Icons.build,
  'business': Icons.business,
  'cable': Icons.cable,
  'calculate': Icons.calculate,
  'camera': Icons.camera,
  'camera_alt': Icons.camera_alt,
  'car_repair': Icons.car_repair,
  'category': Icons.category,
  'celebration': Icons.celebration,
  'chair': Icons.chair,
  'checkroom': Icons.checkroom,
  'child_care': Icons.child_care,
  'circle': Icons.circle,
  'cleaning_services': Icons.cleaning_services,
  'code': Icons.code,
  'computer': Icons.computer,
  'construction': Icons.construction,
  'cruelty_free': Icons.cruelty_free,
  'devices': Icons.devices,
  'directions_car': Icons.directions_car,
  'directions_car_filled': Icons.directions_car_filled,
  'drive_eta': Icons.drive_eta,
  'electrical_services': Icons.electrical_services,
  'face': Icons.face,
  'flutter_dash': Icons.flutter_dash,
  'forklift': Icons.forklift,
  'format_paint': Icons.format_paint,
  'gavel': Icons.gavel,
  'gps_fixed': Icons.gps_fixed,
  'grass': Icons.grass,
  'handyman': Icons.handyman,
  'home': Icons.home,
  'hotel': Icons.hotel,
  'kitchen': Icons.kitchen,
  'landscape': Icons.landscape,
  'laptop': Icons.laptop,
  'laptop_mac': Icons.laptop_mac,
  'lightbulb': Icons.lightbulb,
  'local_hospital': Icons.local_hospital,
  'local_shipping': Icons.local_shipping,
  'menu_book': Icons.menu_book,
  'miscellaneous_services': Icons.miscellaneous_services,
  'museum': Icons.museum,
  'music_note': Icons.music_note,
  'pest_control': Icons.pest_control,
  'pets': Icons.pets,
  'plumbing': Icons.plumbing,
  'precision_manufacturing': Icons.precision_manufacturing,
  'restaurant': Icons.restaurant,
  'rv_hookup': Icons.rv_hookup,
  'sailing': Icons.sailing,
  'school': Icons.school,
  'science': Icons.science,
  'security': Icons.security,
  'settings': Icons.settings,
  'shopping_bag': Icons.shopping_bag,
  'shopping_cart': Icons.shopping_cart,
  'smartphone': Icons.smartphone,
  'spa': Icons.spa,
  'speed': Icons.speed,
  'sports': Icons.sports,
  'sports_esports': Icons.sports_esports,
  'sports_soccer': Icons.sports_soccer,
  'store': Icons.store,
  'tablet': Icons.tablet,
  'toys': Icons.toys,
  'translate': Icons.translate,
  'tv': Icons.tv,
  'two_wheeler': Icons.two_wheeler,
  'villa': Icons.villa,
  'watch': Icons.watch,
  'water': Icons.water,
  'work': Icons.work,
  'work_outline': Icons.work_outline,
  'add_box': Icons.add_box,
  'star': Icons.star,
};

IconData _icon(String name) => _iconMap[name] ?? Icons.category;

const List<Color> _kColors = [
  Color(0xFF1565C0), Color(0xFF2E7D32), Color(0xFFC62828),
  Color(0xFF6A1B9A), Color(0xFFE65100), Color(0xFF37474F),
  Color(0xFF4A148C), Color(0xFF00695C), Color(0xFF01579B),
  Color(0xFF00838F), Color(0xFF4E342E), Color(0xFFFF6B00),
  Color(0xFF1A4F9C), Color(0xFF880E4F), Color(0xFF33691E),
];

// ── Ana ekran ─────────────────────────────────────────────────────────────────

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2035),
        foregroundColor: Colors.white,
        title: const Text('Kategori Yönetimi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined),
            tooltip: 'Varsayılan kategorileri yükle',
            onPressed: () => _confirmSeed(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('categories').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data?.docs ?? [];
          final parents = all
              .where((d) => (d.data() as Map)['parentId'] == null)
              .toList()
            ..sort((a, b) =>
                (((a.data() as Map)['order'] as int?) ?? 0)
                    .compareTo(((b.data() as Map)['order'] as int?) ?? 0));

          if (parents.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.category_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('Henüz kategori yok', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Varsayılan Kategorileri Yükle'),
                    onPressed: () => _confirmSeed(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A2035),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: parents.length + 1,
            itemBuilder: (context, i) {
              if (i == parents.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Ana Kategori Ekle'),
                    onPressed: () => _showParentDialog(context),
                  ),
                );
              }
              final doc = parents[i];
              final d = doc.data() as Map<String, dynamic>;
              final subs = all
                  .where((s) => (s.data() as Map)['parentId'] == doc.id)
                  .toList()
                ..sort((a, b) =>
                    (((a.data() as Map)['order'] as int?) ?? 0)
                        .compareTo(((b.data() as Map)['order'] as int?) ?? 0));
              return _CategoryCard(
                docId: doc.id,
                data: d,
                subs: subs,
              );
            },
          );
        },
      ),
    );
  }

  void _confirmSeed(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Varsayılan Kategorileri Yükle'),
        content: const Text(
            'Bu işlem mevcut kategorileri silip varsayılan kategorileri yükler. Emin misiniz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _seedCategories(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A2035),
                foregroundColor: Colors.white),
            child: const Text('Yükle'),
          ),
        ],
      ),
    );
  }

  Future<void> _seedCategories(BuildContext context) async {
    final db = FirebaseFirestore.instance;
    final existing = await db.collection('categories').get();
    for (final doc in existing.docs) {
      await doc.reference.delete();
    }
    int order = 0;
    for (final cat in _defaultCategories()) {
      final parentRef = db.collection('categories').doc(cat['id'] as String);
      await parentRef.set({
        'name': cat['name'],
        'icon': cat['icon'],
        'color': cat['color'],
        'parentId': null,
        'order': order++,
      });
      int subOrder = 0;
      for (final sub in (cat['subs'] as List)) {
        await db.collection('categories').doc(sub['id'] as String).set({
          'name': sub['name'],
          'icon': sub['icon'],
          'color': cat['color'],
          'parentId': cat['id'],
          'order': subOrder++,
        });
      }
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kategoriler yüklendi'), backgroundColor: Colors.green),
      );
    }
  }
}

// ── Kategori kartı (StatefulWidget — expand/collapse) ─────────────────────────

class _CategoryCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final List<QueryDocumentSnapshot> subs;

  const _CategoryCard({
    required this.docId,
    required this.data,
    required this.subs,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final color = Color(widget.data['color'] as int? ?? 0xFF1A4F9C);
    final iconName = widget.data['icon'] as String? ?? 'category';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => _expanded = !_expanded),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_icon(iconName), color: color, size: 22),
            ),
            title: Text(widget.data['name'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text('${widget.subs.length} alt kategori',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Düzenle',
                  onPressed: () => _showParentDialog(
                    context,
                    docId: widget.docId,
                    existing: widget.data,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  tooltip: 'Sil',
                  onPressed: () => _confirmDelete(context),
                ),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            ...widget.subs.map((sub) {
              final sd = sub.data() as Map<String, dynamic>;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: Icon(_icon(sd['icon'] as String? ?? 'category'),
                    color: color, size: 20),
                title: Text(sd['name'] ?? '', style: const TextStyle(fontSize: 13)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      onPressed: () => _showSubDialog(
                        context,
                        parentId: widget.docId,
                        parentColor: color,
                        docId: sub.id,
                        existing: sd,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      onPressed: () => _confirmDeleteSub(context, sub.id, sd['name'] ?? ''),
                    ),
                  ],
                ),
              );
            }),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.add_circle_outline, color: Color(0xFF1A2035)),
              title: const Text('Alt Kategori Ekle',
                  style: TextStyle(
                      color: Color(0xFF1A2035),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              onTap: () => _showSubDialog(context,
                  parentId: widget.docId, parentColor: color),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kategoriyi Sil'),
        content: Text(
            '"${widget.data['name']}" ve tüm alt kategorileri silinecek. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final db = FirebaseFirestore.instance;
              final subs = await db
                  .collection('categories')
                  .where('parentId', isEqualTo: widget.docId)
                  .get();
              for (final s in subs.docs) {
                await s.reference.delete();
              }
              await db.collection('categories').doc(widget.docId).delete();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSub(BuildContext context, String subId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alt Kategoriyi Sil'),
        content: Text('"$name" silinecek. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('categories')
                  .doc(subId)
                  .delete();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}

// ── Dialog: Ana kategori ekle/düzenle ─────────────────────────────────────────

void _showParentDialog(BuildContext context,
    {String? docId, Map<String, dynamic>? existing}) {
  final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
  var selectedIcon = existing?['icon'] as String? ?? 'category';
  var selectedColor = existing != null
      ? Color(existing['color'] as int)
      : _kColors.first;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(docId == null ? 'Ana Kategori Ekle' : 'Kategoriyi Düzenle'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Kategori Adı', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                const Text('İkon Seç',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4),
                    itemCount: _iconMap.length,
                    itemBuilder: (_, i) {
                      final e = _iconMap.entries.elementAt(i);
                      final sel = e.key == selectedIcon;
                      return GestureDetector(
                        onTap: () => setState(() => selectedIcon = e.key),
                        child: Container(
                          decoration: BoxDecoration(
                            color: sel ? selectedColor.withOpacity(0.15) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: sel ? Border.all(color: selectedColor, width: 2) : null,
                          ),
                          child: Icon(e.value, size: 20,
                              color: sel ? selectedColor : Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Renk Seç',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _kColors.map((c) {
                    final sel = c.value == selectedColor.value;
                    return GestureDetector(
                      onTap: () => setState(() => selectedColor = c),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: sel ? Border.all(color: Colors.black54, width: 2) : null,
                        ),
                        child: sel ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final db = FirebaseFirestore.instance;
              if (docId == null) {
                final all = await db.collection('categories').get();
                final count = all.docs.where((d) => d.data()['parentId'] == null).length;
                await db.collection('categories').add({
                  'name': name,
                  'icon': selectedIcon,
                  'color': selectedColor.value,
                  'parentId': null,
                  'order': count,
                });
              } else {
                await db.collection('categories').doc(docId).update({
                  'name': name,
                  'icon': selectedIcon,
                  'color': selectedColor.value,
                });
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A2035),
                foregroundColor: Colors.white),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    ),
  );
}

// ── Dialog: Alt kategori ekle/düzenle ─────────────────────────────────────────

void _showSubDialog(BuildContext context,
    {required String parentId,
    required Color parentColor,
    String? docId,
    Map<String, dynamic>? existing}) {
  final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
  var selectedIcon = existing?['icon'] as String? ?? 'category';

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(docId == null ? 'Alt Kategori Ekle' : 'Alt Kategoriyi Düzenle'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Alt Kategori Adı', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                const Text('İkon Seç',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4),
                    itemCount: _iconMap.length,
                    itemBuilder: (_, i) {
                      final e = _iconMap.entries.elementAt(i);
                      final sel = e.key == selectedIcon;
                      return GestureDetector(
                        onTap: () => setState(() => selectedIcon = e.key),
                        child: Container(
                          decoration: BoxDecoration(
                            color: sel ? parentColor.withOpacity(0.15) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: sel ? Border.all(color: parentColor, width: 2) : null,
                          ),
                          child: Icon(e.value, size: 20,
                              color: sel ? parentColor : Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final db = FirebaseFirestore.instance;
              if (docId == null) {
                final subs = await db
                    .collection('categories')
                    .where('parentId', isEqualTo: parentId)
                    .get();
                await db.collection('categories').add({
                  'name': name,
                  'icon': selectedIcon,
                  'color': parentColor.value,
                  'parentId': parentId,
                  'order': subs.docs.length,
                });
              } else {
                await db.collection('categories').doc(docId).update({
                  'name': name,
                  'icon': selectedIcon,
                });
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A2035),
                foregroundColor: Colors.white),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    ),
  );
}

// ── Seed data ─────────────────────────────────────────────────────────────────

List<Map<String, dynamic>> _defaultCategories() => [
  {'id': 'vasitalar', 'name': 'Vasıtalar', 'icon': 'directions_car', 'color': const Color(0xFF1565C0).value, 'subs': [
    {'id': 'otomobil', 'name': 'Otomobil', 'icon': 'directions_car'},
    {'id': 'suv', 'name': 'SUV & 4x4', 'icon': 'directions_car_filled'},
    {'id': 'motosiklet', 'name': 'Motosiklet', 'icon': 'two_wheeler'},
    {'id': 'kamyonet', 'name': 'Kamyon & Kamyonet', 'icon': 'local_shipping'},
    {'id': 'tekne', 'name': 'Tekne & Yat', 'icon': 'sailing'},
    {'id': 'caravan', 'name': 'Karavan', 'icon': 'rv_hookup'},
    {'id': 'is_makinesi_vasita', 'name': 'İş Makinesi', 'icon': 'construction'},
  ]},
  {'id': 'emlak', 'name': 'Emlak', 'icon': 'home', 'color': const Color(0xFF2E7D32).value, 'subs': [
    {'id': 'satilik_daire', 'name': 'Satılık Daire', 'icon': 'apartment'},
    {'id': 'kiralik_daire', 'name': 'Kiralık Daire', 'icon': 'apartment'},
    {'id': 'satilik_villa', 'name': 'Satılık Villa', 'icon': 'villa'},
    {'id': 'kiralik_villa', 'name': 'Kiralık Villa', 'icon': 'villa'},
    {'id': 'arsa', 'name': 'Arsa & Tarla', 'icon': 'landscape'},
    {'id': 'isyeri', 'name': 'İşyeri & Ofis', 'icon': 'business'},
    {'id': 'devren', 'name': 'Devren Satılık', 'icon': 'store'},
    {'id': 'turistik', 'name': 'Turistik Tesis', 'icon': 'hotel'},
  ]},
  {'id': 'alisveris', 'name': 'Alışveriş', 'icon': 'shopping_bag', 'color': const Color(0xFFC62828).value, 'subs': [
    {'id': 'kadin_giyim', 'name': 'Kadın Giyim', 'icon': 'checkroom'},
    {'id': 'erkek_giyim', 'name': 'Erkek Giyim', 'icon': 'checkroom'},
    {'id': 'cocuk_giyim', 'name': 'Çocuk & Bebek', 'icon': 'child_care'},
    {'id': 'ayakkabi', 'name': 'Ayakkabı', 'icon': 'accessible'},
    {'id': 'canta_aksesuar', 'name': 'Çanta & Aksesuar', 'icon': 'shopping_bag'},
    {'id': 'saat_murevi', 'name': 'Saat & Mücevher', 'icon': 'watch'},
    {'id': 'kozmetik', 'name': 'Kozmetik & Bakım', 'icon': 'spa'},
    {'id': 'oyuncak', 'name': 'Oyuncak & Hobi', 'icon': 'toys'},
    {'id': 'kitap_muzik', 'name': 'Kitap & Müzik', 'icon': 'menu_book'},
    {'id': 'spor_ekipman', 'name': 'Spor Ekipmanı', 'icon': 'sports_soccer'},
    {'id': 'antika', 'name': 'Antika & Koleksiyon', 'icon': 'museum'},
    {'id': 'diger_alisveris', 'name': 'Diğer', 'icon': 'category'},
  ]},
  {'id': 'elektronik', 'name': 'Elektronik', 'icon': 'devices', 'color': const Color(0xFF6A1B9A).value, 'subs': [
    {'id': 'telefon', 'name': 'Cep Telefonu', 'icon': 'smartphone'},
    {'id': 'bilgisayar', 'name': 'Bilgisayar', 'icon': 'laptop'},
    {'id': 'tablet', 'name': 'Tablet', 'icon': 'tablet'},
    {'id': 'tv', 'name': 'TV & Ses', 'icon': 'tv'},
    {'id': 'kamera', 'name': 'Fotoğraf & Kamera', 'icon': 'camera_alt'},
    {'id': 'beyaz_esya', 'name': 'Beyaz Eşya', 'icon': 'kitchen'},
    {'id': 'oyun_konsol', 'name': 'Oyun & Konsol', 'icon': 'sports_esports'},
    {'id': 'aksesuar_elek', 'name': 'Aksesuar', 'icon': 'cable'},
  ]},
  {'id': 'ev_bahce', 'name': 'Ev & Bahçe', 'icon': 'chair', 'color': const Color(0xFFE65100).value, 'subs': [
    {'id': 'mobilya', 'name': 'Mobilya', 'icon': 'chair'},
    {'id': 'ev_tekstil', 'name': 'Ev Tekstili', 'icon': 'bed'},
    {'id': 'mutfak', 'name': 'Mutfak Gereçleri', 'icon': 'blender'},
    {'id': 'bahce', 'name': 'Bahçe & Yapı', 'icon': 'grass'},
    {'id': 'dekorasyon', 'name': 'Dekorasyon', 'icon': 'format_paint'},
    {'id': 'aydinlatma', 'name': 'Aydınlatma', 'icon': 'lightbulb'},
    {'id': 'guvenlik', 'name': 'Güvenlik Sistemleri', 'icon': 'security'},
  ]},
  {'id': 'yedek_parca', 'name': 'Yedek Parça & Aksesuar', 'icon': 'build', 'color': const Color(0xFF37474F).value, 'subs': [
    {'id': 'parca_otomobil', 'name': 'Otomobil Yedek Parça', 'icon': 'settings'},
    {'id': 'parca_motor', 'name': 'Motor Yedek Parça', 'icon': 'two_wheeler'},
    {'id': 'lastik_jant', 'name': 'Lastik & Jant', 'icon': 'circle'},
    {'id': 'aksesuar_arac', 'name': 'Araç Aksesuarı', 'icon': 'car_repair'},
    {'id': 'tuning', 'name': 'Tuning & Modifikasyon', 'icon': 'speed'},
    {'id': 'elektrik_arac', 'name': 'Elektrik & Elektronik', 'icon': 'electrical_services'},
    {'id': 'navigasyon', 'name': 'Navigasyon & Medya', 'icon': 'gps_fixed'},
    {'id': 'deniz_parca', 'name': 'Deniz Araçları Parça', 'icon': 'sailing'},
  ]},
  {'id': 'is_makineleri', 'name': 'İş Makineleri & Sanayi', 'icon': 'precision_manufacturing', 'color': const Color(0xFF4A148C).value, 'subs': [
    {'id': 'insaat_makinesi', 'name': 'İnşaat Makineleri', 'icon': 'construction'},
    {'id': 'tarim_makinesi', 'name': 'Tarım Makineleri', 'icon': 'agriculture'},
    {'id': 'forklift', 'name': 'Forklift & Vinç', 'icon': 'forklift'},
    {'id': 'jenerator', 'name': 'Jeneratör & Enerji', 'icon': 'bolt'},
    {'id': 'kompressor', 'name': 'Kompresör & Pompa', 'icon': 'air'},
    {'id': 'takim_tezgah', 'name': 'Takım & Tezgah', 'icon': 'handyman'},
    {'id': 'endustriyel', 'name': 'Endüstriyel Ekipman', 'icon': 'precision_manufacturing'},
    {'id': 'gida_makinesi', 'name': 'Gıda & Restoran', 'icon': 'restaurant'},
  ]},
  {'id': 'hizmetler', 'name': 'Ustalar & Hizmetler', 'icon': 'handyman', 'color': const Color(0xFF00695C).value, 'subs': [
    {'id': 'tadilat', 'name': 'Tadilat & Dekorasyon', 'icon': 'format_paint'},
    {'id': 'elektrikci', 'name': 'Elektrikçi', 'icon': 'electrical_services'},
    {'id': 'tesisatci', 'name': 'Tesisatçı', 'icon': 'plumbing'},
    {'id': 'nakliyat', 'name': 'Nakliyat & Taşımacılık', 'icon': 'local_shipping'},
    {'id': 'temizlik', 'name': 'Temizlik Hizmetleri', 'icon': 'cleaning_services'},
    {'id': 'guzellik', 'name': 'Güzellik & Bakım', 'icon': 'face'},
    {'id': 'fotografci', 'name': 'Fotoğrafçı & Çekimci', 'icon': 'camera'},
    {'id': 'organizasyon', 'name': 'Organizasyon & Etkinlik', 'icon': 'celebration'},
    {'id': 'bilisim_servis', 'name': 'Bilişim & Teknik Servis', 'icon': 'computer'},
    {'id': 'hukuk', 'name': 'Hukuk & Danışmanlık', 'icon': 'gavel'},
    {'id': 'saglik', 'name': 'Sağlık & Bakım', 'icon': 'local_hospital'},
    {'id': 'diger_hizmet', 'name': 'Diğer Hizmetler', 'icon': 'miscellaneous_services'},
  ]},
  {'id': 'ozel_ders', 'name': 'Özel Ders', 'icon': 'school', 'color': const Color(0xFF01579B).value, 'subs': [
    {'id': 'matematik', 'name': 'Matematik', 'icon': 'calculate'},
    {'id': 'yabanci_dil', 'name': 'Yabancı Dil', 'icon': 'translate'},
    {'id': 'fen_bilim', 'name': 'Fen Bilimleri', 'icon': 'science'},
    {'id': 'muzik_ders', 'name': 'Müzik Dersi', 'icon': 'music_note'},
    {'id': 'spor_egitim', 'name': 'Spor Eğitimi', 'icon': 'sports'},
    {'id': 'sanat_ders', 'name': 'Sanat & Resim', 'icon': 'brush'},
    {'id': 'bilgisayar_ders', 'name': 'Bilgisayar & Kodlama', 'icon': 'code'},
    {'id': 'surucukursu', 'name': 'Sürücü Kursu', 'icon': 'drive_eta'},
    {'id': 'diger_ders', 'name': 'Diğer Dersler', 'icon': 'menu_book'},
  ]},
  {'id': 'is_ilanlari', 'name': 'İş İlanları', 'icon': 'work', 'color': const Color(0xFF00838F).value, 'subs': [
    {'id': 'tam_zamanli', 'name': 'Tam Zamanlı', 'icon': 'work'},
    {'id': 'yari_zamanli', 'name': 'Yarı Zamanlı', 'icon': 'work_outline'},
    {'id': 'freelance', 'name': 'Freelance', 'icon': 'laptop_mac'},
    {'id': 'staj', 'name': 'Staj', 'icon': 'school'},
    {'id': 'insaat_is', 'name': 'İnşaat & Yapı', 'icon': 'construction'},
    {'id': 'turizm_is', 'name': 'Turizm & Otel', 'icon': 'hotel'},
    {'id': 'restoran_is', 'name': 'Restoran & Cafe', 'icon': 'restaurant'},
    {'id': 'saglik_is', 'name': 'Sağlık', 'icon': 'local_hospital'},
    {'id': 'egitim_is', 'name': 'Eğitim', 'icon': 'school'},
    {'id': 'it_is', 'name': 'IT & Yazılım', 'icon': 'code'},
    {'id': 'muhasebe_is', 'name': 'Muhasebe & Finans', 'icon': 'account_balance'},
    {'id': 'diger_is', 'name': 'Diğer', 'icon': 'category'},
  ]},
  {'id': 'hayvanlar', 'name': 'Hayvanlar Alemi', 'icon': 'pets', 'color': const Color(0xFF4E342E).value, 'subs': [
    {'id': 'kedi', 'name': 'Kedi', 'icon': 'pets'},
    {'id': 'kopek', 'name': 'Köpek', 'icon': 'pets'},
    {'id': 'kus', 'name': 'Kuş', 'icon': 'flutter_dash'},
    {'id': 'balik', 'name': 'Balık & Akvaryum', 'icon': 'water'},
    {'id': 'kemirgen', 'name': 'Kemirgen & Tavşan', 'icon': 'cruelty_free'},
    {'id': 'surungen', 'name': 'Sürüngen & Egzotik', 'icon': 'pest_control'},
    {'id': 'ciftlik', 'name': 'Çiftlik Hayvanları', 'icon': 'agriculture'},
    {'id': 'hayvan_malzeme', 'name': 'Mama & Aksesuar', 'icon': 'shopping_cart'},
    {'id': 'veteriner', 'name': 'Veteriner Hizm.', 'icon': 'local_hospital'},
  ]},
];

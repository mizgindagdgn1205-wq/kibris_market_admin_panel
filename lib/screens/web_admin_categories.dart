import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WebAdminCategories extends StatefulWidget {
  const WebAdminCategories({super.key});

  @override
  State<WebAdminCategories> createState() => _WebAdminCategoriesState();
}

class _WebAdminCategoriesState extends State<WebAdminCategories>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabs,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textLight,
            indicatorColor: AppColors.primary,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Kategoriler'),
              Tab(text: 'Filtreler'),
              Tab(text: 'Araç Verileri'),
              Tab(text: 'Araç Cascade'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [
              _CategoriesTab(),
              _FiltersTab(),
              _VehicleDataTab(),
              _VehicleCascadeTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Categories Tab ────────────────────────────────────────────────────────────

class _CategoriesTab extends StatefulWidget {
  const _CategoriesTab();

  @override
  State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<_CategoriesTab> {
  final _db = FirebaseFirestore.instance;
  final Set<String> _expanded = {};
  bool _syncing = false;
  bool _didAutoExpand = false;

  static const _vehicleSubcats = [
    {'id': 'otomobil',          'name': 'Otomobil',           'icon': 'directions_car',        'order': 0},
    {'id': 'arazi_suv',         'name': 'SUV & 4x4',          'icon': 'directions_car_filled', 'order': 1},
    {'id': 'motosiklet',        'name': 'Motosiklet',          'icon': 'two_wheeler',           'order': 2},
    {'id': 'minivan',           'name': 'Minivan & Mpv',       'icon': 'airport_shuttle',       'order': 3},
    {'id': 'kamyonet',          'name': 'Kamyonet',            'icon': 'local_shipping',        'order': 4},
    {'id': 'kamyon',            'name': 'Kamyon',              'icon': 'fire_truck',            'order': 5},
    {'id': 'minibus',           'name': 'Minibüs & Otobüs',   'icon': 'directions_bus',        'order': 6},
    {'id': 'tir_cekici',        'name': 'Tır & Çekici',        'icon': 'local_shipping',        'order': 7},
    {'id': 'caravan',           'name': 'Karavan',             'icon': 'rv_hookup',             'order': 8},
    {'id': 'atv',               'name': 'ATV & UTV',           'icon': 'directions_bike',       'order': 9},
    {'id': 'tekne',             'name': 'Tekne & Yat',         'icon': 'sailing',               'order': 10},
    {'id': 'su_motorsikleti',   'name': 'Su Motosikleti',      'icon': 'water',                 'order': 11},
    {'id': 'klasik',            'name': 'Klasik & Vintage',    'icon': 'star_outline',          'order': 12},
    {'id': 'engelli_arac',      'name': 'Engelli Araçları',    'icon': 'accessible',            'order': 13},
    {'id': 'is_makinesi_vasita','name': 'İş Makinesi',         'icon': 'construction',          'order': 14},
  ];

  Future<void> _triggerReseed() async {
    setState(() => _syncing = true);
    try {
      await _db.collection('system_config').doc('reseed').set({
        'pending': true,
        'requestedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Senkronizasyon bayrağı ayarlandı. Uygulama bir sonraki açılışta güncellenecek.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _syncing = false);
  }

  Future<void> _syncVehicleCategories() async {
    setState(() => _syncing = true);
    try {
      final batch = _db.batch();

      // Write all new vehicle subcategories
      for (final subcat in _vehicleSubcats) {
        final ref = _db.collection('categories').doc(subcat['id'] as String);
        batch.set(ref, {
          'name': subcat['name'],
          'icon': subcat['icon'],
          'order': subcat['order'],
          'parentId': 'vasitalar',
          'color': 0xFF1565C0,
        }, SetOptions(merge: true));
      }
      await batch.commit();

      // Delete old combined "Kamyon & Kamyonet" entry if it exists
      final oldDocs = await _db.collection('categories')
          .where('name', isEqualTo: 'Kamyon & Kamyonet')
          .get();
      for (final doc in oldDocs.docs) {
        await doc.reference.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Araç kategorileri başarıyla güncellendi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _syncing = false);
  }

  Future<void> _addRoot(List<QueryDocumentSnapshot> all) async {
    final roots = all.where((d) => (d.data() as Map)['parentId'] == null);
    final ref = _db.collection('categories').doc();
    await ref.set({'name': 'Yeni Kategori', 'icon': 'category', 'color': 0xFF1D4ED8, 'order': roots.length, 'parentId': null});
    setState(() => _expanded.add(ref.id));
  }

  Future<void> _addChild(String parentId, List<QueryDocumentSnapshot> all) async {
    final children = all.where((d) => (d.data() as Map)['parentId'] == parentId);
    final ref = _db.collection('categories').doc();
    await ref.set({'name': 'Yeni Alt Kategori', 'icon': 'category', 'color': 0xFF1D4ED8, 'order': children.length, 'parentId': parentId});
    setState(() => _expanded.add(parentId));
  }

  Future<void> _deleteRecursive(String id, List<QueryDocumentSnapshot> all) async {
    final children = all.where((d) => (d.data() as Map)['parentId'] == id);
    final batch = _db.batch();
    for (final c in children) { _deleteInBatch(c.id, all, batch); }
    batch.delete(_db.collection('categories').doc(id));
    await batch.commit();
  }

  void _deleteInBatch(String id, List<QueryDocumentSnapshot> all, WriteBatch batch) {
    for (final c in all.where((d) => (d.data() as Map)['parentId'] == id)) {
      _deleteInBatch(c.id, all, batch);
    }
    batch.delete(_db.collection('categories').doc(id));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('categories').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final all = snap.data!.docs;
        final roots = all.where((d) => (d.data() as Map)['parentId'] == null).toList()
          ..sort((a, b) => (((a.data() as Map)['order'] as int?) ?? 0).compareTo(((b.data() as Map)['order'] as int?) ?? 0));

        // İlk yüklemede tüm kök kategorileri otomatik aç
        if (!_didAutoExpand && roots.isNotEmpty) {
          _didAutoExpand = true;
          final rootIds = roots.map((r) => r.id).toSet();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _expanded.addAll(rootIds));
          });
        }

        return Padding(
          padding: const EdgeInsets.all(20),
          child: AdminCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
                child: Row(children: [
                  const Text('Kategoriler', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const Spacer(),
                  if (_syncing)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  else ...[
                    TextButton.icon(
                      onPressed: _triggerReseed,
                      icon: const Icon(Icons.sync, size: 16),
                      label: const Text('Veritabanını Güncelle', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: AppColors.textLight),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _syncVehicleCategories,
                      icon: const Icon(Icons.directions_car, size: 16),
                      label: const Text('Kategorileri Şimdi Güncelle', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                    ),
                  ],
                  const SizedBox(width: 8),
                  ABtn(label: 'Ana Kategori Ekle', icon: Icons.add, small: true, onTap: () => _addRoot(all)),
                ]),
              ),
              const Divider(),
              Expanded(
                child: roots.isEmpty
                    ? const Center(child: Text('Henüz kategori yok', style: TextStyle(color: AppColors.textLight)))
                    : ListView.builder(
                        itemCount: roots.length,
                        itemBuilder: (c, i) => _CategoryTreeNode(
                          doc: roots[i], all: all, depth: 0, expanded: _expanded,
                          onToggle: (id) => setState(() => _expanded.contains(id) ? _expanded.remove(id) : _expanded.add(id)),
                          onAddChild: (id) => _addChild(id, all),
                          onDelete: (id) => _deleteRecursive(id, all),
                          onSave: (id, name, icon, color) => _db.collection('categories').doc(id).update({'name': name, 'icon': icon, 'color': color}),
                        ),
                      ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _CategoryTreeNode extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final List<QueryDocumentSnapshot> all;
  final int depth;
  final Set<String> expanded;
  final void Function(String) onToggle;
  final void Function(String) onAddChild;
  final void Function(String) onDelete;
  final Future<void> Function(String, String, String, int) onSave;

  const _CategoryTreeNode({required this.doc, required this.all, required this.depth, required this.expanded, required this.onToggle, required this.onAddChild, required this.onDelete, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final children = all.where((s) => (s.data() as Map)['parentId'] == doc.id).toList()
      ..sort((a, b) => (((a.data() as Map)['order'] as int?) ?? 0).compareTo(((b.data() as Map)['order'] as int?) ?? 0));
    final isExpanded = expanded.contains(doc.id);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _CategoryRow(
        doc: doc, data: d, depth: depth, hasChildren: children.isNotEmpty, isExpanded: isExpanded,
        onToggle: () => onToggle(doc.id),
        onAddChild: () => onAddChild(doc.id),
        onDelete: () => onDelete(doc.id),
        onSave: (name, icon, color) => onSave(doc.id, name, icon, color),
      ),
      if (isExpanded)
        ...children.map((c) => _CategoryTreeNode(doc: c, all: all, depth: depth + 1, expanded: expanded, onToggle: onToggle, onAddChild: onAddChild, onDelete: onDelete, onSave: onSave)),
    ]);
  }
}

class _CategoryRow extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  final int depth;
  final bool hasChildren, isExpanded;
  final VoidCallback onToggle, onAddChild, onDelete;
  final Future<void> Function(String, String, int) onSave;

  const _CategoryRow({required this.doc, required this.data, required this.depth, required this.hasChildren, required this.isExpanded, required this.onToggle, required this.onAddChild, required this.onDelete, required this.onSave});

  @override
  State<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends State<_CategoryRow> {
  bool _editing = false;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _iconCtrl;
  late final TextEditingController _colorCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.data['name'] as String? ?? '');
    _iconCtrl  = TextEditingController(text: widget.data['icon'] as String? ?? 'category');
    final colorInt = (widget.data['color'] as num?)?.toInt() ?? 0xFF1D4ED8;
    _colorCtrl = TextEditingController(text: colorInt.toRadixString(16).padLeft(8, '0').toUpperCase());
  }

  @override
  void dispose() { _nameCtrl.dispose(); _iconCtrl.dispose(); _colorCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() => _saving = true);
    final colorVal = int.tryParse(_colorCtrl.text.replaceFirst('#', ''), radix: 16) ?? 0xFF1D4ED8;
    await widget.onSave(_nameCtrl.text.trim(), _iconCtrl.text.trim(), colorVal);
    if (mounted) setState(() { _saving = false; _editing = false; });
  }

  @override
  Widget build(BuildContext context) {
    final color = Color((widget.data['color'] as num?)?.toInt() ?? 0xFF1D4ED8);
    final indent = 20.0 + widget.depth * 24.0;

    return Column(children: [
      Container(
        color: widget.depth > 0 ? AppColors.background.withValues(alpha: 0.5) : Colors.transparent,
        padding: EdgeInsets.only(left: indent, right: 12, top: 4, bottom: 4),
        child: _editing
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TextField(controller: _nameCtrl, style: const TextStyle(fontSize: 13),
                      decoration: _inputDeco('Kategori adı')),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: TextField(controller: _iconCtrl, style: const TextStyle(fontSize: 13),
                        decoration: _inputDeco('İkon (ör: directions_car)'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: _colorCtrl, style: const TextStyle(fontSize: 13),
                        decoration: _inputDeco('Renk hex (ör: FF1D4ED8)'))),
                  ]),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: () => setState(() => _editing = false), child: const Text('İptal', style: TextStyle(fontSize: 12))),
                    const SizedBox(width: 8),
                    ABtn(label: _saving ? '...' : 'Kaydet', small: true, onTap: _saving ? null : _save),
                  ]),
                ]),
              )
            : Row(children: [
                SizedBox(width: 20, height: 36,
                    child: widget.hasChildren
                        ? InkWell(borderRadius: BorderRadius.circular(4), onTap: widget.onToggle,
                            child: Icon(widget.isExpanded ? Icons.expand_more : Icons.chevron_right,
                                size: 18, color: AppColors.textLight))
                        : null),
                const SizedBox(width: 4),
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Icon(Icons.category, color: color, size: 14),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(widget.data['name'] ?? '',
                    style: TextStyle(fontSize: widget.depth == 0 ? 13 : 12,
                        fontWeight: widget.depth == 0 ? FontWeight.w600 : FontWeight.normal,
                        color: AppColors.textPrimary))),
                Text(widget.data['icon'] ?? '', style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
                const SizedBox(width: 8),
                _TinyBtn(Icons.add_circle_outline, AppColors.primary, widget.onAddChild, 'Alt kategori ekle'),
                _TinyBtn(Icons.edit_outlined, AppColors.textSecondary, () => setState(() => _editing = true), 'Düzenle'),
                _TinyBtn(Icons.delete_outline, AppColors.error, () async {
                  final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                    title: const Text('Kategoriyi Sil'),
                    content: Text('"${widget.data['name']}" ve alt kategorileri silinecek.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('İptal')),
                      ElevatedButton(onPressed: () => Navigator.pop(c, true),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                          child: const Text('Sil')),
                    ],
                  ));
                  if (ok == true) widget.onDelete();
                }, 'Sil'),
              ]),
      ),
      const Divider(height: 1),
    ]);
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(fontSize: 12, color: AppColors.textLight),
    isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.divider)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.divider)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
  );
}

class _TinyBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;
  const _TinyBtn(this.icon, this.color, this.onTap, this.tooltip);

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: IconButton(icon: Icon(icon, size: 16, color: color), onPressed: onTap,
        padding: EdgeInsets.zero, constraints: const BoxConstraints(), visualDensity: VisualDensity.compact),
  );
}

// ── Filters Tab ───────────────────────────────────────────────────────────────

class _FiltersTab extends StatefulWidget {
  const _FiltersTab();

  @override
  State<_FiltersTab> createState() => _FiltersTabState();
}

class _FiltersTabState extends State<_FiltersTab> {
  final _db = FirebaseFirestore.instance;
  String? _selectedCatId;
  int? _selectedSectionIdx;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('category_filters').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.data!.docs.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.filter_list_off, size: 48, color: AppColors.textLight),
              const SizedBox(height: 12),
              const Text('Filtre verisi bulunamadı.', style: TextStyle(color: AppColors.textLight, fontSize: 14)),
              const SizedBox(height: 6),
              const Text('"Kategoriler" sekmesindeki "Veritabanını Güncelle" butonuna basın.',
                  style: TextStyle(color: AppColors.textLight, fontSize: 12)),
            ]),
          );
        }

        // Tüm filtre dokümanlarını categoryId'ye göre sırala
        final docs = snap.data!.docs.toList()
          ..sort((a, b) => a.id.compareTo(b.id));

        // Seçili kategori dokümanı
        final selectedDoc = _selectedCatId != null
            ? docs.where((d) => d.id == _selectedCatId).firstOrNull
            : null;

        final sections = selectedDoc != null
            ? (selectedDoc.data() as Map<String, dynamic>)['sections'] as List<dynamic>? ?? []
            : <dynamic>[];

        final selectedSection = (_selectedSectionIdx != null && _selectedSectionIdx! < sections.length)
            ? sections[_selectedSectionIdx!] as Map<String, dynamic>
            : null;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Sol: Kategori listesi ─────────────────────────────────────
            AdminCard(
              padding: EdgeInsets.zero,
              child: SizedBox(
                width: 220,
                child: Column(children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(children: [
                      Icon(Icons.filter_list, size: 16, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Kategoriler', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ]),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (c, i) {
                        final id = docs[i].id;
                        final sects = ((docs[i].data() as Map)['sections'] as List?)?.length ?? 0;
                        final sel = _selectedCatId == id;
                        return InkWell(
                          onTap: () => setState(() {
                            _selectedCatId = id;
                            _selectedSectionIdx = null;
                          }),
                          child: Container(
                            color: sel ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(children: [
                              Expanded(
                                child: Text(id,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                                      color: sel ? AppColors.primary : AppColors.textPrimary,
                                    )),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: sel ? AppColors.primary : AppColors.background,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('$sects', style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: sel ? Colors.white : AppColors.textLight,
                                )),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                ]),
              ),
            ),

            const SizedBox(width: 16),

            // ── Orta: Filter section listesi ──────────────────────────────
            AdminCard(
              padding: EdgeInsets.zero,
              child: SizedBox(
                width: 240,
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(children: [
                      const Icon(Icons.tune, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedCatId != null ? '$_selectedCatId filtreleri' : 'Filtre Bölümleri',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _selectedCatId == null
                        ? const Center(child: Text('Soldan kategori seçin', style: TextStyle(color: AppColors.textLight, fontSize: 12)))
                        : sections.isEmpty
                            ? const Center(child: Text('Bu kategori için filtre yok', style: TextStyle(color: AppColors.textLight, fontSize: 12)))
                            : ListView.builder(
                                itemCount: sections.length,
                                itemBuilder: (c, i) {
                                  final s = sections[i] as Map<String, dynamic>;
                                  final opts = (s['options'] as List?)?.length ?? 0;
                                  final sel = _selectedSectionIdx == i;
                                  return InkWell(
                                    onTap: () => setState(() => _selectedSectionIdx = i),
                                    child: Container(
                                      color: sel ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      child: Row(children: [
                                        Expanded(
                                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            Text(s['title'] ?? '', style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                                              color: sel ? AppColors.primary : AppColors.textPrimary,
                                            )),
                                            Text(s['id'] ?? '', style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
                                          ]),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: sel ? AppColors.primary : AppColors.background,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text('$opts', style: TextStyle(
                                            fontSize: 10, fontWeight: FontWeight.w600,
                                            color: sel ? Colors.white : AppColors.textLight,
                                          )),
                                        ),
                                      ]),
                                    ),
                                  );
                                },
                              ),
                  ),
                ]),
              ),
            ),

            const SizedBox(width: 16),

            // ── Sağ: Seçenekler detayı ────────────────────────────────────
            Expanded(
              child: selectedSection == null
                  ? AdminCard(
                      child: const Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.touch_app_outlined, size: 40, color: AppColors.textLight),
                          SizedBox(height: 10),
                          Text('Ortadan bir filtre bölümü seçin', style: TextStyle(color: AppColors.textLight, fontSize: 13)),
                        ]),
                      ),
                    )
                  : _FilterSectionDetail(
                      categoryId: _selectedCatId!,
                      sectionIndex: _selectedSectionIdx!,
                      section: selectedSection,
                      allSections: sections.cast<Map<String, dynamic>>(),
                      onSave: (updatedSections) async {
                        await _db.collection('category_filters').doc(_selectedCatId).update({
                          'sections': updatedSections,
                        });
                      },
                    ),
            ),
          ]),
        );
      },
    );
  }
}

class _FilterSectionDetail extends StatefulWidget {
  final String categoryId;
  final int sectionIndex;
  final Map<String, dynamic> section;
  final List<Map<String, dynamic>> allSections;
  final Future<void> Function(List<Map<String, dynamic>>) onSave;

  const _FilterSectionDetail({
    required this.categoryId,
    required this.sectionIndex,
    required this.section,
    required this.allSections,
    required this.onSave,
  });

  @override
  State<_FilterSectionDetail> createState() => _FilterSectionDetailState();
}

class _FilterSectionDetailState extends State<_FilterSectionDetail> {
  late final TextEditingController _optCtrl;
  bool _saving = false;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    final opts = (widget.section['options'] as List?)?.cast<String>() ?? [];
    _optCtrl = TextEditingController(text: opts.join('\n'));
  }

  @override
  void didUpdateWidget(_FilterSectionDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sectionIndex != widget.sectionIndex || oldWidget.categoryId != widget.categoryId) {
      final opts = (widget.section['options'] as List?)?.cast<String>() ?? [];
      _optCtrl.text = opts.join('\n');
      _editing = false;
    }
  }

  @override
  void dispose() { _optCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() => _saving = true);
    final newOpts = _optCtrl.text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final updated = List<Map<String, dynamic>>.from(widget.allSections);
    updated[widget.sectionIndex] = {
      ...updated[widget.sectionIndex],
      'options': newOpts,
    };
    await widget.onSave(updated);
    if (mounted) setState(() { _saving = false; _editing = false; });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.section['title'] as String? ?? '';
    final id = widget.section['id'] as String? ?? '';
    final opts = (widget.section['options'] as List?)?.cast<String>() ?? [];

    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text('id: $id', style: const TextStyle(fontSize: 11, color: AppColors.primary, fontFamily: 'monospace')),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(4)),
                  child: Text('${opts.length} seçenek', style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                ),
              ]),
            ]),
          ),
          if (!_editing)
            TextButton.icon(
              onPressed: () => setState(() => _editing = true),
              icon: const Icon(Icons.edit_outlined, size: 15),
              label: const Text('Düzenle', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            ),
        ]),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),

        if (_editing) ...[
          // Edit mode
          const Text('Her satıra bir seçenek yazın:', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _optCtrl,
              maxLines: null,
              expands: true,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(
              onPressed: () => setState(() { _editing = false; final o = (widget.section['options'] as List?)?.cast<String>() ?? []; _optCtrl.text = o.join('\n'); }),
              child: const Text('İptal', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            ABtn(label: _saving ? 'Kaydediliyor...' : 'Kaydet', icon: Icons.save_outlined, onTap: _saving ? null : _save),
          ]),
        ] else ...[
          // View mode — chip grid
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: opts.map((opt) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Text(opt, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                )).toList(),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Vehicle Data Tab ──────────────────────────────────────────────────────────

class _VehicleDataTab extends StatefulWidget {
  const _VehicleDataTab();
  @override
  State<_VehicleDataTab> createState() => _VehicleDataTabState();
}

class _VehicleDataTabState extends State<_VehicleDataTab> {
  final _db = FirebaseFirestore.instance;
  String _selectedDoc = 'brands_by_subcat';
  String? _selectedKey;
  final _textCtrl = TextEditingController();
  bool _saving = false;

  static const _docs = [
    ('brands_by_subcat', 'Markalar'),
    ('models_by_brand', 'Modeller'),
    ('engines_by_model', 'Motorlar'),
  ];

  @override
  void dispose() { _textCtrl.dispose(); super.dispose(); }

  Future<void> _save(Map<String, dynamic> currentData) async {
    if (_selectedKey == null) return;
    setState(() => _saving = true);
    final list = _textCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final updated = Map<String, dynamic>.from(currentData)..[_selectedKey!] = list;
    await _db.collection('vehicle_data').doc(_selectedDoc).set({'data': updated});
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _addKey(Map<String, dynamic> currentData) async {
    final ctrl = TextEditingController();
    final key = await showDialog<String>(context: context, builder: (c) => AlertDialog(
      title: const Text('Yeni Anahtar'),
      content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'anahtar_id'), autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('İptal')),
        ElevatedButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Ekle')),
      ],
    ));
    ctrl.dispose();
    if (key == null || key.isEmpty) return;
    final updated = Map<String, dynamic>.from(currentData)..[key] = <String>[];
    await _db.collection('vehicle_data').doc(_selectedDoc).set({'data': updated});
    setState(() { _selectedKey = key; _textCtrl.clear(); });
  }

  Future<void> _deleteKey(Map<String, dynamic> currentData) async {
    if (_selectedKey == null) return;
    final updated = Map<String, dynamic>.from(currentData)..remove(_selectedKey);
    await _db.collection('vehicle_data').doc(_selectedDoc).set({'data': updated});
    setState(() { _selectedKey = null; _textCtrl.clear(); });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('vehicle_data').doc(_selectedDoc).snapshots(),
      builder: (context, snap) {
        final raw = snap.hasData && snap.data!.exists
            ? ((snap.data!.data() as Map<String, dynamic>?)?['data'] as Map<String, dynamic>?) ?? {}
            : <String, dynamic>{};
        final keys = raw.keys.toList()..sort();

        if (_selectedKey != null && !keys.contains(_selectedKey) && keys.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _selectedKey = null); });
        }

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Doc selector
            Row(children: _docs.map((pair) {
              final sel = _selectedDoc == pair.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() { _selectedDoc = pair.$1; _selectedKey = null; _textCtrl.clear(); }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: sel ? AppColors.primary : AppColors.divider),
                    ),
                    child: Text(pair.$2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: sel ? Colors.white : AppColors.textSecondary)),
                  ),
                ),
              );
            }).toList()),
            const SizedBox(height: 16),
            Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Key list
                AdminCard(
                  padding: EdgeInsets.zero,
                  child: SizedBox(
                    width: 260,
                    child: Column(children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                        child: Row(children: [
                          const Text('Anahtarlar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          const Spacer(),
                          ABtn(label: 'Ekle', icon: Icons.add, small: true, onTap: () => _addKey(raw)),
                        ]),
                      ),
                      const Divider(),
                      Expanded(
                        child: !snap.hasData
                            ? const Center(child: CircularProgressIndicator())
                            : ListView.builder(
                                itemCount: keys.length,
                                itemBuilder: (c, i) {
                                  final k = keys[i];
                                  final sel = _selectedKey == k;
                                  return ListTile(
                                    dense: true,
                                    selected: sel,
                                    selectedTileColor: AppColors.primaryLight,
                                    title: Text(k, style: TextStyle(fontSize: 12, color: sel ? AppColors.primary : AppColors.textPrimary)),
                                    onTap: () {
                                      final vals = (raw[k] as List?)?.cast<String>() ?? [];
                                      setState(() { _selectedKey = k; _textCtrl.text = vals.join(', '); });
                                    },
                                  );
                                },
                              ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: 16),
                // Editor
                Expanded(
                  child: _selectedKey == null
                      ? const Center(child: Text('Sol taraftan bir anahtar seçin', style: TextStyle(color: AppColors.textLight)))
                      : AdminCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(_selectedKey!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                              ABtn(label: 'Anahtarı Sil', icon: Icons.delete_outline, color: AppColors.error, small: true, onTap: () => _deleteKey(raw)),
                            ]),
                            const SizedBox(height: 4),
                            const Text('Değerleri virgülle ayırarak girin:', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                            const SizedBox(height: 10),
                            Expanded(
                              child: TextField(
                                controller: _textCtrl,
                                maxLines: null, expands: true,
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ABtn(label: 'Kaydet', icon: Icons.save_outlined, onTap: _saving ? null : () => _save(raw)),
                            ),
                          ]),
                        ),
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

// ── Vehicle Cascade Tab ───────────────────────────────────────────────────────

class _VehicleCascadeTab extends StatefulWidget {
  const _VehicleCascadeTab();

  @override
  State<_VehicleCascadeTab> createState() => _VehicleCascadeTabState();
}

class _VehicleCascadeTabState extends State<_VehicleCascadeTab> {
  final _db = FirebaseFirestore.instance;

  static const _subcatIds = [
    'otomobil', 'arazi_suv', 'motosiklet', 'minivan', 'kamyonet',
    'kamyon', 'minibus', 'tir_cekici', 'caravan', 'atv',
    'tekne', 'su_motorsikleti', 'klasik', 'engelli_arac', 'is_makinesi_vasita',
  ];

  static const _defaultYears = [
    '2026','2025','2024','2023','2022','2021','2020','2019','2018','2017',
    '2016','2015','2014','2013','2012','2011','2010','2009','2008','2007',
    '2006','2005','2004','2003','2002','2001','2000','1999','1998','1997',
    '1996','1995','1994','1993','1992','1991','1990','1989','1988','1987',
    '1986','1985','1984','1983','1982','1981','1980','1979','1978','1977',
    '1976','1975','1974','1973','1972','1971','1970','1969','1968','1967',
    '1966','1965','1964','1963','1962','1961','1960','Daha Eski',
  ];

  static const _defaultFuelTypes = [
    'Benzin', 'Dizel', 'LPG & Benzin', 'Elektrik', 'Hibrit',
    'Plug-in Hibrit', 'Hidrojen', 'Diğer',
  ];

  static const _defaultTransmission = [
    'Otomatik', 'Manuel', 'Yarı Otomatik (DSG/CVT)', 'Tiptronic', 'Diğer',
  ];

  static const _defaultColors = [
    'Beyaz', 'Siyah', 'Gri', 'Gümüş', 'Mavi', 'Lacivert', 'Kırmızı', 'Bordo',
    'Yeşil', 'Sarı', 'Turuncu', 'Kahverengi', 'Bej', 'Krem', 'Mor', 'Pembe',
    'Altın', 'Bronz', 'Şampanya', 'Diğer',
  ];

  static const _defaultKmRanges = [
    '0 km (Sıfır / Kayıtsız)',
    '1–5.000 km',
    '5.001–20.000 km',
    '20.001–50.000 km',
    '50.001–80.000 km',
    '80.001–120.000 km',
    '120.001–160.000 km',
    '160.001–200.000 km',
    '200.001–250.000 km',
    '250.000+ km',
  ];

  String? _selectedSubcat;
  String? _selectedBrand;
  final _modelsCtrl = TextEditingController();
  bool _savingModels = false;
  bool _loadingDefaults = false;

  @override
  void dispose() {
    _modelsCtrl.dispose();
    super.dispose();
  }

  Future<void> _addBrand(Map<String, dynamic> brandsData) async {
    final ctrl = TextEditingController();
    final brand = await showDialog<String>(context: context, builder: (c) => AlertDialog(
      title: const Text('Marka Ekle'),
      content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Marka adı'), autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('İptal')),
        ElevatedButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Ekle')),
      ],
    ));
    ctrl.dispose();
    if (brand == null || brand.isEmpty || _selectedSubcat == null) return;
    final updated = Map<String, dynamic>.from(brandsData);
    final subcatBrands = List<String>.from((updated[_selectedSubcat] as List?) ?? []);
    if (!subcatBrands.contains(brand)) subcatBrands.add(brand);
    updated[_selectedSubcat!] = subcatBrands;
    await _db.collection('vehicle_data').doc('brands_by_subcat').set(updated, SetOptions(merge: false));
  }

  Future<void> _deleteBrand(Map<String, dynamic> brandsData, String brand) async {
    if (_selectedSubcat == null) return;
    final updated = Map<String, dynamic>.from(brandsData);
    final subcatBrands = List<String>.from((updated[_selectedSubcat] as List?) ?? []);
    subcatBrands.remove(brand);
    updated[_selectedSubcat!] = subcatBrands;
    await _db.collection('vehicle_data').doc('brands_by_subcat').set(updated, SetOptions(merge: false));
    if (_selectedBrand == brand) setState(() { _selectedBrand = null; _modelsCtrl.clear(); });
  }

  Future<void> _saveModels(Map<String, dynamic> modelsData) async {
    if (_selectedBrand == null) return;
    setState(() => _savingModels = true);
    final models = _modelsCtrl.text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final updated = Map<String, dynamic>.from(modelsData)..[_selectedBrand!] = models;
    await _db.collection('vehicle_data').doc('models_by_brand').set(updated, SetOptions(merge: false));
    if (mounted) setState(() => _savingModels = false);
  }

  Future<void> _loadDefaultSpecs() async {
    setState(() => _loadingDefaults = true);
    try {
      await _db.collection('vehicle_data').doc('common_specs').set({
        'years': _defaultYears,
        'fuel_types': _defaultFuelTypes,
        'transmission': _defaultTransmission,
        'colors': _defaultColors,
        'km_ranges': _defaultKmRanges,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Varsayılan değerler yüklendi!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loadingDefaults = false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('vehicle_data').doc('brands_by_subcat').snapshots(),
      builder: (context, brandsSnap) {
        final brandsData = brandsSnap.hasData && brandsSnap.data!.exists
            ? (brandsSnap.data!.data() as Map<String, dynamic>?) ?? {}
            : <String, dynamic>{};

        final brands = _selectedSubcat != null
            ? List<String>.from((brandsData[_selectedSubcat] as List?) ?? [])
            : <String>[];

        return StreamBuilder<DocumentSnapshot>(
          stream: _db.collection('vehicle_data').doc('models_by_brand').snapshots(),
          builder: (context, modelsSnap) {
            final modelsData = modelsSnap.hasData && modelsSnap.data!.exists
                ? (modelsSnap.data!.data() as Map<String, dynamic>?) ?? {}
                : <String, dynamic>{};

            final models = _selectedBrand != null
                ? List<String>.from((modelsData[_selectedBrand] as List?) ?? [])
                : <String>[];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // 3-column layout
                SizedBox(
                  height: 500,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Left: subcategory list
                    AdminCard(
                      padding: EdgeInsets.zero,
                      child: SizedBox(
                        width: 200,
                        child: Column(children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
                            child: Text('Alt Kategoriler',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _subcatIds.length,
                              itemBuilder: (c, i) {
                                final id = _subcatIds[i];
                                final sel = _selectedSubcat == id;
                                return InkWell(
                                  onTap: () => setState(() {
                                    _selectedSubcat = id;
                                    _selectedBrand = null;
                                    _modelsCtrl.clear();
                                  }),
                                  child: Container(
                                    color: sel ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    child: Text(id,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                                          color: sel ? AppColors.primary : AppColors.textPrimary,
                                        )),
                                  ),
                                );
                              },
                            ),
                          ),
                        ]),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Middle: brands
                    AdminCard(
                      padding: EdgeInsets.zero,
                      child: SizedBox(
                        width: 250,
                        child: Column(children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                            child: Row(children: [
                              Expanded(
                                child: Text(
                                  _selectedSubcat != null ? '$_selectedSubcat markaları' : 'Markalar',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_selectedSubcat != null)
                                _TinyBtn(Icons.add, AppColors.primary, () => _addBrand(brandsData), 'Marka ekle'),
                            ]),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: _selectedSubcat == null
                                ? const Center(child: Text('Soldan kategori seçin', style: TextStyle(color: AppColors.textLight, fontSize: 12)))
                                : !brandsSnap.hasData
                                    ? const Center(child: CircularProgressIndicator())
                                    : brands.isEmpty
                                        ? const Center(child: Text('Marka yok', style: TextStyle(color: AppColors.textLight, fontSize: 12)))
                                        : ListView.builder(
                                            itemCount: brands.length,
                                            itemBuilder: (c, i) {
                                              final brand = brands[i];
                                              final sel = _selectedBrand == brand;
                                              return InkWell(
                                                onTap: () {
                                                  final m = List<String>.from((modelsData[brand] as List?) ?? []);
                                                  setState(() {
                                                    _selectedBrand = brand;
                                                    _modelsCtrl.text = m.join('\n');
                                                  });
                                                },
                                                child: Container(
                                                  color: sel ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  child: Row(children: [
                                                    Expanded(
                                                      child: Text(brand,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                                                            color: sel ? AppColors.primary : AppColors.textPrimary,
                                                          )),
                                                    ),
                                                    _TinyBtn(Icons.close, AppColors.error,
                                                        () => _deleteBrand(brandsData, brand), 'Markayı sil'),
                                                  ]),
                                                ),
                                              );
                                            },
                                          ),
                          ),
                        ]),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Right: models
                    Expanded(
                      child: _selectedBrand == null
                          ? AdminCard(
                              child: const Center(
                                child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.touch_app_outlined, size: 40, color: AppColors.textLight),
                                  SizedBox(height: 10),
                                  Text('Ortadan bir marka seçin', style: TextStyle(color: AppColors.textLight, fontSize: 13)),
                                ]),
                              ),
                            )
                          : AdminCard(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('$_selectedBrand Modelleri',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                const SizedBox(height: 4),
                                Text('${models.length} model', style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                                const SizedBox(height: 12),
                                const Divider(),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: models.map((m) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.divider),
                                    ),
                                    child: Text(m, style: const TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                                  )).toList(),
                                ),
                                const SizedBox(height: 12),
                                const Divider(),
                                const SizedBox(height: 8),
                                const Text('Her satıra bir model (düzenle):', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 180,
                                  child: TextField(
                                    controller: _modelsCtrl,
                                    maxLines: null,
                                    expands: true,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                                      contentPadding: const EdgeInsets.all(10),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ABtn(
                                    label: _savingModels ? 'Kaydediliyor...' : 'Kaydet',
                                    icon: Icons.save_outlined,
                                    onTap: _savingModels ? null : () => _saveModels(modelsData),
                                  ),
                                ),
                              ]),
                            ),
                    ),
                  ]),
                ),

                const SizedBox(height: 24),

                // Common specs section
                _CommonSpecsSection(
                  onLoadDefaults: _loadingDefaults ? null : _loadDefaultSpecs,
                  loadingDefaults: _loadingDefaults,
                ),
              ]),
            );
          },
        );
      },
    );
  }
}

class _CommonSpecsSection extends StatelessWidget {
  final VoidCallback? onLoadDefaults;
  final bool loadingDefaults;

  const _CommonSpecsSection({required this.onLoadDefaults, required this.loadingDefaults});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('vehicle_data').doc('common_specs').snapshots(),
      builder: (context, snap) {
        final data = snap.hasData && snap.data!.exists
            ? (snap.data!.data() as Map<String, dynamic>?) ?? {}
            : <String, dynamic>{};

        return AdminCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('Ortak Araç Özellikleri',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              if (loadingDefaults)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else
                ABtn(
                  label: 'Varsayılanları Yükle',
                  icon: Icons.restore,
                  small: true,
                  onTap: onLoadDefaults,
                ),
            ]),
            const SizedBox(height: 16),
            if (!snap.hasData)
              const Center(child: CircularProgressIndicator())
            else ...[
              _SpecField(
                label: 'Yıllar',
                fieldKey: 'years',
                data: data,
                onSave: (vals) => db.collection('vehicle_data').doc('common_specs').set({'years': vals}, SetOptions(merge: true)),
              ),
              _SpecField(
                label: 'Yakıt Tipleri',
                fieldKey: 'fuel_types',
                data: data,
                onSave: (vals) => db.collection('vehicle_data').doc('common_specs').set({'fuel_types': vals}, SetOptions(merge: true)),
              ),
              _SpecField(
                label: 'Vites',
                fieldKey: 'transmission',
                data: data,
                onSave: (vals) => db.collection('vehicle_data').doc('common_specs').set({'transmission': vals}, SetOptions(merge: true)),
              ),
              _SpecField(
                label: 'Renkler',
                fieldKey: 'colors',
                data: data,
                onSave: (vals) => db.collection('vehicle_data').doc('common_specs').set({'colors': vals}, SetOptions(merge: true)),
              ),
              _SpecField(
                label: 'KM Aralıkları',
                fieldKey: 'km_ranges',
                data: data,
                onSave: (vals) => db.collection('vehicle_data').doc('common_specs').set({'km_ranges': vals}, SetOptions(merge: true)),
              ),
            ],
          ]),
        );
      },
    );
  }
}

class _SpecField extends StatefulWidget {
  final String label;
  final String fieldKey;
  final Map<String, dynamic> data;
  final Future<void> Function(List<String>) onSave;

  const _SpecField({
    required this.label,
    required this.fieldKey,
    required this.data,
    required this.onSave,
  });

  @override
  State<_SpecField> createState() => _SpecFieldState();
}

class _SpecFieldState extends State<_SpecField> {
  bool _expanded = false;
  bool _editing = false;
  bool _saving = false;
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    final vals = List<String>.from((widget.data[widget.fieldKey] as List?) ?? []);
    _ctrl = TextEditingController(text: vals.join('\n'));
  }

  @override
  void didUpdateWidget(_SpecField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing) {
      final vals = List<String>.from((widget.data[widget.fieldKey] as List?) ?? []);
      _ctrl.text = vals.join('\n');
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() => _saving = true);
    final vals = _ctrl.text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    await widget.onSave(vals);
    if (mounted) setState(() { _saving = false; _editing = false; });
  }

  @override
  Widget build(BuildContext context) {
    final vals = List<String>.from((widget.data[widget.fieldKey] as List?) ?? []);

    return Column(children: [
      InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(_expanded ? Icons.expand_more : Icons.chevron_right, size: 18, color: AppColors.textLight),
            const SizedBox(width: 8),
            Text(widget.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Text('${vals.length}', style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
      if (_expanded)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!_editing) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: vals.map((v) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Text(v, style: const TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                )).toList(),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _editing = true),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Düzenle', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                ),
              ),
            ] else ...[
              TextField(
                controller: _ctrl,
                maxLines: 8,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Her satıra bir değer',
                  hintStyle: const TextStyle(fontSize: 12, color: AppColors.textLight),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _editing = false;
                      _ctrl.text = vals.join('\n');
                    });
                  },
                  child: const Text('İptal', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ABtn(label: _saving ? 'Kaydediliyor...' : 'Kaydet', icon: Icons.save_outlined, small: true, onTap: _saving ? null : _save),
              ]),
            ],
          ]),
        ),
      const SizedBox(height: 8),
    ]);
  }
}

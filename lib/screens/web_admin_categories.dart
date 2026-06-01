import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
    _tabs = TabController(length: 3, vsync: this);
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
            labelColor: const Color(0xFF1A4F9C),
            unselectedLabelColor: const Color(0xFF8899AA),
            indicatorColor: const Color(0xFF1A4F9C),
            tabs: const [
              Tab(text: 'Kategoriler'),
              Tab(text: 'Araç Verileri'),
              Tab(text: 'Form Şemaları'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [
              _CategoriesTab(),
              _VehicleDataTab(),
              _SchemasTab(),
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

  Future<void> _addRoot(List<QueryDocumentSnapshot> all) async {
    final roots = all.where((d) => (d.data() as Map)['parentId'] == null);
    final ref = _db.collection('categories').doc();
    await ref.set(<String, dynamic>{
      'id': ref.id,
      'name': 'Yeni Kategori',
      'icon': 'category',
      'color': 0xFF1A4F9C.toDouble(),
      'order': roots.length.toDouble(),
      'schemaId': 'generic',
      'hasVehicleCatalog': false,
      'isLeaf': false,
    });
    setState(() => _expanded.add(ref.id));
  }

  Future<void> _addChild(String parentId, List<QueryDocumentSnapshot> all) async {
    final children = all.where((d) => (d.data() as Map)['parentId'] == parentId);
    final ref = _db.collection('categories').doc();
    await ref.set(<String, dynamic>{
      'id': ref.id,
      'name': 'Yeni Alt Kategori',
      'icon': 'category',
      'color': 0xFF1A4F9C.toDouble(),
      'order': children.length.toDouble(),
      'parentId': parentId,
      'schemaId': 'generic',
      'hasVehicleCatalog': false,
      'isLeaf': true,
    });
    setState(() => _expanded.add(parentId));
  }

  Future<void> _deleteRecursive(String id, List<QueryDocumentSnapshot> all) async {
    final children = all.where((d) => (d.data() as Map)['parentId'] == id);
    final batch = _db.batch();
    for (final c in children) {
      _deleteRecursiveInBatch(c.id, all, batch);
    }
    batch.delete(_db.collection('categories').doc(id));
    await batch.commit();
  }

  void _deleteRecursiveInBatch(
      String id, List<QueryDocumentSnapshot> all, WriteBatch batch) {
    final children = all.where((d) => (d.data() as Map)['parentId'] == id);
    for (final c in children) {
      _deleteRecursiveInBatch(c.id, all, batch);
    }
    batch.delete(_db.collection('categories').doc(id));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('categories').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snap.data!.docs;
        final roots = all
            .where((d) => (d.data() as Map)['parentId'] == null)
            .toList()
          ..sort((a, b) =>
              (((a.data() as Map)['order'] as int?) ?? 0)
                  .compareTo(((b.data() as Map)['order'] as int?) ?? 0));

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE8ECF0)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    children: [
                      const Text('Kategoriler',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A2035))),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _addRoot(all),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Ana Kategori Ekle',
                            style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE8ECF0)),
                Expanded(
                  child: roots.isEmpty
                      ? const Center(
                          child: Text('Henüz kategori yok',
                              style: TextStyle(color: Color(0xFF8899AA))))
                      : ListView.builder(
                          itemCount: roots.length,
                          itemBuilder: (_, i) => _CategoryTreeNode(
                            doc: roots[i],
                            all: all,
                            depth: 0,
                            expanded: _expanded,
                            onToggle: (id) =>
                                setState(() => _expanded.contains(id)
                                    ? _expanded.remove(id)
                                    : _expanded.add(id)),
                            onAddChild: (id) => _addChild(id, all),
                            onDelete: (id) => _deleteRecursive(id, all),
                            onSave: (id, name, icon, color, schemaId) => _db
                                .collection('categories')
                                .doc(id)
                                .update({
                                  'name': name,
                                  'icon': icon,
                                  'color': color,
                                  'schemaId': ?schemaId,
                                }),
                          ),
                        ),
                ),
              ],
            ),
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
  final void Function(String id) onToggle;
  final void Function(String parentId) onAddChild;
  final void Function(String id) onDelete;
  final Future<void> Function(String id, String name, String icon, int color, String? schemaId) onSave;

  const _CategoryTreeNode({
    required this.doc,
    required this.all,
    required this.depth,
    required this.expanded,
    required this.onToggle,
    required this.onAddChild,
    required this.onDelete,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final hasVehicleCatalog = d['hasVehicleCatalog'] as bool? ?? false;

    final subcatChildren = all
        .where((s) => (s.data() as Map)['parentId'] == doc.id)
        .toList()
      ..sort((a, b) =>
          (((a.data() as Map)['order'] as int?) ?? 0)
              .compareTo(((b.data() as Map)['order'] as int?) ?? 0));

    final hasChildren = subcatChildren.isNotEmpty || hasVehicleCatalog;
    final isExpanded = expanded.contains(doc.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryRow(
          doc: doc,
          data: d,
          depth: depth,
          hasChildren: hasChildren,
          isExpanded: isExpanded,
          onToggle: () => onToggle(doc.id),
          onAddChild: () => onAddChild(doc.id),
          onDelete: () => onDelete(doc.id),
          onSave: (name, icon, color, schemaId) => onSave(doc.id, name, icon, color, schemaId),
        ),
        if (isExpanded) ...[
          if (hasVehicleCatalog)
            _VehicleBrandsNode(categoryId: doc.id, depth: depth + 1),
          ...subcatChildren.map((c) => _CategoryTreeNode(
                doc: c,
                all: all,
                depth: depth + 1,
                expanded: expanded,
                onToggle: onToggle,
                onAddChild: onAddChild,
                onDelete: onDelete,
                onSave: onSave,
              )),
        ],
      ],
    );
  }
}


// ── Vehicle Brands Node ───────────────────────────────────────────────────────

class _VehicleBrandsNode extends StatefulWidget {
  final String categoryId;
  final int depth;
  const _VehicleBrandsNode({required this.categoryId, required this.depth});

  @override
  State<_VehicleBrandsNode> createState() => _VehicleBrandsNodeState();
}

class _VehicleBrandsNodeState extends State<_VehicleBrandsNode> {
  final _db = FirebaseFirestore.instance;
  final Set<String> _expandedBrands = {};
  Map<String, List<String>>? _cachedData;

  @override
  void initState() {
    super.initState();
    _loadData().then((data) {
      if (mounted) setState(() => _cachedData = data);
    });
  }

  void _updateLocal(void Function(Map<String, List<String>> data) updater) {
    if (!mounted) return;
    final current = Map<String, List<String>>.from(_cachedData ?? {});
    updater(current);
    setState(() => _cachedData = current);
  }

  double get _indent => 16.0 + widget.depth * 24.0;

  // Kullanıcı tarafıyla aynı koleksiyonları oku
  static const _catCollectionMap = <String, String>{
    'arazi_suv': 'arazi_suv_brands',
    'motosiklet': 'motosiklet_brands',
  };

  String get _brandsCollection =>
      _catCollectionMap[widget.categoryId] ?? 'vehicle_brands';

  Future<Map<String, List<String>>> _loadData() async {
    try {
      final col = _brandsCollection;
      // client-side filtreleme — arrayContains Firestore web'de index gerektirir
      final allBrandsSnap = await _db.collection(col).get();

      final brandDocs = allBrandsSnap.docs.where((d) {
        if (col != 'vehicle_brands') return true;
        final ids = (d.data() as Map)['categoryIds'];
        if (ids == null) return false;
        return (ids as List).contains(widget.categoryId);
      }).toList()
        ..sort((a, b) {
          final ao = (a.data() as Map)['sortOrder'] as int? ?? 0;
          final bo = (b.data() as Map)['sortOrder'] as int? ?? 0;
          return ao.compareTo(bo);
        });

      final result = <String, List<String>>{};
      for (final brandDoc in brandDocs) {
        final brandName = (brandDoc.data() as Map)['name'] as String? ?? brandDoc.id;
        try {
          final modelsSnap = await _db
              .collection(col)
              .doc(brandDoc.id)
              .collection('models')
              .get();
          final models = modelsSnap.docs.toList()
            ..sort((a, b) {
              final ao = (a.data() as Map)['sortOrder'] as int? ?? 0;
              final bo = (b.data() as Map)['sortOrder'] as int? ?? 0;
              return ao.compareTo(bo);
            });
          result[brandName] = models
              .map((d) => (d.data() as Map)['name'] as String? ?? d.id)
              .toList();
        } catch (_) {
          result[brandName] = [];
        }
      }
      _cachedData = result;
      return result;
    } catch (e) {
      debugPrint('[VehicleBrandsNode] _loadData hata: $e');
      return {};
    }
  }

  Future<String?> _brandDocId(String brandName) async {
    final col = _brandsCollection;
    final snap = await _db.collection(col).where('name', isEqualTo: brandName).limit(1).get();
    if (snap.docs.isNotEmpty) return snap.docs.first.id;
    // id'yi isimden türet
    return brandName.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
  }

  Future<void> _addBrand(Map<String, List<String>> current) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Marka Ekle'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Marka adı'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Ekle')),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty) return;
    final col = _brandsCollection;
    final docId = name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
    final existing = await _db.collection(col).doc(docId).get();
    final sortOrder = current.length;
    if (existing.exists) {
      // Marka zaten var — sadece bu kategoriyi ekle
      if (col == 'vehicle_brands') {
        await _db.collection(col).doc(docId).update({
          'categoryIds': FieldValue.arrayUnion([widget.categoryId]),
        });
      }
    } else {
      final data = <String, dynamic>{
        'id': docId,
        'name': name,
        'sortOrder': sortOrder,
      };
      if (col == 'vehicle_brands') {
        data['categoryIds'] = [widget.categoryId];
      }
      debugPrint('[addBrand] col=$col docId=$docId data=$data');
      try {
        await _db.collection(col).doc(docId).set(data);
        debugPrint('[addBrand] set başarılı');
      } catch (e, st) {
        debugPrint('[addBrand] set HATA: $e\n$st');
      }
    }
    _updateLocal((data) => data[name] = []);
  }

  Future<void> _deleteBrand(String brandName) async {
    final docId = await _brandDocId(brandName);
    if (docId == null) return;
    final col = _brandsCollection;
    final models = await _db.collection(col).doc(docId).collection('models').get();
    for (final m in models.docs) {
      await m.reference.delete();
    }
    await _db.collection(col).doc(docId).delete();
    _updateLocal((data) {
      data.remove(brandName);
      _expandedBrands.remove(brandName);
    });
  }

  Future<void> _addModel(String brandName) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('$brandName — Model Ekle'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Model adı'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Ekle')),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty) return;
    final brandDocId = await _brandDocId(brandName);
    if (brandDocId == null) return;
    final col = _brandsCollection;
    final modelId = name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
    final modelsCol = _db.collection(col).doc(brandDocId).collection('models');
    final count = (await modelsCol.get()).docs.length;
    await modelsCol.doc(modelId).set({'id': modelId, 'name': name, 'sortOrder': count}, SetOptions(merge: true));
    _updateLocal((data) => data[brandName] = [...(data[brandName] ?? []), name]);
  }

  Future<void> _deleteModel(String brandName, String modelName) async {
    final brandDocId = await _brandDocId(brandName);
    if (brandDocId == null) return;
    final col = _brandsCollection;
    final modelId = modelName.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
    await _db.collection(col).doc(brandDocId).collection('models').doc(modelId).delete();
    _updateLocal((data) {
      data[brandName] = (data[brandName] ?? []).where((m) => m != modelName).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _cachedData;
    if (data == null) {
      return Padding(
        padding: EdgeInsets.only(left: _indent, top: 8, bottom: 8),
        child: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final brands = data.keys.toList()..sort();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with "Markalar" label and add button
            Container(
              color: const Color(0xFFF5F7FA),
              padding: EdgeInsets.only(left: _indent, right: 8, top: 4, bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.directions_car, size: 13, color: Color(0xFF8899AA)),
                  const SizedBox(width: 6),
                  const Text('Markalar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF8899AA))),
                  const Spacer(),
                  Tooltip(
                    message: 'Marka ekle',
                    child: InkWell(
                      onTap: () => _addBrand(data),
                      child: const Icon(Icons.add_circle_outline, size: 14, color: Color(0xFF1A4F9C)),
                    ),
                  ),
                ],
              ),
            ),
            ...brands.map((brand) {
              final models = data[brand] ?? [];
              final isExpanded = _expandedBrands.contains(brand);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    color: const Color(0xFFF8F9FB),
                    padding: EdgeInsets.only(left: _indent + 8, right: 8, top: 3, bottom: 3),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => setState(() => isExpanded ? _expandedBrands.remove(brand) : _expandedBrands.add(brand)),
                          child: Icon(isExpanded ? Icons.expand_more : Icons.chevron_right, size: 15, color: const Color(0xFF8899AA)),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(brand, style: const TextStyle(fontSize: 12, color: Color(0xFF1A2035))),
                        ),
                        Text('${models.length} model', style: const TextStyle(fontSize: 10, color: Color(0xFF8899AA))),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Model ekle',
                          child: InkWell(
                            onTap: () => _addModel(brand),
                            child: const Icon(Icons.add_circle_outline, size: 13, color: Color(0xFF1A4F9C)),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'Markayı sil',
                          child: InkWell(
                            onTap: () => _deleteBrand(brand),
                            child: const Icon(Icons.delete_outline, size: 13, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isExpanded)
                    ...models.map((model) => Container(
                          color: const Color(0xFFFAFBFC),
                          padding: EdgeInsets.only(left: _indent + 32, right: 8, top: 2, bottom: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.subdirectory_arrow_right, size: 11, color: Color(0xFFCCCCCC)),
                              const SizedBox(width: 4),
                              Expanded(child: Text(model, style: const TextStyle(fontSize: 11, color: Color(0xFF1A2035)))),
                              Tooltip(
                                message: 'Modeli sil',
                                child: InkWell(
                                  onTap: () => _deleteModel(brand, model),
                                  child: const Icon(Icons.close, size: 12, color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        )),
                  const Divider(height: 1, color: Color(0xFFEEF0F3)),
                ],
              );
            }),
            const Divider(height: 1, color: Color(0xFFE8ECF0)),
          ],
        );
  }
}

// ── Category Row ──────────────────────────────────────────────────────────────

class _CategoryRow extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  final int depth;
  final bool hasChildren;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onAddChild;
  final VoidCallback onDelete;
  final Future<void> Function(String name, String icon, int color, String? schemaId) onSave;

  const _CategoryRow({
    required this.doc,
    required this.data,
    required this.depth,
    required this.hasChildren,
    required this.isExpanded,
    required this.onToggle,
    required this.onAddChild,
    required this.onDelete,
    required this.onSave,
  });

  @override
  State<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends State<_CategoryRow> {
  bool _editing = false;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _iconCtrl;
  late final TextEditingController _colorCtrl;
  late final TextEditingController _schemaCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.data['name'] ?? '');
    _iconCtrl = TextEditingController(text: widget.data['icon'] ?? 'category');
    _colorCtrl = TextEditingController(
        text: (widget.data['color'] as int? ?? 0xFF1A4F9C)
            .toRadixString(16)
            .padLeft(8, '0')
            .toUpperCase());
    _schemaCtrl = TextEditingController(text: widget.data['schemaId'] ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _iconCtrl.dispose();
    _colorCtrl.dispose();
    _schemaCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final colorVal =
        int.tryParse(_colorCtrl.text.replaceFirst('#', ''), radix: 16) ??
            0xFF1A4F9C;
    final schema = _schemaCtrl.text.trim();
    await widget.onSave(
      _nameCtrl.text.trim(),
      _iconCtrl.text.trim(),
      colorVal,
      schema.isEmpty ? null : schema,
    );
    if (mounted) setState(() { _saving = false; _editing = false; });
  }

  @override
  Widget build(BuildContext context) {
    final colorVal = widget.data['color'] as int? ?? 0xFF1A4F9C;
    final color = Color(colorVal);
    final indent = 16.0 + widget.depth * 24.0;

    return Column(
      children: [
        Container(
          color: widget.depth == 0
              ? null
              : const Color(0xFF1A4F9C).withValues(alpha: 0.02),
          padding: EdgeInsets.only(
              left: indent, right: 8, top: 4, bottom: 4),
          child: _editing
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      decoration: _deco('İsim'),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _iconCtrl,
                            decoration: _deco('İkon (ör: directions_car)'),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _colorCtrl,
                            decoration: _deco('Renk hex (ör: FF1565C0)'),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _schemaCtrl,
                            decoration: _deco('Şema ID (ör: phone, laptop)'),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _editing = false),
                          child: const Text('İptal', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A4F9C),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Kaydet',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                )
              : Row(
                  children: [
                    // expand/collapse toggle
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: widget.hasChildren
                          ? InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: widget.onToggle,
                              child: Icon(
                                widget.isExpanded
                                    ? Icons.expand_more
                                    : Icons.chevron_right,
                                size: 18,
                                color: const Color(0xFF8899AA),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.category, color: color, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(widget.data['name'] ?? '',
                          style: TextStyle(
                              fontSize: widget.depth == 0 ? 13 : 12,
                              fontWeight: widget.depth == 0
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: const Color(0xFF1A2035))),
                    ),
                    if ((widget.data['schemaId'] as String?) != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A4F9C).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(widget.data['schemaId'] as String,
                            style: const TextStyle(fontSize: 9, color: Color(0xFF1A4F9C), fontWeight: FontWeight.w600)),
                      ),
                    Text(widget.data['icon'] ?? '',
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF8899AA))),
                    const SizedBox(width: 6),
                    // add child button
                    Tooltip(
                      message: 'Alt kategori ekle',
                      child: IconButton(
                        icon: const Icon(Icons.add_circle_outline,
                            size: 15, color: Color(0xFF1A4F9C)),
                        onPressed: widget.onAddChild,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 15, color: Color(0xFF8899AA)),
                      onPressed: () => setState(() => _editing = true),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 15, color: Colors.red),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Sil'),
                            content: Text(
                                '"${widget.data['name']}" ve tüm alt kategorileri silinsin mi?'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('İptal')),
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  child: const Text('Sil',
                                      style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (ok == true) widget.onDelete();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
        ),
        const Divider(height: 1, color: Color(0xFFE8ECF0)),
      ],
    );
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF8899AA)),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFDDE2EA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFDDE2EA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide:
              const BorderSide(color: Color(0xFF1A4F9C), width: 1.5),
        ),
      );
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
    ('brands_by_subcat', 'Markalar (alt kategori → markalar)'),
    ('models_by_brand', 'Modeller (marka → modeller)'),
    ('engines_by_model', 'Motorlar (model → motorlar)'),
  ];

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(Map<String, dynamic> currentData) async {
    if (_selectedKey == null) return;
    setState(() => _saving = true);
    final list = _textCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final updated = Map<String, dynamic>.from(currentData)..[_selectedKey!] = list;
    await _db
        .collection('vehicle_data')
        .doc(_selectedDoc)
        .set({'data': updated});
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _addKey(Map<String, dynamic> currentData) async {
    final ctrl = TextEditingController();
    final key = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Yeni Anahtar'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'anahtar_id'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal')),
          TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Ekle')),
        ],
      ),
    );
    ctrl.dispose();
    if (key == null || key.isEmpty) return;
    final updated = Map<String, dynamic>.from(currentData)..[key] = <String>[];
    await _db
        .collection('vehicle_data')
        .doc(_selectedDoc)
        .set({'data': updated});
    setState(() => _selectedKey = key);
    _textCtrl.clear();
  }

  Future<void> _deleteKey(Map<String, dynamic> currentData) async {
    if (_selectedKey == null) return;
    final updated = Map<String, dynamic>.from(currentData)..remove(_selectedKey);
    await _db
        .collection('vehicle_data')
        .doc(_selectedDoc)
        .set({'data': updated});
    setState(() { _selectedKey = null; _textCtrl.clear(); });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db
          .collection('vehicle_data')
          .doc(_selectedDoc)
          .snapshots(),
      builder: (context, snap) {
        final raw = snap.hasData && snap.data!.exists
            ? ((snap.data!.data() as Map<String, dynamic>?)?['data']
                    as Map<String, dynamic>?) ??
                {}
            : <String, dynamic>{};

        final keys = raw.keys.toList()..sort();

        if (_selectedKey != null &&
            !keys.contains(_selectedKey) &&
            keys.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedKey = null);
          });
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doc selector
              Row(
                children: _docs.map((pair) {
                  final selected = _selectedDoc == pair.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(pair.$2,
                          style: TextStyle(
                              fontSize: 12,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF1A2035))),
                      selected: selected,
                      selectedColor: const Color(0xFF1A4F9C),
                      onSelected: (_) => setState(() {
                        _selectedDoc = pair.$1;
                        _selectedKey = null;
                        _textCtrl.clear();
                      }),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Key list
                    Container(
                      width: 260,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE8ECF0)),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(12, 10, 8, 10),
                            child: Row(
                              children: [
                                const Text('Anahtarlar',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1A2035))),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () => _addKey(raw),
                                  icon: const Icon(Icons.add, size: 14),
                                  label: const Text('Ekle',
                                      style: TextStyle(fontSize: 12)),
                                  style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8)),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFE8ECF0)),
                          Expanded(
                            child: !snap.hasData
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : ListView.builder(
                                    itemCount: keys.length,
                                    itemBuilder: (_, i) {
                                      final k = keys[i];
                                      final sel = _selectedKey == k;
                                      return ListTile(
                                        dense: true,
                                        selected: sel,
                                        selectedTileColor: const Color(
                                                0xFF1A4F9C)
                                            .withValues(alpha: 0.06),
                                        title: Text(k,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: sel
                                                    ? const Color(0xFF1A4F9C)
                                                    : const Color(
                                                        0xFF1A2035))),
                                        onTap: () {
                                          final vals =
                                              (raw[k] as List?)
                                                      ?.cast<String>() ??
                                                  [];
                                          setState(() {
                                            _selectedKey = k;
                                            _textCtrl.text =
                                                vals.join(', ');
                                          });
                                        },
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Editor
                    Expanded(
                      child: _selectedKey == null
                          ? const Center(
                              child: Text('Bir anahtar seçin',
                                  style: TextStyle(
                                      color: Color(0xFF8899AA))))
                          : Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFFE8ECF0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(_selectedKey!,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1A2035))),
                                      const Spacer(),
                                      TextButton.icon(
                                        onPressed: () => _deleteKey(raw),
                                        icon: const Icon(
                                            Icons.delete_outline,
                                            size: 14,
                                            color: Colors.red),
                                        label: const Text('Sil',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                      'Değerleri virgülle ayırarak girin:',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF8899AA))),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _textCtrl,
                                      maxLines: null,
                                      expands: true,
                                      style: const TextStyle(fontSize: 13),
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                              color: Color(0xFFDDE2EA)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                              color: Color(0xFFDDE2EA)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF1A4F9C),
                                              width: 1.5),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.all(12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      onPressed:
                                          _saving ? null : () => _save(raw),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF1A4F9C),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                      child: _saving
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child:
                                                  CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white))
                                          : const Text('Kaydet',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Form Şemaları Tab ─────────────────────────────────────────────────────────

class _SchemasTab extends StatefulWidget {
  const _SchemasTab();
  @override
  State<_SchemasTab> createState() => _SchemasTabState();
}

class _SchemasTabState extends State<_SchemasTab> {
  final _db = FirebaseFirestore.instance;
  String? _selectedSchemaId;
  int? _selectedSectionIdx;
  int? _selectedFieldIdx;
  bool _saving = false;

  static const _primary = Color(0xFF1A4F9C);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('listing_field_schemas').snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final schemas = snap.data!.docs.toList()..sort((a, b) => a.id.compareTo(b.id));

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Sol: Şema listesi ──────────────────────────────────────────
              _panel(
                width: 200,
                header: Row(
                  children: [
                    const Text('Şemalar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A2035))),
                    const Spacer(),
                    _iconBtn(Icons.add, 'Yeni şema', () => _addSchema()),
                  ],
                ),
                child: ListView.builder(
                  itemCount: schemas.length,
                  itemBuilder: (_, i) {
                    final id = schemas[i].id;
                    final sel = _selectedSchemaId == id;
                    return ListTile(
                      dense: true,
                      selected: sel,
                      selectedTileColor: _primary.withValues(alpha: 0.07),
                      title: Text(id, style: TextStyle(fontSize: 12, color: sel ? _primary : const Color(0xFF1A2035))),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                        onPressed: () => _deleteSchema(id),
                        padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                      ),
                      onTap: () => setState(() {
                        _selectedSchemaId = id;
                        _selectedSectionIdx = null;
                        _selectedFieldIdx = null;
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),

              // ── Orta: Section/Field ağacı ──────────────────────────────────
              if (_selectedSchemaId != null)
                StreamBuilder<DocumentSnapshot>(
                  stream: _db.collection('listing_field_schemas').doc(_selectedSchemaId).snapshots(),
                  builder: (ctx, sdoc) {
                    if (!sdoc.hasData || !sdoc.data!.exists) return const SizedBox();
                    final data = sdoc.data!.data() as Map<String, dynamic>;
                    final sections = (data['sections'] as List? ?? []).cast<Map<String, dynamic>>();

                    return _panel(
                      width: 280,
                      header: Row(
                        children: [
                          Expanded(child: Text(_selectedSchemaId!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A2035)), overflow: TextOverflow.ellipsis)),
                          _iconBtn(Icons.add, 'Section ekle', () => _addSection(sections)),
                        ],
                      ),
                      child: ListView.builder(
                        itemCount: sections.length,
                        itemBuilder: (_, si) {
                          final section = sections[si];
                          final fields = (section['fields'] as List? ?? []).cast<Map<String, dynamic>>();
                          final selSec = _selectedSectionIdx == si;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                color: selSec && _selectedFieldIdx == null
                                    ? _primary.withValues(alpha: 0.07)
                                    : const Color(0xFFF5F7FA),
                                child: ListTile(
                                  dense: true,
                                  title: Text(section['title'] as String? ?? '(section)',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8899AA))),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _iconBtn(Icons.add, 'Field ekle', () => _addField(sections, si)),
                                      _iconBtn(Icons.delete_outline, 'Sil', () => _deleteSection(sections, si), color: Colors.red),
                                    ],
                                  ),
                                  onTap: () => setState(() { _selectedSectionIdx = si; _selectedFieldIdx = null; }),
                                ),
                              ),
                              ...fields.asMap().entries.map((fe) {
                                final fi = fe.key;
                                final field = fe.value;
                                final selF = selSec && _selectedFieldIdx == fi;
                                return ListTile(
                                  dense: true,
                                  selected: selF,
                                  selectedTileColor: _primary.withValues(alpha: 0.07),
                                  contentPadding: const EdgeInsets.only(left: 24, right: 8),
                                  leading: Icon(_fieldTypeIcon(field['type'] as String? ?? 'text'), size: 14, color: selF ? _primary : const Color(0xFF8899AA)),
                                  title: Text(field['label'] as String? ?? field['key'] as String? ?? '',
                                      style: TextStyle(fontSize: 12, color: selF ? _primary : const Color(0xFF1A2035))),
                                  subtitle: Text(field['type'] as String? ?? '', style: const TextStyle(fontSize: 10, color: Color(0xFF8899AA))),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 13, color: Colors.red),
                                    onPressed: () => _deleteField(sections, si, fi),
                                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                                  ),
                                  onTap: () => setState(() { _selectedSectionIdx = si; _selectedFieldIdx = fi; }),
                                );
                              }),
                              const Divider(height: 1, color: Color(0xFFE8ECF0)),
                            ],
                          );
                        },
                      ),
                    );
                  },
                ),
              const SizedBox(width: 12),

              // ── Sağ: Düzenleyici ──────────────────────────────────────────
              if (_selectedSchemaId != null && _selectedSectionIdx != null)
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: _db.collection('listing_field_schemas').doc(_selectedSchemaId).snapshots(),
                    builder: (ctx, sdoc) {
                      if (!sdoc.hasData || !sdoc.data!.exists) return const SizedBox();
                      final data = sdoc.data!.data() as Map<String, dynamic>;
                      final sections = (data['sections'] as List? ?? []).cast<Map<String, dynamic>>();
                      if (_selectedSectionIdx! >= sections.length) return const SizedBox();
                      final section = sections[_selectedSectionIdx!];
                      final fields = (section['fields'] as List? ?? []).cast<Map<String, dynamic>>();

                      if (_selectedFieldIdx == null) {
                        return _SectionEditor(
                          section: section,
                          onSave: (updated) => _saveSection(sections, _selectedSectionIdx!, updated),
                          saving: _saving,
                        );
                      }
                      if (_selectedFieldIdx! >= fields.length) return const SizedBox();
                      return _FieldEditor(
                        field: fields[_selectedFieldIdx!],
                        onSave: (updated) => _saveField(sections, _selectedSectionIdx!, _selectedFieldIdx!, updated),
                        saving: _saving,
                      );
                    },
                  ),
                ),

              if (_selectedSchemaId == null)
                const Expanded(child: Center(child: Text('Bir şema seçin', style: TextStyle(color: Color(0xFF8899AA))))),
            ],
          ),
        );
      },
    );
  }

  Widget _panel({required double width, required Widget header, required Widget child}) {
    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE8ECF0))),
        child: Column(
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(12, 10, 8, 10), child: header),
            const Divider(height: 1, color: Color(0xFFE8ECF0)),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback onTap, {Color? color}) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 15, color: color ?? _primary),
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  IconData _fieldTypeIcon(String type) {
    switch (type) {
      case 'select': return Icons.list;
      case 'dependentSelect': return Icons.account_tree_outlined;
      case 'number': case 'numberWithUnit': return Icons.tag;
      case 'textarea': return Icons.notes;
      case 'imagePicker': return Icons.image_outlined;
      default: return Icons.text_fields;
    }
  }

  Future<void> _addSchema() async {
    final ctrl = TextEditingController();
    final id = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Yeni Şema'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Şema ID (ör: clothing)'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Ekle')),
        ],
      ),
    );
    ctrl.dispose();
    if (id == null || id.isEmpty) return;
    await _db.collection('listing_field_schemas').doc(id).set({
      'id': id,
      'sections': [
        {'id': 'price_section', 'title': 'FİYAT', 'sortOrder': 0, 'fields': [
          {'key': 'title', 'label': 'Başlık', 'type': 'text', 'required': true, 'placeholder': 'Başlık', 'sortOrder': 0},
          {'key': 'price', 'label': 'Fiyat', 'type': 'number', 'required': true, 'placeholder': 'Fiyat', 'sortOrder': 1},
          {'key': 'currency', 'label': 'Para Birimi', 'type': 'select', 'required': true, 'optionGroupId': 'currencies', 'defaultValue': 'GBP', 'sortOrder': 2},
        ]},
        {'id': 'desc_section', 'title': 'AÇIKLAMA', 'sortOrder': 2, 'fields': [
          {'key': 'description', 'label': 'Açıklama', 'type': 'textarea', 'required': false, 'sortOrder': 0},
        ]},
        {'id': 'photos_section', 'title': 'FOTOĞRAFLAR', 'sortOrder': 99, 'fields': [
          {'key': 'photos', 'label': 'Fotoğraflar', 'type': 'imagePicker', 'required': true, 'sortOrder': 0},
        ]},
      ],
    });
    setState(() { _selectedSchemaId = id; _selectedSectionIdx = null; _selectedFieldIdx = null; });
  }

  Future<void> _deleteSchema(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Şemayı Sil'),
        content: Text('"$id" şeması silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    await _db.collection('listing_field_schemas').doc(id).delete();
    if (_selectedSchemaId == id) setState(() { _selectedSchemaId = null; _selectedSectionIdx = null; _selectedFieldIdx = null; });
  }

  Future<void> _addSection(List<Map<String, dynamic>> sections) async {
    final updated = List<Map<String, dynamic>>.from(sections)..add({
      'id': 'section_${DateTime.now().millisecondsSinceEpoch}',
      'title': 'YENİ BÖLÜM',
      'sortOrder': sections.length,
      'fields': [],
    });
    await _db.collection('listing_field_schemas').doc(_selectedSchemaId).update({'sections': updated});
    setState(() { _selectedSectionIdx = updated.length - 1; _selectedFieldIdx = null; });
  }

  Future<void> _deleteSection(List<Map<String, dynamic>> sections, int idx) async {
    final updated = List<Map<String, dynamic>>.from(sections)..removeAt(idx);
    await _db.collection('listing_field_schemas').doc(_selectedSchemaId).update({'sections': updated});
    setState(() { _selectedSectionIdx = null; _selectedFieldIdx = null; });
  }

  Future<void> _saveSection(List<Map<String, dynamic>> sections, int idx, Map<String, dynamic> updated) async {
    setState(() => _saving = true);
    final list = List<Map<String, dynamic>>.from(sections);
    list[idx] = updated;
    await _db.collection('listing_field_schemas').doc(_selectedSchemaId).update({'sections': list});
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _addField(List<Map<String, dynamic>> sections, int si) async {
    final section = Map<String, dynamic>.from(sections[si]);
    final fields = List<Map<String, dynamic>>.from((section['fields'] as List? ?? []).cast<Map<String, dynamic>>());
    fields.add({'key': 'field_${DateTime.now().millisecondsSinceEpoch}', 'label': 'Yeni Alan', 'type': 'text', 'required': false, 'sortOrder': fields.length});
    section['fields'] = fields;
    final updatedSections = List<Map<String, dynamic>>.from(sections)..[si] = section;
    await _db.collection('listing_field_schemas').doc(_selectedSchemaId).update({'sections': updatedSections});
    setState(() { _selectedSectionIdx = si; _selectedFieldIdx = fields.length - 1; });
  }

  Future<void> _deleteField(List<Map<String, dynamic>> sections, int si, int fi) async {
    final section = Map<String, dynamic>.from(sections[si]);
    final fields = List<Map<String, dynamic>>.from((section['fields'] as List? ?? []).cast<Map<String, dynamic>>())..removeAt(fi);
    section['fields'] = fields;
    final updatedSections = List<Map<String, dynamic>>.from(sections)..[si] = section;
    await _db.collection('listing_field_schemas').doc(_selectedSchemaId).update({'sections': updatedSections});
    setState(() { _selectedSectionIdx = si; _selectedFieldIdx = null; });
  }

  Future<void> _saveField(List<Map<String, dynamic>> sections, int si, int fi, Map<String, dynamic> updated) async {
    setState(() => _saving = true);
    final section = Map<String, dynamic>.from(sections[si]);
    final fields = List<Map<String, dynamic>>.from((section['fields'] as List? ?? []).cast<Map<String, dynamic>>())..[fi] = updated;
    section['fields'] = fields;
    final updatedSections = List<Map<String, dynamic>>.from(sections)..[si] = section;
    await _db.collection('listing_field_schemas').doc(_selectedSchemaId).update({'sections': updatedSections});
    if (mounted) setState(() => _saving = false);
  }
}

// ── Section düzenleyici ───────────────────────────────────────────────────────

class _SectionEditor extends StatefulWidget {
  final Map<String, dynamic> section;
  final Future<void> Function(Map<String, dynamic>) onSave;
  final bool saving;
  const _SectionEditor({required this.section, required this.onSave, required this.saving});
  @override
  State<_SectionEditor> createState() => _SectionEditorState();
}

class _SectionEditorState extends State<_SectionEditor> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _idCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.section['title'] as String? ?? '');
    _idCtrl = TextEditingController(text: widget.section['id'] as String? ?? '');
  }

  @override
  void dispose() { _titleCtrl.dispose(); _idCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return _editorShell(
      title: 'Bölüm Düzenle',
      saving: widget.saving,
      onSave: () => widget.onSave({...widget.section, 'id': _idCtrl.text.trim(), 'title': _titleCtrl.text.trim()}),
      children: [
        _fieldWidget('Bölüm ID', _idCtrl),
        const SizedBox(height: 12),
        _fieldWidget('Başlık', _titleCtrl),
      ],
    );
  }
}

// ── Field düzenleyici ─────────────────────────────────────────────────────────

class _FieldEditor extends StatefulWidget {
  final Map<String, dynamic> field;
  final Future<void> Function(Map<String, dynamic>) onSave;
  final bool saving;
  const _FieldEditor({required this.field, required this.onSave, required this.saving});
  @override
  State<_FieldEditor> createState() => _FieldEditorState();
}

class _FieldEditorState extends State<_FieldEditor> {
  late final TextEditingController _keyCtrl, _labelCtrl, _placeholderCtrl,
      _unitCtrl, _optionGroupCtrl, _dependsOnCtrl, _defaultCtrl;
  late String _type;
  late bool _required;

  static const _types = ['text', 'number', 'numberWithUnit', 'textarea', 'select', 'dependentSelect', 'imagePicker'];

  @override
  void initState() {
    super.initState();
    final f = widget.field;
    _keyCtrl = TextEditingController(text: f['key'] as String? ?? '');
    _labelCtrl = TextEditingController(text: f['label'] as String? ?? '');
    _placeholderCtrl = TextEditingController(text: f['placeholder'] as String? ?? '');
    _unitCtrl = TextEditingController(text: f['unit'] as String? ?? '');
    _optionGroupCtrl = TextEditingController(text: f['optionGroupId'] as String? ?? '');
    _dependsOnCtrl = TextEditingController(text: f['dependsOn'] as String? ?? '');
    _defaultCtrl = TextEditingController(text: f['defaultValue'] as String? ?? '');
    _type = f['type'] as String? ?? 'text';
    _required = f['required'] as bool? ?? false;
  }

  @override
  void dispose() {
    for (final c in [_keyCtrl, _labelCtrl, _placeholderCtrl, _unitCtrl, _optionGroupCtrl, _dependsOnCtrl, _defaultCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _editorShell(
      title: 'Alan Düzenle',
      saving: widget.saving,
      onSave: () => widget.onSave({
        'key': _keyCtrl.text.trim(),
        'label': _labelCtrl.text.trim(),
        'type': _type,
        'required': _required,
        if (_placeholderCtrl.text.isNotEmpty) 'placeholder': _placeholderCtrl.text.trim(),
        if (_unitCtrl.text.isNotEmpty) 'unit': _unitCtrl.text.trim(),
        if (_optionGroupCtrl.text.isNotEmpty) 'optionGroupId': _optionGroupCtrl.text.trim(),
        if (_dependsOnCtrl.text.isNotEmpty) 'dependsOn': _dependsOnCtrl.text.trim(),
        if (_defaultCtrl.text.isNotEmpty) 'defaultValue': _defaultCtrl.text.trim(),
        'sortOrder': widget.field['sortOrder'] ?? 0,
      }),
      children: [
        Row(children: [
          Expanded(child: _fieldWidget('Alan Key', _keyCtrl)),
          const SizedBox(width: 12),
          Expanded(child: _fieldWidget('Etiket', _labelCtrl)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tip', style: TextStyle(fontSize: 12, color: Color(0xFF8899AA))),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _type,
                items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _type = v!),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFDDE2EA))),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFDDE2EA))),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1A4F9C), width: 1.5)),
                ),
              ),
            ],
          )),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Zorunlu', style: TextStyle(fontSize: 12, color: Color(0xFF8899AA))),
            Switch(value: _required, onChanged: (v) => setState(() => _required = v), activeThumbColor: const Color(0xFF1A4F9C)),
          ]),
        ]),
        const SizedBox(height: 12),
        _fieldWidget('Placeholder', _placeholderCtrl),
        if (_type == 'numberWithUnit') ...[const SizedBox(height: 12), _fieldWidget('Birim (ör: m², km)', _unitCtrl)],
        if (_type == 'select' || _type == 'dependentSelect') ...[const SizedBox(height: 12), _fieldWidget('Option Group ID', _optionGroupCtrl)],
        if (_type == 'dependentSelect') ...[const SizedBox(height: 12), _fieldWidget('Bağımlı Alan (dependsOn)', _dependsOnCtrl)],
        const SizedBox(height: 12),
        _fieldWidget('Varsayılan Değer', _defaultCtrl),
      ],
    );
  }
}

Widget _editorShell({required String title, required bool saving, required VoidCallback onSave, required List<Widget> children}) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE8ECF0))),
    child: ListView(
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A2035))),
        const SizedBox(height: 16),
        ...children,
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: saving ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A4F9C),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Kaydet', style: TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ),
      ],
    ),
  );
}

Widget _fieldWidget(String label, TextEditingController ctrl) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8899AA))),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 13),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFDDE2EA))),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFDDE2EA))),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1A4F9C), width: 1.5)),
        ),
      ),
    ],
  );
}

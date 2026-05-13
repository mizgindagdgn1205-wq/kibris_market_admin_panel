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
    _tabs = TabController(length: 2, vsync: this);
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
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [
              _CategoriesTab(),
              _VehicleDataTab(),
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
    await ref.set({
      'name': 'Yeni Kategori',
      'icon': 'category',
      'color': 0xFF1A4F9C,
      'order': roots.length,
      'parentId': null,
    });
    setState(() => _expanded.add(ref.id));
  }

  Future<void> _addChild(String parentId, List<QueryDocumentSnapshot> all) async {
    final children = all.where((d) => (d.data() as Map)['parentId'] == parentId);
    final ref = _db.collection('categories').doc();
    await ref.set({
      'name': 'Yeni Alt Kategori',
      'icon': 'category',
      'color': 0xFF1A4F9C,
      'order': children.length,
      'parentId': parentId,
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
                            onSave: (id, name, icon, color) => _db
                                .collection('categories')
                                .doc(id)
                                .update({'name': name, 'icon': icon, 'color': color}),
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
  final Future<void> Function(String id, String name, String icon, int color) onSave;

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
    final children = all
        .where((s) => (s.data() as Map)['parentId'] == doc.id)
        .toList()
      ..sort((a, b) =>
          (((a.data() as Map)['order'] as int?) ?? 0)
              .compareTo(((b.data() as Map)['order'] as int?) ?? 0));
    final hasChildren = children.isNotEmpty;
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
          onSave: (name, icon, color) => onSave(doc.id, name, icon, color),
        ),
        if (isExpanded)
          ...children.map((c) => _CategoryTreeNode(
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
    );
  }
}


class _CategoryRow extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  final int depth;
  final bool hasChildren;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onAddChild;
  final VoidCallback onDelete;
  final Future<void> Function(String name, String icon, int color) onSave;

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
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _iconCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final colorVal =
        int.tryParse(_colorCtrl.text.replaceFirst('#', ''), radix: 16) ??
            0xFF1A4F9C;
    await widget.onSave(_nameCtrl.text.trim(), _iconCtrl.text.trim(), colorVal);
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

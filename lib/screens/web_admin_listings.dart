import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/listing.dart';
import '../providers/listing_provider.dart';
import '../theme/app_theme.dart';

class WebAdminListings extends StatefulWidget {
  final bool onlyPending;
  const WebAdminListings({super.key, required this.onlyPending});

  @override
  State<WebAdminListings> createState() => _WebAdminListingsState();
}

class _WebAdminListingsState extends State<WebAdminListings> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String? _statusFilter;
  String? _locationFilter;
  int _page = 0;
  static const _perPage = 25;
  final Set<String> _selected = {};

  static const _locations = ['Lefkoşa', 'Girne', 'Gazimağusa', 'İskele', 'Güzelyurt', 'Lefke'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Listing> _filter(List<Listing> all) {
    var list = widget.onlyPending
        ? all.where((l) => l.status == ListingStatus.pending).toList()
        : [...all];

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((l) =>
          l.title.toLowerCase().contains(q) ||
          (l.sellerName ?? '').toLowerCase().contains(q) ||
          l.location.toLowerCase().contains(q)).toList();
    }
    if (_statusFilter != null) {
      list = list.where((l) => l.status.name == _statusFilter).toList();
    }
    if (_locationFilter != null) {
      list = list.where((l) => l.location == _locationFilter).toList();
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  void _setPage(int p) => setState(() { _page = p; _selected.clear(); });

  Future<void> _approve(Listing l) async {
    await context.read<ListingProvider>().setListingStatus(l.id, ListingStatus.active);
  }

  Future<void> _reject(Listing l) async {
    await context.read<ListingProvider>().setListingStatus(l.id, ListingStatus.expired);
  }

  Future<void> _delete(Listing l) async {
    final ok = await _confirm('İlanı sil', '"${l.title}" kalıcı olarak silinecek.');
    if (!mounted) return;
    if (ok) await context.read<ListingProvider>().deleteListing(l.id);
  }

  Future<bool> _confirm(String title, String msg) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: Text(msg),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('Sil'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _bulkApprove(List<Listing> all) async {
    final prov = context.read<ListingProvider>();
    for (final id in _selected.toList()) {
      final l = all.firstWhere((x) => x.id == id, orElse: () => all.first);
      if (l.status == ListingStatus.pending) {
        await prov.setListingStatus(id, ListingStatus.active);
      }
    }
    setState(() => _selected.clear());
  }

  Future<void> _bulkReject(List<Listing> all) async {
    final prov = context.read<ListingProvider>();
    for (final id in _selected.toList()) {
      await prov.setListingStatus(id, ListingStatus.expired);
    }
    setState(() => _selected.clear());
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<ListingProvider>().allListings;
    final filtered = _filter(all);
    final totalPages = (filtered.length / _perPage).ceil().clamp(1, 99999);
    final safePage = _page.clamp(0, totalPages - 1);
    final pageItems = filtered.skip(safePage * _perPage).take(_perPage).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          SectionHeader(
            title: widget.onlyPending ? 'Onay Bekleyen İlanlar' : 'Tüm İlanlar',
            subtitle: '${filtered.length} ilan',
          ),
          const SizedBox(height: 16),

          // ── Filters ───────────────────────────────────────────────────────
          AdminCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() { _search = v; _page = 0; }),
                      decoration: const InputDecoration(
                        hintText: 'Başlık, satıcı veya şehir ara...',
                        prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textLight),
                        contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (!widget.onlyPending)
                  _DropFilter(
                    hint: 'Durum',
                    value: _statusFilter,
                    items: const {'pending': 'Bekliyor', 'active': 'Aktif', 'expired': 'Reddedildi', 'sold': 'Satıldı'},
                    onChanged: (v) => setState(() { _statusFilter = v; _page = 0; }),
                  ),
                if (!widget.onlyPending) const SizedBox(width: 10),
                _DropFilter(
                  hint: 'Şehir',
                  value: _locationFilter,
                  items: {for (final l in _locations) l: l},
                  onChanged: (v) => setState(() { _locationFilter = v; _page = 0; }),
                ),
                if (_search.isNotEmpty || _statusFilter != null || _locationFilter != null) ...[
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () => setState(() { _search = ''; _statusFilter = null; _locationFilter = null; _searchCtrl.clear(); _page = 0; }),
                    child: const Text('Temizle', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Bulk actions ──────────────────────────────────────────────────
          if (_selected.isNotEmpty)
            AdminCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.primaryLight,
              child: Row(
                children: [
                  Text('${_selected.length} ilan seçildi',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  const SizedBox(width: 16),
                  ABtn(label: 'Toplu Onayla', icon: Icons.check, color: AppColors.success, small: true,
                      onTap: () => _bulkApprove(all)),
                  const SizedBox(width: 8),
                  ABtn(label: 'Toplu Reddet', icon: Icons.close, color: AppColors.error, small: true,
                      onTap: () => _bulkReject(all)),
                  const Spacer(),
                  TextButton(onPressed: () => setState(() => _selected.clear()), child: const Text('İptal')),
                ],
              ),
            ),
          if (_selected.isNotEmpty) const SizedBox(height: 10),

          // ── Table ─────────────────────────────────────────────────────────
          Expanded(
            child: AdminCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          child: Checkbox(
                            value: pageItems.isNotEmpty && pageItems.every((l) => _selected.contains(l.id)),
                            tristate: true,
                            onChanged: (v) => setState(() {
                              if (v == true) { _selected.addAll(pageItems.map((l) => l.id)); }
                              else { _selected.removeAll(pageItems.map((l) => l.id)); }
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const _TH('İlan', flex: 4),
                        const _TH('Satıcı', flex: 2),
                        const _TH('Şehir', flex: 2),
                        const _TH('Fiyat', flex: 2),
                        const _TH('Durum', flex: 2),
                        const _TH('Tarih', flex: 2),
                        const _TH('İşlem', flex: 2),
                      ],
                    ),
                  ),
                  const Divider(),
                  // Rows
                  Expanded(
                    child: pageItems.isEmpty
                        ? const Center(child: Text('İlan bulunamadı', style: TextStyle(color: AppColors.textLight)))
                        : ListView.separated(
                            itemCount: pageItems.length,
                            separatorBuilder: (c, i) => const Divider(height: 1),
                            itemBuilder: (_, i) => _ListingRow(
                              listing: pageItems[i],
                              selected: _selected.contains(pageItems[i].id),
                              onSelect: (v) => setState(() {
                                if (v) { _selected.add(pageItems[i].id); }
                                else { _selected.remove(pageItems[i].id); }
                              }),
                              onApprove: () => _approve(pageItems[i]),
                              onReject: () => _reject(pageItems[i]),
                              onDelete: () => _delete(pageItems[i]),
                              onToggleFeatured: () => context.read<ListingProvider>().toggleFeatured(pageItems[i].id),
                              onTap: () => _showDetail(context, pageItems[i]),
                            ),
                          ),
                  ),
                  // Pagination
                  const Divider(),
                  _Pagination(
                    page: safePage,
                    total: totalPages,
                    count: filtered.length,
                    perPage: _perPage,
                    onPage: _setPage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, Listing l) {
    showDialog(
      context: context,
      builder: (_) => _ListingDetailDialog(
        listing: l,
        onApprove: () => _approve(l),
        onReject: () => _reject(l),
        onToggleFeatured: () => context.read<ListingProvider>().toggleFeatured(l.id),
      ),
    );
  }
}

// ── Row ───────────────────────────────────────────────────────────────────────

class _ListingRow extends StatelessWidget {
  final Listing listing;
  final bool selected;
  final void Function(bool) onSelect;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onDelete;
  final VoidCallback onToggleFeatured;
  final VoidCallback onTap;
  const _ListingRow({
    required this.listing, required this.selected, required this.onSelect,
    required this.onApprove, required this.onReject, required this.onDelete,
    required this.onToggleFeatured, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = listing;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? AppColors.primaryLight : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: Checkbox(value: selected, onChanged: (v) => onSelect(v ?? false)),
            ),
            const SizedBox(width: 12),
            // İlan + thumbnail
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: l.imageUrls.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: l.imageUrls.first,
                            width: 40, height: 40, fit: BoxFit.cover,
                            errorWidget: (c, u, e) => _imgPlaceholder(),
                          )
                        : _imgPlaceholder(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(l.title,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                  ),
                ],
              ),
            ),
            Expanded(flex: 2, child: _cell(l.sellerName ?? '-')),
            Expanded(flex: 2, child: _cell(l.location)),
            Expanded(flex: 2, child: _cell('${l.price.toStringAsFixed(0)} ${l.currency}')),
            Expanded(flex: 2, child: _StatusChip(l.status)),
            Expanded(flex: 2, child: _cell(_date(l.createdAt))),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  _IconBtn(
                    l.isFeatured ? Icons.star : Icons.star_outline,
                    AppColors.accent,
                    onToggleFeatured,
                  ),
                  const SizedBox(width: 4),
                  if (l.status == ListingStatus.pending) ...[
                    _IconBtn(Icons.check, AppColors.success, onApprove),
                    const SizedBox(width: 4),
                    _IconBtn(Icons.close, AppColors.error, onReject),
                  ] else
                    _IconBtn(Icons.delete_outline, AppColors.error, onDelete),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(String t) => Text(t, maxLines: 1, overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary));

  String _date(DateTime d) => '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year}';

  Widget _imgPlaceholder() => Container(
      width: 40, height: 40, color: AppColors.background,
      child: const Icon(Icons.image_outlined, size: 18, color: AppColors.textLight));
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn(this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ── Status Chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final ListingStatus status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      ListingStatus.active  => ('Aktif',     AppColors.success, AppColors.successLight),
      ListingStatus.pending => ('Bekliyor',  AppColors.warning, AppColors.warningLight),
      ListingStatus.sold    => ('Satıldı',   AppColors.info,    AppColors.infoLight),
      ListingStatus.expired => ('Reddedildi',AppColors.error,   AppColors.errorLight),
    };
    return StatusBadge(label: label, color: color, bg: bg);
  }
}

// ── Pagination ────────────────────────────────────────────────────────────────

class _Pagination extends StatelessWidget {
  final int page, total, count, perPage;
  final void Function(int) onPage;
  const _Pagination({required this.page, required this.total, required this.count, required this.perPage, required this.onPage});

  @override
  Widget build(BuildContext context) {
    final from = page * perPage + 1;
    final to = (page * perPage + perPage).clamp(0, count);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text('$from–$to / $count ilan',
              style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
          const Spacer(),
          _PBtn(Icons.first_page, page > 0, () => onPage(0)),
          _PBtn(Icons.chevron_left, page > 0, () => onPage(page - 1)),
          ...List.generate(total.clamp(0, 5), (i) {
            final idx = (page - 2 + i).clamp(0, total - 1);
            final show = idx >= 0 && idx < total;
            if (!show) return const SizedBox.shrink();
            final sel = idx == page;
            return InkWell(
              onTap: () => onPage(idx),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: sel ? AppColors.primary : AppColors.divider),
                ),
                child: Text('${idx + 1}',
                    style: TextStyle(fontSize: 12, color: sel ? Colors.white : AppColors.textSecondary)),
              ),
            );
          }),
          _PBtn(Icons.chevron_right, page < total - 1, () => onPage(page + 1)),
          _PBtn(Icons.last_page, page < total - 1, () => onPage(total - 1)),
        ],
      ),
    );
  }
}

class _PBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PBtn(this.icon, this.enabled, this.onTap);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18),
      color: enabled ? AppColors.textSecondary : AppColors.textLight,
      onPressed: enabled ? onTap : null,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(),
    );
  }
}

// ── Detail Dialog ─────────────────────────────────────────────────────────────

class _ListingDetailDialog extends StatefulWidget {
  final Listing listing;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onToggleFeatured;
  const _ListingDetailDialog({required this.listing, required this.onApprove, required this.onReject, required this.onToggleFeatured});

  @override
  State<_ListingDetailDialog> createState() => _ListingDetailDialogState();
}

class _ListingDetailDialogState extends State<_ListingDetailDialog> {
  int _imgIdx = 0;

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year}  '
      '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    final screenW = MediaQuery.of(context).size.width;
    final dialogW = (screenW * 0.82).clamp(760.0, 1100.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: Colors.white,
      child: SizedBox(
        width: dialogW,
        height: 580,
        child: Row(
          children: [
            // ── Sol: resim paneli ────────────────────────────────────────
            Container(
              width: dialogW * 0.42,
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.horizontal(left: Radius.circular(14)),
              ),
              child: Column(
                children: [
                  // Büyük resim
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
                              // Resim sayacı
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
                              // Sol/sağ ok
                              if (l.imageUrls.length > 1) ...[
                                Positioned(
                                  left: 8, top: 0, bottom: 0,
                                  child: Center(
                                    child: _ArrowBtn(Icons.chevron_left, _imgIdx > 0,
                                        () => setState(() => _imgIdx--)),
                                  ),
                                ),
                                Positioned(
                                  right: 8, top: 0, bottom: 0,
                                  child: Center(
                                    child: _ArrowBtn(Icons.chevron_right, _imgIdx < l.imageUrls.length - 1,
                                        () => setState(() => _imgIdx++)),
                                  ),
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

            // ── Sağ: bilgi paneli ────────────────────────────────────────
            Expanded(
              child: Column(
                children: [
                  // Başlık bar
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 18, 16, 16),
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
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              const SizedBox(height: 6),
                              Row(children: [
                                _StatusChip(l.status),
                                if (l.isFeatured) ...[
                                  const SizedBox(width: 8),
                                  const StatusBadge(label: 'Öne Çıkan', color: Color(0xFFD97706), bg: Color(0xFFFFFBEB)),
                                ],
                              ]),
                            ],
                          ),
                        ),
                        Tooltip(
                          message: l.isFeatured ? 'Öne çıkarmayı kaldır' : 'Öne çıkar',
                          child: IconButton(
                            icon: Icon(
                              l.isFeatured ? Icons.star : Icons.star_outline,
                              size: 22,
                              color: l.isFeatured ? AppColors.accent : AppColors.textLight,
                            ),
                            onPressed: () { widget.onToggleFeatured(); Navigator.pop(context); },
                            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Fiyat
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
                          const SizedBox(height: 18),

                          // Bilgi tablosu
                          _InfoTable(rows: [
                            ('Satıcı',    l.sellerName?.isNotEmpty == true ? l.sellerName! : l.sellerId),
                            ('Şehir',     l.location),
                            ('İlçe',      l.district.isNotEmpty ? l.district : '-'),
                            ('Kategori',  l.categoryId.isNotEmpty ? l.categoryId : '-'),
                            ('Alt Kategori', l.subcategoryId.isNotEmpty ? l.subcategoryId : '-'),
                            ('İlan Türü', _typeLabel(l.type)),
                            ('Tarih',     _fmt(l.createdAt)),
                            ('Görüntülenme', '${l.viewCount}'),
                          ]),

                          // Özellikler
                          if (l.attributes.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text('Özellikler', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            _InfoTable(rows: l.attributes.entries.map((e) => (e.key, e.value)).toList()),
                          ],

                          // Açıklama
                          if (l.description.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text('Açıklama', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
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

                  // Alt butonlar
                  if (l.status == ListingStatus.pending)
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.divider)),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: ABtn(
                            label: 'Onayla', icon: Icons.check_circle_outline,
                            color: AppColors.success,
                            onTap: () { widget.onApprove(); Navigator.pop(context); },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ABtn(
                            label: 'Reddet', icon: Icons.cancel_outlined,
                            color: AppColors.error,
                            onTap: () { widget.onReject(); Navigator.pop(context); },
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

  String _typeLabel(ListingType t) => switch (t) {
    ListingType.sell   => 'Satılık',
    ListingType.rent   => 'Kiralık',
    ListingType.wanted => 'Aranıyor',
  };
}

class _ArrowBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _ArrowBtn(this.icon, this.enabled, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1.0 : 0.2,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _InfoTable extends StatelessWidget {
  final List<(String, String)> rows;
  const _InfoTable({required this.rows});

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
            child: Row(
              children: [
                Container(
                  width: 130,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      right: const BorderSide(color: AppColors.divider),
                      bottom: i < rows.length - 1 ? const BorderSide(color: AppColors.divider) : BorderSide.none,
                    ),
                  ),
                  child: Text(k, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: i < rows.length - 1 ? const BorderSide(color: AppColors.divider) : BorderSide.none,
                      ),
                    ),
                    child: Text(v, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}


// ── Helpers ───────────────────────────────────────────────────────────────────

class _TH extends StatelessWidget {
  final String label;
  final int flex;
  const _TH(this.label, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: AppColors.textLight, letterSpacing: 0.4)),
    );
  }
}

class _DropFilter extends StatelessWidget {
  final String hint;
  final String? value;
  final Map<String, String> items;
  final void Function(String?) onChanged;
  const _DropFilter({required this.hint, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: DropdownButtonHideUnderline(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: DropdownButton<String?>(
            value: value,
            hint: Text(hint, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
            items: [
              DropdownMenuItem(value: null, child: Text('Tümü ($hint)')),
              ...items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

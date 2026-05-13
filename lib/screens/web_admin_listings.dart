import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/listing_provider.dart';
import '../theme/app_theme.dart';
import '../models/listing.dart';

class WebAdminListings extends StatefulWidget {
  final bool onlyPending;
  const WebAdminListings({super.key, required this.onlyPending});

  @override
  State<WebAdminListings> createState() => _WebAdminListingsState();
}

class _WebAdminListingsState extends State<WebAdminListings> {
  String _search = '';
  String? _locationFilter;
  String? _categoryFilter;
  Listing? _selected; // sadece onlyPending modunda kullanılır

  static const _locations = ['Lefkoşa', 'Girne', 'Gazimağusa', 'İskele', 'Güzelyurt', 'Lefke'];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ListingProvider>();
    var listings = widget.onlyPending
        ? provider.allListings.where((l) => l.status == ListingStatus.pending).toList()
        : provider.allListings;

    // Seçili ilan hâlâ pending mi kontrol et
    if (_selected != null &&
        !listings.any((l) => l.id == _selected!.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selected = listings.isEmpty ? null : listings.first);
      });
    }

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      listings = listings.where((l) =>
          l.title.toLowerCase().contains(q) ||
          l.location.toLowerCase().contains(q) ||
          l.sellerId.toLowerCase().contains(q)).toList();
    }
    if (_locationFilter != null) {
      listings = listings.where((l) => l.location == _locationFilter).toList();
    }
    if (_categoryFilter != null) {
      listings = listings.where((l) => l.categoryId == _categoryFilter).toList();
    }

    // ── Onay Ekranı: 2-Panel Layout ────────────────────────────────────────
    if (widget.onlyPending) {
      if (listings.isEmpty) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 56, color: AppColors.success),
              SizedBox(height: 12),
              Text('Onay bekleyen ilan yok',
                  style: TextStyle(color: AppColors.textLight, fontSize: 15)),
            ],
          ),
        );
      }
      final sel = _selected ?? listings.first;
      return Row(
        children: [
          // Sol: bekleyen ilan listesi
          SizedBox(
            width: 320,
            child: Column(
              children: [
                Container(
                  color: const Color(0xFFF8F9FB),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${listings.length} bekliyor',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: Colors.orange)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.divider),
                Expanded(
                  child: ListView.separated(
                    itemCount: listings.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (_, i) {
                      final l = listings[i];
                      final isSelected = l.id == sel.id;
                      return InkWell(
                        onTap: () => setState(() => _selected = l),
                        child: Container(
                          color: isSelected
                              ? const Color(0xFF1A4F9C).withValues(alpha: 0.06)
                              : null,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              // Thumbnail
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: l.imageUrls.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: l.imageUrls.first,
                                        width: 52, height: 52,
                                        fit: BoxFit.cover,
                                        placeholder: (c, u) => Container(
                                            width: 52, height: 52,
                                            color: AppColors.background),
                                        errorWidget: (c, e, s) => _placeholder52(),
                                      )
                                    : _placeholder52(),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? const Color(0xFF1A4F9C)
                                                : AppColors.textPrimary)),
                                    const SizedBox(height: 3),
                                    Text('${l.sellerName ?? l.sellerId} · ${l.location}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textLight)),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.chevron_right,
                                    size: 16, color: Color(0xFF1A4F9C)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1, color: AppColors.divider),
          // Sağ: seçili ilanın tam detayı
          Expanded(
            child: _ReviewPanel(
              listing: sel,
              onApprove: () => _setStatus(context, sel, ListingStatus.active),
              onReject: () => _setStatus(context, sel, ListingStatus.expired),
              onDelete: () => _confirmDelete(context, sel),
            ),
          ),
        ],
      );
    }

    // ── Normal İlanlar: Tablo Layout ────────────────────────────────────────
    return Column(
      children: [
        // Toolbar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'İlan ara…',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textLight),
                    prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textLight),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _FilterChip(
                label: _locationFilter ?? 'Tüm Şehirler',
                items: _locations,
                onSelected: (v) => setState(() => _locationFilter = v == 'Tüm Şehirler' ? null : v),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: _categoryFilter != null ? _catLabel(_categoryFilter!) : 'Tüm Kategoriler',
                items: const ['Tüm Kategoriler', 'vasitalar', 'emlak', 'elektronik', 'ev_esyalari', 'giyim'],
                displayMap: const {
                  'vasitalar': 'Vasıtalar', 'emlak': 'Emlak', 'elektronik': 'Elektronik',
                  'ev_esyalari': 'Ev & Yaşam', 'giyim': 'Giyim',
                },
                onSelected: (v) => setState(() => _categoryFilter = v == 'Tüm Kategoriler' ? null : v),
              ),
              const Spacer(),
              Text('${listings.length} ilan',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
        Container(
          color: const Color(0xFFF8F9FB),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: const Row(
            children: [
              SizedBox(width: 48),
              SizedBox(width: 12),
              Expanded(flex: 3, child: _HeaderText('İlan Başlığı')),
              Expanded(flex: 1, child: _HeaderText('Satıcı')),
              Expanded(flex: 1, child: _HeaderText('Konum')),
              Expanded(flex: 1, child: _HeaderText('Fiyat')),
              Expanded(flex: 1, child: _HeaderText('Tarih')),
              Expanded(flex: 1, child: _HeaderText('Durum')),
              SizedBox(width: 120, child: _HeaderText('İşlemler')),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
        Expanded(
          child: listings.isEmpty
              ? const Center(child: Text('İlan bulunamadı',
                    style: TextStyle(color: AppColors.textLight)))
              : ListView.separated(
                  itemCount: listings.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (_, i) => _ListingRow(
                    listing: listings[i],
                    onApprove: () => _setStatus(context, listings[i], ListingStatus.active),
                    onReject: () => _setStatus(context, listings[i], ListingStatus.expired),
                    onToggleFeatured: () => context.read<ListingProvider>().toggleFeatured(listings[i].id),
                    onDelete: () => _confirmDelete(context, listings[i]),
                  ),
                ),
        ),
      ],
    );
  }

  void _setStatus(BuildContext context, Listing l, ListingStatus s) {
    context.read<ListingProvider>().setListingStatus(l.id, s);
    final msg = s == ListingStatus.active ? '"${l.title}" onaylandı' : '"${l.title}" reddedildi';
    final color = s == ListingStatus.active ? AppColors.success : Colors.red;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _confirmDelete(BuildContext context, Listing l) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İlanı Sil'),
        content: Text('"${l.title}" kalıcı olarak silinecek. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ListingProvider>().deleteListing(l.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('İlan silindi'), backgroundColor: Colors.red),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  Widget _placeholder52() => Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.image_outlined, size: 20, color: AppColors.textLight),
      );

  String _catLabel(String id) {
    const m = {
      'vasitalar': 'Vasıtalar', 'emlak': 'Emlak', 'elektronik': 'Elektronik',
      'ev_esyalari': 'Ev & Yaşam', 'giyim': 'Giyim',
    };
    return m[id] ?? id;
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final List<String> items;
  final Map<String, String>? displayMap;
  final void Function(String) onSelected;

  const _FilterChip({required this.label, required this.items, required this.onSelected, this.displayMap});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (_) => items.map((item) => PopupMenuItem(
        value: item,
        child: Text(displayMap?[item] ?? item, style: const TextStyle(fontSize: 13)),
      )).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String text;
  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary));
  }
}

class _ListingRow extends StatelessWidget {
  final Listing listing;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onToggleFeatured;
  final VoidCallback onDelete;

  const _ListingRow({
    required this.listing,
    required this.onApprove,
    required this.onReject,
    required this.onToggleFeatured,
    required this.onDelete,
  });

  void _showImages(BuildContext context) {
    if (listing.imageUrls.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(listing.title,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: listing.imageUrls.length,
                  itemBuilder: (_, i) => Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: listing.imageUrls[i],
                          fit: BoxFit.cover,
                          placeholder: (context2, url) => Container(
                              color: const Color(0xFFF0F2F5)),
                          errorWidget: (context2, e, s) => Container(
                            color: const Color(0xFFF0F2F5),
                            child: const Icon(Icons.broken_image_outlined,
                                color: Color(0xFF8899AA)),
                          ),
                        ),
                      ),
                      // Watermark overlay (admin görüntülemede)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _WatermarkPainter('İlango'),
                          ),
                        ),
                      ),
                      if (i == 0)
                        Positioned(
                          bottom: 4, left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A4F9C).withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Kapak',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showImages(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: listing.imageUrls.isNotEmpty
                  ? Stack(
                      children: [
                        CachedNetworkImage(
                            imageUrl: listing.imageUrls.first,
                            width: 48, height: 48, fit: BoxFit.cover,
                            placeholder: (c, u) => _imgPlaceholder(),
                            errorWidget: (c, e, s) => _imgPlaceholder()),
                        if (listing.imageUrls.length > 1)
                          Positioned(
                            bottom: 2, right: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('+${listing.imageUrls.length - 1}',
                                  style: const TextStyle(
                                      fontSize: 9, color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                    )
                  : _imgPlaceholder(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(listing.title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (listing.isFeatured)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.star, size: 12, color: Colors.amber),
                      ),
                    Text(listing.subcategoryId,
                        style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(listing.sellerName ?? listing.sellerId,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 1,
            child: Text(listing.location,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            flex: 1,
            child: Text(listing.formattedPrice,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
          Expanded(
            flex: 1,
            child: Text(listing.timeAgo,
                style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
          ),
          Expanded(
            flex: 1,
            child: _StatusBadge(status: listing.status),
          ),
          SizedBox(
            width: 120,
            child: Row(
              children: [
                if (listing.status == ListingStatus.pending) ...[
                  _Btn(icon: Icons.check, color: AppColors.success, tooltip: 'Onayla', onTap: onApprove),
                  const SizedBox(width: 4),
                  _Btn(icon: Icons.close, color: Colors.red, tooltip: 'Reddet', onTap: onReject),
                  const SizedBox(width: 4),
                ] else ...[
                  _Btn(
                    icon: listing.isFeatured ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    tooltip: listing.isFeatured ? 'Öne çıkarma kaldır' : 'Öne çıkar',
                    onTap: onToggleFeatured,
                  ),
                  const SizedBox(width: 4),
                ],
                _Btn(icon: Icons.delete_outline, color: Colors.red, tooltip: 'Sil', onTap: onDelete),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.image_outlined, size: 20, color: AppColors.textLight),
      );
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _Btn({required this.icon, required this.color, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ListingStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ListingStatus.active  => ('Yayında', AppColors.success),
      ListingStatus.pending => ('Bekliyor', Colors.orange),
      ListingStatus.sold    => ('Satıldı', Colors.blue),
      ListingStatus.expired => ('Reddedildi', Colors.red),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ── Review Panel (onay ekranı sağ panel) ─────────────────────────────────────

class _ReviewPanel extends StatefulWidget {
  final Listing listing;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onDelete;

  const _ReviewPanel({
    required this.listing,
    required this.onApprove,
    required this.onReject,
    required this.onDelete,
  });

  @override
  State<_ReviewPanel> createState() => _ReviewPanelState();
}

class _ReviewPanelState extends State<_ReviewPanel> {
  int _imgIdx = 0;

  @override
  void didUpdateWidget(_ReviewPanel old) {
    super.didUpdateWidget(old);
    if (old.listing.id != widget.listing.id) {
      setState(() => _imgIdx = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık + aksiyon butonları
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.person_outline, size: 13,
                          color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text(l.sellerName ?? l.sellerId,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(width: 12),
                      const Icon(Icons.location_on_outlined, size: 13,
                          color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text(l.location,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(width: 12),
                      const Icon(Icons.access_time, size: 13,
                          color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text(_fmt(l.createdAt),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textLight)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Onayla
              ElevatedButton.icon(
                onPressed: widget.onApprove,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Onayla',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              // Reddet
              OutlinedButton.icon(
                onPressed: widget.onReject,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Reddet',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              // Sil
              IconButton(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Sil',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 16),

          // İçerik: resimler sol + bilgiler sağ
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Resimler
              Expanded(
                flex: 5,
                child: l.imageUrls.isEmpty
                    ? Container(
                        height: 260,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: const Center(
                          child: Icon(Icons.image_not_supported_outlined,
                              size: 48, color: AppColors.textLight),
                        ),
                      )
                    : Column(
                        children: [
                          // Ana resim
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: AspectRatio(
                                  aspectRatio: 16 / 10,
                                  child: CachedNetworkImage(
                                    imageUrl: l.imageUrls[_imgIdx],
                                    fit: BoxFit.cover,
                                    fadeInDuration:
                                        const Duration(milliseconds: 150),
                                    placeholder: (c, u) => Container(
                                        color: AppColors.background),
                                    errorWidget: (c, e, s) => Container(
                                        color: AppColors.background,
                                        child: const Icon(
                                            Icons.broken_image_outlined,
                                            color: AppColors.textLight)),
                                  ),
                                ),
                              ),
                              // Watermark overlay
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: _WatermarkPainter('İlango'),
                                    ),
                                  ),
                                ),
                              ),
                              // Resim sayısı rozeti
                              Positioned(
                                bottom: 10, right: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${_imgIdx + 1} / ${l.imageUrls.length}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (l.imageUrls.length > 1) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 68,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: l.imageUrls.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 6),
                                itemBuilder: (_, i) => GestureDetector(
                                  onTap: () => setState(() => _imgIdx = i),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 120),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _imgIdx == i
                                            ? const Color(0xFF1A4F9C)
                                            : AppColors.divider,
                                        width: _imgIdx == i ? 2 : 1,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(5),
                                      child: CachedNetworkImage(
                                        imageUrl: l.imageUrls[i],
                                        width: 68, height: 68,
                                        fit: BoxFit.cover,
                                        placeholder: (c, u) => Container(
                                            width: 68, height: 68,
                                            color: AppColors.background),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(width: 20),
              // Bilgiler
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow('Fiyat',
                          '${l.currency}${l.formattedPrice}',
                          bold: true, valueColor: const Color(0xFFE8880A)),
                      _InfoRow('Tür', l.type == ListingType.sell ? 'Satılık' : l.type == ListingType.rent ? 'Kiralık' : 'Aranıyor'),
                      _InfoRow('Kategori', l.categoryId),
                      _InfoRow('Alt Kategori', l.subcategoryId),
                      _InfoRow('İlçe', l.district),
                      if (l.attributes.isNotEmpty) ...[
                        const Divider(height: 20),
                        const Text('Araç Özellikleri',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        ...l.attributes.entries.map((e) =>
                            _InfoRow(e.key, e.value)),
                      ],
                      const Divider(height: 20),
                      const Text('Açıklama',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      Text(l.description,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.6),
                          maxLines: 8,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _InfoRow(this.label, this.value,
      {this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textLight)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        bold ? FontWeight.w700 : FontWeight.w500,
                    color: valueColor ?? AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  final String text;
  const _WatermarkPainter(this.text);

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.30),
          fontSize: (size.width * 0.12).clamp(14.0, 36.0),
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final stepX = textPainter.width + 20;
    final stepY = textPainter.height + 20;
    final diagLen = math.sqrt(size.width * size.width + size.height * size.height);
    final cols = (diagLen / stepX).ceil() + 2;
    final rows = (diagLen / stepY).ceil() + 2;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 5);
    for (int r = -rows; r <= rows; r++) {
      for (int c = -cols; c <= cols; c++) {
        textPainter.paint(
          canvas,
          Offset(c * stepX - textPainter.width / 2,
              r * stepY - textPainter.height / 2),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

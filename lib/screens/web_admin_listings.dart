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

  static const _locations = ['Lefkoşa', 'Girne', 'Gazimağusa', 'İskele', 'Güzelyurt', 'Lefke'];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ListingProvider>();
    var listings = widget.onlyPending
        ? provider.allListings.where((l) => l.status == ListingStatus.pending).toList()
        : provider.allListings;

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

    return Column(
      children: [
        // Toolbar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // Search
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
              // Location filter
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
        // Table header
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
        // Rows
        Expanded(
          child: listings.isEmpty
              ? Center(
                  child: Text(
                    widget.onlyPending ? 'Onay bekleyen ilan yok' : 'İlan bulunamadı',
                    style: const TextStyle(color: AppColors.textLight),
                  ),
                )
              : ListView.separated(
                  itemCount: listings.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.divider),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: listing.imageUrls.isNotEmpty
                ? Image.network(listing.imageUrls.first, width: 48, height: 48, fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => _imgPlaceholder())
                : _imgPlaceholder(),
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

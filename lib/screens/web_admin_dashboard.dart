import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/listing_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../models/listing.dart';

class WebAdminDashboard extends StatelessWidget {
  const WebAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final listings = context.watch<ListingProvider>();
    final userProv = context.watch<UserProvider>();
    final all = listings.allListings;
    final pending = all.where((l) => l.status == ListingStatus.pending).length;
    final active = all.where((l) => l.status == ListingStatus.active).length;
    final sold = all.where((l) => l.status == ListingStatus.sold).length;
    final featured = all.where((l) => l.isFeatured).length;
    final totalUsers = userProv.users.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat cards
          Row(
            children: [
              _StatCard(
                label: 'Toplam İlan',
                value: '${all.length}',
                icon: Icons.list_alt,
                color: AppColors.primary,
                sub: '$active aktif',
              ),
              const SizedBox(width: 16),
              _StatCard(
                label: 'Onay Bekleyen',
                value: '$pending',
                icon: Icons.pending_actions,
                color: Colors.orange,
                sub: 'İnceleme gerekiyor',
                urgent: pending > 0,
              ),
              const SizedBox(width: 16),
              _StatCard(
                label: 'Öne Çıkan',
                value: '$featured',
                icon: Icons.star,
                color: Colors.amber,
                sub: 'Öne çıkarılmış ilan',
              ),
              const SizedBox(width: 16),
              _StatCard(
                label: 'Satıldı',
                value: '$sold',
                icon: Icons.check_circle_outline,
                color: AppColors.success,
                sub: 'Tamamlanan işlem',
              ),
              const SizedBox(width: 16),
              _StatCard(
                label: 'Kullanıcılar',
                value: '$totalUsers',
                icon: Icons.people,
                color: Colors.teal,
                sub: 'Kayıtlı üye',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Second row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pending listings
              Expanded(
                flex: 3,
                child: _PendingListingsCard(
                  listings: all.where((l) => l.status == ListingStatus.pending).take(5).toList(),
                  onApprove: (l) => _approve(context, l),
                  onReject: (l) => _reject(context, l),
                ),
              ),
              const SizedBox(width: 16),
              // Category breakdown
              Expanded(
                flex: 2,
                child: _CategoryBreakdown(listings: all),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Recent listings
          _RecentListings(listings: all.take(8).toList()),
        ],
      ),
    );
  }

  void _approve(BuildContext context, Listing l) {
    context.read<ListingProvider>().setListingStatus(l.id, ListingStatus.active);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${l.title}" onaylandı'), backgroundColor: AppColors.success),
    );
  }

  void _reject(BuildContext context, Listing l) {
    context.read<ListingProvider>().setListingStatus(l.id, ListingStatus.expired);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${l.title}" reddedildi'), backgroundColor: Colors.red),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String sub;
  final bool urgent;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.sub,
    this.urgent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: urgent ? Border.all(color: Colors.orange.withValues(alpha: 0.5)) : null,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (urgent) ...[
                  const Spacer(),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Text(value,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
          ],
        ),
      ),
    );
  }
}

class _PendingListingsCard extends StatelessWidget {
  final List<Listing> listings;
  final void Function(Listing) onApprove;
  final void Function(Listing) onReject;

  const _PendingListingsCard({required this.listings, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('Onay Bekleyen İlanlar',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const Spacer(),
                if (listings.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${listings.length}',
                        style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          if (listings.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('Onay bekleyen ilan yok', style: TextStyle(color: AppColors.textLight)),
              ),
            )
          else
            ...listings.map((l) => _PendingRow(listing: l, onApprove: onApprove, onReject: onReject)),
        ],
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  final Listing listing;
  final void Function(Listing) onApprove;
  final void Function(Listing) onReject;

  const _PendingRow({required this.listing, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: listing.imageUrls.isNotEmpty
                ? Image.network(listing.imageUrls.first, width: 44, height: 44, fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => _placeholder())
                : _placeholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(listing.title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${listing.location} · ${listing.timeAgo}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(listing.formattedPrice,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(width: 12),
          Row(
            children: [
              _ActionBtn(
                icon: Icons.check,
                color: AppColors.success,
                tooltip: 'Onayla',
                onTap: () => onApprove(listing),
              ),
              const SizedBox(width: 6),
              _ActionBtn(
                icon: Icons.close,
                color: Colors.red,
                tooltip: 'Reddet',
                onTap: () => onReject(listing),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 44, height: 44,
        color: AppColors.background,
        child: const Icon(Icons.image_outlined, size: 18, color: AppColors.textLight),
      );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionBtn({required this.icon, required this.color, required this.tooltip, required this.onTap});

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

class _CategoryBreakdown extends StatelessWidget {
  final List<Listing> listings;

  const _CategoryBreakdown({required this.listings});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final l in listings) {
      counts[l.categoryId] = (counts[l.categoryId] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Kategori Dağılımı',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: sorted.take(6).map((e) {
                final pct = listings.isEmpty ? 0.0 : e.value / listings.length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(_catLabel(e.key),
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ),
                          Text('${e.value}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 6,
                          backgroundColor: AppColors.divider,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _catLabel(String id) {
    const m = {
      'vasitalar': 'Vasıtalar',
      'emlak': 'Emlak',
      'elektronik': 'Elektronik',
      'ev_esyalari': 'Ev & Yaşam',
      'giyim': 'Giyim',
      'diger': 'Diğer',
    };
    return m[id] ?? id;
  }
}

class _RecentListings extends StatelessWidget {
  final List<Listing> listings;

  const _RecentListings({required this.listings});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Son İlanlar',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(1.5),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
              4: FlexColumnWidth(1.2),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFF8F9FB)),
                children: ['İlan Başlığı', 'Konum', 'Fiyat', 'Görüntülenme', 'Durum'].map((h) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(h,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                )).toList(),
              ),
              ...listings.map((l) => TableRow(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Text(l.title,
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Text(l.location,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Text(l.formattedPrice,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Text('${l.viewCount}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: _StatusBadge(status: l.status),
                  ),
                ],
              )),
            ],
          ),
          const SizedBox(height: 8),
        ],
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/listing_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../models/listing.dart';
import '../models/user_model.dart';

class WebAdminDashboard extends StatelessWidget {
  const WebAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final listings = context.watch<ListingProvider>();
    final userProv = context.watch<UserProvider>();
    final all = listings.allListings;
    final pending = all.where((l) => l.status == ListingStatus.pending).length;
    final active = all.where((l) => l.status == ListingStatus.active).length;
    final featured = all.where((l) => l.isFeatured).length;
    final totalViews = all.fold<int>(0, (sum, l) => sum + l.viewCount);
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
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => _ListingsDialog(
                    title: 'Tüm İlanlar',
                    listings: all,
                    showStatus: true,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              _StatCard(
                label: 'Onay Bekleyen',
                value: '$pending',
                icon: Icons.pending_actions,
                color: Colors.orange,
                sub: 'İnceleme gerekiyor',
                urgent: pending > 0,
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => _PendingDialog(
                    listings: all.where((l) => l.status == ListingStatus.pending).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              _StatCard(
                label: 'Öne Çıkan',
                value: '$featured',
                icon: Icons.star,
                color: Colors.amber,
                sub: 'Öne çıkarılmış ilan',
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => _ListingsDialog(
                    title: 'Öne Çıkan İlanlar',
                    listings: all.where((l) => l.isFeatured).toList(),
                    showStatus: false,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              _StatCard(
                label: 'Toplam Görüntülenme',
                value: '$totalViews',
                icon: Icons.visibility_outlined,
                color: Colors.indigo,
                sub: 'Tüm ilanlar',
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => _ViewsDialog(listings: all),
                ),
              ),
              const SizedBox(width: 16),
              _StatCard(
                label: 'Kullanıcılar',
                value: '$totalUsers',
                icon: Icons.people,
                color: Colors.teal,
                sub: 'Kayıtlı üye',
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => _UsersDialog(users: userProv.users),
                ),
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
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.sub,
    this.urgent = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: urgent
                ? Border.all(color: Colors.orange.withValues(alpha: 0.5))
                : onTap != null
                    ? Border.all(color: color.withValues(alpha: 0.2))
                    : null,
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
                  if (onTap != null && !urgent) ...[
                    const Spacer(),
                    Icon(Icons.chevron_right, size: 16, color: color.withValues(alpha: 0.5)),
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
      ),
    );
  }
}

// ── Görüntülenme Dialog ────────────────────────────────────────────────────────

class _ViewsDialog extends StatefulWidget {
  final List<Listing> listings;
  const _ViewsDialog({required this.listings});

  @override
  State<_ViewsDialog> createState() => _ViewsDialogState();
}

class _ViewsDialogState extends State<_ViewsDialog> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  List<Listing> _filter(int tabIndex) {
    final now = DateTime.now();
    DateTime from;
    switch (tabIndex) {
      case 0:
        from = DateTime(now.year, now.month, now.day);
      case 1:
        from = now.subtract(const Duration(days: 7));
      case 2:
        from = DateTime(now.year, now.month, 1);
      case 3:
        from = DateTime(now.year, 1, 1);
      default:
        from = DateTime(now.year, 1, 1);
    }
    return (widget.listings.where((l) => l.createdAt.isAfter(from)).toList()
      ..sort((a, b) => b.viewCount.compareTo(a.viewCount)));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 600,
        height: 520,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_outlined, size: 20, color: Colors.indigo),
                  const SizedBox(width: 10),
                  const Text('Görüntülenme İstatistikleri',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Tabs
            TabBar(
              controller: _tab,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              labelColor: Colors.indigo,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: Colors.indigo,
              tabs: const [
                Tab(text: 'Günlük'),
                Tab(text: 'Haftalık'),
                Tab(text: 'Aylık'),
                Tab(text: 'Yıllık'),
              ],
              onTap: (_) => setState(() {}),
            ),
            const Divider(height: 1, color: AppColors.divider),
            // List
            Expanded(
              child: AnimatedBuilder(
                animation: _tab,
                builder: (context2, snap) {
                  final items = _filter(_tab.index);
                  if (items.isEmpty) {
                    return const Center(
                      child: Text('Bu dönemde ilan bulunamadı',
                          style: TextStyle(color: AppColors.textLight)),
                    );
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (context3, index2) => const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (_, i) {
                      final l = items[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Row(
                          children: [
                            Text('${i + 1}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l.title,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Text('${l.location} · ${l.timeAgo}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Row(
                              children: [
                                const Icon(Icons.visibility_outlined, size: 14, color: Colors.indigo),
                                const SizedBox(width: 4),
                                Text('${l.viewCount}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.indigo)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
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

// ── Toplam İlan / Öne Çıkan Dialog ───────────────────────────────────────────

class _ListingsDialog extends StatelessWidget {
  final String title;
  final List<Listing> listings;
  final bool showStatus;

  const _ListingsDialog({
    required this.title,
    required this.listings,
    required this.showStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 640,
        height: 540,
        child: Column(
          children: [
            _DialogHeader(title: title, count: listings.length),
            const Divider(height: 1, color: AppColors.divider),
            if (listings.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('Gösterilecek ilan yok',
                      style: TextStyle(color: AppColors.textLight)),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: listings.length,
                  separatorBuilder: (_, i) => const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (_, i) {
                    final l = listings[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: l.imageUrls.isNotEmpty
                                ? Image.network(l.imageUrls.first,
                                    width: 40, height: 40, fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, st) => _imgPlaceholder())
                                : _imgPlaceholder(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.title,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text('${l.location} · ${l.timeAgo}',
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.textLight)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(l.formattedPrice,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary)),
                          if (showStatus) ...[
                            const SizedBox(width: 12),
                            _StatusBadge(status: l.status),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
        width: 40,
        height: 40,
        color: AppColors.background,
        child: const Icon(Icons.image_outlined, size: 16, color: AppColors.textLight),
      );
}

// ── Onay Bekleyen Dialog ──────────────────────────────────────────────────────

class _PendingDialog extends StatelessWidget {
  final List<Listing> listings;

  const _PendingDialog({required this.listings});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 640,
        height: 540,
        child: Column(
          children: [
            _DialogHeader(title: 'Onay Bekleyen İlanlar', count: listings.length, color: Colors.orange),
            const Divider(height: 1, color: AppColors.divider),
            if (listings.isEmpty)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, size: 48, color: AppColors.success),
                      SizedBox(height: 10),
                      Text('Onay bekleyen ilan yok',
                          style: TextStyle(color: AppColors.textLight)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: listings.length,
                  separatorBuilder: (_, i) => const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (_, i) {
                    final l = listings[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: l.imageUrls.isNotEmpty
                                ? Image.network(l.imageUrls.first,
                                    width: 40, height: 40, fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, st) => _pendingPlaceholder())
                                : _pendingPlaceholder(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.title,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text('${l.location} · ${l.timeAgo}',
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.textLight)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(l.formattedPrice,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary)),
                          const SizedBox(width: 12),
                          _ActionBtn(
                            icon: Icons.check,
                            color: AppColors.success,
                            tooltip: 'Onayla',
                            onTap: () {
                              context.read<ListingProvider>().setListingStatus(l.id, ListingStatus.active);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('"${l.title}" onaylandı'),
                                backgroundColor: AppColors.success,
                              ));
                            },
                          ),
                          const SizedBox(width: 6),
                          _ActionBtn(
                            icon: Icons.close,
                            color: Colors.red,
                            tooltip: 'Reddet',
                            onTap: () {
                              context.read<ListingProvider>().setListingStatus(l.id, ListingStatus.expired);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('"${l.title}" reddedildi'),
                                backgroundColor: Colors.red,
                              ));
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pendingPlaceholder() => Container(
        width: 40,
        height: 40,
        color: AppColors.background,
        child: const Icon(Icons.image_outlined, size: 16, color: AppColors.textLight),
      );
}

// ── Kullanıcılar Dialog ───────────────────────────────────────────────────────

class _UsersDialog extends StatelessWidget {
  final List<UserModel> users;

  const _UsersDialog({required this.users});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 600,
        height: 540,
        child: Column(
          children: [
            _DialogHeader(title: 'Kayıtlı Kullanıcılar', count: users.length, color: Colors.teal),
            const Divider(height: 1, color: AppColors.divider),
            if (users.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('Kullanıcı bulunamadı',
                      style: TextStyle(color: AppColors.textLight)),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, i) => const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (_, i) {
                    final u = users[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: u.photoUrl != null ? NetworkImage(u.photoUrl!) : null,
                            backgroundColor: Colors.teal.withValues(alpha: 0.1),
                            child: u.photoUrl == null
                                ? Text(
                                    u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(u.displayName,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textPrimary)),
                                const SizedBox(height: 2),
                                Text(u.email,
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.textLight),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: u.isBanned
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : Colors.teal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              u.isBanned ? 'Yasaklı' : 'Aktif',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: u.isBanned ? Colors.red : Colors.teal),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Ortak Dialog Header ───────────────────────────────────────────────────────

class _DialogHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _DialogHeader({
    required this.title,
    required this.count,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$count',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

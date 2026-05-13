import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/listing_provider.dart';
import '../providers/user_provider.dart';
import '../models/listing.dart';
import '../theme/app_theme.dart';

class WebAdminReports extends StatelessWidget {
  const WebAdminReports({super.key});

  @override
  Widget build(BuildContext context) {
    final listingProv = context.watch<ListingProvider>();
    final userProv = context.watch<UserProvider>();
    final all = listingProv.allListings;
    final users = userProv.users;

    final totalListings = all.length;
    final activeListings = all.where((l) => l.status == ListingStatus.active).length;
    final pendingListings = all.where((l) => l.status == ListingStatus.pending).length;
    final soldListings = all.where((l) => l.status == ListingStatus.sold).length;
    final rejectedListings = all.where((l) => l.status == ListingStatus.expired).length;
    final featuredListings = all.where((l) => l.isFeatured).length;
    final totalUsers = users.length;
    final adminUsers = users.where((u) => u.isAdmin).length;
    final bannedUsers = users.where((u) => u.isBanned).length;

    final categoryMap = <String, int>{};
    for (final l in all) {
      categoryMap[l.categoryId] = (categoryMap[l.categoryId] ?? 0) + 1;
    }
    final sortedCats = categoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final locationMap = <String, int>{};
    for (final l in all) {
      locationMap[l.location] = (locationMap[l.location] ?? 0) + 1;
    }
    final sortedLocs = locationMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Genel Rapor',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Firebase\'den alınan gerçek zamanlı veriler',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 24),

          // İlan istatistikleri
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ReportCard(
                  title: 'İlan İstatistikleri',
                  icon: Icons.list_alt,
                  color: AppColors.primary,
                  rows: [
                    _Row('Toplam İlan', '$totalListings'),
                    _Row('Yayında (Aktif)', '$activeListings',
                        color: AppColors.success),
                    _Row('Onay Bekleyen', '$pendingListings',
                        color: Colors.orange),
                    _Row('Satıldı', '$soldListings', color: Colors.blue),
                    _Row('Reddedildi / Süresi Doldu', '$rejectedListings',
                        color: Colors.red),
                    _Row('Öne Çıkan', '$featuredListings',
                        color: Colors.amber),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ReportCard(
                  title: 'Kullanıcı İstatistikleri',
                  icon: Icons.people,
                  color: Colors.teal,
                  rows: [
                    _Row('Toplam Kullanıcı', '$totalUsers'),
                    _Row('Admin', '$adminUsers', color: Colors.purple),
                    _Row('Yasaklı', '$bannedUsers', color: Colors.red),
                    _Row('Normal Üye', '${totalUsers - adminUsers - bannedUsers}',
                        color: AppColors.success),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kategori dağılımı
              Expanded(
                child: _BarChartCard(
                  title: 'Kategori Dağılımı',
                  icon: Icons.category,
                  color: AppColors.primary,
                  total: totalListings,
                  entries: sortedCats.map((e) => _BarEntry(_catLabel(e.key), e.value)).toList(),
                ),
              ),
              const SizedBox(width: 16),
              // Şehir dağılımı
              Expanded(
                child: _BarChartCard(
                  title: 'Şehir Dağılımı',
                  icon: Icons.location_on,
                  color: Colors.teal,
                  total: totalListings,
                  entries: sortedLocs.map((e) => _BarEntry(e.key, e.value)).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // İlan durumu dağılımı
          _StatusPieCard(
            active: activeListings,
            pending: pendingListings,
            sold: soldListings,
            rejected: rejectedListings,
            total: totalListings,
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

class _Row {
  final String label;
  final String value;
  final Color? color;
  const _Row(this.label, this.value, {this.color});
}

class _ReportCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<_Row> rows;

  const _ReportCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: rows.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        if (r.color != null)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: r.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Expanded(
                          child: Text(r.label,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                        ),
                        Text(r.value,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: r.color ?? AppColors.textPrimary)),
                      ],
                    ),
                  )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarEntry {
  final String label;
  final int value;
  const _BarEntry(this.label, this.value);
}

class _BarChartCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int total;
  final List<_BarEntry> entries;

  const _BarChartCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.total,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final top = entries.take(8).toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.all(16),
            child: total == 0
                ? const Center(
                    child: Text('Veri yok',
                        style: TextStyle(color: AppColors.textLight)))
                : Column(
                    children: top.map((e) {
                      final pct = e.value / total;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(e.label.isEmpty ? '(boş)' : e.label,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                ),
                                Text('${e.value}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 6,
                                backgroundColor: AppColors.divider,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(color),
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
}

class _StatusPieCard extends StatelessWidget {
  final int active;
  final int pending;
  final int sold;
  final int rejected;
  final int total;

  const _StatusPieCard({
    required this.active,
    required this.pending,
    required this.sold,
    required this.rejected,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('İlan Durum Dağılımı',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Row(
            children: [
              _statusTile('Yayında', active, total, AppColors.success),
              const SizedBox(width: 12),
              _statusTile('Bekliyor', pending, total, Colors.orange),
              const SizedBox(width: 12),
              _statusTile('Satıldı', sold, total, Colors.blue),
              const SizedBox(width: 12),
              _statusTile('Reddedildi', rejected, total, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusTile(String label, int count, int total, Color color) {
    final pct = total == 0 ? 0.0 : count / total;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 4),
            Text('${(pct * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

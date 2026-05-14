import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/listing.dart';
import '../providers/listing_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';

class WebAdminReports extends StatelessWidget {
  const WebAdminReports({super.key});

  @override
  Widget build(BuildContext context) {
    final listings = context.watch<ListingProvider>().allListings;
    final users    = context.watch<UserProvider>().users;

    final total    = listings.length;
    final active   = listings.where((l) => l.status == ListingStatus.active).length;
    final pending  = listings.where((l) => l.status == ListingStatus.pending).length;
    final sold     = listings.where((l) => l.status == ListingStatus.sold).length;
    final rejected = listings.where((l) => l.status == ListingStatus.expired).length;
    final featured = listings.where((l) => l.isFeatured).length;

    final catMap = <String, int>{};
    for (final l in listings) { catMap[l.categoryId] = (catMap[l.categoryId] ?? 0) + 1; }
    final topCats = (catMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(8).toList();

    final locMap = <String, int>{};
    for (final l in listings) { locMap[l.location] = (locMap[l.location] ?? 0) + 1; }
    final topLocs = (locMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(8).toList();

    final admins = users.where((u) => u.isAdmin).length;
    final banned = users.where((u) => u.isBanned).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader(title: 'Raporlar', subtitle: 'Firebase gerçek zamanlı veriler'),
        const SizedBox(height: 20),

        // ── İlan istatistikleri ──────────────────────────────────────────
        const _Label('İlan İstatistikleri'),
        const SizedBox(height: 10),
        Row(children: [
          _StatTile('Toplam', '$total', AppColors.primary, Icons.list_alt_rounded),
          const SizedBox(width: 12),
          _StatTile('Aktif', '$active', AppColors.success, Icons.check_circle_outline),
          const SizedBox(width: 12),
          _StatTile('Bekleyen', '$pending', AppColors.warning, Icons.access_time_rounded),
          const SizedBox(width: 12),
          _StatTile('Satılan', '$sold', AppColors.info, Icons.sell_outlined),
          const SizedBox(width: 12),
          _StatTile('Reddedilen', '$rejected', AppColors.error, Icons.cancel_outlined),
          const SizedBox(width: 12),
          _StatTile('Öne Çıkan', '$featured', const Color(0xFF7C3AED), Icons.star_outline),
        ]),
        const SizedBox(height: 24),

        // ── Kullanıcı istatistikleri ─────────────────────────────────────
        const _Label('Kullanıcı İstatistikleri'),
        const SizedBox(height: 10),
        Row(children: [
          _StatTile('Toplam Üye', '${users.length}', AppColors.primary, Icons.people_outline),
          const SizedBox(width: 12),
          _StatTile('Admin', '$admins', const Color(0xFF7C3AED), Icons.admin_panel_settings_outlined),
          const SizedBox(width: 12),
          _StatTile('Engellendi', '$banned', AppColors.error, Icons.block_outlined),
          const Expanded(child: SizedBox()),
          const Expanded(child: SizedBox()),
          const Expanded(child: SizedBox()),
        ]),
        const SizedBox(height: 24),

        // ── Dağılımlar ───────────────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _BarCard(title: 'Kategoriye Göre', entries: topCats, color: AppColors.primary)),
          const SizedBox(width: 16),
          Expanded(child: _BarCard(title: 'Şehre Göre', entries: topLocs, color: AppColors.success)),
        ]),
        const SizedBox(height: 16),

        // ── Durum özeti ──────────────────────────────────────────────────
        AdminCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Align(alignment: Alignment.centerLeft,
                  child: Text('İlan Durum Özeti', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
            ),
            const Divider(),
            _SummaryRow('Aktif',      active,   total, AppColors.success),
            _SummaryRow('Bekleyen',   pending,  total, AppColors.warning),
            _SummaryRow('Satılan',    sold,     total, AppColors.info),
            _SummaryRow('Reddedilen', rejected, total, AppColors.error),
            const SizedBox(height: 8),
          ]),
        ),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _StatTile(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) => Expanded(
    child: AdminCard(
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
        ]),
      ]),
    ),
  );
}

class _BarCard extends StatelessWidget {
  final String title;
  final List<MapEntry<String, int>> entries;
  final Color color;
  const _BarCard({required this.title, required this.entries, required this.color});

  @override
  Widget build(BuildContext context) {
    final maxVal = entries.isEmpty ? 1 : entries.first.value;
    return AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 16),
        if (entries.isEmpty)
          const Text('Veri yok', style: TextStyle(color: AppColors.textLight))
        else
          ...entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                Text('${e.value}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: e.value / maxVal, minHeight: 6,
                  backgroundColor: AppColors.divider,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ]),
          )),
      ]),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final int value, total;
  final Color color;
  const _SummaryRow(this.label, this.value, this.total, this.color);

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : value / total;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: AppColors.divider,
                valueColor: AlwaysStoppedAnimation(color)),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(width: 70, child: Text('$value  (${(pct * 100).toStringAsFixed(1)}%)',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
      ]),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary));
}

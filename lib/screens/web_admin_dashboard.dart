import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/listing.dart';
import '../providers/listing_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';

class WebAdminDashboard extends StatelessWidget {
  const WebAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final listings = context.watch<ListingProvider>().allListings;
    final users = context.watch<UserProvider>().users;

    final total   = listings.length;
    final pending = listings.where((l) => l.status == ListingStatus.pending).length;
    final active  = listings.where((l) => l.status == ListingStatus.active).length;
    final sold    = listings.where((l) => l.status == ListingStatus.sold).length;

    final recent = [...listings]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recentSlice = recent.take(8).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Dashboard', subtitle: 'Genel bakış'),
          const SizedBox(height: 20),

          // ── Stat cards ──────────────────────────────────────────────────
          Row(children: [
            _StatCard(label: 'Toplam İlan',   value: '$total',   icon: Icons.list_alt_rounded,    color: AppColors.primary),
            const SizedBox(width: 14),
            _StatCard(label: 'Onay Bekleyen', value: '$pending', icon: Icons.access_time_rounded,  color: AppColors.warning, urgent: pending > 0),
            const SizedBox(width: 14),
            _StatCard(label: 'Aktif İlan',    value: '$active',  icon: Icons.check_circle_outline, color: AppColors.success),
            const SizedBox(width: 14),
            _StatCard(label: 'Satılan',       value: '$sold',    icon: Icons.sell_outlined,         color: AppColors.info),
            const SizedBox(width: 14),
            _StatCard(label: 'Kullanıcı',     value: '${users.length}', icon: Icons.people_outline, color: const Color(0xFF7C3AED)),
          ]),

          const SizedBox(height: 24),

          // ── Recent listings ─────────────────────────────────────────────
          AdminCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Text('Son Eklenen İlanlar',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ),
                const Divider(),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(children: const [
                    _TH('İlan Başlığı', flex: 4),
                    _TH('Satıcı',       flex: 2),
                    _TH('Şehir',        flex: 2),
                    _TH('Fiyat',        flex: 2),
                    _TH('Durum',        flex: 2),
                    _TH('Tarih',        flex: 2),
                  ]),
                ),
                const Divider(),
                ...recentSlice.map((l) => _RecentRow(l)),
                if (recentSlice.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Henüz ilan yok', style: TextStyle(color: AppColors.textLight))),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Category breakdown ──────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _CategoryBreakdown(listings)),
              const SizedBox(width: 14),
              Expanded(child: _LocationBreakdown(listings)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final bool urgent;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color, this.urgent = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AdminCard(
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                        color: urgent ? AppColors.error : AppColors.textPrimary)),
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent Row ────────────────────────────────────────────────────────────────

class _RecentRow extends StatelessWidget {
  final Listing l;
  const _RecentRow(this.l);

  String _date(DateTime d) => '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (l.status) {
      ListingStatus.active  => ('Aktif',      AppColors.success, AppColors.successLight),
      ListingStatus.pending => ('Bekliyor',   AppColors.warning, AppColors.warningLight),
      ListingStatus.sold    => ('Satıldı',    AppColors.info,    AppColors.infoLight),
      ListingStatus.expired => ('Reddedildi', AppColors.error,   AppColors.errorLight),
    };
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(children: [
            Expanded(flex: 4, child: Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
            Expanded(flex: 2, child: _cell(l.sellerName ?? '-')),
            Expanded(flex: 2, child: _cell(l.location)),
            Expanded(flex: 2, child: _cell('${l.price.toStringAsFixed(0)} ${l.currency}')),
            Expanded(flex: 2, child: StatusBadge(label: label, color: color, bg: bg)),
            Expanded(flex: 2, child: _cell(_date(l.createdAt))),
          ]),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _cell(String t) => Text(t, maxLines: 1, overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary));
}

// ── Breakdown Cards ───────────────────────────────────────────────────────────

class _CategoryBreakdown extends StatelessWidget {
  final List<Listing> listings;
  const _CategoryBreakdown(this.listings);

  @override
  Widget build(BuildContext context) {
    final map = <String, int>{};
    for (final l in listings) {
      map[l.categoryId] = (map[l.categoryId] ?? 0) + 1;
    }
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(6).toList();
    final maxVal = top.isEmpty ? 1 : top.first.value;

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kategoriye Göre İlanlar',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          if (top.isEmpty)
            const Text('Veri yok', style: TextStyle(color: AppColors.textLight))
          else
            ...top.map((e) => _BarRow(label: e.key, value: e.value, max: maxVal)),
        ],
      ),
    );
  }
}

class _LocationBreakdown extends StatelessWidget {
  final List<Listing> listings;
  const _LocationBreakdown(this.listings);

  @override
  Widget build(BuildContext context) {
    final map = <String, int>{};
    for (final l in listings) {
      map[l.location] = (map[l.location] ?? 0) + 1;
    }
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(6).toList();
    final maxVal = top.isEmpty ? 1 : top.first.value;

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Şehre Göre İlanlar',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          if (top.isEmpty)
            const Text('Veri yok', style: TextStyle(color: AppColors.textLight))
          else
            ...top.map((e) => _BarRow(label: e.key, value: e.value, max: maxVal, color: AppColors.success)),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final int value, max;
  final Color color;
  const _BarRow({required this.label, required this.value, required this.max, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    final ratio = max == 0 ? 0.0 : value / max;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              Text('$value', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _TH extends StatelessWidget {
  final String label;
  final int flex;
  const _TH(this.label, {required this.flex});

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: AppColors.textLight, letterSpacing: 0.4)),
      );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/listing_provider.dart';
import '../models/listing.dart';
import '../theme/app_theme.dart';
import 'web_admin_categories.dart';
import 'web_admin_dashboard.dart';
import 'web_admin_listings.dart';
import 'web_admin_messages.dart';
import 'web_admin_reports.dart';
import 'web_admin_users.dart';

enum AdminSection { dashboard, pending, listings, users, messages, reports, categories }

class WebAdminShell extends StatefulWidget {
  const WebAdminShell({super.key});
  @override
  State<WebAdminShell> createState() => _WebAdminShellState();
}

class _WebAdminShellState extends State<WebAdminShell> {
  AdminSection _section = AdminSection.dashboard;

  static const _nav = [
    _NavItem(AdminSection.dashboard,  Icons.grid_view_rounded,    'Dashboard'),
    _NavItem(AdminSection.pending,    Icons.access_time_rounded,  'Onay Bekleyen'),
    _NavItem(AdminSection.listings,   Icons.list_alt_rounded,     'Tüm İlanlar'),
    _NavItem(AdminSection.users,      Icons.people_outline,       'Kullanıcılar'),
    _NavItem(AdminSection.messages,   Icons.chat_bubble_outline,  'Mesajlar'),
    _NavItem(AdminSection.reports,    Icons.bar_chart_rounded,    'Raporlar'),
    _NavItem(AdminSection.categories, Icons.category_outlined,    'Kategoriler'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          _Sidebar(section: _section, nav: _nav, onSelect: (s) => setState(() => _section = s)),
          Expanded(
            child: Column(
              children: [
                _TopBar(title: _nav.firstWhere((n) => n.section == _section).label),
                Expanded(child: _body()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() => switch (_section) {
        AdminSection.dashboard  => const WebAdminDashboard(),
        AdminSection.pending    => const WebAdminListings(onlyPending: true),
        AdminSection.listings   => const WebAdminListings(onlyPending: false),
        AdminSection.users      => const WebAdminUsers(),
        AdminSection.messages   => const WebAdminMessages(),
        AdminSection.reports    => const WebAdminReports(),
        AdminSection.categories => const WebAdminCategories(),
      };
}

// ── Sidebar ───────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final AdminSection section;
  final List<_NavItem> nav;
  final void Function(AdminSection) onSelect;
  const _Sidebar({required this.section, required this.nav, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Container(
      width: 220,
      color: AppColors.sidebar,
      child: Column(
        children: [
          // Logo
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(7)),
                  child: const Icon(Icons.storefront, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                const Text('Kıbrıs Market', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1E293B), height: 1),
          const SizedBox(height: 8),
          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: nav.map((item) => _NavTile(item: item, selected: section == item.section, onTap: () => onSelect(item.section))).toList(),
            ),
          ),
          const Divider(color: Color(0xFF1E293B), height: 1),
          // User + logout
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    auth.displayName.isNotEmpty ? auth.displayName[0].toUpperCase() : 'A',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(auth.displayName.isEmpty ? 'Admin' : auth.displayName,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      const Text('Yönetici', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Color(0xFF64748B), size: 18),
                  tooltip: 'Çıkış',
                  onPressed: () => auth.signOut(),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _NavTile({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Pending badge
    int pending = 0;
    if (item.section == AdminSection.pending) {
      try {
        pending = Provider.of<ListingProvider>(context)
            .allListings
            .where((l) => l.status == ListingStatus.pending)
            .length;
      } catch (_) {}
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(item.icon, size: 18,
                color: selected ? Colors.white : const Color(0xFF94A3B8)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(item.label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? Colors.white : const Color(0xFF94A3B8))),
            ),
            if (pending > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$pending',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String title;
  const _TopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(6)),
            child: const Row(
              children: [
                CircleAvatar(radius: 4, backgroundColor: AppColors.success),
                SizedBox(width: 6),
                Text('Canlı', style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final AdminSection section;
  final IconData icon;
  final String label;
  const _NavItem(this.section, this.icon, this.label);
}

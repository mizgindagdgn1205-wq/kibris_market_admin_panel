import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'web_admin_dashboard.dart';
import 'web_admin_listings.dart';
import 'web_admin_messages.dart';
import 'web_admin_users.dart';

enum AdminSection { dashboard, pendingListings, allListings, users, messages, reports }

class WebAdminShell extends StatefulWidget {
  const WebAdminShell({super.key});

  @override
  State<WebAdminShell> createState() => _WebAdminShellState();
}

class _WebAdminShellState extends State<WebAdminShell> {
  AdminSection _section = AdminSection.dashboard;

  static const _navItems = [
    _NavItem(AdminSection.dashboard,       Icons.dashboard_outlined,       Icons.dashboard,          'Dashboard'),
    _NavItem(AdminSection.pendingListings, Icons.pending_actions_outlined,  Icons.pending_actions,    'Onay Bekleyen'),
    _NavItem(AdminSection.allListings,     Icons.list_alt_outlined,         Icons.list_alt,           'Tüm İlanlar'),
    _NavItem(AdminSection.users,           Icons.people_outline,            Icons.people,             'Kullanıcılar'),
    _NavItem(AdminSection.messages,        Icons.chat_bubble_outline,       Icons.chat_bubble,        'Mesajlar'),
    _NavItem(AdminSection.reports,         Icons.bar_chart_outlined,        Icons.bar_chart,          'Raporlar'),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Erişim Yetkisi Yok', style: TextStyle(fontSize: 18))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Row(
        children: [
          _AdminSidebar(
            selected: _section,
            onSelect: (s) => setState(() => _section = s),
          ),
          Expanded(
            child: Column(
              children: [
                _AdminTopBar(section: _section),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return switch (_section) {
      AdminSection.dashboard       => const WebAdminDashboard(),
      AdminSection.pendingListings => const WebAdminListings(onlyPending: true),
      AdminSection.allListings     => const WebAdminListings(onlyPending: false),
      AdminSection.users           => const WebAdminUsers(),
      AdminSection.messages        => const WebAdminMessages(),
      AdminSection.reports         => const WebAdminDashboard(),
    };
  }
}

// ─── Sidebar ─────────────────────────────────────────────────────────────────

class _AdminSidebar extends StatelessWidget {
  final AdminSection selected;
  final void Function(AdminSection) onSelect;

  const _AdminSidebar({required this.selected, required this.onSelect});

  static const _navItems = _WebAdminShellState._navItems;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: const Color(0xFF1A2035),
      child: Column(
        children: [
          // Logo
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF2A3050))),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Text('Admin Panel',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              children: _navItems.map((item) {
                final isSelected = selected == item.section;
                return _pending(item) > 0 && !isSelected
                    ? _buildBadgeItem(item, isSelected)
                    : _buildItem(item, isSelected);
              }).toList(),
            ),
          ),
          // Bottom: site'ye dön
          const Divider(color: Color(0xFF2A3050), height: 1),
          InkWell(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: const Row(
                children: [
                  Icon(Icons.arrow_back, color: Color(0xFF8899AA), size: 18),
                  SizedBox(width: 10),
                  Text('Siteye Dön', style: TextStyle(color: Color(0xFF8899AA), fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  int _pending(_NavItem item) =>
      item.section == AdminSection.pendingListings ? 7 : 0;

  Widget _buildItem(_NavItem item, bool isSelected) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isSelected ? Border.all(color: AppColors.primary.withValues(alpha: 0.5)) : null,
      ),
      child: ListTile(
        dense: true,
        leading: Icon(isSelected ? item.activeIcon : item.icon,
            color: isSelected ? Colors.white : const Color(0xFF8899AA), size: 20),
        title: Text(item.label,
            style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF8899AA),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
        onTap: () => onSelect(item.section),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        minLeadingWidth: 20,
      ),
    );
  }

  Widget _buildBadgeItem(_NavItem item, bool isSelected) {
    final count = _pending(item);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        dense: true,
        leading: Icon(item.icon, color: const Color(0xFF8899AA), size: 20),
        title: Text(item.label,
            style: const TextStyle(color: Color(0xFF8899AA), fontSize: 13)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        onTap: () => onSelect(item.section),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        minLeadingWidth: 20,
      ),
    );
  }
}

// ─── Top Bar ─────────────────────────────────────────────────────────────────

class _AdminTopBar extends StatelessWidget {
  final AdminSection section;
  const _AdminTopBar({required this.section});

  static const _titles = {
    AdminSection.dashboard:       'Dashboard',
    AdminSection.pendingListings: 'Onay Bekleyen İlanlar',
    AdminSection.allListings:     'Tüm İlanlar',
    AdminSection.users:           'Kullanıcı Yönetimi',
    AdminSection.messages:        'Mesajlar',
    AdminSection.reports:         'Raporlar',
  };

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Text(_titles[section] ?? '',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(width: 7, height: 7,
                    decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                const Text('Canlı', style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              auth.displayName.isNotEmpty ? auth.displayName[0].toUpperCase() : 'A',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(auth.displayName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const Text('Yönetici', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final AdminSection section;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.section, this.icon, this.activeIcon, this.label);
}

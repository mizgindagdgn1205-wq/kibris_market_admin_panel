import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';

class WebAdminUsers extends StatefulWidget {
  const WebAdminUsers({super.key});
  @override
  State<WebAdminUsers> createState() => _WebAdminUsersState();
}

class _WebAdminUsersState extends State<WebAdminUsers> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String? _filter; // 'admin' | 'banned' | null
  int _page = 0;
  static const _perPage = 25;

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<UserModel> _filtered(List<UserModel> all) {
    var list = all;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((u) =>
          u.displayName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q)).toList();
    }
    if (_filter == 'admin')  list = list.where((u) => u.isAdmin).toList();
    if (_filter == 'banned') list = list.where((u) => u.isBanned).toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<UserProvider>();
    final filtered = _filtered(prov.users);
    final totalPages = (filtered.length / _perPage).ceil().clamp(1, 99999);
    final safePage = _page.clamp(0, totalPages - 1);
    final pageItems = filtered.skip(safePage * _perPage).take(_perPage).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Kullanıcılar', subtitle: '${filtered.length} kullanıcı'),
          const SizedBox(height: 16),

          // Filters
          AdminCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() { _search = v; _page = 0; }),
                    decoration: const InputDecoration(
                      hintText: 'İsim veya e-posta ara...',
                      prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textLight),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _FilterChip(label: 'Admin', selected: _filter == 'admin',
                  onTap: () => setState(() { _filter = _filter == 'admin' ? null : 'admin'; _page = 0; })),
              const SizedBox(width: 8),
              _FilterChip(label: 'Engellendi', selected: _filter == 'banned', color: AppColors.error,
                  onTap: () => setState(() { _filter = _filter == 'banned' ? null : 'banned'; _page = 0; })),
              if (_search.isNotEmpty || _filter != null) ...[
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => setState(() { _search = ''; _filter = null; _searchCtrl.clear(); _page = 0; }),
                  child: const Text('Temizle', style: TextStyle(fontSize: 12)),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 12),

          // Table
          Expanded(
            child: AdminCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                  ),
                  child: const Row(children: [
                    _TH('Kullanıcı',  flex: 4),
                    _TH('E-posta',    flex: 3),
                    _TH('Rol',        flex: 2),
                    _TH('Durum',      flex: 2),
                    _TH('Kayıt',      flex: 2),
                    _TH('İşlem',      flex: 2),
                  ]),
                ),
                const Divider(),
                Expanded(
                  child: pageItems.isEmpty
                      ? const Center(child: Text('Kullanıcı bulunamadı', style: TextStyle(color: AppColors.textLight)))
                      : ListView.separated(
                          itemCount: pageItems.length,
                          separatorBuilder: (c, i) => const Divider(height: 1),
                          itemBuilder: (c, i) => _UserRow(
                            user: pageItems[i],
                            onToggleAdmin: () => prov.setAdmin(pageItems[i].uid, !pageItems[i].isAdmin),
                            onToggleBan:   () => prov.setBanned(pageItems[i].uid, !pageItems[i].isBanned),
                          ),
                        ),
                ),
                const Divider(),
                _Pagination(page: safePage, total: totalPages, count: filtered.length, perPage: _perPage,
                    onPage: (p) => setState(() { _page = p; })),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── User Row ──────────────────────────────────────────────────────────────────

class _UserRow extends StatelessWidget {
  final UserModel user;
  final VoidCallback onToggleAdmin;
  final VoidCallback onToggleBan;
  const _UserRow({required this.user, required this.onToggleAdmin, required this.onToggleBan});

  String _date(DateTime? d) {
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final u = user;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(children: [
        // Avatar + name
        Expanded(flex: 4, child: Row(children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: AppColors.primaryLight,
            backgroundImage: u.photoUrl != null ? NetworkImage(u.photoUrl!) : null,
            child: u.photoUrl == null
                ? Text(u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(u.displayName.isNotEmpty ? u.displayName : 'İsimsiz',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ])),
        Expanded(flex: 3, child: _cell(u.email)),
        Expanded(flex: 2, child: u.isAdmin
            ? const StatusBadge(label: 'Admin', color: AppColors.primary, bg: AppColors.primaryLight)
            : const StatusBadge(label: 'Üye', color: AppColors.textSecondary, bg: AppColors.background)),
        Expanded(flex: 2, child: u.isBanned
            ? const StatusBadge(label: 'Engelli', color: AppColors.error, bg: AppColors.errorLight)
            : const StatusBadge(label: 'Aktif', color: AppColors.success, bg: AppColors.successLight)),
        Expanded(flex: 2, child: _cell(_date(u.createdAt))),
        Expanded(flex: 2, child: Row(children: [
          _ActionBtn(
            label: u.isAdmin ? 'Admin Al' : 'Admin Yap',
            color: AppColors.primary,
            onTap: onToggleAdmin,
          ),
          const SizedBox(width: 6),
          _ActionBtn(
            label: u.isBanned ? 'Aç' : 'Engelle',
            color: u.isBanned ? AppColors.success : AppColors.error,
            onTap: onToggleBan,
          ),
        ])),
      ]),
    );
  }

  Widget _cell(String t) => Text(t, maxLines: 1, overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary));
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }
}

// ── Filter Chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : AppColors.divider),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: selected ? color : AppColors.textSecondary)),
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(children: [
        Text('$from–$to / $count', style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
        const Spacer(),
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: page > 0 ? () => onPage(page - 1) : null,
            iconSize: 20, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        const SizedBox(width: 8),
        Text('${page + 1} / $total', style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 8),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: page < total - 1 ? () => onPage(page + 1) : null,
            iconSize: 20, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
      ]),
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
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: AppColors.textLight, letterSpacing: 0.4)),
      );
}

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class _AdminUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final int listingCount;
  final DateTime joinedAt;
  final bool isAdmin;
  final bool isBanned;

  const _AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.listingCount,
    required this.joinedAt,
    this.isAdmin = false,
    this.isBanned = false,
  });

  _AdminUser copyWith({bool? isAdmin, bool? isBanned}) => _AdminUser(
        id: id, name: name, email: email, phone: phone,
        listingCount: listingCount, joinedAt: joinedAt,
        isAdmin: isAdmin ?? this.isAdmin,
        isBanned: isBanned ?? this.isBanned,
      );
}

final _kMockUsers = [
  _AdminUser(id: 'user1', name: 'Ali Yılmaz',    email: 'ali@email.com',    phone: '0533 111 2233', listingCount: 12, joinedAt: DateTime(2023, 3, 15)),
  _AdminUser(id: 'user2', name: 'Mehmet Demir',  email: 'mehmet@email.com', phone: '0542 222 3344', listingCount: 5,  joinedAt: DateTime(2023, 7, 22)),
  _AdminUser(id: 'user3', name: 'Fatma Kaya',    email: 'fatma@email.com',  phone: '0555 333 4455', listingCount: 8,  joinedAt: DateTime(2024, 1, 8)),
  _AdminUser(id: 'user4', name: 'Ayşe Şahin',   email: 'ayse@email.com',   phone: '0537 444 5566', listingCount: 3,  joinedAt: DateTime(2024, 4, 19)),
  _AdminUser(id: 'user5', name: 'Hasan Arslan',  email: 'hasan@email.com',  phone: '0548 555 6677', listingCount: 21, joinedAt: DateTime(2022, 11, 3)),
  _AdminUser(id: 'user6', name: 'Zeynep Çelik',  email: 'zeynep@email.com', phone: '0561 666 7788', listingCount: 0,  joinedAt: DateTime(2025, 2, 14)),
  _AdminUser(id: 'user7', name: 'Kemal Öztürk',  email: 'kemal@email.com',  phone: '0532 777 8899', listingCount: 7,  joinedAt: DateTime(2023, 9, 30)),
  _AdminUser(id: 'admin1', name: 'Admin Kullanıcı', email: 'admin@kibris.com', phone: '0533 000 0001', listingCount: 0, joinedAt: DateTime(2022, 1, 1), isAdmin: true),
];

class WebAdminUsers extends StatefulWidget {
  const WebAdminUsers({super.key});

  @override
  State<WebAdminUsers> createState() => _WebAdminUsersState();
}

class _WebAdminUsersState extends State<WebAdminUsers> {
  String _search = '';
  final List<_AdminUser> _users = List.from(_kMockUsers);
  _AdminUser? _selected;

  List<_AdminUser> get _filtered {
    if (_search.isEmpty) return _users;
    final q = _search.toLowerCase();
    return _users.where((u) =>
        u.name.toLowerCase().contains(q) ||
        u.email.toLowerCase().contains(q) ||
        u.phone.contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // User list
        Expanded(
          flex: 3,
          child: Column(
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
                          hintText: 'Kullanıcı ara…',
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
                    const Spacer(),
                    Text('${_filtered.length} kullanıcı',
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
                    SizedBox(width: 40),
                    SizedBox(width: 12),
                    Expanded(flex: 2, child: Text('Ad Soyad', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                    Expanded(flex: 2, child: Text('E-posta', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                    Expanded(flex: 1, child: Text('İlan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                    Expanded(flex: 1, child: Text('Üyelik', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                    Expanded(flex: 1, child: Text('Durum', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                    SizedBox(width: 80, child: Text('İşlem', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: ListView.separated(
                  itemCount: _filtered.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (_, i) {
                    final u = _filtered[i];
                    final isSelected = _selected?.id == u.id;
                    return InkWell(
                      onTap: () => setState(() => _selected = isSelected ? null : u),
                      child: Container(
                        color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: Text(
                                u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(u.name,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                                  Text(u.phone, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(u.email,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text('${u.listingCount}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                '${u.joinedAt.day}.${u.joinedAt.month}.${u.joinedAt.year}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: _UserBadge(isAdmin: u.isAdmin, isBanned: u.isBanned),
                            ),
                            SizedBox(
                              width: 80,
                              child: Row(
                                children: [
                                  if (!u.isAdmin)
                                    _UserBtn(
                                      icon: u.isBanned ? Icons.lock_open : Icons.block,
                                      color: u.isBanned ? AppColors.success : Colors.red,
                                      tooltip: u.isBanned ? 'Yasağı Kaldır' : 'Yasakla',
                                      onTap: () => setState(() {
                                        final idx = _users.indexWhere((x) => x.id == u.id);
                                        if (idx != -1) _users[idx] = u.copyWith(isBanned: !u.isBanned);
                                      }),
                                    ),
                                  const SizedBox(width: 4),
                                  _UserBtn(
                                    icon: u.isAdmin ? Icons.admin_panel_settings : Icons.admin_panel_settings_outlined,
                                    color: u.isAdmin ? Colors.purple : AppColors.textLight,
                                    tooltip: u.isAdmin ? 'Admin yetkisini kaldır' : 'Admin yap',
                                    onTap: () => setState(() {
                                      final idx = _users.indexWhere((x) => x.id == u.id);
                                      if (idx != -1) _users[idx] = u.copyWith(isAdmin: !u.isAdmin);
                                    }),
                                  ),
                                ],
                              ),
                            ),
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
        // User detail panel
        if (_selected != null) ...[
          const VerticalDivider(width: 1, color: AppColors.divider),
          SizedBox(
            width: 300,
            child: _UserDetailPanel(
              user: _selected!,
              onClose: () => setState(() => _selected = null),
            ),
          ),
        ],
      ],
    );
  }
}

class _UserBadge extends StatelessWidget {
  final bool isAdmin;
  final bool isBanned;

  const _UserBadge({required this.isAdmin, required this.isBanned});

  @override
  Widget build(BuildContext context) {
    if (isBanned) {
      return _badge('Yasaklı', Colors.red);
    } else if (isAdmin) {
      return _badge('Admin', Colors.purple);
    }
    return _badge('Aktif', AppColors.success);
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );
}

class _UserBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _UserBtn({required this.icon, required this.color, required this.tooltip, required this.onTap});

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

class _UserDetailPanel extends StatelessWidget {
  final _AdminUser user;
  final VoidCallback onClose;

  const _UserDetailPanel({required this.user, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                const Text('Kullanıcı Detayı',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(user.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ),
                  const SizedBox(height: 4),
                  Center(child: _UserBadge(isAdmin: user.isAdmin, isBanned: user.isBanned)),
                  const SizedBox(height: 20),
                  _DetailRow(label: 'E-posta', value: user.email),
                  _DetailRow(label: 'Telefon', value: user.phone),
                  _DetailRow(label: 'Kullanıcı ID', value: user.id),
                  _DetailRow(label: 'Üyelik Tarihi',
                      value: '${user.joinedAt.day}.${user.joinedAt.month}.${user.joinedAt.year}'),
                  _DetailRow(label: 'Toplam İlan', value: '${user.listingCount}'),
                  const SizedBox(height: 20),
                  const Text('Hızlı İşlemler',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.list_alt, size: 16),
                      label: const Text('İlanlarını Gör'),
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.message_outlined, size: 16),
                      label: const Text('Mesaj Gönder'),
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

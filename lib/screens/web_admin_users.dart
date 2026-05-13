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
  String _search = '';
  UserModel? _selected;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();

    if (provider.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.error != null) {
      return Center(child: Text('Hata: ${provider.error}', style: const TextStyle(color: Colors.red)));
    }

    final users = provider.users;
    final filtered = _search.isEmpty
        ? users
        : users.where((u) {
            final q = _search.toLowerCase();
            return u.displayName.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q) ||
                u.phone.contains(q);
          }).toList();

    return Row(
      children: [
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
                    Text('${filtered.length} kullanıcı',
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
                    Expanded(flex: 2, child: _HeaderText('Ad Soyad')),
                    Expanded(flex: 2, child: _HeaderText('E-posta')),
                    Expanded(flex: 1, child: _HeaderText('Telefon')),
                    Expanded(flex: 1, child: _HeaderText('Üyelik')),
                    Expanded(flex: 1, child: _HeaderText('Durum')),
                    SizedBox(width: 80, child: _HeaderText('İşlem')),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('Kullanıcı bulunamadı',
                            style: TextStyle(color: AppColors.textLight)),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: AppColors.divider),
                        itemBuilder: (_, i) {
                          final u = filtered[i];
                          final isSelected = _selected?.uid == u.uid;
                          return InkWell(
                            onTap: () => setState(
                                () => _selected = isSelected ? null : u),
                            child: Container(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.05)
                                  : Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundImage: u.photoUrl != null
                                        ? NetworkImage(u.photoUrl!)
                                        : null,
                                    backgroundColor:
                                        AppColors.primary.withValues(alpha: 0.1),
                                    child: u.photoUrl == null
                                        ? Text(
                                            u.displayName.isNotEmpty
                                                ? u.displayName[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                                fontSize: 14),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(u.displayName,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.textPrimary)),
                                        Text(u.phone,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textLight)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(u.email,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(u.phone,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '${u.createdAt.day}.${u.createdAt.month}.${u.createdAt.year}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textLight),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: _UserBadge(
                                        isAdmin: u.isAdmin,
                                        isBanned: u.isBanned),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Row(
                                      children: [
                                        if (!u.isAdmin)
                                          _UserBtn(
                                            icon: u.isBanned
                                                ? Icons.lock_open
                                                : Icons.block,
                                            color: u.isBanned
                                                ? AppColors.success
                                                : Colors.red,
                                            tooltip: u.isBanned
                                                ? 'Yasağı Kaldır'
                                                : 'Yasakla',
                                            onTap: () => context
                                                .read<UserProvider>()
                                                .setBanned(
                                                    u.uid, !u.isBanned),
                                          ),
                                        const SizedBox(width: 4),
                                        _UserBtn(
                                          icon: u.isAdmin
                                              ? Icons.admin_panel_settings
                                              : Icons
                                                  .admin_panel_settings_outlined,
                                          color: u.isAdmin
                                              ? Colors.purple
                                              : AppColors.textLight,
                                          tooltip: u.isAdmin
                                              ? 'Admin yetkisini kaldır'
                                              : 'Admin yap',
                                          onTap: () => context
                                              .read<UserProvider>()
                                              .setAdmin(u.uid, !u.isAdmin),
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

class _HeaderText extends StatelessWidget {
  final String text;
  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary));
  }
}

class _UserBadge extends StatelessWidget {
  final bool isAdmin;
  final bool isBanned;

  const _UserBadge({required this.isAdmin, required this.isBanned});

  @override
  Widget build(BuildContext context) {
    if (isBanned) return _badge('Yasaklı', Colors.red);
    if (isAdmin) return _badge('Admin', Colors.purple);
    return _badge('Aktif', AppColors.success);
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );
}

class _UserBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _UserBtn(
      {required this.icon,
      required this.color,
      required this.tooltip,
      required this.onTap});

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
  final UserModel user;
  final VoidCallback onClose;

  const _UserDetailPanel({required this.user, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                const Text('Kullanıcı Detayı',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
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
                      backgroundImage: user.photoUrl != null
                          ? NetworkImage(user.photoUrl!)
                          : null,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.1),
                      child: user.photoUrl == null
                          ? Text(
                              user.displayName.isNotEmpty
                                  ? user.displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(user.displayName,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                  ),
                  const SizedBox(height: 4),
                  Center(
                      child: _UserBadge(
                          isAdmin: user.isAdmin, isBanned: user.isBanned)),
                  const SizedBox(height: 20),
                  _DetailRow(label: 'E-posta', value: user.email),
                  _DetailRow(label: 'Telefon', value: user.phone),
                  _DetailRow(label: 'Kullanıcı ID', value: user.uid),
                  _DetailRow(
                      label: 'Üyelik Tarihi',
                      value:
                          '${user.createdAt.day}.${user.createdAt.month}.${user.createdAt.year}'),
                  if (user.bio != null && user.bio!.isNotEmpty)
                    _DetailRow(label: 'Hakkında', value: user.bio!),
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
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textLight)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';

// ── Model — ai_usage/{userId} ─────────────────────────────────────────────────

class _AiUserStat {
  final String userId;
  final int totalQueries;
  final int totalInputTokens;
  final int totalOutputTokens;
  final double totalUsd;
  final double totalTry;
  final double totalGbp;
  final DateTime lastQueryAt;

  const _AiUserStat({
    required this.userId,
    required this.totalQueries,
    required this.totalInputTokens,
    required this.totalOutputTokens,
    required this.totalUsd,
    required this.totalTry,
    required this.totalGbp,
    required this.lastQueryAt,
  });

  int get totalTokens => totalInputTokens + totalOutputTokens;

  factory _AiUserStat.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _AiUserStat(
      userId:            doc.id,
      totalQueries:      (d['totalQueries']      as num?)?.toInt()    ?? 0,
      totalInputTokens:  (d['totalInputTokens']  as num?)?.toInt()    ?? 0,
      totalOutputTokens: (d['totalOutputTokens'] as num?)?.toInt()    ?? 0,
      totalUsd:          (d['totalUsd']          as num?)?.toDouble() ?? 0.0,
      totalTry:          (d['totalTry']          as num?)?.toDouble() ?? 0.0,
      totalGbp:          (d['totalGbp']          as num?)?.toDouble() ?? 0.0,
      lastQueryAt:       (d['lastQueryAt']        as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ── Ana ekran ─────────────────────────────────────────────────────────────────

class WebAdminCosts extends StatefulWidget {
  const WebAdminCosts({super.key});

  @override
  State<WebAdminCosts> createState() => _WebAdminCostsState();
}

class _WebAdminCostsState extends State<WebAdminCosts> {
  final _db = FirebaseFirestore.instance;

  List<_AiUserStat> _stats = [];
  bool _loading = true;
  String? _error;
  StreamSubscription<QuerySnapshot>? _sub;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    _sub?.cancel();
    setState(() { _loading = true; _error = null; });

    _sub = _db
        .collection('ai_usage')
        .snapshots()
        .listen(
      (snap) => setState(() {
        _stats = snap.docs.map(_AiUserStat.fromDoc).toList()
          ..sort((a, b) => b.totalUsd.compareTo(a.totalUsd));
        _loading = false;
      }),
      onError: (e) => setState(() { _error = e.toString(); _loading = false; }),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ── Toplamlar ──────────────────────────────────────────────────────────────

  double get _grandUsd     => _stats.fold(0.0, (s, e) => s + e.totalUsd);
  double get _grandTry     => _stats.fold(0.0, (s, e) => s + e.totalTry);
  double get _grandGbp     => _stats.fold(0.0, (s, e) => s + e.totalGbp);
  int    get _grandQueries => _stats.fold(0,   (s, e) => s + e.totalQueries);
  int    get _grandTokens  => _stats.fold(0,   (s, e) => s + e.totalTokens);

  @override
  Widget build(BuildContext context) {
    final users = context.watch<UserProvider>().users;

    String userName(String uid) {
      try {
        final u = users.firstWhere((u) => u.uid == uid);
        return u.displayName.isNotEmpty ? u.displayName : u.email;
      } catch (_) {
        return uid.substring(0, 8);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Başlık + yenile ───────────────────────────────────────────────
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Yapay Zeka Gider Özeti',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  SizedBox(height: 2),
                  Text('Tüm zamanlar · Kullanıcı başına birikimli toplam',
                      style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                ],
              ),
              const Spacer(),
              if (_loading)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else
                _iconBtn(Icons.refresh, 'Yenile', _subscribe),
            ],
          ),
          const SizedBox(height: 20),

          // ── Hata ──────────────────────────────────────────────────────────
          if (_error != null)
            _ErrorBanner(message: _error!),

          // ── Özet kartlar ──────────────────────────────────────────────────
          Row(
            children: [
              _SummaryCard(
                label: 'Toplam Gider',
                value: '\$${_grandUsd.toStringAsFixed(4)}',
                sub: '£${_grandGbp.toStringAsFixed(4)}  ·  ₺${_grandTry.toStringAsFixed(2)}',
                icon: Icons.attach_money,
                color: Colors.red.shade600,
                large: true,
              ),
              const SizedBox(width: 16),
              _SummaryCard(
                label: 'Toplam Sorgu',
                value: '$_grandQueries',
                sub: 'Tüm kullanıcılar',
                icon: Icons.psychology_outlined,
                color: Colors.indigo,
              ),
              const SizedBox(width: 16),
              _SummaryCard(
                label: 'Toplam Token',
                value: _fmt(_grandTokens),
                sub: 'Giriş + Çıkış',
                icon: Icons.data_usage_outlined,
                color: Colors.teal,
              ),
              const SizedBox(width: 16),
              _SummaryCard(
                label: 'Aktif Kullanıcı',
                value: '${_stats.length}',
                sub: 'Yapay zeka kullanan',
                icon: Icons.people_outline,
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Kullanıcı sıralaması + Token dağılımı ─────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sol: Kullanıcı sıralaması
              Expanded(
                flex: 3,
                child: _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Kullanıcı Bazlı Gider',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('${_stats.length} kullanıcı',
                                style: TextStyle(fontSize: 11, color: Colors.red.shade600, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_loading)
                        const Center(child: CircularProgressIndicator())
                      else if (_stats.isEmpty)
                        const Center(child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Text('Henüz veri yok', style: TextStyle(color: AppColors.textLight)),
                        ))
                      else
                        ..._stats.take(8).mapIndexed((i, s) {
                          final name = userName(s.userId);
                          final maxUsd = _stats.first.totalUsd;
                          final pct = maxUsd == 0 ? 0.0 : s.totalUsd / maxUsd;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _RankBadge(rank: i + 1),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(name,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('\$${s.totalUsd.toStringAsFixed(4)}',
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red.shade600)),
                                        Text('₺${s.totalTry.toStringAsFixed(2)}',
                                            style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    minHeight: 5,
                                    backgroundColor: AppColors.divider,
                                    valueColor: AlwaysStoppedAnimation(_rankColor(i)),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text('${s.totalQueries} sorgu  ·  ${_fmt(s.totalTokens)} token  ·  son: ${_timeAgo(s.lastQueryAt)}',
                                    style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Sağ: Token & maliyet dağılım kutuları
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Token Dağılımı',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          const SizedBox(height: 16),
                          _TokenBar(
                            label: 'Giriş Token',
                            value: _stats.fold(0, (s, e) => s + e.totalInputTokens),
                            total: _grandTokens,
                            color: Colors.indigo,
                          ),
                          const SizedBox(height: 12),
                          _TokenBar(
                            label: 'Çıkış Token',
                            value: _stats.fold(0, (s, e) => s + e.totalOutputTokens),
                            total: _grandTokens,
                            color: Colors.purple,
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: AppColors.divider),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Toplam', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              Text(_fmt(_grandTokens),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ortalama / Kullanıcı',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          const SizedBox(height: 16),
                          if (_stats.isEmpty)
                            const Text('—', style: TextStyle(color: AppColors.textLight))
                          else ...[
                            _AvgRow(label: 'Gider (USD)', value: '\$${(_grandUsd / _stats.length).toStringAsFixed(4)}'),
                            _AvgRow(label: 'Gider (₺)',   value: '₺${(_grandTry  / _stats.length).toStringAsFixed(2)}'),
                            _AvgRow(label: 'Sorgu',       value: (_grandQueries / _stats.length).toStringAsFixed(1)),
                            _AvgRow(label: 'Token',       value: _fmt((_grandTokens / _stats.length).round())),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Detay tablosu ─────────────────────────────────────────────────
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Tüm Kullanıcı Detayı',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${_stats.length} kayıt',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Tablo başlığı
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFF8F9FB), borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      SizedBox(width: 32),
                      SizedBox(width: 8),
                      Expanded(flex: 3, child: _TH('Kullanıcı')),
                      Expanded(flex: 2, child: _TH('Sorgu')),
                      Expanded(flex: 2, child: _TH('Input Token')),
                      Expanded(flex: 2, child: _TH('Output Token')),
                      Expanded(flex: 2, child: _TH('USD')),
                      Expanded(flex: 2, child: _TH('₺')),
                      Expanded(flex: 2, child: _TH('Son Sorgu')),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_stats.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('Kayıt bulunamadı', style: TextStyle(color: AppColors.textLight))),
                  )
                else
                  ..._stats.mapIndexed((i, s) => _TableRow(
                        rank: i + 1,
                        name: userName(s.userId),
                        stat: s,
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Color _rankColor(int i) => switch (i) {
        0 => Colors.amber.shade700,
        1 => Colors.blueGrey.shade500,
        2 => Colors.orange.shade700,
        _ => AppColors.primary,
      };

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk önce';
    if (diff.inHours < 24)   return '${diff.inHours}sa önce';
    return '${diff.inDays}g önce';
  }
}

// ── Tablo satırı ──────────────────────────────────────────────────────────────

class _TableRow extends StatelessWidget {
  final int rank;
  final String name;
  final _AiUserStat stat;

  const _TableRow({required this.rank, required this.name, required this.stat});

  @override
  Widget build(BuildContext context) {
    final diff = DateTime.now().difference(stat.lastQueryAt);
    final lastStr = diff.inMinutes < 60
        ? '${diff.inMinutes}dk önce'
        : diff.inHours < 24
            ? '${diff.inHours}sa önce'
            : '${diff.inDays}g önce';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
      child: Row(
        children: [
          SizedBox(width: 32, child: _RankBadge(rank: rank)),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(name,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          Expanded(flex: 2, child: _Cell('${stat.totalQueries}')),
          Expanded(flex: 2, child: _Cell(_fmtN(stat.totalInputTokens))),
          Expanded(flex: 2, child: _Cell(_fmtN(stat.totalOutputTokens))),
          Expanded(
            flex: 2,
            child: Text('\$${stat.totalUsd.toStringAsFixed(4)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade600)),
          ),
          Expanded(
            flex: 2,
            child: Text('₺${stat.totalTry.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
          ),
          Expanded(flex: 2, child: _Cell(lastStr)),
        ],
      ),
    );
  }

  String _fmtN(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ── Küçük widgetlar ───────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: child,
      );
}

class _SummaryCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  final bool large;

  const _SummaryCard({
    required this.label, required this.value, required this.sub,
    required this.icon, required this.color, this.large = false,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: large ? color : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: large ? Colors.white.withValues(alpha: 0.2) : color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: large ? Colors.white : color, size: 20),
              ),
              const SizedBox(height: 14),
              Text(value,
                  style: TextStyle(fontSize: large ? 22 : 22, fontWeight: FontWeight.bold,
                      color: large ? Colors.white : AppColors.textPrimary)),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: large ? Colors.white.withValues(alpha: 0.85) : AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(sub,
                  style: TextStyle(fontSize: 10,
                      color: large ? Colors.white.withValues(alpha: 0.65) : AppColors.textLight)),
            ],
          ),
        ),
      );
}

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  Color get _color => switch (rank) {
        1 => Colors.amber.shade700,
        2 => Colors.blueGrey.shade500,
        3 => Colors.orange.shade700,
        _ => AppColors.textLight,
      };

  @override
  Widget build(BuildContext context) => Container(
        width: 24, height: 24,
        decoration: BoxDecoration(color: _color.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Center(
          child: Text('$rank',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _color)),
        ),
      );
}

class _TokenBar extends StatelessWidget {
  final String label;
  final int value, total;
  final Color color;

  const _TokenBar({required this.label, required this.value, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : value / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const Spacer(),
            Text(_fmt(value), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(width: 6),
            Text('(${(pct * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct, minHeight: 6,
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _AvgRow extends StatelessWidget {
  final String label, value;
  const _AvgRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ],
        ),
      );
}

class _Cell extends StatelessWidget {
  final String text;
  const _Cell(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary));
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary));
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text('Hata: $message',
                style: TextStyle(fontSize: 12, color: Colors.red.shade700))),
          ],
        ),
      );
}

// ── Extension ─────────────────────────────────────────────────────────────────

extension _IndexedIterable<T> on Iterable<T> {
  Iterable<R> mapIndexed<R>(R Function(int index, T item) f) sync* {
    var i = 0;
    for (final item in this) { yield f(i++, item); }
  }
}

// Reviewer home — inbox / sessions / board / wallet + online toggle.
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _me;
  bool _error = false;
  int _tab = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final me = await RevApi.instance.me();
      if (mounted) setState(() { _me = me; _error = false; });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _toggleOnline() async {
    try {
      final on = await RevApi.instance.toggleOnline();
      if (mounted) setState(() => _me?['is_online'] = on);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _logout() async {
    await RevApi.instance.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final ar = RevApi.instance.lang == 'ar';
    final online = _me?['is_online'] == true;
    final active = (_me?['status'] ?? '') == 'approved';
    return Scaffold(
      appBar: AppBar(
        title: Text(ar ? '🎓 أخصائيو يلو' : '🎓 Uellow Reviewers',
            style: const TextStyle(fontWeight: FontWeight.w900,
                fontSize: 16)),
        actions: [
          if (active)
            // online switch — the heart of fast responses
            GestureDetector(
              onTap: _toggleOnline,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.symmetric(horizontal: 11),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: online ? kGreen : Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(children: [
                  Icon(online ? Icons.wifi : Icons.wifi_off,
                      size: 13, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(online
                      ? (ar ? 'متاح' : 'Online')
                      : (ar ? 'غير متاح' : 'Offline'),
                      style: const TextStyle(color: Colors.white,
                          fontSize: 11, fontWeight: FontWeight.w900)),
                ]),
              ),
            ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () async {
              await RevApi.instance.setLang(ar ? 'en' : 'ar');
              ReviewersApp.of(context)?.rebuild();
            },
            icon: const Icon(Icons.translate),
          ),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: _body(ar),
    );
  }

  Widget _body(bool ar) {
    if (_error) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_outlined, size: 56, color: Colors.grey),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _load,
            child: Text(ar ? 'إعادة المحاولة' : 'Retry')),
      ]));
    }
    final me = _me;
    if (me == null) {
      return const Center(child: CircularProgressIndicator(color: kDark));
    }
    final status = (me['status'] ?? 'none').toString();
    if (status == 'none') return _JoinPitch(onDone: _load);
    if (status == 'pending') {
      return Center(child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('⏳', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          Text(ar ? 'طلبك قيد المراجعة' : 'Application under review',
              style: const TextStyle(fontSize: 17,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(ar ? 'ستعتمدك إدارة يلو قريباً'
                  : 'Uellow will approve you soon',
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: _load,
              child: Text(ar ? 'تحقق الآن' : 'Check now')),
        ]),
      ));
    }
    if (status == 'suspended' || status == 'rejected') {
      return Center(child: Padding(
        padding: const EdgeInsets.all(36),
        child: Text(ar ? 'حسابك غير نشط — تواصل مع إدارة يلو'
                       : 'Account inactive — contact Uellow',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16,
                fontWeight: FontWeight.w900)),
      ));
    }
    return Column(children: [
      Container(
        color: Colors.white,
        child: Row(children: [
          for (final (i, label, icon) in [
            (0, ar ? 'الطلبات' : 'Inbox', Icons.inbox_outlined),
            (1, ar ? 'جلساتي' : 'Sessions', Icons.history),
            (2, ar ? 'لوحتي' : 'Board', Icons.dashboard_outlined),
            (3, ar ? 'محفظتي' : 'Wallet',
                Icons.account_balance_wallet_outlined),
          ]) Expanded(child: InkWell(
            onTap: () => setState(() => _tab = i),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(
                color: _tab == i ? kGold : Colors.transparent,
                width: 2.5,
              ))),
              child: Column(children: [
                Icon(icon, size: 18,
                    color: _tab == i ? kDark : Colors.grey),
                Text(label, style: TextStyle(fontSize: 10.5,
                    fontWeight:
                        _tab == i ? FontWeight.w900 : FontWeight.w600,
                    color: _tab == i ? kDark : Colors.grey)),
              ]),
            ),
          )),
        ]),
      ),
      Expanded(child: switch (_tab) {
        1 => const SessionsTab(),
        2 => DashboardTab(me: me),
        3 => WalletTab(me: me, onChanged: _load),
        _ => InboxTab(onChanged: _load),
      }),
    ]);
  }
}

// ─── join pitch ───────────────────────────────────────────────────────

class _JoinPitch extends StatefulWidget {
  const _JoinPitch({required this.onDone});
  final VoidCallback onDone;
  @override
  State<_JoinPitch> createState() => _JoinPitchState();
}

class _JoinPitchState extends State<_JoinPitch> {
  final _spec = TextEditingController();
  final _bio = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final ar = RevApi.instance.lang == 'ar';
    return ListView(padding: const EdgeInsets.all(18), children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [kDark, kAccent]),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(children: [
          const Text('🎓', style: TextStyle(fontSize: 46)),
          Text(ar ? 'رأيك يصنع القرار' : 'Your expertise, rewarded',
              style: const TextStyle(color: kGoldLight, fontSize: 19,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(ar
              ? 'أعط آراءك المتخصصة للمتسوقين واكسب نقاطاً + نسبة من كل بيع تساهم فيه'
              : 'Give expert opinions and earn points + a share of every sale you influence',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70,
                  fontSize: 12.5)),
        ]),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _spec,
        decoration: InputDecoration(
          labelText: ar ? 'تخصصاتك *' : 'Your specialties *',
          hintText: ar ? 'موضة رجالي، إلكترونيات، عطور…'
                       : 'Fashion, electronics, fragrances…',
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _bio, maxLines: 3,
        decoration: InputDecoration(
          labelText: ar ? 'نبذة عنك' : 'About you',
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
      ),
      const SizedBox(height: 14),
      ElevatedButton(
        onPressed: () async {
          if (_spec.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ar ? 'اكتب تخصصاتك أولاً'
                                 : 'Specialties required')));
            return;
          }
          try {
            await RevApi.instance.apply(
                specialties: _spec.text.trim(), bio: _bio.text.trim());
            widget.onDone();
          } on ApiException catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(e.message)));
            }
          }
        },
        style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15)),
        child: Text(ar ? '🎓 قدّم طلب انضمام' : '🎓 Apply now',
            style: const TextStyle(fontSize: 14)),
      ),
    ]);
  }
}

// ─── inbox: pending/active requests + FAST verdict composer ──────────

class InboxTab extends StatefulWidget {
  const InboxTab({super.key, required this.onChanged});
  final VoidCallback onChanged;
  @override
  State<InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<InboxTab> {
  List<Map<String, dynamic>>? _items;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    // light auto-refresh — requests expire in minutes, speed matters
    _poll = Timer.periodic(const Duration(seconds: 45), (_) => _load());
  }

  @override
  void dispose() { _poll?.cancel(); super.dispose(); }

  Future<void> _load() async {
    try {
      final v = await RevApi.instance.requests(state: 'inbox');
      if (mounted) setState(() => _items = v);
    } catch (_) {
      if (mounted) setState(() => _items ??= const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = RevApi.instance.lang == 'ar';
    final items = _items;
    if (items == null) {
      return const Center(child: CircularProgressIndicator(color: kDark));
    }
    if (items.isEmpty) {
      return RefreshIndicator(onRefresh: _load, child: ListView(children: [
        const SizedBox(height: 90),
        const Center(child: Text('📭', style: TextStyle(fontSize: 52))),
        const SizedBox(height: 12),
        Center(child: Text(
            ar ? 'لا توجد طلبات الآن — فعّل «متاح» ليصلك المزيد'
               : 'No requests now — go Online to receive more',
            style: const TextStyle(color: Colors.grey))),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 30),
        itemCount: items.length,
        itemBuilder: (_, i) => _card(items[i], ar),
      ),
    );
  }

  Widget _card(Map<String, dynamic> q, bool ar) {
    final product = (q['product'] as Map?)?.cast<String, dynamic>()
        ?? const {};
    final img = (q['tryon_image_url'] ?? '').toString().isNotEmpty
        ? (q['tryon_image_url'] ?? '').toString()
        : (product['image_url'] ?? '').toString();
    final isTryon = (q['kind'] ?? '') == 'tryon_opinion';
    final state = (q['state'] ?? '').toString();
    final type = (q['session_type'] ?? 'written').toString();
    final typeLbl = switch (type) {
      'chat' => ar ? '💬 شات' : '💬 Chat',
      'photo' => ar ? '📷 صورة' : '📷 Photo',
      'video' => ar ? '🎥 فيديو' : '🎥 Video',
      _ => ar ? '✍️ مكتوب' : '✍️ Written',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x11000000),
              blurRadius: 6, offset: Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
                imageUrl: img.startsWith('http')
                    ? img : '${RevApi.baseUrl}$img',
                width: 58, height: 58, fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    const ColoredBox(color: Color(0xFFEFEFEF),
                        child: SizedBox(width: 58, height: 58))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((product['name'] ?? '').toString(),
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Row(children: [
              _chip(typeLbl, const Color(0xFFEDF3FA),
                  const Color(0xFF1D5FA6)),
              const SizedBox(width: 5),
              if (isTryon) _chip(ar ? '🪞 تراي-أون' : '🪞 Try-on',
                  const Color(0xFFF6EDFA), const Color(0xFF7B2D8E)),
              if (state != 'pending') ...[
                const SizedBox(width: 5),
                _chip(ar ? 'جارية' : 'Active',
                    const Color(0xFFE6F7EF), kGreen),
              ],
            ]),
          ])),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          if (state == 'pending') Expanded(child: OutlinedButton(
            onPressed: () async {
              try {
                await RevApi.instance.accept(
                    (q['id'] as num).toInt());
                _load();
              } on ApiException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(e.message)));
                }
              }
            },
            child: Text(ar ? 'قبول' : 'Accept',
                style: const TextStyle(fontWeight: FontWeight.w800,
                    fontSize: 12)),
          )),
          if (state == 'pending') const SizedBox(width: 8),
          Expanded(flex: 2, child: ElevatedButton.icon(
            onPressed: () => _openComposer(q, ar),
            icon: const Icon(Icons.rate_review_outlined, size: 16),
            label: Text(ar ? '⚡ أعط رأيك الآن' : '⚡ Review now',
                style: const TextStyle(fontWeight: FontWeight.w900,
                    fontSize: 12.5)),
          )),
        ]),
      ]),
    );
  }

  Widget _chip(String t, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: bg,
            borderRadius: BorderRadius.circular(999)),
        child: Text(t, style: TextStyle(fontSize: 9.5,
            fontWeight: FontWeight.w800, color: fg)),
      );

  // ── the FAST verdict composer ──
  void _openComposer(Map<String, dynamic> q, bool ar) {
    var verdict = 'recommend';
    var quality = 4, value = 4, comfort = 4;
    final notes = TextEditingController();
    final quick = ar
        ? ['جودة ممتازة مقابل السعر 👌', 'الخامة جيدة جداً',
           'المقاس مظبوط — خذ مقاسك المعتاد', 'يستحق الشراء بهذا السعر',
           'فيه أفضل منه بنفس السعر', 'القصّة عصرية وأنيقة']
        : ['Great value for money 👌', 'Excellent material quality',
           'True to size — order your usual', 'Worth it at this price',
           'Better options exist at this price', 'Modern, elegant cut'];
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius:
          BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) =>
        Padding(
          padding: EdgeInsets.fromLTRB(18, 14, 18,
              16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE3E3E3),
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Text(ar ? '⚡ رأيك السريع' : '⚡ Quick verdict',
                style: const TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            // verdict segmented
            Row(children: [
              for (final v in [
                ('recommend', ar ? '👍 أنصح' : '👍 Yes', kGreen),
                ('neutral', ar ? '😐 محايد' : '😐 Neutral',
                    const Color(0xFFB8860B)),
                ('not_recommend', ar ? '👎 لا أنصح' : '👎 No', kRed),
              ]) Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  onTap: () => setSheet(() => verdict = v.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: verdict == v.$1
                          ? v.$3.withValues(alpha: 0.12) : Colors.white,
                      border: Border.all(color: verdict == v.$1
                          ? v.$3 : const Color(0xFFE3E3E3),
                          width: verdict == v.$1 ? 1.6 : 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(v.$2, style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: verdict == v.$1 ? v.$3 : Colors.grey)),
                  ),
                ),
              )),
            ]),
            const SizedBox(height: 12),
            // sliders
            for (final s in [
              (ar ? 'الجودة' : 'Quality', quality,
                  (int x) => setSheet(() => quality = x)),
              (ar ? 'القيمة مقابل السعر' : 'Value', value,
                  (int x) => setSheet(() => value = x)),
              (ar ? 'الراحة' : 'Comfort', comfort,
                  (int x) => setSheet(() => comfort = x)),
            ]) Row(children: [
              SizedBox(width: 110, child: Text(s.$1,
                  style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w700))),
              Expanded(child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 1; i <= 5; i++) GestureDetector(
                    onTap: () => s.$3(i),
                    child: Icon(
                        i <= s.$2 ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                        size: 26,
                        color: i <= s.$2
                            ? const Color(0xFFFFC107)
                            : const Color(0xFFCFCFCF)),
                  ),
                ],
              )),
            ]),
            const SizedBox(height: 10),
            // quick phrases
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final ph in quick) GestureDetector(
                onTap: () => setSheet(() {
                  notes.text = notes.text.isEmpty
                      ? ph : '${notes.text}\n$ph';
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6F8),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE3E3E3)),
                  ),
                  child: Text(ph, style: const TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: notes, maxLines: 3,
              decoration: InputDecoration(
                hintText: ar ? 'رأيك بالتفصيل…' : 'Your detailed opinion…',
                filled: true, fillColor: const Color(0xFFF7F8FA),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () async {
                try {
                  await RevApi.instance.complete(
                    (q['id'] as num).toInt(),
                    verdict: verdict, notes: notes.text.trim(),
                    quality: quality, value: value, comfort: comfort,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load(); widget.onChanged();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ar
                            ? '✓ أُرسل رأيك وكسبت نقاطك 🎉'
                            : '✓ Sent — points earned 🎉')));
                  }
                } on ApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(e.message)));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(ar ? '📨 إرسال الرأي' : '📨 Send verdict',
                  style: const TextStyle(fontSize: 14)),
            )),
          ])),
        )),
    );
  }
}

// ─── sessions history ─────────────────────────────────────────────────

class SessionsTab extends StatefulWidget {
  const SessionsTab({super.key});
  @override
  State<SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends State<SessionsTab> {
  List<Map<String, dynamic>>? _items;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final v = await RevApi.instance.requests(state: 'completed');
      if (mounted) setState(() => _items = v);
    } catch (_) {
      if (mounted) setState(() => _items = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = RevApi.instance.lang == 'ar';
    final items = _items;
    if (items == null) {
      return const Center(child: CircularProgressIndicator(color: kDark));
    }
    if (items.isEmpty) {
      return Center(child: Text(
          ar ? 'لا توجد جلسات مكتملة بعد' : 'No completed sessions yet',
          style: const TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 30),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final q = items[i];
        final product = (q['product'] as Map?)?.cast<String, dynamic>()
            ?? const {};
        final verdict = (q['verdict'] ?? '').toString();
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((product['name'] ?? '').toString(),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w800)),
              Text(((q['create_date'] ?? '') as String).split('T').first,
                  style: const TextStyle(fontSize: 10,
                      color: Colors.grey)),
            ])),
            Text(switch (verdict) {
              'recommend' => '👍',
              'not_recommend' => '👎',
              _ => '😐',
            }, style: const TextStyle(fontSize: 18)),
          ]),
        );
      },
    );
  }
}

// ─── dashboard ────────────────────────────────────────────────────────

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key, required this.me});
  final Map<String, dynamic> me;

  @override
  Widget build(BuildContext context) {
    final ar = RevApi.instance.lang == 'ar';
    final level = (me['level'] ?? 'starter').toString();
    final levelLbl = {'starter': '⭐', 'regular': '⭐⭐',
        'expert': '⭐⭐⭐', 'elite': '⭐⭐⭐⭐'}[level] ?? '⭐';
    return ListView(padding: const EdgeInsets.all(14), children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [kDark, kAccent]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((me['name'] ?? '').toString(), style: const TextStyle(
                color: kGoldLight, fontSize: 19,
                fontWeight: FontWeight.w900)),
            Text('$levelLbl ${level.toUpperCase()} · ★ ${me['rating']}',
                style: const TextStyle(color: Colors.white70,
                    fontSize: 12, fontWeight: FontWeight.w700)),
            if ((me['specialty_text'] ?? '').toString().isNotEmpty)
              Text((me['specialty_text']).toString(),
                  style: const TextStyle(color: Colors.white54,
                      fontSize: 11)),
          ])),
          Column(children: [
            Text('${me['points_balance'] ?? 0}',
                style: const TextStyle(color: kGoldLight, fontSize: 26,
                    fontWeight: FontWeight.w900)),
            Text(ar ? 'نقطة' : 'points',
                style: const TextStyle(color: Colors.white60,
                    fontSize: 11)),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        _stat(ar ? 'مراجعات' : 'Reviews', '${me['review_count'] ?? 0}',
            kDark),
        const SizedBox(width: 8),
        _stat(ar ? 'هذا الشهر' : 'This month',
            '${me['done_month'] ?? 0}', kDark),
        const SizedBox(width: 8),
        _stat(ar ? 'نقاط الشهر' : 'Month pts',
            '${me['points_month'] ?? 0}', const Color(0xFFB8860B)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        _stat(ar ? 'المحفظة' : 'Wallet',
            '${((me['wallet_kd'] as num?) ?? 0).toStringAsFixed(3)}',
            kGreen),
        const SizedBox(width: 8),
        _stat(ar ? 'أرباح المبيعات' : 'Sales share',
            '${((me['profit_earned_kd'] as num?) ?? 0).toStringAsFixed(3)}',
            kGreen),
        const SizedBox(width: 8),
        _stat(ar ? 'تحويلات' : 'Conversions',
            '${me['purchase_count'] ?? 0}', kDark),
      ]),
      const SizedBox(height: 14),
      const LeaderboardCard(),
    ]);
  }

  Widget _stat(String label, String value, Color color) =>
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          FittedBox(child: Text(value, style: TextStyle(fontSize: 14,
              fontWeight: FontWeight.w900, color: color))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 9.5,
              color: Colors.grey, fontWeight: FontWeight.w700)),
        ]),
      ));
}

class LeaderboardCard extends StatefulWidget {
  const LeaderboardCard({super.key});
  @override
  State<LeaderboardCard> createState() => _LeaderboardCardState();
}

class _LeaderboardCardState extends State<LeaderboardCard> {
  Map<String, dynamic>? _data;
  @override
  void initState() {
    super.initState();
    RevApi.instance.leaderboard().then((d) {
      if (mounted) setState(() => _data = d);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final ar = RevApi.instance.lang == 'ar';
    final top = List<Map<String, dynamic>>.from(
        (_data?['top'] as List?) ?? const []);
    if (top.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(ar ? '🏆 متصدرو الشهر (نقاط)' : '🏆 Monthly leaders (points)',
            style: const TextStyle(fontSize: 13,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        for (final r in top) Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(width: 26, child: Text(
                ['🥇', '🥈', '🥉'].elementAtOrNull(
                    ((r['rank'] as num?) ?? 4).toInt() - 1)
                    ?? '${r['rank']}.',
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w800))),
            Expanded(child: Text((r['name'] ?? '').toString(),
                style: TextStyle(fontSize: 12,
                    fontWeight: r['me'] == true
                        ? FontWeight.w900 : FontWeight.w600))),
            Text('${r['points']} ${ar ? 'نقطة' : 'pts'}',
                style: const TextStyle(fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB8860B))),
          ]),
        ),
        if (_data?['my_rank'] != null)
          Text(ar ? 'ترتيبك: #${_data!['my_rank']}'
                  : 'Your rank: #${_data!['my_rank']}',
              style: const TextStyle(fontSize: 11, color: Colors.grey,
                  fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ─── wallet: points → KD + payouts ────────────────────────────────────

class WalletTab extends StatefulWidget {
  const WalletTab({super.key, required this.me, required this.onChanged});
  final Map<String, dynamic> me;
  final VoidCallback onChanged;
  @override
  State<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<WalletTab> {
  List<Map<String, dynamic>>? _entries;
  List<Map<String, dynamic>>? _payouts;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final e = await RevApi.instance.points();
      final p = await RevApi.instance.payouts();
      if (mounted) setState(() { _entries = e; _payouts = p; });
    } catch (_) {
      if (mounted) {
        setState(() { _entries = const []; _payouts = const []; });
      }
    }
  }

  Future<void> _redeem() async {
    final ar = RevApi.instance.lang == 'ar';
    try {
      final res = await RevApi.instance.redeem();
      _load(); widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ar
                ? '✓ تحوّلت نقاطك إلى ${res['kd_credited']} د.ك'
                : '✓ Redeemed → ${res['kd_credited']} KD')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _requestPayout() async {
    final ar = RevApi.instance.lang == 'ar';
    final wallet = ((widget.me['wallet_kd'] as num?) ?? 0).toDouble();
    final minPayout =
        ((widget.me['min_payout_kd'] as num?) ?? 5).toDouble();
    final amountCtrl =
        TextEditingController(text: wallet.toStringAsFixed(3));
    var method = 'knet';
    final detailsCtrl = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius:
          BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) =>
        Padding(
          padding: EdgeInsets.fromLTRB(18, 16, 18,
              18 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ar ? '💸 طلب سحب' : '💸 Request payout',
                style: const TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w900)),
            Text(ar
                ? 'المحفظة: ${wallet.toStringAsFixed(3)} د.ك · الحد الأدنى ${minPayout.toStringAsFixed(3)}'
                : 'Wallet: ${wallet.toStringAsFixed(3)} KD · min ${minPayout.toStringAsFixed(3)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              decoration: InputDecoration(
                  labelText: ar ? 'المبلغ' : 'Amount',
                  border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              for (final m in [
                ('knet', '💳 KNET'),
                ('bank', ar ? '🏦 بنك' : '🏦 Bank'),
                ('wallet', ar ? '👛 محفظة يلو' : '👛 Wallet'),
              ]) ChoiceChip(
                label: Text(m.$2, style: const TextStyle(fontSize: 12)),
                selected: method == m.$1,
                onSelected: (_) => setSheet(() => method = m.$1),
              ),
            ]),
            if (method != 'wallet') Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextField(
                controller: detailsCtrl,
                decoration: InputDecoration(
                    labelText: ar ? 'IBAN / رقم الهاتف' : 'IBAN / phone',
                    border: const OutlineInputBorder()),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13)),
              child: Text(ar ? 'إرسال الطلب' : 'Submit'),
            )),
          ]),
        )),
    );
    if (ok != true) return;
    try {
      await RevApi.instance.requestPayout(
        amount: double.tryParse(amountCtrl.text.trim()) ?? 0,
        method: method, details: detailsCtrl.text.trim(),
      );
      _load(); widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ar ? 'تم إرسال طلب السحب ✓'
                             : 'Payout requested ✓')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = RevApi.instance.lang == 'ar';
    final pts = (widget.me['points_balance'] as num?)?.toInt() ?? 0;
    final rate = (widget.me['points_per_kd'] as num?)?.toDouble() ?? 100;
    final wallet = ((widget.me['wallet_kd'] as num?) ?? 0).toDouble();
    final entries = _entries;
    return ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 30),
        children: [
      // convert card
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFB8860B), kGold]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$pts ${ar ? 'نقطة' : 'pts'} ≈ '
                 '${(pts / rate).toStringAsFixed(3)} ${ar ? 'د.ك' : 'KD'}',
                style: const TextStyle(color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w900)),
            Text(ar ? 'كل ${rate.toInt()} نقطة = 1 د.ك'
                    : 'Every ${rate.toInt()} pts = 1 KD',
                style: const TextStyle(color: Colors.white70,
                    fontSize: 11)),
          ])),
          ElevatedButton(
            onPressed: _redeem,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, foregroundColor: kDark),
            child: Text(ar ? '🔄 تحويل' : '🔄 Redeem',
                style: const TextStyle(fontWeight: FontWeight.w900,
                    fontSize: 12)),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      // payout card
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: kDark,
            borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${wallet.toStringAsFixed(3)} ${ar ? 'د.ك' : 'KD'}',
                style: const TextStyle(color: kGoldLight, fontSize: 17,
                    fontWeight: FontWeight.w900)),
            Text(ar ? 'رصيد محفظتك القابل للسحب'
                    : 'Withdrawable wallet balance',
                style: const TextStyle(color: Colors.white60,
                    fontSize: 11)),
          ])),
          ElevatedButton(
            onPressed: _requestPayout,
            child: Text(ar ? '💸 سحب' : '💸 Withdraw',
                style: const TextStyle(fontWeight: FontWeight.w900,
                    fontSize: 12)),
          ),
        ]),
      ),
      if ((_payouts ?? const []).isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(ar ? 'طلبات السحب' : 'Payout requests',
            style: const TextStyle(fontSize: 13,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        for (final p in _payouts!) Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Text('${((p['amount'] as num?) ?? 0).toStringAsFixed(3)} '
                 '${ar ? 'د.ك' : 'KD'}',
                style: const TextStyle(fontWeight: FontWeight.w900,
                    fontSize: 12)),
            const SizedBox(width: 8),
            Text((p['method'] ?? '').toString(),
                style: const TextStyle(fontSize: 11,
                    color: Colors.grey)),
            const Spacer(),
            Text((p['state'] ?? '') == 'paid'
                ? (ar ? '✅ مدفوع' : '✅ Paid')
                : (ar ? '⏳ معلّق' : '⏳ Pending'),
                style: const TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
      ],
      const SizedBox(height: 12),
      Text(ar ? 'سجل النقاط والأرباح' : 'Points & earnings ledger',
          style: const TextStyle(fontSize: 13,
              fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      if (entries == null)
        const Center(child: Padding(padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(color: kDark)))
      else if (entries.isEmpty)
        Center(child: Padding(padding: const EdgeInsets.all(20),
            child: Text(ar ? 'لا يوجد سجل بعد — أكمل أول جلسة!'
                           : 'No entries yet — complete a session!',
                style: const TextStyle(color: Colors.grey))))
      else for (final e in entries) Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Text(switch ((e['source'] ?? '').toString()) {
            'review_written' => '✍️', 'review_chat' => '💬',
            'review_photo' => '📷', 'review_video' => '🎥',
            'tryon_opinion' => '🪞', 'profit_share' => '🛒',
            'redeem' => '🔄', 'bonus' => '🎁', _ => '✏️',
          }, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((e['note'] ?? '').toString().isEmpty
                    ? (e['source'] ?? '').toString()
                    : (e['note'] ?? '').toString(),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5,
                    fontWeight: FontWeight.w700)),
            Text(((e['date'] ?? '') as String).split('T').first,
                style: const TextStyle(fontSize: 10,
                    color: Colors.grey)),
          ])),
          if (((e['points'] as num?) ?? 0) != 0)
            Text('${((e['points'] as num?) ?? 0) > 0 ? '+' : ''}'
                 '${e['points']} ${ar ? 'نقطة' : 'pts'}',
                style: TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: ((e['points'] as num?) ?? 0) > 0
                        ? const Color(0xFFB8860B) : kRed)),
          if (((e['kd_amount'] as num?) ?? 0) != 0) ...[
            const SizedBox(width: 6),
            Text('+${((e['kd_amount'] as num?) ?? 0).toStringAsFixed(3)}',
                style: const TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w900, color: kGreen)),
          ],
        ]),
      ),
    ]);
  }
}

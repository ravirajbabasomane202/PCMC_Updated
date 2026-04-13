import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:main_ui/l10n/app_localizations.dart';
import 'package:main_ui/models/grievance_model.dart';
import 'package:main_ui/models/user_model.dart';
import 'package:main_ui/models/master_data_model.dart';
import 'package:main_ui/services/user_service.dart';
import 'package:main_ui/services/master_data_service.dart';
import 'package:main_ui/providers/admin_provider.dart';
import 'package:main_ui/widgets/navigation_drawer.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────── Design Tokens (shared dark theme) ────────────
const Color _bg         = Color(0xFF050B18);
const Color _surface    = Color(0xFF0D1829);
const Color _surfaceAlt = Color(0xFF0F2040);
const Color _cyan       = Color(0xFF00E5FF);
const Color _cyanDim    = Color(0xFF0097A7);
const Color _amber      = Color(0xFFFFB300);
const Color _green      = Color(0xFF00E676);
const Color _red        = Color(0xFFFF1744);
const Color _orange     = Color(0xFFFF6D00);
const Color _purple     = Color(0xFFD500F9);
const Color _text1      = Color(0xFFE8F4FD);
const Color _text2      = Color(0xFF8BA3BE);
const Color _border     = Color(0xFF1A3050);

// ────────────────────────── State Machine ────────────────────────────────────
/// Valid next states from a given current state.
/// terminal states (closed, rejected) return empty list.
List<String> _allowedTransitions(String current) {
  switch (current.toLowerCase()) {
    case 'new':         return ['in_progress', 'rejected'];
    case 'in_progress': return ['on_hold', 'resolved', 'rejected'];
    case 'on_hold':     return ['in_progress', 'rejected'];
    case 'resolved':    return ['closed'];
    case 'closed':      return [];   // terminal
    case 'rejected':    return [];   // terminal
    default:            return ['in_progress'];
  }
}

bool _isTerminal(String status) =>
    status == 'closed' || status == 'rejected';

// ────────────────────────── Status Helpers ───────────────────────────────────
Color _statusColor(String s) {
  switch (s.toLowerCase()) {
    case 'new':         return _amber;
    case 'in_progress': return _orange;
    case 'on_hold':     return _purple;
    case 'resolved':    return _green;
    case 'closed':      return _cyanDim;
    case 'rejected':    return _red;
    default:            return _text2;
  }
}
IconData _statusIcon(String s) {
  switch (s.toLowerCase()) {
    case 'new':         return Icons.fiber_new;
    case 'in_progress': return Icons.sync;
    case 'on_hold':     return Icons.pause_circle;
    case 'resolved':    return Icons.check_circle;
    case 'closed':      return Icons.lock;
    case 'rejected':    return Icons.cancel;
    default:            return Icons.help;
  }
}
String _statusLabel(String s) {
  switch (s.toLowerCase()) {
    case 'in_progress': return 'IN PROGRESS';
    case 'on_hold':     return 'ON HOLD';
    default:            return s.toUpperCase();
  }
}

TextStyle _heading(double s, {Color c = _text1}) =>
    TextStyle(color: c, fontSize: s, fontWeight: FontWeight.w700);
TextStyle _mono(double s, {Color c = _text2}) =>
    TextStyle(color: c, fontSize: s, fontFamily: 'monospace');

BoxDecoration _card({Color glow = _cyan, double r = 14}) => BoxDecoration(
  color: _surfaceAlt,
  borderRadius: BorderRadius.circular(r),
  border: Border.all(color: glow.withOpacity(0.25), width: 1),
  boxShadow: [BoxShadow(color: glow.withOpacity(0.07), blurRadius: 16)],
);

// ─────────────────────────────────── Screen ──────────────────────────────────
class ComplaintManagement extends ConsumerStatefulWidget {
  const ComplaintManagement({super.key});
  @override
  _ComplaintManagementState createState() => _ComplaintManagementState();
}

class _ComplaintManagementState extends ConsumerState<ComplaintManagement>
    with TickerProviderStateMixin {
  String? _filterStatus;
  String? _filterPriority;
  int?    _filterArea;
  String  _searchQuery = '';
  List<Grievance> _grievances = [];
  List<User>      _assignees  = [];
  List<MasterArea> _areas     = [];
  bool   _loading = true;
  String? _error;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _fetchData();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final gs = await ref.read(adminProvider.notifier).getAllGrievances(
        status: _filterStatus, priority: _filterPriority, areaId: _filterArea,
      );
      final us = await UserService.getUsers();
      final ar = await MasterDataService.getAreas();
      if (!mounted) return;
      setState(() {
        _grievances = gs;
        _assignees  = us.where((u) => u.role?.toLowerCase() == 'field_staff').toList();
        _areas      = ar;
        _loading    = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Grievance> get _filtered {
    var list = _grievances;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((g) =>
          g.title.toLowerCase().contains(q) ||
          g.complaintId.toLowerCase().contains(q) ||
          (g.citizen?.name?.toLowerCase().contains(q) ?? false)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      drawer: const CustomNavigationDrawer(),
      body: _loading ? _loadingBody()
          : _error != null ? _errorBody()
          : _mainBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: _surface,
    elevation: 0,
    iconTheme: const IconThemeData(color: _cyan),
    bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _cyan.withOpacity(0.3))),
    title: Row(children: [
      AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (_, __) => Container(width: 8, height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _orange,
            boxShadow: [BoxShadow(color: _orange.withOpacity(0.3 + _pulseCtrl.value * 0.7), blurRadius: 10)])),
      ),
      const SizedBox(width: 10),
      Text('COMPLAINT HQ', style: TextStyle(color: _text1, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 2)),
    ]),
    actions: [
      IconButton(icon: const Icon(Icons.refresh, color: _cyan), onPressed: _fetchData),
    ],
  );

  Widget _mainBody() {
    final items = _filtered;
    return Column(children: [
      _buildFilterBar(),
      Expanded(
        child: items.isEmpty
            ? _emptyState()
            : RefreshIndicator(
                onRefresh: _fetchData, color: _cyan, backgroundColor: _surface,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 30),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _grievanceCard(items[i]),
                ),
              ),
      ),
    ]);
  }

  Widget _buildFilterBar() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Column(children: [
        // Search
        Container(
          decoration: _card(glow: _cyan, r: 10),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(color: _text1, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search complaints…',
              hintStyle: _mono(12),
              prefixIcon: const Icon(Icons.search, color: _cyanDim, size: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _filterChip('ALL', null, _text2, _filterStatus),
            for (final s in ['new', 'in_progress', 'on_hold', 'resolved', 'closed', 'rejected'])
              _filterChip(_statusLabel(s), s, _statusColor(s), _filterStatus),
            const SizedBox(width: 12),
            _priorityChip('HIGH', 'high', _red),
            _priorityChip('MEDIUM', 'medium', _amber),
            _priorityChip('LOW', 'low', _green),
          ]),
        ),
      ]),
    );
  }

  Widget _filterChip(String label, String? val, Color color, String? current) {
    final sel = current == val;
    return GestureDetector(
      onTap: () { setState(() { _filterStatus = val; }); _fetchData(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? color : _border),
        ),
        child: Text(label,
            style: TextStyle(color: sel ? color : _text2, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      ),
    );
  }

  Widget _priorityChip(String label, String val, Color color) {
    final sel = _filterPriority == val;
    return GestureDetector(
      onTap: () { setState(() { _filterPriority = sel ? null : val; }); _fetchData(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? color : _border),
        ),
        child: Row(children: [
          Icon(Icons.flag, color: sel ? color : _text2, size: 10),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: sel ? color : _text2, fontSize: 10, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _grievanceCard(Grievance g) {
    final sc  = _statusColor(g.status ?? 'new');
    final pc  = g.priority == 'high' ? _red : g.priority == 'medium' ? _amber : _green;
    final transitions = _allowedTransitions(g.status ?? 'new');
    final terminal = _isTerminal(g.status ?? '');
    final fmt = DateFormat('dd MMM yy, HH:mm');

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sc.withOpacity(terminal ? 0.1 : 0.3), width: terminal ? 1 : 1.5),
          boxShadow: terminal ? [] : [BoxShadow(color: sc.withOpacity(0.1), blurRadius: 16)],
        ),
        child: Column(children: [
          // ── Header stripe ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: sc.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              border: Border(bottom: BorderSide(color: sc.withOpacity(0.15))),
            ),
            child: Row(children: [
              Icon(_statusIcon(g.status ?? 'new'), color: sc, size: 16),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: sc.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sc.withOpacity(0.5)),
                ),
                child: Text(_statusLabel(g.status ?? 'new'),
                    style: TextStyle(color: sc, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
              const SizedBox(width: 8),
              if (g.priority != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: pc.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: pc.withOpacity(0.4)),
                  ),
                  child: Row(children: [
                    Icon(Icons.flag, color: pc, size: 9),
                    const SizedBox(width: 3),
                    Text((g.priority!).toUpperCase(),
                        style: TextStyle(color: pc, fontSize: 9, fontWeight: FontWeight.w700)),
                  ]),
                ),
              const Spacer(),
              Text(g.complaintId, style: _mono(10, c: _cyanDim)),
            ]),
          ),

          // ── Body ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g.title, style: _heading(14)),
              const SizedBox(height: 4),
              Text(g.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: _mono(12, c: _text2)),
              const SizedBox(height: 10),
              // Meta row
              Wrap(spacing: 12, runSpacing: 6, children: [
                if (g.area != null) _metaChip(Icons.location_on, g.area!.name ?? '', _cyanDim),
                if (g.subject != null) _metaChip(Icons.category, g.subject!.name ?? '', _purple),
                if (g.citizen != null) _metaChip(Icons.person, g.citizen!.name ?? '', _text2),
                _metaChip(Icons.calendar_today, fmt.format(g.createdAt), _text2),
                if (g.assignee != null) _metaChip(Icons.engineering, g.assignee!.name ?? 'Unassigned', _orange),
              ]),

              // ── State machine actions ─────────────────────────────
              if (!terminal && transitions.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(height: 1, color: _border),
                const SizedBox(height: 12),
                Row(children: [
                  Icon(Icons.alt_route, color: _cyan, size: 14),
                  const SizedBox(width: 6),
                  Text('TRANSITION', style: _mono(10, c: _cyan)),
                  const Spacer(),
                  ...transitions.map((next) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _transitionBtn(g, next),
                  )),
                ]),
              ],

              if (terminal) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: sc.withOpacity(0.08), borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: sc.withOpacity(0.2))),
                  child: Row(children: [
                    Icon(Icons.lock, color: sc, size: 13),
                    const SizedBox(width: 6),
                    Text('TERMINAL STATE — no further transitions allowed',
                        style: _mono(10, c: sc.withOpacity(0.8))),
                  ]),
                ),
              ],

              // ── Assign / Comment actions ──────────────────────────
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _actionBtn(Icons.person_add, 'ASSIGN', _cyan, () => _showAssignDialog(g))),
                const SizedBox(width: 8),
                Expanded(child: _actionBtn(Icons.comment, 'COMMENT', _text2, () => _showCommentDialog(g))),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 11),
      const SizedBox(width: 4),
      Text(label, style: _mono(10, c: color)),
    ]);
  }

  Widget _transitionBtn(Grievance g, String next) {
    final nc = _statusColor(next);
    return GestureDetector(
      onTap: () => _confirmTransition(g, next),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: nc.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: nc.withOpacity(0.5)),
          boxShadow: [BoxShadow(color: nc.withOpacity(0.2), blurRadius: 8)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_statusIcon(next), color: nc, size: 12),
          const SizedBox(width: 4),
          Text(_statusLabel(next),
              style: TextStyle(color: nc, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ]),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ]),
      ),
    );
  }

  // ── Dialogs ─────────────────────────────────────────────────────────────────

  Future<void> _confirmTransition(Grievance g, String next) async {
    String? rejectionReason;
    bool confirmed = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        final nc = _statusColor(next);
        return Dialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: nc.withOpacity(0.4))),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: StatefulBuilder(
              builder: (ctx2, setDialogState) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(_statusIcon(next), color: nc, size: 20),
                    const SizedBox(width: 10),
                    Text('MOVE TO ${_statusLabel(next)}',
                        style: TextStyle(color: nc, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ]),
                  const SizedBox(height: 12),
                  Text('${g.title}', style: _heading(12)),
                  const SizedBox(height: 4),
                  Text(g.complaintId, style: _mono(10, c: _cyanDim)),
                  const SizedBox(height: 14),
                  // State flow visual
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _statusPill(g.status ?? 'new'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward, color: nc, size: 16),
                    ),
                    _statusPill(next),
                  ]),
                  if (next == 'rejected') ...[
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: _red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _red.withOpacity(0.3)),
                      ),
                      child: TextField(
                        onChanged: (v) => rejectionReason = v,
                        maxLines: 3,
                        style: const TextStyle(color: _text1, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Rejection reason (required)…',
                          hintStyle: _mono(11, c: _red.withOpacity(0.5)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('CANCEL', style: TextStyle(color: _text2, fontSize: 12, letterSpacing: 1)),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: ElevatedButton(
                      onPressed: next == 'rejected' && (rejectionReason?.isEmpty ?? true)
                          ? null
                          : () { confirmed = true; Navigator.pop(ctx); },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: nc.withOpacity(0.2),
                        foregroundColor: nc,
                        side: BorderSide(color: nc.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('CONFIRM', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    )),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!confirmed) return;
    try {
      final body = <String, dynamic>{'status': next};
      if (rejectionReason != null && rejectionReason!.isNotEmpty) {
        body['rejection_reason'] = rejectionReason;
      }
      await ref.read(adminProvider.notifier).updateGrievanceStatusWithBody(g.id, next, body);
      _showToast('Status updated to ${_statusLabel(next)}', _statusColor(next));
      _fetchData();
    } catch (e) {
      _showToast('Update failed: $e', _red);
    }
  }

  Widget _statusPill(String status) {
    final c = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.5))),
      child: Text(_statusLabel(status),
          style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }

  Future<void> _showAssignDialog(Grievance g) async {
    User? selected;
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: _cyan.withOpacity(0.3))),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: StatefulBuilder(
            builder: (ctx2, set) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.engineering, color: _cyan, size: 18),
                  const SizedBox(width: 10),
                  Text('ASSIGN FIELD STAFF', style: _heading(13, c: _cyan)),
                ]),
                const SizedBox(height: 16),
                ..._assignees.map((u) => InkWell(
                  onTap: () { set(() => selected = u); },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selected?.id == u.id ? _cyan.withOpacity(0.15) : _surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: selected?.id == u.id ? _cyan.withOpacity(0.6) : _border),
                    ),
                    child: Row(children: [
                      Container(width: 32, height: 32,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                          color: _cyan.withOpacity(0.15),
                          border: Border.all(color: _cyan.withOpacity(0.3))),
                        child: Center(child: Text((u.name ?? '?').substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: _cyan, fontWeight: FontWeight.bold))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(u.name ?? '', style: _heading(12)),
                        Text(u.email ?? '', style: _mono(10)),
                      ])),
                      if (selected?.id == u.id) const Icon(Icons.check_circle, color: _cyan, size: 18),
                    ]),
                  ),
                )),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('CANCEL', style: TextStyle(color: _text2, letterSpacing: 1, fontSize: 12)),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton(
                    onPressed: selected == null ? null : () async {
                      Navigator.pop(ctx);
                      try {
                        await ref.read(adminProvider.notifier)
                            .assignGrievance(g.id, selected!.id);
                        _showToast('Assigned to ${selected!.name}', _cyan);
                        _fetchData();
                      } catch (e) { _showToast('Assign failed: $e', _red); }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _cyan.withOpacity(0.2), foregroundColor: _cyan,
                      side: const BorderSide(color: _cyanDim),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('ASSIGN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  )),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCommentDialog(Grievance g) async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: _purple.withOpacity(0.3))),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.comment, color: _purple, size: 18),
              const SizedBox(width: 10),
              Text('ADD COMMENT', style: _heading(13, c: _purple)),
            ]),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(color: _surfaceAlt, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _purple.withOpacity(0.3))),
              child: TextField(
                controller: ctrl,
                maxLines: 4,
                style: const TextStyle(color: _text1, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Enter your comment…',
                  hintStyle: TextStyle(color: _text2, fontSize: 12),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCEL', style: TextStyle(color: _text2, letterSpacing: 1, fontSize: 12)),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                onPressed: () async {
                  if (ctrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  try {
                    await ref.read(adminProvider.notifier).addComment(g.id, ctrl.text.trim());
                    _showToast('Comment added', _purple);
                  } catch (e) { _showToast('Failed: $e', _red); }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple.withOpacity(0.2), foregroundColor: _purple,
                  side: const BorderSide(color: _purple),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('POST', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  void _showToast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Container(width: 4, height: 30, decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(color: _text1, fontSize: 13))),
      ]),
      backgroundColor: _surfaceAlt,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withOpacity(0.4))),
      duration: const Duration(seconds: 3),
    ));
  }

  Widget _loadingBody() => Scaffold(
    backgroundColor: _bg,
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 50, height: 50,
          child: CircularProgressIndicator(strokeWidth: 3, color: _cyan, backgroundColor: _border)),
      const SizedBox(height: 16),
      Text('LOADING COMPLAINTS…', style: _mono(12)),
    ])),
  );

  Widget _errorBody() => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, color: _red, size: 48),
      const SizedBox(height: 12),
      Text(_error!, style: _mono(12, c: _red), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      ElevatedButton(onPressed: _fetchData,
          style: ElevatedButton.styleFrom(backgroundColor: _red.withOpacity(0.2),
              foregroundColor: _red, side: const BorderSide(color: _red)),
          child: const Text('RETRY')),
    ]),
  ));

  Widget _emptyState() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.inbox, color: _text2.withOpacity(0.4), size: 64),
    const SizedBox(height: 12),
    Text('NO COMPLAINTS FOUND', style: _mono(13, c: _text2)),
  ]));
}

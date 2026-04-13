import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:main_ui/l10n/app_localizations.dart';
import 'package:main_ui/providers/admin_provider.dart';
import 'package:main_ui/models/grievance_model.dart';
import 'package:main_ui/models/kpi_model.dart';
import 'package:main_ui/widgets/navigation_drawer.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart';
import 'dart:io' as io;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

// ─────────────────────────────────── Design Tokens ────────────────────────────
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

BoxDecoration _glassCard({Color glow = _cyan, double r = 16}) => BoxDecoration(
  color: _surfaceAlt.withOpacity(0.7),
  borderRadius: BorderRadius.circular(r),
  border: Border.all(color: glow.withOpacity(0.25), width: 1),
  boxShadow: [BoxShadow(color: glow.withOpacity(0.08), blurRadius: 20, spreadRadius: 2)],
);
TextStyle _heading(double s, {Color c = _text1}) =>
    TextStyle(color: c, fontSize: s, fontWeight: FontWeight.w700, letterSpacing: 0.5);
TextStyle _mono(double s, {Color c = _text2}) =>
    TextStyle(color: c, fontSize: s, fontFamily: 'monospace');

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

class Dashboard extends ConsumerStatefulWidget {
  const Dashboard({super.key});
  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<Dashboard>
    with TickerProviderStateMixin {
  String _selectedPeriod = 'all';
  late Future<List<Grievance>> _grievancesFuture;
  late AnimationController _pulseCtrl, _scanCtrl;
  late Animation<double> _pulse, _scan;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _scanCtrl  = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    _scan  = CurvedAnimation(parent: _scanCtrl,  curve: Curves.linear);
    _grievancesFuture = ref.read(adminProvider.notifier).getAllGrievances();
    _fetchData();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _scanCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      await ref.read(adminProvider.notifier).fetchAdvancedKPIs(timePeriod: _selectedPeriod);
      if (mounted) setState(() {
        _grievancesFuture = ref.read(adminProvider.notifier).getAllGrievances();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final kpi = ref.watch(adminProvider).kpiData;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      drawer: const CustomNavigationDrawer(),
      body: RefreshIndicator(
        onRefresh: _fetchData, color: _cyan, backgroundColor: _surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _scanLine(),
              const SizedBox(height: 20),
              if (kpi != null) ...[
                _kpiGrid(kpi, loc),
                const SizedBox(height: 24),
                _statusRing(kpi),
                const SizedBox(height: 24),
                _trendLine(kpi, loc),
                const SizedBox(height: 24),
                _barChart(kpi, loc),
                const SizedBox(height: 24),
                _slaSection(kpi),
                const SizedBox(height: 24),
                _recentSection(loc),
                const SizedBox(height: 24),
                _exportRow(loc),
              ] else _loadingState(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: _surface,
    elevation: 0,
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: _cyan.withOpacity(0.3)),
    ),
    iconTheme: const IconThemeData(color: _cyan),
    title: Row(children: [
      AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => Container(width: 8, height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _cyan,
            boxShadow: [BoxShadow(color: _cyan.withOpacity(0.4 + _pulse.value * 0.6), blurRadius: 10)])),
      ),
      const SizedBox(width: 10),
      Text('COMMAND CENTER',
          style: TextStyle(color: _cyan, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 3)),
    ]),
    actions: [
      for (final p in ['7d', '30d', 'all']) _periodChip(p),
      const SizedBox(width: 8),
    ],
  );

  Widget _periodChip(String label) {
    final sel = _selectedPeriod == label;
    return GestureDetector(
      onTap: () { setState(() => _selectedPeriod = label); _fetchData(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: sel ? _cyan : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: sel ? _cyan : _border),
        ),
        child: Text(label,
            style: TextStyle(color: sel ? _bg : _text2, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
      ),
    );
  }

  Widget _scanLine() {
    return AnimatedBuilder(
      animation: _scan,
      builder: (_, __) => Container(height: 2,
        decoration: BoxDecoration(gradient: LinearGradient(
          stops: const [0, 0.5, 1],
          colors: [Colors.transparent, _cyan.withOpacity(0.9), Colors.transparent],
          begin: Alignment(_scan.value * 2 - 1.2, 0),
          end: Alignment(_scan.value * 2 + 0.2, 0),
        ))),
    );
  }

  Widget _sectionTitle(String title, IconData icon) => Row(children: [
    Icon(icon, color: _cyan, size: 16),
    const SizedBox(width: 8),
    Text(title, style: _mono(11, c: _cyan)),
    const SizedBox(width: 8),
    Expanded(child: Container(height: 1, color: _cyan.withOpacity(0.2))),
  ]);

  Widget _kpiGrid(KpiData kpi, AppLocalizations loc) {
    final items = [
      ['TOTAL', kpi.totalGrievances, Icons.list_alt, _cyan],
      ['NEW', kpi.newCount, Icons.fiber_new, _amber],
      ['IN PROGRESS', kpi.inProgressCount, Icons.sync, _orange],
      ['RESOLVED', kpi.resolvedCount, Icons.check_circle, _green],
      ['CLOSED', kpi.closedCount, Icons.lock, _cyanDim],
      ['REJECTED', kpi.rejectedCount, Icons.cancel, _red],
      ['ON HOLD', kpi.onHoldCount, Icons.pause_circle, _purple],
      ['AVG DAYS', kpi.avgResolutionTime, Icons.timer, _cyan],
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.7),
      itemBuilder: (_, i) {
        final item = items[i];
        final color = item[3] as Color;
        final rawVal = item[1];
        final val = rawVal is double ? rawVal.toStringAsFixed(1) : '${rawVal ?? 0}';
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 300 + i * 80),
          curve: Curves.easeOut,
          builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 15 * (1 - v)), child: child)),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
              boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 14)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Icon(item[2] as IconData, color: color, size: 14),
                  const SizedBox(width: 6),
                  Text(item[0] as String, style: _mono(9, c: color.withOpacity(0.8))),
                ]),
                Text(val, style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    shadows: [Shadow(color: color.withOpacity(0.5), blurRadius: 12)])),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusRing(KpiData kpi) {
    final total = max(1, (kpi.totalGrievances as num?)?.toInt() ?? 1);
    final data = [
      [kpi.resolvedCount, _green],
      [kpi.inProgressCount, _orange],
      [kpi.newCount, _amber],
      [kpi.onHoldCount, _purple],
      [kpi.rejectedCount, _red],
      [kpi.closedCount, _cyanDim],
    ].map((e) {
      final v = (e[0] as num?)?.toDouble() ?? 0;
      return v > 0 ? PieChartSectionData(value: v, color: e[1] as Color, title: '', radius: 22) : null;
    }).whereType<PieChartSectionData>().toList();

    final labels = [
      ['RESOLVED', _green, kpi.resolvedCount],
      ['IN PROGRESS', _orange, kpi.inProgressCount],
      ['NEW', _amber, kpi.newCount],
      ['ON HOLD', _purple, kpi.onHoldCount],
      ['REJECTED', _red, kpi.rejectedCount],
      ['CLOSED', _cyanDim, kpi.closedCount],
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _glassCard(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('STATUS DISTRIBUTION', Icons.donut_large),
        const SizedBox(height: 16),
        SizedBox(height: 180, child: Row(children: [
          Expanded(flex: 2, child: data.isEmpty
              ? const Center(child: Text('No data', style: TextStyle(color: _text2)))
              : PieChart(PieChartData(sections: data, centerSpaceRadius: 52, sectionsSpace: 3,
                  borderData: FlBorderData(show: false)))),
          Expanded(flex: 3, child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: labels.map((l) {
              final count = (l[2] as num?)?.toInt() ?? 0;
              final pct = (count / total * 100).toStringAsFixed(1);
              final color = l[1] as Color;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Container(width: 8, height: 8,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: color,
                          boxShadow: [BoxShadow(color: color.withOpacity(0.7), blurRadius: 4)])),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l[0] as String, style: _mono(9))),
                  Text('$count', style: _mono(11, c: color)),
                  const SizedBox(width: 4),
                  Text('$pct%', style: _mono(9)),
                ]),
              );
            }).toList(),
          )),
        ])),
      ]),
    );
  }

  Widget _trendLine(KpiData kpi, AppLocalizations loc) {
    final trend = (kpi.trend as List?) ?? [];
    if (trend.isEmpty) return const SizedBox.shrink();
    final spots = trend.asMap().entries.map((e) {
      final v = ((e.value as Map)['count'] as num?)?.toDouble() ?? 0;
      return FlSpot(e.key.toDouble(), v);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _glassCard(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('COMPLAINT TREND', Icons.show_chart),
        const SizedBox(height: 16),
        SizedBox(height: 140, child: LineChart(LineChartData(
          backgroundColor: Colors.transparent,
          gridData: FlGridData(show: true,
              getDrawingHorizontalLine: (_) => FlLine(color: _border, strokeWidth: 0.5),
              getDrawingVerticalLine: (_) => FlLine(color: _border, strokeWidth: 0.5)),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30,
                getTitlesWidget: (v, _) => Text('${v.toInt()}', style: _mono(9)))),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [LineChartBarData(
            spots: spots, isCurved: true, color: _cyan, barWidth: 2,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: true, gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [_cyan.withOpacity(0.3), Colors.transparent],
            )),
          )],
        ))),
      ]),
    );
  }

  Widget _barChart(KpiData kpi, AppLocalizations loc) {
    final Map<String, dynamic> bySubject = (kpi.bySubject is Map)
        ? Map<String, dynamic>.from(kpi.bySubject as Map) : {};
    if (bySubject.isEmpty) return const SizedBox.shrink();
    final entries = bySubject.entries.take(6).toList();
    final bars = entries.asMap().entries.map((e) => BarChartGroupData(
      x: e.key,
      barRods: [BarChartRodData(
        toY: (e.value.value as num?)?.toDouble() ?? 0,
        gradient: const LinearGradient(colors: [_cyanDim, _cyan], begin: Alignment.bottomCenter, end: Alignment.topCenter),
        width: 18,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        backDrawRodData: BackgroundBarChartRodData(show: true, toY: 40, color: _border.withOpacity(0.3)),
      )],
    )).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _glassCard(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('BY SUBJECT CATEGORY', Icons.bar_chart),
        const SizedBox(height: 16),
        SizedBox(height: 150, child: BarChart(BarChartData(
          backgroundColor: Colors.transparent,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx >= entries.length) return const SizedBox();
                  final lbl = entries[idx].key.toString();
                  return Padding(padding: const EdgeInsets.only(top: 4),
                      child: Text(lbl.length > 5 ? '${lbl.substring(0, 5)}…' : lbl, style: _mono(8)));
                })),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: bars,
        ))),
      ]),
    );
  }

  Widget _slaSection(KpiData kpi) {
    final sla = (kpi.slaCompliance as num?)?.toDouble() ?? 0.0;
    final good = sla >= 80;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _glassCard(glow: good ? _green : _red),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('SLA COMPLIANCE', Icons.verified_user),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${sla.toStringAsFixed(1)}%',
                style: TextStyle(color: good ? _green : _red, fontSize: 40, fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    shadows: [Shadow(color: (good ? _green : _red).withOpacity(0.7), blurRadius: 16)])),
            Text('resolved within SLA target', style: _mono(11)),
          ])),
          SizedBox(width: 64, height: 64, child: CircularProgressIndicator(
            value: sla / 100, strokeWidth: 6,
            color: good ? _green : _red, backgroundColor: _border,
          )),
        ]),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: sla / 100, minHeight: 6,
                color: good ? _green : _red, backgroundColor: _border)),
      ]),
    );
  }

  Widget _recentSection(AppLocalizations loc) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('RECENT ACTIVITY', Icons.rss_feed),
      const SizedBox(height: 12),
      FutureBuilder<List<Grievance>>(
        future: _grievancesFuture,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _cyan));
          }
          final items = (snap.data ?? []).take(6).toList();
          if (items.isEmpty) return Container(
            padding: const EdgeInsets.all(20), decoration: _glassCard(),
            child: const Center(child: Text('No recent data', style: TextStyle(color: _text2))),
          );
          return Column(children: items.map(_activityRow).toList());
        },
      ),
    ]);
  }

  Widget _activityRow(Grievance g) {
    final sc = _statusColor(g.status ?? 'new');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceAlt.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sc.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(width: 4, height: 36,
            decoration: BoxDecoration(color: sc, borderRadius: BorderRadius.circular(2),
                boxShadow: [BoxShadow(color: sc.withOpacity(0.7), blurRadius: 6)])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(g.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _heading(13)),
          const SizedBox(height: 2),
          Text(g.complaintId, style: _mono(10, c: _cyanDim)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: sc.withOpacity(0.15), borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sc.withOpacity(0.5))),
          child: Text((g.status ?? 'new').toUpperCase(),
              style: TextStyle(color: sc, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
        ),
      ]),
    );
  }

  Widget _exportRow(AppLocalizations loc) {
    return Row(children: [
      Expanded(child: _exportBtn('EXPORT CSV', Icons.table_chart, _cyan, 'csv', loc)),
      const SizedBox(width: 12),
      Expanded(child: _exportBtn('EXPORT PDF', Icons.picture_as_pdf, _amber, 'pdf', loc)),
    ]);
  }

  Widget _exportBtn(String label, IconData icon, Color color, String type, AppLocalizations loc) {
    return GestureDetector(
      onTap: () => _export(type, loc),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.4))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        ]),
      ),
    );
  }

  Widget _loadingState() => Center(
    child: Padding(padding: const EdgeInsets.all(60),
        child: Column(children: [
          SizedBox(width: 60, height: 60,
              child: CircularProgressIndicator(strokeWidth: 3, color: _cyan, backgroundColor: _border)),
          const SizedBox(height: 20),
          Text('LOADING DATA…', style: _mono(12)),
        ])),
  );

  Future<void> _export(String type, AppLocalizations loc) async {
    try {
      final res = await ref.read(adminProvider.notifier)
          .exportGrievances(format: type, timePeriod: _selectedPeriod);
      if (res == null) return;
      if (kIsWeb) {
        final blob = html.Blob([res]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', 'report.$type')
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final dir = await getTemporaryDirectory();
        final file = io.File('${dir.path}/report.$type');
        await file.writeAsBytes(res);
        await OpenFile.open(file.path);
      }
    } catch (_) {}
  }
}

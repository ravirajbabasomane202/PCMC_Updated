class KpiData {
  final Map<String, int> totalComplaints;
  final Map<String, int> statusOverview;
  final Map<String, int> deptWise;
  final Map<String, dynamic> slaMetrics;
  final Map<String, int> staffPerformance;

  KpiData({
    required this.totalComplaints,
    required this.statusOverview,
    required this.deptWise,
    required this.slaMetrics,
    required this.staffPerformance,
  });

  factory KpiData.fromJson(Map<String, dynamic> json) {
    return KpiData(
      totalComplaints: Map<String, int>.from(json['total_complaints'] ?? {}),
      statusOverview: Map<String, int>.from(json['status_overview'] ?? {}),
      deptWise: Map<String, int>.from(json['dept_wise'] ?? {}),
      slaMetrics: Map<String, dynamic>.from(json['sla_metrics'] ?? {}),
      staffPerformance: Map<String, int>.from(json['staff_performance'] ?? {}),
    );
  }

  // Computed getters for dashboard
  int get totalGrievances => statusOverview.values.fold(0, (sum, count) => sum + count);

  int get newCount => statusOverview['new'] ?? 0;
  int get inProgressCount => statusOverview['in_progress'] ?? 0;
  int get resolvedCount => statusOverview['resolved'] ?? 0;
  int get closedCount => statusOverview['closed'] ?? 0;
  int get rejectedCount => statusOverview['rejected'] ?? 0;
  int get onHoldCount => statusOverview['on_hold'] ?? 0;

  double get avgResolutionTime => (slaMetrics['avg_resolution_time'] as num?)?.toDouble() ?? 0.0;

  List<dynamic> get trend => slaMetrics['trend'] as List<dynamic>? ?? [];

  Map<String, dynamic> get bySubject => deptWise.map((key, value) => MapEntry(key, value as dynamic));

  double get slaCompliance => (slaMetrics['compliance'] as num?)?.toDouble() ?? 0.0;
}
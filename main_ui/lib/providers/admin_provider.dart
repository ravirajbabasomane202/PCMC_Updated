import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../models/grievance_model.dart';
import '../models/kpi_model.dart';
import '../services/api_service.dart';

class Config {
  final String key;
  final String value;

  const Config({required this.key, required this.value});

  factory Config.fromJson(Map<String, dynamic> json) => Config(
        key: json['key'] as String? ?? '',
        value: json['value'] as String? ?? '',
      );
}

class AdminState {
  final KpiData? kpiData;
  final List<Grievance> grievances;
  final List<Config> configs;
  final bool isLoading;
  final String? error;

  const AdminState({
    this.kpiData,
    this.grievances = const [],
    this.configs = const [],
    this.isLoading = false,
    this.error,
  });

  AdminState copyWith({
    KpiData? kpiData,
    List<Grievance>? grievances,
    List<Config>? configs,
    bool? isLoading,
    String? error,
  }) =>
      AdminState(
        kpiData: kpiData ?? this.kpiData,
        grievances: grievances ?? this.grievances,
        configs: configs ?? this.configs,
        isLoading: isLoading ?? this.isLoading,
        error: error,          // null clears previous error
      );
}

class AdminNotifier extends StateNotifier<AdminState> {
  AdminNotifier() : super(const AdminState()) {
    getConfigs();
  }

  Future<void> fetchAdvancedKPIs({String timePeriod = 'all'}) async {
    try {
      final response = await ApiService.get(
          '/admins/reports/kpis/advanced?time_period=$timePeriod');
      state = state.copyWith(kpiData: KpiData.fromJson(response.data));
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<List<Grievance>> getAllGrievances({
    String? status,
    String? priority,
    int? areaId,
    int? subjectId,
  }) async {
    try {
      final response = await ApiService.get('/admins/grievances/all');
      final grievances = (response.data as List)
          .map((g) => Grievance.fromJson(g as Map<String, dynamic>))
          .toList();
      state = state.copyWith(grievances: grievances);
      return grievances;
    } catch (e) {
      state = state.copyWith(grievances: [], error: e.toString());
      return [];
    }
  }

  Future<void> escalateGrievance(
      int grievanceId, int newAssigneeId, int userId) async {
    try {
      await ApiService.post('/admins/grievances/$grievanceId/escalate',
          {'escalated_by': userId, 'assignee_id': newAssigneeId});
      await getAllGrievances();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> reassignGrievance(int grievanceId, int assigneeId) async {
    try {
      await ApiService.post(
          '/admins/reassign/$grievanceId', {'assigned_to': assigneeId});
      await getAllGrievances();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateGrievanceStatus(int grievanceId, String status) async {
    try {
      await ApiService.post(
          '/grievances/$grievanceId/status', {'status': status});
      await getAllGrievances();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateGrievanceStatusWithBody(int id, String status, Map<String, dynamic> body) async {
    try {
      await ApiService.put('/grievances/$id/status', body);
      await getAllGrievances();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> assignGrievance(int grievanceId, int staffId) async {
    try {
      await ApiService.put('/admins/grievances/$grievanceId/assign', {'assigned_to': staffId});
      await getAllGrievances();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> addComment(int grievanceId, String comment) async {
    try {
      await ApiService.post('/grievances/$grievanceId/comments', {'content': comment});
      await getAllGrievances();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<List<int>> exportGrievances({required String format, required String timePeriod}) async {
    try {
      final response = await ApiService.get(
        '/admins/reports/export?format=$format&time_period=$timePeriod',
        responseType: ResponseType.bytes,
      );
      return List<int>.from(response.data as List);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return [];
    }
  }

  Future<List<Grievance>> getCitizenHistory(int userId) async {
    try {
      final response =
          await ApiService.get('/admins/users/$userId/history');
      final grievances = (response.data as List)
          .map((g) => Grievance.fromJson(g as Map<String, dynamic>))
          .toList();
      state = state.copyWith(grievances: grievances);
      return grievances;
    } catch (e) {
      state = state.copyWith(grievances: [], error: e.toString());
      return [];
    }
  }

  Future<List<int>> generateReport(String filter, String format) async {
    try {
      final response = await ApiService.get(
        '/admins/reports?filter_type=$filter&format=$format',
        responseType: ResponseType.bytes,
      );
      return List<int>.from(response.data as List);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return [];
    }
  }

  Future<void> getConfigs() async {
    try {
      final response = await ApiService.get('/admins/configs');
      final configs = (response.data as List)
          .map((j) => Config.fromJson(j as Map<String, dynamic>))
          .toList();
      state = state.copyWith(configs: configs);
    } catch (e) {
      state = state.copyWith(error: 'Failed to fetch configs: $e');
    }
  }

  Future<void> addConfig(String key, String value) async {
    try {
      await ApiService.post('/admins/configs', {'key': key, 'value': value});
      await getConfigs();
    } catch (e) {
      state = state.copyWith(error: 'Failed to add config: $e');
    }
  }
}

final adminProvider =
    StateNotifierProvider<AdminNotifier, AdminState>((ref) => AdminNotifier());

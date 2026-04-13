import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/grievance_model.dart';
import '../services/grievance_service.dart';

// ── Family provider: citizen grievance history by userId ─────────────────────
final citizenHistoryProvider =
    FutureProvider.family<List<Grievance>, int>((ref, userId) async {
  return GrievanceService().getGrievancesByUserId(userId);
});

// ── State ─────────────────────────────────────────────────────────────────────
class GrievanceState {
  final List<Grievance> grievances;
  final bool isLoading;
  final String? error;

  const GrievanceState({
    this.grievances = const [],
    this.isLoading = false,
    this.error,
  });

  GrievanceState copyWith({
    List<Grievance>? grievances,
    bool? isLoading,
    String? error,
  }) =>
      GrievanceState(
        grievances: grievances ?? this.grievances,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class GrievanceNotifier extends StateNotifier<GrievanceState> {
  GrievanceNotifier() : super(const GrievanceState());

  final _service = GrievanceService();

  Future<void> _fetch(Future<List<Grievance>> Function() loader) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      state = state.copyWith(grievances: await loader(), isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> fetchMyGrievances() => _fetch(_service.getMyGrievances);
  Future<void> fetchNewGrievances() => _fetch(_service.getNewGrievances);
  Future<void> fetchAssignedGrievances() => _fetch(_service.getAssignedGrievances);
}

final grievanceProvider =
    StateNotifierProvider<GrievanceNotifier, GrievanceState>(
        (ref) => GrievanceNotifier());

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';

import '../models/grievance_model.dart';
import 'api_service.dart';

class GrievanceService {
  static final Dio _dio = ApiService.dio;

  // ── Helpers ──────────────────────────────────────────────────────────────

  List<Grievance> _parseGrievanceList(Response response) {
    if (response.data is List) {
      return (response.data as List)
          .map((g) => Grievance.fromJson(g as Map<String, dynamic>))
          .toList();
    }
    if (response.data is Map && response.data['grievances'] is List) {
      return (response.data['grievances'] as List)
          .map((g) => Grievance.fromJson(g as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Unexpected response format');
  }

  Exception _handleDioException(DioException e, String action) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return Exception('Cannot connect to server. Check your network.');
    }
    if (e.response?.statusCode == 401) {
      return Exception('Session expired. Please log in again.');
    }
    return Exception(
        'Failed to $action: ${e.response?.data?['msg'] ?? e.message}');
  }

  static Future<Position?> _getLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    return Geolocator.getCurrentPosition();
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  Future<Grievance> getGrievanceById(int id) async {
    try {
      final response = await _dio.get('/grievances/$id');
      return Grievance.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioException(e, 'fetch grievance');
    }
  }

  Future<Grievance> getGrievanceDetails(int id) async {
    return getGrievanceById(id);
  }

  Future<List<Grievance>> getMyGrievances() async {
    try {
      return _parseGrievanceList(await _dio.get('/grievances/mine'));
    } on DioException catch (e) {
      throw _handleDioException(e, 'fetch my grievances');
    }
  }

  Future<List<Grievance>> getGrievancesByUserId(int userId) async {
    try {
      return _parseGrievanceList(await _dio.get('/grievances/track'));
    } on DioException catch (e) {
      throw _handleDioException(e, 'fetch user grievances');
    }
  }

  Future<List<Grievance>> getNewGrievances() async {
    try {
      return _parseGrievanceList(await _dio.get('/grievances/all'));
    } on DioException catch (e) {
      throw _handleDioException(e, 'fetch new grievances');
    }
  }

  Future<List<Grievance>> getAssignedGrievances() async {
    try {
      return _parseGrievanceList(await _dio.get('/grievances/assigned'));
    } on DioException catch (e) {
      throw _handleDioException(e, 'fetch assigned grievances');
    }
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  Future<void> createGrievance({
    required String title,
    required String description,
    required int subjectId,
    required int areaId,
    String? priority,
    String? address,
    List<PlatformFile>? attachments,
  }) async {
    try {
      final position = await _getLocation();
      final formData = FormData.fromMap({
        'title': title,
        'description': description,
        'subject_id': subjectId,
        'area_id': areaId,
        'priority': priority ?? 'medium',
        if (position != null) 'latitude': position.latitude,
        if (position != null) 'longitude': position.longitude,
        if (address != null) 'address': address,
      });

      if (attachments != null) {
        for (final file in attachments) {
          formData.files.add(MapEntry(
            'attachments',
            kIsWeb
                ? MultipartFile.fromBytes(file.bytes!, filename: file.name)
                : await MultipartFile.fromFile(file.path!, filename: file.name),
          ));
        }
      }

      final response = await _dio.post('/grievances/', data: formData);
      if (response.statusCode != 201) {
        throw Exception('Failed to create grievance');
      }
    } on DioException catch (e) {
      throw _handleDioException(e, 'create grievance');
    }
  }

  Future<Map<String, dynamic>> updateGrievance(
      int id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/grievances/$id', data: data);
      if (response.statusCode == 200) return response.data;
      throw Exception('Failed to update grievance');
    } on DioException catch (e) {
      throw _handleDioException(e, 'update grievance');
    }
  }

  Future<void> deleteGrievance(int grievanceId) async {
    try {
      await _dio.delete('/grievances/$grievanceId');
    } on DioException catch (e) {
      throw _handleDioException(e, 'delete grievance');
    }
  }

  Future<void> addComment(int id, String commentText,
      {List<PlatformFile>? attachments}) async {
    try {
      final formData = FormData.fromMap({'comment_text': commentText});
      if (attachments != null) {
        for (final file in attachments) {
          formData.files.add(MapEntry(
            'attachments',
            kIsWeb
                ? MultipartFile.fromBytes(file.bytes!, filename: file.name)
                : await MultipartFile.fromFile(file.path!, filename: file.name),
          ));
        }
      }
      await _dio.post('/grievances/$id/comments', data: formData);
    } on DioException catch (e) {
      throw _handleDioException(e, 'add comment');
    }
  }

  Future<void> submitFeedback(
      int grievanceId, int rating, String feedbackText) async {
    try {
      await _dio.post('/grievances/$grievanceId/feedback',
          data: {'rating': rating, 'feedback_text': feedbackText});
    } on DioException catch (e) {
      throw _handleDioException(e, 'submit feedback');
    }
  }

  Future<void> reassignGrievance(int grievanceId, int assigneeId) async {
    try {
      await _dio.put('/grievances/$grievanceId/reassign',
          data: {'assignee_id': assigneeId});
    } on DioException catch (e) {
      throw _handleDioException(e, 'reassign grievance');
    }
  }

  Future<void> updateGrievanceStatus(
      int grievanceId, String status) async {
    try {
      await _dio.put('/grievances/$grievanceId/status',
          data: {'status': status});
    } on DioException catch (e) {
      throw _handleDioException(e, 'update grievance status');
    }
  }

  Future<void> escalateGrievance(int grievanceId,
      {int? assigneeId}) async {
    try {
      await _dio.post(
        '/grievances/$grievanceId/escalate',
        data: assigneeId != null ? {'assignee_id': assigneeId} : {},
      );
    } on DioException catch (e) {
      throw _handleDioException(e, 'escalate grievance');
    }
  }
}

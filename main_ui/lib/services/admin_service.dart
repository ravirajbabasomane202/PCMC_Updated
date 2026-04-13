import 'api_service.dart';

class AdminService {
  static Future<Map<String, dynamic>> getDashboard() async {
    try {
      final response = await ApiService.get('/admins/dashboard');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to load dashboard data: $e');
    }
  }

  static Future<List<dynamic>> getAuditLogs() async {
    try {
      final response = await ApiService.get('/admins/audit-logs');
      return response.data as List<dynamic>;
    } catch (e) {
      throw Exception('Failed to load audit logs: $e');
    }
  }
}

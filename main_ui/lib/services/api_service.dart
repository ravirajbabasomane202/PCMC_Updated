import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:logging/logging.dart';

import 'package:main_ui/models/user_model.dart';
import 'package:main_ui/models/ad_model.dart';
import 'package:main_ui/services/auth_service.dart';
import 'package:main_ui/utils/constants.dart';

final Logger _logger = Logger('ApiService');

class ApiService {
  static final Dio _dio = Dio();

  /* ================= INITIALIZATION ================= */

  static Future<void> init() async {
    _dio.options
      ..baseUrl = Constants.baseUrl
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 15)
      ..headers = {'Content-Type': 'application/json'};

    _dio.interceptors.clear();

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await AuthService.getToken();

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
            _logger.fine('Authorization attached');
          } else {
            options.headers.remove('Authorization');
          }

          handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            _logger.warning(
              '401 Unauthorized → clearing auth state',
            );
            await AuthService.logout();
          }
          handler.next(error);
        },
      ),
    );

    _logger.info('ApiService initialized: ${Constants.baseUrl}');
  }

  /* ================= AUTH HEADER RESET ================= */

  static void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  static Dio get dio => _dio;

  /* ================= BASIC REQUESTS ================= */

  static Future<Response> get(
    String path, {
    Map<String, dynamic>? headers,
    ResponseType? responseType,
  }) async {
    try {
      return await _dio.get(
        path,
        options: Options(headers: headers, responseType: responseType),
      );
    } on DioException catch (e) {
      _logger.severe('GET failed [$path]: ${e.message}');
      rethrow;
    }
  }

  static Future<Response> post(
    String path,
    dynamic data, {
    Map<String, dynamic>? headers,
    ResponseType? responseType,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        options: Options(headers: headers, responseType: responseType),
      );
    } on DioException catch (e) {
      _logger.severe('POST failed [$path]: ${e.message}');
      rethrow;
    }
  }

  static Future<Response> put(
    String path,
    dynamic data, {
    Map<String, dynamic>? headers,
    ResponseType? responseType,
  }) async {
    try {
      return await _dio.put(
        path,
        data: data,
        options: Options(headers: headers, responseType: responseType),
      );
    } on DioException catch (e) {
      _logger.severe('PUT failed [$path]: ${e.message}');
      rethrow;
    }
  }

  static Future<Response> delete(
    String path, {
    Map<String, dynamic>? headers,
    ResponseType? responseType,
  }) async {
    try {
      return await _dio.delete(
        path,
        options: Options(headers: headers, responseType: responseType),
      );
    } on DioException catch (e) {
      _logger.severe('DELETE failed [$path]: ${e.message}');
      rethrow;
    }
  }

  /* ================= MULTIPART ================= */

  static Future<Response> postMultipart(
    String path, {
    required List<PlatformFile> files,
    Map<String, dynamic>? data,
    String fieldName = 'files',
  }) async {
    try {
      final formData = FormData.fromMap({
        ...?data,
        fieldName: files.length == 1
            ? MultipartFile.fromBytes(
                files.first.bytes!,
                filename: files.first.name,
              )
            : files
                .map(
                  (f) => MultipartFile.fromBytes(
                    f.bytes!,
                    filename: f.name,
                  ),
                )
                .toList(),
      });

      return await _dio.post(path, data: formData);
    } on DioException catch (e) {
      _logger.severe('Multipart POST failed [$path]: ${e.message}');
      rethrow;
    }
  }

  static Future<Response> putMultipart(
    String path, {
    required Map<String, dynamic> data,
    PlatformFile? file,
    String fileField = 'image_file',
  }) async {
    try {
      final formData = FormData.fromMap({
        ...data,
        if (file != null)
          fileField: kIsWeb
              ? MultipartFile.fromBytes(
                  file.bytes!,
                  filename: file.name,
                )
              : await MultipartFile.fromFile(
                  file.path!,
                  filename: file.name,
                ),
      });

      return await _dio.put(
        path,
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );
    } on DioException catch (e) {
      _logger.severe('Multipart PUT failed [$path]: ${e.message}');
      rethrow;
    }
  }

  /* ================= USERS ================= */

  static Future<List<User>> getUsers() async {
    final response = await _dio.get('/admins/users');
    return (response.data as List)
        .map((json) => User.fromJson(json))
        .toList();
  }

  static Future<User> addUpdateUser(Map<String, dynamic> data) async {
    try {
      final id = data['id']?.toString();
      final response = id != null && id.isNotEmpty
          ? await _dio.put('/admins/users/$id', data: data)
          : await _dio.post('/admins/users', data: data);

      return User.fromJson(response.data);
    } on DioException catch (e) {
      _logger.severe('User save failed: ${e.response?.data}');
      throw Exception(
        e.response?.data?['msg'] ?? 'Failed to save user',
      );
    }
  }

  static Future<void> deleteUser(int userId) async {
  final response = await _dio.delete('/admins/users/$userId');

  if (response.statusCode != 200) {
    throw Exception(response.data?['msg'] ?? 'Failed to delete user');
  }
}


  /* ================= PROFILE ================= */

  static Future<User> updateProfile({
    String? name,
    String? email,
    String? password,
    String? address,
    PlatformFile? profilePic,
  }) async {
    try {
      final Map<String, dynamic> fields = {};

      if (name != null) fields['name'] = name;
      if (email != null) fields['email'] = email;
      if (password != null && password.isNotEmpty) {
        fields['password'] = password;
      }
      if (address != null) fields['address'] = address;

      if (profilePic != null) {
        fields['profile_picture'] = kIsWeb
            ? MultipartFile.fromBytes(
                profilePic.bytes!,
                filename: profilePic.name,
              )
            : await MultipartFile.fromFile(
                profilePic.path!,
                filename: profilePic.name,
              );
      }

      final response = await _dio.put(
        '/auth/me',
        data: FormData.fromMap(fields),
      );

      return User.fromJson(response.data);
    } on DioException catch (e) {
      _logger.severe('Profile update failed: ${e.message}');
      throw Exception('Failed to update profile');
    }
  }

  /* ================= MISC ================= */

  static Future<Map<String, dynamic>?> getMasterArea(int areaId) async {
    final response = await _dio.get('/areas/$areaId');
    return response.data as Map<String, dynamic>?;
  }

  static Future<Response> getGrievance(int id) async {
    return _dio.get('/grievances/$id');
  }

  static Future<List<Advertisement>> fetchAds() async {
    final response = await _dio.get('/advertisements');

    final List ads = response.data is List
        ? response.data
        : response.data['data'] ?? response.data['advertisements'] ?? [];

    return ads
        .map((json) => Advertisement.fromJson(json))
        .toList();
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ApiService {
  static String _baseUrl = _defaultBaseUrl();
  static String? _accessToken;
  static String? _refreshToken;

  static String _defaultBaseUrl() {
    return 'https://achi717.pythonanywhere.com';
  }

  static String get baseUrl => _baseUrl;
  static String? get accessToken => _accessToken;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('imposti_base_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrl = savedUrl.replaceAll(RegExp(r'/$'), '');
    }
    _accessToken = prefs.getString('imposti_access_token');
    _refreshToken = prefs.getString('imposti_refresh_token');
  }

  static Future<void> setBaseUrl(String url) async {
    final cleaned = url.trim().replaceAll(RegExp(r'/$'), '');
    if (cleaned.isEmpty) return;
    _baseUrl = cleaned;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('imposti_base_url', _baseUrl);
  }

  static Future<void> saveTokens(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('imposti_access_token', access);
    await prefs.setString('imposti_refresh_token', refresh);
  }

  static Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('imposti_access_token');
    await prefs.remove('imposti_refresh_token');
  }

  static String resolveMediaUrl(String pathOrUrl) {
    if (pathOrUrl.isEmpty) return '';
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return pathOrUrl;
    }
    if (!pathOrUrl.startsWith('/')) {
      return '$_baseUrl/$pathOrUrl';
    }
    return '$_baseUrl$pathOrUrl';
  }

  static String buildReportUrl(String path, {bool downloadPdf = false}) {
    final uri = Uri.parse('$_baseUrl$path');
    final params = Map<String, String>.from(uri.queryParameters);
    if (downloadPdf) {
      params['download'] = 'pdf';
    }
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      params['token'] = _accessToken!;
    }
    return uri.replace(queryParameters: params).toString();
  }

  static Map<String, String> _headers({bool jsonBody = true}) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (jsonBody) {
      headers['Content-Type'] = 'application/json';
    }
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  static Future<bool> _tryRefreshToken() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) return false;
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': _refreshToken}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data['access'] != null) {
          _accessToken = data['access'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('imposti_access_token', _accessToken!);
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  static Future<http.Response> _sendWithRetry(
    Future<http.Response> Function() requestFn,
  ) async {
    var response = await requestFn();
    if (response.statusCode == 401 && await _tryRefreshToken()) {
      response = await requestFn();
    }
    return response;
  }

  static dynamic _decode(http.Response res) {
    if (res.bodyBytes.isEmpty) return {};
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static String _extractError(http.Response res) {
    try {
      final data = _decode(res);
      if (data is Map) {
        if (data['error'] != null) return data['error'].toString();
        if (data['detail'] != null) return data['detail'].toString();
        return data.values.map((v) => v.toString()).join(', ');
      }
    } catch (_) {}
    return 'სერვერის შეცდომა (${res.statusCode})';
  }

  // ==================== AUTH ====================

  static Future<AppUser> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/login/'),
      headers: _headers(),
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode == 200) {
      final data = _decode(res);
      await saveTokens(data['access'], data['refresh']);
      return AppUser.fromJson(Map<String, dynamic>.from(data['user']));
    }
    throw Exception(_extractError(res));
  }

  static Future<AppUser> signup({
    required String companyName,
    required String username,
    required String password,
    String firstName = '',
    String lastName = '',
    String phone = '',
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/signup/'),
      headers: _headers(),
      body: jsonEncode({
        'company_name': companyName,
        'username': username,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
      }),
    );
    if (res.statusCode == 201 || res.statusCode == 200) {
      final data = _decode(res);
      await saveTokens(data['access'], data['refresh']);
      return AppUser.fromJson(Map<String, dynamic>.from(data['user']));
    }
    throw Exception(_extractError(res));
  }

  static Future<AppUser> getProfile() async {
    final res = await _sendWithRetry(
      () => http.get(Uri.parse('$_baseUrl/api/profile/'), headers: _headers()),
    );
    if (res.statusCode == 200) {
      return AppUser.fromJson(Map<String, dynamic>.from(_decode(res)));
    }
    throw Exception(_extractError(res));
  }

  static Future<void> logout() async {
    if (_refreshToken != null) {
      try {
        await http.post(
          Uri.parse('$_baseUrl/api/logout/'),
          headers: _headers(),
          body: jsonEncode({'refresh': _refreshToken}),
        );
      } catch (_) {}
    }
    await clearTokens();
  }

  // ==================== DASHBOARDS ====================

  static Future<Map<String, dynamic>> getManagerDashboard() async {
    final res = await _sendWithRetry(
      () => http.get(
        Uri.parse('$_baseUrl/api/manager/dashboard/'),
        headers: _headers(),
      ),
    );
    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(_decode(res));
    }
    throw Exception(_extractError(res));
  }

  static Future<Map<String, dynamic>> getClientDashboard() async {
    final res = await _sendWithRetry(
      () => http.get(
        Uri.parse('$_baseUrl/api/client/dashboard/'),
        headers: _headers(),
      ),
    );
    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(_decode(res));
    }
    throw Exception(_extractError(res));
  }

  // ==================== COMPANIES ====================

  static Future<List<CompanyModel>> getCompanies() async {
    final res = await _sendWithRetry(
      () => http.get(Uri.parse('$_baseUrl/api/companies/'), headers: _headers()),
    );
    if (res.statusCode == 200) {
      final list = _decode(res) as List<dynamic>;
      return list
          .map((e) => CompanyModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    throw Exception(_extractError(res));
  }

  static Future<CompanyModel> createCompany(String name) async {
    final res = await _sendWithRetry(
      () => http.post(
        Uri.parse('$_baseUrl/api/companies/'),
        headers: _headers(),
        body: jsonEncode({'name': name}),
      ),
    );
    if (res.statusCode == 201 || res.statusCode == 200) {
      return CompanyModel.fromJson(Map<String, dynamic>.from(_decode(res)));
    }
    throw Exception(_extractError(res));
  }

  static Future<CompanyModel> updateCompany(int id, String name) async {
    final res = await _sendWithRetry(
      () => http.patch(
        Uri.parse('$_baseUrl/api/companies/$id/'),
        headers: _headers(),
        body: jsonEncode({'name': name}),
      ),
    );
    if (res.statusCode == 200) {
      return CompanyModel.fromJson(Map<String, dynamic>.from(_decode(res)));
    }
    throw Exception(_extractError(res));
  }

  static Future<void> deleteCompany(int id) async {
    final res = await _sendWithRetry(
      () => http.delete(
        Uri.parse('$_baseUrl/api/companies/$id/'),
        headers: _headers(),
      ),
    );
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception(_extractError(res));
    }
  }

  // ==================== SITES ====================

  static Future<List<SiteModel>> getSites({int? companyId}) async {
    final query = companyId != null ? '?company=$companyId' : '';
    final res = await _sendWithRetry(
      () => http.get(
        Uri.parse('$_baseUrl/api/sites/$query'),
        headers: _headers(),
      ),
    );
    if (res.statusCode == 200) {
      final list = _decode(res) as List<dynamic>;
      return list
          .map((e) => SiteModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    throw Exception(_extractError(res));
  }

  static Future<SiteModel> createSite({
    required int companyId,
    required String name,
    required String address,
  }) async {
    final res = await _sendWithRetry(
      () => http.post(
        Uri.parse('$_baseUrl/api/sites/'),
        headers: _headers(),
        body: jsonEncode({
          'company': companyId,
          'name': name,
          'address': address,
        }),
      ),
    );
    if (res.statusCode == 201 || res.statusCode == 200) {
      return SiteModel.fromJson(Map<String, dynamic>.from(_decode(res)));
    }
    throw Exception(_extractError(res));
  }

  static Future<SiteModel> updateSite({
    required int id,
    required int companyId,
    required String name,
    required String address,
  }) async {
    final res = await _sendWithRetry(
      () => http.patch(
        Uri.parse('$_baseUrl/api/sites/$id/'),
        headers: _headers(),
        body: jsonEncode({
          'company': companyId,
          'name': name,
          'address': address,
        }),
      ),
    );
    if (res.statusCode == 200) {
      return SiteModel.fromJson(Map<String, dynamic>.from(_decode(res)));
    }
    throw Exception(_extractError(res));
  }

  static Future<void> deleteSite(int id) async {
    final res = await _sendWithRetry(
      () => http.delete(
        Uri.parse('$_baseUrl/api/sites/$id/'),
        headers: _headers(),
      ),
    );
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception(_extractError(res));
    }
  }

  // ==================== CATEGORIES & EQUIPMENT ====================

  static Future<List<CategoryModel>> getCategories() async {
    final res = await _sendWithRetry(
      () => http.get(
        Uri.parse('$_baseUrl/api/categories/'),
        headers: _headers(),
      ),
    );
    if (res.statusCode == 200) {
      final list = _decode(res) as List<dynamic>;
      return list
          .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    throw Exception(_extractError(res));
  }

  static Future<CategoryModel> createCategory({
    required String name,
    required String code,
    String systemType = 'hvac',
    String icon = 'bi-gear',
    String color = '#0d6efd',
  }) async {
    final res = await _sendWithRetry(
      () => http.post(
        Uri.parse('$_baseUrl/api/categories/'),
        headers: _headers(),
        body: jsonEncode({
          'name': name,
          'code': code.toUpperCase(),
          'system_type': systemType,
          'icon': icon,
          'color': color,
        }),
      ),
    );
    if (res.statusCode == 201 || res.statusCode == 200) {
      return CategoryModel.fromJson(Map<String, dynamic>.from(_decode(res)));
    }
    throw Exception(_extractError(res));
  }

  static Future<void> deleteCategory(int id) async {
    final res = await _sendWithRetry(
      () => http.delete(
        Uri.parse('$_baseUrl/api/categories/$id/'),
        headers: _headers(),
      ),
    );
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception(_extractError(res));
    }
  }

  static Future<List<EquipmentModel>> getEquipment({
    int? siteId,
    int? companyId,
    int? categoryId,
    String? status,
  }) async {
    final params = <String, String>{};
    if (siteId != null) params['site'] = siteId.toString();
    if (companyId != null) params['company'] = companyId.toString();
    if (categoryId != null) params['category'] = categoryId.toString();
    if (status != null && status.isNotEmpty) params['status'] = status;
    final uri = Uri.parse('$_baseUrl/api/equipment/').replace(
      queryParameters: params.isEmpty ? null : params,
    );
    final res = await _sendWithRetry(() => http.get(uri, headers: _headers()));
    if (res.statusCode == 200) {
      final list = _decode(res) as List<dynamic>;
      return list
          .map((e) => EquipmentModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    throw Exception(_extractError(res));
  }

  static Future<EquipmentModel> createEquipment(
    Map<String, dynamic> payload,
  ) async {
    final res = await _sendWithRetry(
      () => http.post(
        Uri.parse('$_baseUrl/api/equipment/'),
        headers: _headers(),
        body: jsonEncode(payload),
      ),
    );
    if (res.statusCode == 201 || res.statusCode == 200) {
      return EquipmentModel.fromJson(Map<String, dynamic>.from(_decode(res)));
    }
    throw Exception(_extractError(res));
  }

  static Future<EquipmentModel> updateEquipment(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final res = await _sendWithRetry(
      () => http.patch(
        Uri.parse('$_baseUrl/api/equipment/$id/'),
        headers: _headers(),
        body: jsonEncode(payload),
      ),
    );
    if (res.statusCode == 200) {
      return EquipmentModel.fromJson(Map<String, dynamic>.from(_decode(res)));
    }
    throw Exception(_extractError(res));
  }

  static Future<void> deleteEquipment(int id) async {
    final res = await _sendWithRetry(
      () => http.delete(
        Uri.parse('$_baseUrl/api/equipment/$id/'),
        headers: _headers(),
      ),
    );
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception(_extractError(res));
    }
  }

  // ==================== SCHEDULES ====================

  static Future<List<ScheduleModel>> getSchedules({int? equipmentId}) async {
    final query = equipmentId != null ? '?equipment=$equipmentId' : '';
    final res = await _sendWithRetry(
      () => http.get(
        Uri.parse('$_baseUrl/api/schedules/$query'),
        headers: _headers(),
      ),
    );
    if (res.statusCode == 200) {
      final list = _decode(res) as List<dynamic>;
      return list
          .map((e) => ScheduleModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    throw Exception(_extractError(res));
  }

  static Future<ScheduleModel> createSchedule({
    required int equipmentId,
    required String taskName,
    required String frequency,
  }) async {
    final res = await _sendWithRetry(
      () => http.post(
        Uri.parse('$_baseUrl/api/schedules/'),
        headers: _headers(),
        body: jsonEncode({
          'equipment': equipmentId,
          'task_name': taskName,
          'frequency': frequency,
        }),
      ),
    );
    if (res.statusCode == 201 || res.statusCode == 200) {
      return ScheduleModel.fromJson(Map<String, dynamic>.from(_decode(res)));
    }
    throw Exception(_extractError(res));
  }

  static Future<ScheduleModel> updateSchedule({
    required int id,
    required int equipmentId,
    required String taskName,
    required String frequency,
  }) async {
    final res = await _sendWithRetry(
      () => http.patch(
        Uri.parse('$_baseUrl/api/schedules/$id/'),
        headers: _headers(),
        body: jsonEncode({
          'equipment': equipmentId,
          'task_name': taskName,
          'frequency': frequency,
        }),
      ),
    );
    if (res.statusCode == 200) {
      return ScheduleModel.fromJson(Map<String, dynamic>.from(_decode(res)));
    }
    throw Exception(_extractError(res));
  }

  static Future<void> deleteSchedule(int id) async {
    final res = await _sendWithRetry(
      () => http.delete(
        Uri.parse('$_baseUrl/api/schedules/$id/'),
        headers: _headers(),
      ),
    );
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception(_extractError(res));
    }
  }

  // ==================== TASKS ====================

  static Future<List<TaskModel>> getTasks({
    String? status,
    int? inspectorId,
    int? companyId,
    int? equipmentId,
    String? search,
    String? dateFrom,
    String? dateTo,
  }) async {
    final params = <String, String>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (inspectorId != null) params['inspector'] = inspectorId.toString();
    if (companyId != null) params['company'] = companyId.toString();
    if (equipmentId != null) params['equipment'] = equipmentId.toString();
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (dateFrom != null && dateFrom.isNotEmpty) params['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) params['date_to'] = dateTo;

    final uri = Uri.parse('$_baseUrl/api/tasks/').replace(
      queryParameters: params.isEmpty ? null : params,
    );
    final res = await _sendWithRetry(() => http.get(uri, headers: _headers()));
    if (res.statusCode == 200) {
      final list = _decode(res) as List<dynamic>;
      return list
          .map((e) => TaskModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    throw Exception(_extractError(res));
  }

  static Future<TaskModel> getTask(int id) async {
    final res = await _sendWithRetry(
      () => http.get(Uri.parse('$_baseUrl/api/tasks/$id/'), headers: _headers()),
    );
    if (res.statusCode == 200) {
      return TaskModel.fromJson(Map<String, dynamic>.from(_decode(res)));
    }
    throw Exception(_extractError(res));
  }

  static Future<TaskModel> createTask({
    required int scheduleId,
    required int inspectorId,
    required String scheduledDate,
  }) async {
    final res = await _sendWithRetry(
      () => http.post(
        Uri.parse('$_baseUrl/api/tasks/'),
        headers: _headers(),
        body: jsonEncode({
          'schedule': scheduleId,
          'assigned_to': inspectorId,
          'scheduled_date': scheduledDate,
          'status': 'pending',
        }),
      ),
    );
    if (res.statusCode == 201 || res.statusCode == 200) {
      return TaskModel.fromJson(Map<String, dynamic>.from(_decode(res)));
    }
    throw Exception(_extractError(res));
  }

  static Future<TaskModel> updateTask(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final res = await _sendWithRetry(
      () => http.patch(
        Uri.parse('$_baseUrl/api/tasks/$id/'),
        headers: _headers(),
        body: jsonEncode(payload),
      ),
    );
    if (res.statusCode == 200) {
      return TaskModel.fromJson(Map<String, dynamic>.from(_decode(res)));
    }
    throw Exception(_extractError(res));
  }

  static Future<void> deleteTask(int id) async {
    final res = await _sendWithRetry(
      () => http.delete(
        Uri.parse('$_baseUrl/api/tasks/$id/'),
        headers: _headers(),
      ),
    );
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception(_extractError(res));
    }
  }

  static Future<int> generateTasks({int? inspectorId}) async {
    final res = await _sendWithRetry(
      () => http.post(
        Uri.parse('$_baseUrl/api/generate-tasks/'),
        headers: _headers(),
        body: jsonEncode({
          'inspector': ?inspectorId,
        }),
      ),
    );
    if (res.statusCode == 200) {
      final data = _decode(res);
      return data['created_count'] ?? 0;
    }
    throw Exception(_extractError(res));
  }

  static Future<TaskModel> completeOrSaveTask({
    required int taskId,
    required String comment,
    required String action, // 'save' or 'complete'
    List<PickedPhotoFile> photos = const [],
  }) async {
    Future<http.Response> sendMultipart() async {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/tasks/$taskId/complete/'),
      );
      if (_accessToken != null && _accessToken!.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer $_accessToken';
      }
      req.fields['comment'] = comment;
      req.fields['action'] = action;
      for (final p in photos) {
        req.files.add(
          http.MultipartFile.fromBytes(
            'photos',
            p.bytes,
            filename: p.name,
          ),
        );
      }
      final streamed = await req.send();
      return http.Response.fromStream(streamed);
    }

    final res = await _sendWithRetry(sendMultipart);
    if (res.statusCode == 200) {
      return TaskModel.fromJson(Map<String, dynamic>.from(_decode(res)));
    }
    throw Exception(_extractError(res));
  }

  static Future<void> deleteTaskPhoto({
    required int taskId,
    required int photoId,
  }) async {
    final res = await _sendWithRetry(
      () => http.delete(
        Uri.parse('$_baseUrl/api/tasks/$taskId/photos/$photoId/'),
        headers: _headers(),
      ),
    );
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception(_extractError(res));
    }
  }

  static Future<TaskModel> approveTask(int taskId) async {
    final res = await _sendWithRetry(
      () => http.post(
        Uri.parse('$_baseUrl/api/tasks/$taskId/approve/'),
        headers: _headers(),
      ),
    );
    if (res.statusCode == 200) {
      return TaskModel.fromJson(Map<String, dynamic>.from(_decode(res)));
    }
    throw Exception(_extractError(res));
  }

  static Future<TaskModel> rejectTask(int taskId, String reason) async {
    final res = await _sendWithRetry(
      () => http.post(
        Uri.parse('$_baseUrl/api/tasks/$taskId/reject/'),
        headers: _headers(),
        body: jsonEncode({'reason': reason}),
      ),
    );
    if (res.statusCode == 200) {
      return TaskModel.fromJson(Map<String, dynamic>.from(_decode(res)));
    }
    throw Exception(_extractError(res));
  }

  // ==================== USERS ====================

  static Future<List<AppUser>> getUsers({String? role}) async {
    final query = role != null ? '?role=$role' : '';
    final res = await _sendWithRetry(
      () => http.get(
        Uri.parse('$_baseUrl/api/users/$query'),
        headers: _headers(),
      ),
    );
    if (res.statusCode == 200) {
      final list = _decode(res) as List<dynamic>;
      return list
          .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    throw Exception(_extractError(res));
  }

  static Future<AppUser> createUser(Map<String, dynamic> payload) async {
    final res = await _sendWithRetry(
      () => http.post(
        Uri.parse('$_baseUrl/api/users/'),
        headers: _headers(),
        body: jsonEncode(payload),
      ),
    );
    if (res.statusCode == 201 || res.statusCode == 200) {
      return AppUser.fromJson(Map<String, dynamic>.from(_decode(res)));
    }
    throw Exception(_extractError(res));
  }

  static Future<AppUser> updateUser(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final res = await _sendWithRetry(
      () => http.patch(
        Uri.parse('$_baseUrl/api/users/$id/'),
        headers: _headers(),
        body: jsonEncode(payload),
      ),
    );
    if (res.statusCode == 200) {
      return AppUser.fromJson(Map<String, dynamic>.from(_decode(res)));
    }
    throw Exception(_extractError(res));
  }

  static Future<void> deleteUser(int id) async {
    final res = await _sendWithRetry(
      () => http.delete(
        Uri.parse('$_baseUrl/api/users/$id/'),
        headers: _headers(),
      ),
    );
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception(_extractError(res));
    }
  }

  // ==================== NOTIFICATIONS ====================

  static Future<Map<String, dynamic>> getNotifications() async {
    final res = await _sendWithRetry(
      () => http.get(
        Uri.parse('$_baseUrl/api/notifications/'),
        headers: _headers(),
      ),
    );
    if (res.statusCode == 200) {
      final data = Map<String, dynamic>.from(_decode(res));
      final list = (data['notifications'] as List<dynamic>? ?? [])
          .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return {
        'unread_count': data['unread_count'] ?? 0,
        'notifications': list,
      };
    }
    throw Exception(_extractError(res));
  }

  static Future<void> markNotificationRead(int id) async {
    await _sendWithRetry(
      () => http.post(
        Uri.parse('$_baseUrl/api/notifications/$id/read/'),
        headers: _headers(),
      ),
    );
  }

  static Future<void> markAllNotificationsRead() async {
    await _sendWithRetry(
      () => http.post(
        Uri.parse('$_baseUrl/api/notifications/read-all/'),
        headers: _headers(),
      ),
    );
  }

  static Future<void> deleteNotification(int id) async {
    await _sendWithRetry(
      () => http.post(
        Uri.parse('$_baseUrl/api/notifications/$id/delete/'),
        headers: _headers(),
      ),
    );
  }

  // ==================== REPORTS JSON ====================

  static Future<Map<String, dynamic>> getMonthlyReportJson() async {
    final res = await _sendWithRetry(
      () => http.get(
        Uri.parse('$_baseUrl/reports/monthly/?format=json'),
        headers: _headers(),
      ),
    );
    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(_decode(res));
    }
    throw Exception(_extractError(res));
  }

  static Future<Map<String, dynamic>> getEquipmentHistoryJson(
    int equipmentId,
  ) async {
    final res = await _sendWithRetry(
      () => http.get(
        Uri.parse('$_baseUrl/reports/equipment/$equipmentId/?format=json'),
        headers: _headers(),
      ),
    );
    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(_decode(res));
    }
    throw Exception(_extractError(res));
  }
}

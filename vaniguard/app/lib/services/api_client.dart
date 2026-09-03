/// PURPOSE: Centralized HTTP and WebSocket client for VaniGuard backend communication.
/// ROLE IN SYSTEM: Manages API base URL, JWT token auth, REST calls, and WS connections.
/// TALKS TO: server/app/main.py, server/app/api/v1/
import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  // Default to localhost; override via settings for real device testing
  static String _baseUrl = 'http://10.0.2.2:8000';
  static String? _authToken;
  static Dio? _dio;

  static void configure({required String baseUrl, String? token}) {
    _baseUrl = baseUrl;
    _authToken = token;
    _dio = null; // Reset to pick up new config
  }

  static void setToken(String token) {
    _authToken = token;
    _dio = null;
  }

  static Dio get dio {
    _dio ??= Dio(BaseOptions(
      baseUrl: '$_baseUrl/api/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      },
    ))
      ..interceptors.add(InterceptorsWrapper(
        onError: (error, handler) {
          // Calm retry message instead of raw stack trace
          if (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout) {
            error = error.copyWith(
              message: 'Connection timed out. Please check your network and try again.',
            );
          }
          handler.next(error);
        },
      ));
    return _dio!;
  }

  // ---- Health ----
  static Future<Map<String, dynamic>> healthCheck() async {
    final resp = await dio.get('/health');
    return resp.data as Map<String, dynamic>;
  }

  // ---- Auth ----
  static Future<Map<String, dynamic>> sessionExchange({
    required String phone,
    String? password,
    String language = 'hi',
  }) async {
    final resp = await dio.post('/auth/session', data: {
      'phone': phone,
      if (password != null) 'password': password,
      'preferred_language': language,
    });
    final data = resp.data as Map<String, dynamic>;
    if (data.containsKey('token')) {
      setToken(data['token'] as String);
    }
    return data;
  }

  static Future<void> logout() async {
    try {
      await dio.post('/auth/logout');
    } catch (_) {}
    _authToken = null;
    _dio = null;
  }

  // ---- Voice Enrollment ----
  static Future<Map<String, dynamic>> voiceEnroll({
    required List<List<int>> phrasePcmChunks,
    String? userId,
  }) async {
    final resp = await dio.post('/onboarding/voice-enroll', data: {
      'phrases': phrasePcmChunks.map((chunk) => base64Encode(chunk)).toList(),
      if (userId != null) 'user_id': userId,
    });
    return resp.data as Map<String, dynamic>;
  }

  // ---- Transfers ----
  static Future<Map<String, dynamic>> initiateTransfer({
    required String sourceAccountId,
    required String payeeId,
    required int amountPaise,
    required String idempotencyKey,
    String? transcript,
    bool? secondVoiceDetected,
    int? voiceStressScore,
  }) async {
    final resp = await dio.post(
      '/transfers',
      data: {
        'source_account_id': sourceAccountId,
        'payee_id': payeeId,
        'amount_paise': amountPaise,
        if (transcript != null) 'transcript': transcript,
        if (secondVoiceDetected != null) 'second_voice_detected': secondVoiceDetected,
        if (voiceStressScore != null) 'voice_stress_score': voiceStressScore,
      },
      options: Options(headers: {
        'X-Idempotency-Key': idempotencyKey,
      }),
    );
    return resp.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> cancelTransfer(String transferId) async {
    final resp = await dio.post('/transfers/$transferId/cancel');
    return resp.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getTransfer(String transferId) async {
    final resp = await dio.get('/transfers/$transferId');
    return resp.data as Map<String, dynamic>;
  }

  // ---- Trusted Contact ----
  static Future<List<dynamic>> getTcPending({String? tcUserId}) async {
    final resp = await dio.get('/tc/pending', queryParameters: {
      if (tcUserId != null) 'tc_user_id': tcUserId,
    });
    return resp.data as List<dynamic>;
  }

  static Future<Map<String, dynamic>> tcApprove({
    required String transferId,
    required bool attestation,
    String? note,
    String? reasonCategory,
    String? tcUserId,
  }) async {
    final resp = await dio.post(
      '/tc/transfers/$transferId/approve',
      data: {
        'attestation': attestation,
        if (note != null) 'note': note,
        if (reasonCategory != null) 'reason_category': reasonCategory,
      },
      queryParameters: {
        if (tcUserId != null) 'tc_user_id': tcUserId,
      },
    );
    return resp.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> tcDeny({
    required String transferId,
    required bool attestation,
    String? note,
    String? reasonCategory,
    String? tcUserId,
  }) async {
    final resp = await dio.post(
      '/tc/transfers/$transferId/deny',
      data: {
        'attestation': attestation,
        if (note != null) 'note': note,
        if (reasonCategory != null) 'reason_category': reasonCategory,
      },
      queryParameters: {
        if (tcUserId != null) 'tc_user_id': tcUserId,
      },
    );
    return resp.data as Map<String, dynamic>;
  }

  // ---- Accounts ----
  static Future<List<dynamic>> getAccounts() async {
    final resp = await dio.get('/accounts');
    return resp.data as List<dynamic>;
  }

  // ---- Guardian Mode ----
  static Future<Map<String, dynamic>> getGuardianStatus(String accountHolderId) async {
    final resp = await dio.get('/guardian/status', queryParameters: {
      'account_holder_id': accountHolderId,
    });
    return resp.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateCoolingWindow({
    required String accountHolderId,
    required int coolingWindowMinutes,
  }) async {
    final resp = await dio.patch('/guardian/cooling-window', data: {
      'account_holder_id': accountHolderId,
      'cooling_window_minutes': coolingWindowMinutes,
    });
    return resp.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> addAlwaysAllowPayee({
    required String accountHolderId,
    required String payeeId,
  }) async {
    final resp = await dio.post('/guardian/always-allow-payees', data: {
      'account_holder_id': accountHolderId,
      'payee_id': payeeId,
    });
    return resp.data as Map<String, dynamic>;
  }

  // ---- WebSocket Voice Session ----
  static WebSocketChannel connectVoiceSession() {
    final wsUrl = _baseUrl.replaceFirst('http', 'ws');
    final uri = Uri.parse('$wsUrl/ws/voice-session');
    return WebSocketChannel.connect(
      uri,
      protocols: _authToken != null ? ['Bearer', _authToken!] : null,
    );
  }

  // ---- WebSocket Push Events ----
  static WebSocketChannel connectEvents({String? userId}) {
    final wsUrl = _baseUrl.replaceFirst('http', 'ws');
    final query = userId != null ? '?user_id=$userId' : '';
    final uri = Uri.parse('$wsUrl/ws/events$query');
    return WebSocketChannel.connect(
      uri,
      protocols: _authToken != null ? ['Bearer', _authToken!] : null,
    );
  }

  // ---- Persistence ----
  static Future<void> saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', _baseUrl);
    if (_authToken != null) {
      await prefs.setString('auth_token', _authToken!);
    }
  }

  static Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('api_base_url');
    if (savedUrl != null) {
      _baseUrl = savedUrl;
    }
    _authToken = prefs.getString('auth_token');
  }

  static String get baseUrl => _baseUrl;
  static String? get authToken => _authToken;
}

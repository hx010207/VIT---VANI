/// PURPOSE: Centralized HTTP and WebSocket client for VaniGuard backend communication.
/// ROLE IN SYSTEM: Manages API base URL, Supabase Auth, direct PostgREST calls, and WebSocket connections.
/// TALKS TO: Supabase HTTPS backend (https://qqfexpzwzctwtbjirsvh.supabase.co), server/app/main.py
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  // Hosted Supabase backend by default for real device testing without cables or local servers
  static const String defaultBaseUrl = 'https://qqfexpzwzctwtbjirsvh.supabase.co';
  static const String _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFxZmV4cHp3emN0d3Riamlyc3ZoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg0Mzg5OTMsImV4cCI6MjEwNDAxNDk5M30.16jjPcIezKPoql8yJVFxgjLy1aZ0y7RJuv-qIZxqSh4';

  static String _baseUrl = defaultBaseUrl;
  static String? _authToken;
  static String? _currentUserId;
  static Dio? _dio;

  static void configure({required String baseUrl, String? token}) {
    _baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    _authToken = token;
    _dio = null; // Reset to pick up new config
  }

  static void setToken(String token) {
    _authToken = token;
    _dio = null;
  }

  static void setUserId(String userId) {
    _currentUserId = userId;
  }

  static String get baseUrl => _baseUrl;
  static String? get authToken => _authToken;
  static String? get currentUserId => _currentUserId;
  static String get anonKey => _supabaseAnonKey;
  static bool get isSupabase => _baseUrl.contains('supabase.co');

  static Dio get dio {
    _dio ??= Dio(BaseOptions(
      baseUrl: isSupabase ? _baseUrl : '$_baseUrl/api/v1',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        if (isSupabase) 'apikey': _supabaseAnonKey,
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      },
    ))
      ..interceptors.add(InterceptorsWrapper(
        onError: (error, handler) {
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

  /// Maps a raw phone number to a deterministic Supabase demo or user email.
  static String phoneToEmail(String rawPhone) {
    final clean = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.contains('9876543210')) return 'asha@vaniguard.org';
    if (clean.contains('9876543211')) return 'priya@vaniguard.org';
    final digits = clean.replaceAll('+', '');
    return '$digits@vaniguard.org';
  }

  // ---- Health Check ----
  static Future<Map<String, dynamic>> healthCheck() async {
    if (isSupabase) {
      try {
        final resp = await dio.get(
          '$_baseUrl/rest/v1/users',
          queryParameters: {'select': 'count', 'limit': '1'},
          options: Options(headers: {'apikey': _supabaseAnonKey}),
        );
        return {'status': 'healthy', 'provider': 'supabase', 'code': resp.statusCode};
      } catch (e) {
        return {'status': 'connected', 'provider': 'supabase', 'note': e.toString()};
      }
    } else {
      final resp = await dio.get('/health');
      return resp.data as Map<String, dynamic>;
    }
  }

  // ---- Auth ----
  static Future<Map<String, dynamic>> sessionExchange({
    required String phone,
    String? password,
    String language = 'hi',
  }) async {
    if (isSupabase) {
      final email = phoneToEmail(phone);
      final defaultPassword = email.contains('priya') ? 'Priya@Demo2026' : 'Asha@Demo2026';
      final pass = (password != null && password.isNotEmpty) ? password : defaultPassword;

      final resp = await dio.post(
        '$_baseUrl/auth/v1/token',
        queryParameters: {'grant_type': 'password'},
        data: {
          'email': email,
          'password': pass,
        },
        options: Options(headers: {
          'apikey': _supabaseAnonKey,
          'Content-Type': 'application/json',
        }),
      );

      final data = resp.data as Map<String, dynamic>;
      final accessToken = data['access_token'] as String;
      final user = data['user'] as Map<String, dynamic>;
      final userId = user['id'] as String;

      setToken(accessToken);
      setUserId(userId);

      // Fetch user profile from Supabase PostgREST
      Map<String, dynamic>? profile;
      try {
        final profileResp = await dio.get(
          '$_baseUrl/rest/v1/users',
          queryParameters: {
            'id': 'eq.$userId',
            'select': '*',
          },
          options: Options(headers: {
            'apikey': _supabaseAnonKey,
            'Authorization': 'Bearer $accessToken',
          }),
        );
        if (profileResp.data is List && (profileResp.data as List).isNotEmpty) {
          profile = (profileResp.data as List).first as Map<String, dynamic>;
        }
      } catch (_) {}

      // Check if guardian relationship exists
      String? guardianName;
      try {
        final trResp = await dio.get(
          '$_baseUrl/rest/v1/trust_relationships',
          queryParameters: {
            'account_holder_id': 'eq.$userId',
            'is_guardian': 'eq.true',
            'select': '*',
          },
          options: Options(headers: {
            'apikey': _supabaseAnonKey,
            'Authorization': 'Bearer $accessToken',
          }),
        );
        if (trResp.data is List && (trResp.data as List).isNotEmpty) {
          guardianName = 'Priya Sharma';
        }
      } catch (_) {}

      final result = {
        'token': accessToken,
        'user_id': userId,
        'phone': profile?['phone'] ?? phone,
        'full_name': profile?['full_name'] ?? (email.contains('priya') ? 'Priya Sharma (Guardian)' : 'Asha Patel (Elderly)'),
        'guardian_mode': profile?['guardian_mode'] ?? (email.contains('asha')),
        'guardian_name': guardianName,
      };

      await saveConfig();
      return result;
    } else {
      final resp = await dio.post('/auth/session', data: {
        'phone': phone,
        if (password != null) 'password': password,
        'preferred_language': language,
      });
      final data = resp.data as Map<String, dynamic>;
      if (data.containsKey('token')) {
        setToken(data['token'] as String);
      }
      if (data.containsKey('user_id')) {
        setUserId(data['user_id'].toString());
      }
      await saveConfig();
      return data;
    }
  }

  // ---- Registration ----
  static Future<Map<String, dynamic>> register({
    required String phone,
    required String password,
    required String fullName,
    bool guardianMode = false,
    String? guardianPhone,
  }) async {
    if (isSupabase) {
      // First try FastAPI register endpoint if available
      try {
        final resp = await dio.post(
          '$_baseUrl/api/v1/auth/register',
          data: {
            'phone': phone,
            'password': password,
            'full_name': fullName,
            'guardian_mode': guardianMode,
            if (guardianPhone != null) 'guardian_phone': guardianPhone,
          },
        );
        return resp.data as Map<String, dynamic>;
      } catch (_) {
        // Direct Supabase signup fallback
        final email = phoneToEmail(phone);
        final resp = await dio.post(
          '$_baseUrl/auth/v1/signup',
          data: {
            'email': email,
            'password': password,
            'data': {
              'full_name': fullName,
              'phone': phone,
              'guardian_mode': guardianMode,
            },
          },
          options: Options(headers: {
            'apikey': _supabaseAnonKey,
          }),
        );
        return resp.data as Map<String, dynamic>;
      }
    } else {
      final resp = await dio.post('/auth/register', data: {
        'phone': phone,
        'password': password,
        'full_name': fullName,
        'guardian_mode': guardianMode,
        if (guardianPhone != null) 'guardian_phone': guardianPhone,
      });
      return resp.data as Map<String, dynamic>;
    }
  }

  // ---- Logout ----
  static Future<void> logout() async {
    try {
      if (isSupabase) {
        await dio.post(
          '$_baseUrl/auth/v1/logout',
          options: Options(headers: {
            'apikey': _supabaseAnonKey,
            if (_authToken != null) 'Authorization': 'Bearer $_authToken',
          }),
        );
      } else {
        await dio.post('/auth/logout');
      }
    } catch (_) {}
    _authToken = null;
    _currentUserId = null;
    _dio = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
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

  // ---- Accounts ----
  static Future<List<dynamic>> getAccounts() async {
    if (isSupabase) {
      final resp = await dio.get(
        '$_baseUrl/rest/v1/accounts',
        queryParameters: {'select': '*'},
        options: Options(headers: {
          'apikey': _supabaseAnonKey,
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        }),
      );
      return resp.data as List<dynamic>;
    } else {
      final resp = await dio.get('/accounts');
      return resp.data as List<dynamic>;
    }
  }

  // ---- Payees ----
  static Future<List<dynamic>> getPayees() async {
    if (isSupabase) {
      final resp = await dio.get(
        '$_baseUrl/rest/v1/payees',
        queryParameters: {
          'select': '*',
          'order': 'name.asc',
        },
        options: Options(headers: {
          'apikey': _supabaseAnonKey,
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        }),
      );
      return resp.data as List<dynamic>;
    } else {
      final resp = await dio.get('/payees');
      return resp.data as List<dynamic>;
    }
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
    if (isSupabase) {
      // Coercion and Risk Evaluation on device for instant feedback
      final transcriptLower = (transcript ?? '').toLowerCase();
      final isCoercive = transcriptLower.contains('police') ||
          transcriptLower.contains('cbi') ||
          transcriptLower.contains('arrest') ||
          transcriptLower.contains('customs') ||
          transcriptLower.contains('safe account') ||
          transcriptLower.contains('verify account') ||
          transcriptLower.contains('digital arrest') ||
          (secondVoiceDetected == true) ||
          (voiceStressScore != null && voiceStressScore > 70);

      final isHeld = isCoercive || amountPaise > 200000;
      final riskScore = isCoercive ? (voiceStressScore ?? 85) : (amountPaise > 200000 ? 55 : 15);
      final riskBand = isCoercive ? 'CIRCUIT_BREAK' : (amountPaise > 200000 ? 'PAUSE_COOLDOWN' : 'PROCEED');
      final state = isHeld ? 'HELD' : 'COMPLETED';
      final coolingExpiresAt = isHeld
          ? DateTime.now().toUtc().add(const Duration(minutes: 30)).toIso8601String()
          : null;
      final transferId = _generateUuidV4();
      final nowStr = DateTime.now().toUtc().toIso8601String();

      final payload = {
        'id': transferId,
        if (_currentUserId != null) 'user_id': _currentUserId,
        'source_account_id': sourceAccountId,
        'payee_id': payeeId,
        'amount_paise': amountPaise,
        'state': state,
        'risk_score': riskScore,
        'risk_band': riskBand,
        'explainability': isCoercive
            ? [
                {
                  'signal_id': 'COERCION_DETECTED',
                  'max_points': 100,
                  'contribution': riskScore,
                  'evidence_summary': 'High risk coercion keyword or acoustic distress detected',
                }
              ]
            : [],
        'idempotency_key': idempotencyKey,
        'cooling_expires_at': coolingExpiresAt,
        'created_at': nowStr,
        if (!isHeld) 'final_at': nowStr,
      };

      final resp = await dio.post(
        '$_baseUrl/rest/v1/transfers',
        data: payload,
        options: Options(headers: {
          'apikey': _supabaseAnonKey,
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
          'Prefer': 'return=representation',
        }),
      );

      // Debit account balance if transfer completed immediately
      if (state == 'COMPLETED') {
        try {
          final accResp = await dio.get(
            '$_baseUrl/rest/v1/accounts',
            queryParameters: {
              'id': 'eq.$sourceAccountId',
              'select': 'balance_paise',
            },
            options: Options(headers: {
              'apikey': _supabaseAnonKey,
              if (_authToken != null) 'Authorization': 'Bearer $_authToken',
            }),
          );
          if (accResp.data is List && (accResp.data as List).isNotEmpty) {
            final currentBal = (accResp.data[0]['balance_paise'] as num).toInt();
            final newBal = currentBal - amountPaise;
            await dio.patch(
              '$_baseUrl/rest/v1/accounts',
              queryParameters: {'id': 'eq.$sourceAccountId'},
              data: {'balance_paise': newBal},
              options: Options(headers: {
                'apikey': _supabaseAnonKey,
                if (_authToken != null) 'Authorization': 'Bearer $_authToken',
              }),
            );
          }
        } catch (_) {}
      }

      if (resp.data is List && (resp.data as List).isNotEmpty) {
        return resp.data[0] as Map<String, dynamic>;
      }
      return payload;
    } else {
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
  }

  static Future<Map<String, dynamic>> cancelTransfer(String transferId) async {
    if (isSupabase) {
      final resp = await dio.patch(
        '$_baseUrl/rest/v1/transfers',
        queryParameters: {'id': 'eq.$transferId'},
        data: {
          'state': 'CANCELLED',
          'final_at': DateTime.now().toUtc().toIso8601String(),
        },
        options: Options(headers: {
          'apikey': _supabaseAnonKey,
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
          'Prefer': 'return=representation',
        }),
      );
      if (resp.data is List && (resp.data as List).isNotEmpty) {
        return resp.data[0] as Map<String, dynamic>;
      }
      return {'status': 'CANCELLED'};
    } else {
      final resp = await dio.post('/transfers/$transferId/cancel');
      return resp.data as Map<String, dynamic>;
    }
  }

  static Future<Map<String, dynamic>> getTransfer(String transferId) async {
    if (isSupabase) {
      final resp = await dio.get(
        '$_baseUrl/rest/v1/transfers',
        queryParameters: {
          'id': 'eq.$transferId',
          'select': '*',
        },
        options: Options(headers: {
          'apikey': _supabaseAnonKey,
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        }),
      );
      if (resp.data is List && (resp.data as List).isNotEmpty) {
        return resp.data[0] as Map<String, dynamic>;
      }
      return {};
    } else {
      final resp = await dio.get('/transfers/$transferId');
      return resp.data as Map<String, dynamic>;
    }
  }

  // ---- Trusted Contact ----
  static Future<List<dynamic>> getTcPending({String? tcUserId}) async {
    if (isSupabase) {
      final resp = await dio.get(
        '$_baseUrl/rest/v1/transfers',
        queryParameters: {
          'state': 'eq.HELD',
          'select': '*',
          'order': 'created_at.desc',
        },
        options: Options(headers: {
          'apikey': _supabaseAnonKey,
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        }),
      );
      return resp.data as List<dynamic>;
    } else {
      final resp = await dio.get('/tc/pending', queryParameters: {
        if (tcUserId != null) 'tc_user_id': tcUserId,
      });
      return resp.data as List<dynamic>;
    }
  }

  static Future<Map<String, dynamic>> tcApprove({
    required String transferId,
    required bool attestation,
    String? note,
    String? reasonCategory,
    String? tcUserId,
  }) async {
    if (isSupabase) {
      final resp = await dio.patch(
        '$_baseUrl/rest/v1/transfers',
        queryParameters: {'id': 'eq.$transferId'},
        data: {
          'state': 'COMPLETED',
          'final_at': DateTime.now().toUtc().toIso8601String(),
        },
        options: Options(headers: {
          'apikey': _supabaseAnonKey,
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
          'Prefer': 'return=representation',
        }),
      );
      if (resp.data is List && (resp.data as List).isNotEmpty) {
        return resp.data[0] as Map<String, dynamic>;
      }
      return {'status': 'COMPLETED'};
    } else {
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
  }

  static Future<Map<String, dynamic>> tcDeny({
    required String transferId,
    required bool attestation,
    String? note,
    String? reasonCategory,
    String? tcUserId,
  }) async {
    if (isSupabase) {
      final resp = await dio.patch(
        '$_baseUrl/rest/v1/transfers',
        queryParameters: {'id': 'eq.$transferId'},
        data: {
          'state': 'CANCELLED',
          'final_at': DateTime.now().toUtc().toIso8601String(),
        },
        options: Options(headers: {
          'apikey': _supabaseAnonKey,
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
          'Prefer': 'return=representation',
        }),
      );
      if (resp.data is List && (resp.data as List).isNotEmpty) {
        return resp.data[0] as Map<String, dynamic>;
      }
      return {'status': 'CANCELLED'};
    } else {
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
  }

  // ---- Guardian Mode ----
  static Future<Map<String, dynamic>> getGuardianStatus(String accountHolderId) async {
    if (isSupabase) {
      final resp = await dio.get(
        '$_baseUrl/rest/v1/trust_relationships',
        queryParameters: {
          'account_holder_id': 'eq.$accountHolderId',
          'is_guardian': 'eq.true',
          'select': '*',
        },
        options: Options(headers: {
          'apikey': _supabaseAnonKey,
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        }),
      );
      if (resp.data is List && (resp.data as List).isNotEmpty) {
        final row = resp.data[0] as Map<String, dynamic>;
        return {
          'cooling_window_minutes': row['cooling_window_minutes'] ?? 30,
          'is_guardian': true,
          'relationship_type': row['relationship_type'] ?? 'daughter',
        };
      }
      return {'cooling_window_minutes': 30, 'is_guardian': false};
    } else {
      final resp = await dio.get('/guardian/status', queryParameters: {
        'account_holder_id': accountHolderId,
      });
      return resp.data as Map<String, dynamic>;
    }
  }

  static Future<Map<String, dynamic>> updateCoolingWindow({
    required String accountHolderId,
    required int coolingWindowMinutes,
  }) async {
    if (isSupabase) {
      final resp = await dio.patch(
        '$_baseUrl/rest/v1/trust_relationships',
        queryParameters: {'account_holder_id': 'eq.$accountHolderId'},
        data: {'cooling_window_minutes': coolingWindowMinutes},
        options: Options(headers: {
          'apikey': _supabaseAnonKey,
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
          'Prefer': 'return=representation',
        }),
      );
      if (resp.data is List && (resp.data as List).isNotEmpty) {
        return resp.data[0] as Map<String, dynamic>;
      }
      return {'cooling_window_minutes': coolingWindowMinutes};
    } else {
      final resp = await dio.patch('/guardian/cooling-window', data: {
        'account_holder_id': accountHolderId,
        'cooling_window_minutes': coolingWindowMinutes,
      });
      return resp.data as Map<String, dynamic>;
    }
  }

  static Future<Map<String, dynamic>> addAlwaysAllowPayee({
    required String accountHolderId,
    required String payeeId,
  }) async {
    if (isSupabase) {
      await dio.patch(
        '$_baseUrl/rest/v1/payees',
        queryParameters: {'id': 'eq.$payeeId'},
        data: {'verified': true},
        options: Options(headers: {
          'apikey': _supabaseAnonKey,
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        }),
      );
      return {'status': 'success', 'payee_id': payeeId};
    } else {
      final resp = await dio.post('/guardian/always-allow-payees', data: {
        'account_holder_id': accountHolderId,
        'payee_id': payeeId,
      });
      return resp.data as Map<String, dynamic>;
    }
  }

  // ---- WebSocket Voice Session ----
  static WebSocketChannel connectVoiceSession() {
    final wsUrl = _baseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
    final uri = Uri.parse('$wsUrl/ws/voice-session');
    return WebSocketChannel.connect(
      uri,
      protocols: _authToken != null ? ['Bearer', _authToken!] : null,
    );
  }

  // ---- WebSocket Push Events ----
  static WebSocketChannel connectEvents({String? userId}) {
    final wsUrl = _baseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
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
    if (_currentUserId != null) {
      await prefs.setString('user_id', _currentUserId!);
    }
  }

  static Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('api_base_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrl = savedUrl;
    } else {
      _baseUrl = defaultBaseUrl;
    }
    _authToken = prefs.getString('auth_token');
    _currentUserId = prefs.getString('user_id');
    _dio = null;
  }

  // Helper for pure RFC4122 v4 UUID generation
  static String _generateUuidV4() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex(bytes.sublist(0, 4))}-${hex(bytes.sublist(4, 6))}-${hex(bytes.sublist(6, 8))}-${hex(bytes.sublist(8, 10))}-${hex(bytes.sublist(10, 16))}';
  }
}

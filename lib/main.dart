import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MatjariApp());
}

const _brandBlue = Color(0xFF1769D2);
const _softBlue = Color(0xFFE8F2FF);
const _ink = Color(0xFF202124);
const _muted = Color(0xFF5F6368);
const _line = Color(0xFFE0E3E7);
const _surface = Color(0xFFF7F9FC);
const _appVersionName = '1.1.2';
const _appBuildNumber = 4;
const _whatsAppOtpEndpoint =
    'https://whatsapp-server1-production-72d1.up.railway.app/api/whatsapp/send-message';
const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://matjari-api.onrender.com',
);
const _nativeChannel = MethodChannel('matjari/native');

class MatjariApp extends StatelessWidget {
  const MatjariApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Matjari',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _brandBlue,
          primary: _brandBlue,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: _ink,
          displayColor: _ink,
          fontFamily: 'Roboto',
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: _surface,
          indicatorColor: Color(0xFFCDEBFF),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.white,
          selectedColor: const Color(0xFFCDEBFF),
          side: const BorderSide(color: _line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      home: const MatjariShell(),
    );
  }
}

class StoreItem {
  const StoreItem({
    this.id = '',
    required this.name,
    required this.category,
    required this.summary,
    required this.rating,
    required this.icon,
    required this.color,
    required this.type,
    this.installed = false,
    this.updateAvailable = false,
    this.price,
    this.size = '48 MB',
    this.version = '1.0.0',
    this.versionCode = 1,
    this.downloads = '10K+',
    this.packageName = '',
    this.platform = 'android',
    this.iconUrl,
    this.fileUrl,
    this.screenshotUrls = const [],
    this.forceUpdate = false,
    this.updatedOn = 'Today',
    this.releasedOn = '2026-01-01',
    this.offeredBy = 'Matjari',
  });

  factory StoreItem.fromApi(Map<String, dynamic> json) {
    final category = json['category'] is Map<String, dynamic>
        ? json['category'] as Map<String, dynamic>
        : <String, dynamic>{};
    final categoryName =
        _stringValue(category['name']) ??
        _stringValue(json['category']) ??
        'Apps';
    final type = _stringValue(category['type']) ?? 'apps';
    final name = _stringValue(json['name']) ?? 'Untitled app';
    final packageName = _stringValue(json['package_name']) ?? '';
    final rating = _doubleValue(json['rating']) ?? _ratingForName(name);

    return StoreItem(
      id: _stringValue(json['id']) ?? packageName.ifEmpty(name),
      name: name,
      category: categoryName,
      summary: _stringValue(json['description']) ?? 'No description yet.',
      rating: rating,
      icon: _iconFor(type, categoryName, name),
      color: _colorFor(categoryName, name),
      type: type,
      size: _stringValue(json['size']) ?? 'Unknown',
      version: _stringValue(json['version_name']) ?? '1.0.0',
      versionCode: _intValue(json['version_code']) ?? 1,
      downloads: _downloadLabel(_intValue(json['downloads_count']) ?? 0),
      packageName: packageName,
      platform: _stringValue(json['platform']) ?? 'android',
      iconUrl: _absoluteApiUrl(_stringValue(json['icon_url'])),
      fileUrl: _absoluteApiUrl(
        _stringValue(json['file_url']) ?? _stringValue(json['apk_file_url']),
      ),
      screenshotUrls: _screenshotUrls(json['screenshots']),
      forceUpdate: json['is_force_update'] == true,
      updateAvailable: json['is_force_update'] == true,
      updatedOn: _dateLabel(_stringValue(json['updated_at'])),
      releasedOn: _dateLabel(_stringValue(json['created_at'])),
      offeredBy: _offeredBy(packageName),
    );
  }

  final String id;
  final String name;
  final String category;
  final String summary;
  final double rating;
  final IconData icon;
  final Color color;
  final String type;
  final bool installed;
  final bool updateAvailable;
  final String? price;
  final String size;
  final String version;
  final int versionCode;
  final String downloads;
  final String packageName;
  final String platform;
  final String? iconUrl;
  final String? fileUrl;
  final List<String> screenshotUrls;
  final bool forceUpdate;
  final String updatedOn;
  final String releasedOn;
  final String offeredBy;
}

List<String> _screenshotUrls(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map<String, dynamic>>()
      .map((item) => _stringValue(item['image_url']))
      .map(_absoluteApiUrl)
      .whereType<String>()
      .toList();
}

class InstalledPackageMatch {
  const InstalledPackageMatch({
    required this.packageName,
    required this.versionCode,
  });

  final String packageName;
  final int versionCode;
}

class AdminUploadFile {
  const AdminUploadFile({
    required this.url,
    this.sizeBytes,
    this.packageName,
    this.versionCode,
    this.versionName,
  });

  final String url;
  final int? sizeBytes;
  final String? packageName;
  final int? versionCode;
  final String? versionName;

  String? get displaySize {
    final bytes = sizeBytes;
    if (bytes == null || bytes <= 0) return null;
    final mb = bytes / (1024 * 1024);
    if (mb >= 10) return '${mb.round()} MB';
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class RegisterFormData {
  const RegisterFormData({
    required this.email,
    required this.username,
    required this.phoneNumber,
    required this.fullName,
    required this.password,
    required this.avatarUrl,
  });

  final String email;
  final String username;
  final String phoneNumber;
  final String fullName;
  final String password;
  final String avatarUrl;
}

class GoogleProfile {
  const GoogleProfile({
    required this.email,
    required this.name,
    required this.avatarUrl,
  });

  final String email;
  final String name;
  final String avatarUrl;
}

class StoreCategory {
  const StoreCategory({
    required this.id,
    required this.name,
    required this.type,
  });

  factory StoreCategory.fromApi(Map<String, dynamic> json) {
    return StoreCategory(
      id: _stringValue(json['id']) ?? '',
      name: _stringValue(json['name']) ?? 'Category',
      type: _stringValue(json['type']) ?? 'apps',
    );
  }

  final String id;
  final String name;
  final String type;
}

class StoreData {
  const StoreData({
    required this.items,
    required this.categories,
    required this.connected,
    this.message,
  });

  factory StoreData.fallback([String? message]) {
    return StoreData(
      items: _items,
      categories: _fallbackCategories,
      connected: false,
      message: message,
    );
  }

  final List<StoreItem> items;
  final List<StoreCategory> categories;
  final bool connected;
  final String? message;
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.role,
    required this.name,
    required this.email,
    required this.username,
    required this.phoneNumber,
    required this.avatarUrl,
  });

  final String token;
  final String role;
  final String name;
  final String email;
  final String username;
  final String phoneNumber;
  final String avatarUrl;
}

typedef StoreItemLabelBuilder = String Function(StoreItem item);
typedef StoreItemProgressBuilder = double? Function(StoreItem item);
typedef StoreItemPredicate = bool Function(StoreItem item);

class MatjariApi {
  MatjariApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<StoreData> fetchStoreData() async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _fetchStoreDataOnline().timeout(
          const Duration(seconds: 55),
        );
      } catch (error) {
        lastError = error;
      }
    }

    return StoreData.fallback('Offline mode: ${lastError.toString()}');
  }

  Future<StoreData> _fetchStoreDataOnline() async {
    try {
      await _get('/health');
      final responses = await Future.wait([
        _get('/api/apps?platform=android'),
        _get('/api/categories'),
      ]);

      final appsJson = responses[0]['apps'];
      final categoriesJson = responses[1]['categories'];
      final apps = appsJson is List
          ? appsJson
                .whereType<Map<String, dynamic>>()
                .map(StoreItem.fromApi)
                .toList()
          : <StoreItem>[];
      final categories = categoriesJson is List
          ? categoriesJson
                .whereType<Map<String, dynamic>>()
                .map(StoreCategory.fromApi)
                .toList()
          : <StoreCategory>[];

      return StoreData(
        items: apps.isEmpty ? _items : apps,
        categories: categories.isEmpty ? _fallbackCategories : categories,
        connected: true,
        message: 'Connected to $_apiBaseUrl',
      );
    } catch (error) {
      throw Exception(error.toString());
    }
  }

  Future<AuthSession> adminLogin({
    required String username,
    required String password,
  }) async {
    final payload = await _post('/api/auth/admin-login', {
      'username': username,
      'password': password,
    });
    return _sessionFromPayload(payload);
  }

  Future<AuthSession> login({
    required String email,
    String? identifier,
    required String password,
  }) async {
    final payload = await _post('/api/auth/login', {
      'email': email,
      'identifier': identifier ?? email,
      'password': password,
    });
    return _sessionFromPayload(payload);
  }

  Future<AuthSession> register({
    required String email,
    required String password,
    required String fullName,
    String? username,
    String? phoneNumber,
    String? avatarUrl,
  }) async {
    final body = {'email': email, 'password': password, 'full_name': fullName};
    if (username != null) body['username'] = username;
    if (phoneNumber != null) body['phone_number'] = phoneNumber;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    final payload = await _post('/api/auth/register', body);
    return _sessionFromPayload(payload);
  }

  Future<Map<String, dynamic>> googleLogin({
    required String email,
    String? fullName,
    String? username,
    String? phoneNumber,
    String? avatarUrl,
  }) async {
    final body = {'email': email};
    if (fullName != null) body['full_name'] = fullName;
    if (username != null) body['username'] = username;
    if (phoneNumber != null) body['phone_number'] = phoneNumber;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    return _post('/api/auth/google-login', body);
  }

  Future<bool> sendWhatsAppOtp({
    required String numberphone,
    required String message,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse(_whatsAppOtpEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'numberphone': numberphone,
              'message': message.trim(),
            }),
          )
          .timeout(const Duration(seconds: 25));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchReviews(String appId) async {
    if (appId.isEmpty) return [];
    final payload = await _get('/api/reviews/app/$appId');
    final reviews = payload['reviews'];
    return reviews is List
        ? reviews.whereType<Map<String, dynamic>>().toList()
        : [];
  }

  Future<void> recordDownload(StoreItem item, String token) async {
    if (item.id.isEmpty) return;
    await _post('/api/downloads', {
      'app_id': item.id,
      'platform': item.platform,
      'app_version': item.version,
    }, token: token);
  }

  Future<Map<String, int>> fetchUserLibrary(String token) async {
    final payload = await _get('/api/library/me', token: token);
    final apps = payload['apps'];
    if (apps is! List) return {};

    return {
      for (final entry in apps.whereType<Map<String, dynamic>>())
        if (_stringValue(entry['app_id']) != null)
          _stringValue(entry['app_id'])!:
              _intValue(entry['installed_version_code']) ?? 1,
    };
  }

  Future<void> saveUserApp({
    required String token,
    required StoreItem item,
  }) async {
    if (item.id.isEmpty) return;
    await _post('/api/library/me', {
      'app_id': item.id,
      'platform': item.platform,
      'version_code': item.versionCode,
    }, token: token);
  }

  Future<void> openUserApp({
    required String token,
    required StoreItem item,
  }) async {
    if (item.id.isEmpty) return;
    await _post('/api/library/me/${item.id}/open', {}, token: token);
  }

  Future<void> uninstallUserApp({
    required String token,
    required StoreItem item,
  }) async {
    if (item.id.isEmpty) return;
    await _delete('/api/library/me/${item.id}', token: token);
  }

  Future<void> submitReview({
    required String token,
    required StoreItem item,
    required int rating,
    required String comment,
  }) async {
    if (item.id.isEmpty) return;
    await _post('/api/reviews', {
      'app_id': item.id,
      'rating': rating,
      'comment': comment,
    }, token: token);
  }

  Future<void> saveApp({
    required String token,
    StoreItem? existing,
    required String name,
    required String packageName,
    required String description,
    required String platform,
    required String versionName,
    required int versionCode,
    required String size,
    required String iconUrl,
    required String fileUrl,
    required List<String> screenshotUrls,
    required bool forceUpdate,
  }) async {
    final payload = {
      'name': name,
      'package_name': packageName,
      'description': description,
      'platform': platform,
      'version_name': versionName,
      'version_code': versionCode,
      'size': size,
      'icon_url': iconUrl,
      'file_url': fileUrl,
      'apk_file_url': fileUrl,
      'screenshot_urls': screenshotUrls,
      'is_active': true,
      'is_force_update': forceUpdate,
    };

    if (existing == null || existing.id.isEmpty) {
      await _post('/api/apps', payload, token: token);
    } else {
      await _put('/api/apps/${existing.id}', payload, token: token);
    }
  }

  Future<void> deleteApp({
    required String token,
    required StoreItem app,
  }) async {
    if (app.id.isEmpty) return;
    await _delete('/api/apps/${app.id}', token: token);
  }

  Future<void> releaseUpdate({
    required String token,
    required StoreItem app,
    required String versionName,
    required int versionCode,
    required String fileUrl,
    required bool forceUpdate,
    required String changelog,
  }) async {
    if (app.id.isEmpty) return;
    await _post('/api/apps/${app.id}/update', {
      'version_name': versionName,
      'version_code': versionCode,
      'file_url': fileUrl,
      'is_force_update': forceUpdate,
      'changelog': changelog,
    }, token: token);
  }

  Future<Map<String, dynamic>> fetchAnalytics(String token) async {
    return _get('/api/apps/analytics/overview', token: token);
  }

  Future<Map<String, dynamic>> _get(String path, {String? token}) async {
    final response = await _client.get(
      Uri.parse('$_apiBaseUrl$path'),
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final response = await _client.post(
      Uri.parse('$_apiBaseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _delete(
    String path, {
    required String token,
  }) async {
    final response = await _client.delete(
      Uri.parse('$_apiBaseUrl$path'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _put(
    String path,
    Map<String, dynamic> body, {
    required String token,
  }) async {
    final response = await _client.put(
      Uri.parse('$_apiBaseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = jsonDecode(response.body);
    final payload = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = payload['error'] is Map<String, dynamic>
          ? payload['error'] as Map<String, dynamic>
          : <String, dynamic>{};
      throw Exception(_stringValue(error['message']) ?? 'Request failed');
    }
    return payload;
  }

  AuthSession sessionFromPayload(Map<String, dynamic> payload) {
    final user = payload['user'] is Map<String, dynamic>
        ? payload['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    return AuthSession(
      token: _stringValue(payload['token']) ?? '',
      role: _stringValue(user['role']) ?? 'user',
      name:
          _stringValue(user['full_name']) ??
          _stringValue(user['username']) ??
          'User',
      email: _stringValue(user['email']) ?? '',
      username: _stringValue(user['username']) ?? '',
      phoneNumber: _stringValue(user['phone_number']) ?? '',
      avatarUrl: _stringValue(user['avatar_url']) ?? '',
    );
  }

  AuthSession _sessionFromPayload(Map<String, dynamic> payload) {
    return sessionFromPayload(payload);
  }
}

const _fallbackCategories = [
  StoreCategory(id: 'apps', name: 'Apps', type: 'apps'),
  StoreCategory(id: 'games', name: 'Games', type: 'games'),
  StoreCategory(id: 'books', name: 'Books', type: 'books'),
  StoreCategory(id: 'shopping', name: 'Shopping', type: 'apps'),
  StoreCategory(id: 'productivity', name: 'Productivity', type: 'apps'),
  StoreCategory(id: 'action', name: 'Action', type: 'games'),
  StoreCategory(id: 'simulation', name: 'Simulation', type: 'games'),
];

String? _stringValue(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String avatarForEmail(String email) {
  final label = Uri.encodeComponent(email.split('@').first.ifEmpty('User'));
  return 'https://ui-avatars.com/api/?name=$label&background=1769D2&color=fff&bold=true';
}

String? _absoluteApiUrl(String? value) {
  if (value == null) return null;
  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme) return value;
  if (value.startsWith('/')) return '$_apiBaseUrl$value';
  return value;
}

double? _doubleValue(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

int? _intValue(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String _dateLabel(String? value) {
  if (value == null) return 'Today';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

String _downloadLabel(int count) {
  if (count >= 1000000) {
    final millions = count / 1000000;
    return '${millions.toStringAsFixed(millions >= 10 ? 0 : 1)}M+';
  }
  if (count >= 1000) {
    final thousands = count / 1000;
    return '${thousands.toStringAsFixed(thousands >= 10 ? 0 : 1)}K+';
  }
  return '$count downloads';
}

String _offeredBy(String packageName) {
  final parts = packageName
      .split('.')
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length < 2) return 'Matjari';
  final brand = parts[parts.length - 2];
  return '${brand.characters.first.toUpperCase()}${brand.substring(1)}';
}

List<String> _lines(String value) {
  return value
      .split(RegExp(r'\r?\n|,'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
}

Future<Map<String, dynamic>?> _downloadAndInstallApk({
  required String url,
  required String fileName,
  required String downloadId,
}) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return null;
  if (!_canUseAndroidPackageBridge) return null;

  try {
    final payload = await _nativeChannel.invokeMethod<Object?>(
      'downloadAndInstallApk',
      {'url': uri.toString(), 'fileName': fileName, 'downloadId': downloadId},
    );
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    return null;
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}

Future<bool> _openInstalledPackage(String packageName) async {
  if (!_canUseAndroidPackageBridge || packageName.trim().isEmpty) return false;

  try {
    return await _nativeChannel.invokeMethod<bool>('openPackage', {
          'packageName': packageName,
        }) ??
        false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

Future<bool> _uninstallPackage(String packageName) async {
  if (!_canUseAndroidPackageBridge || packageName.trim().isEmpty) return false;

  try {
    return await _nativeChannel.invokeMethod<bool>('uninstallPackage', {
          'packageName': packageName,
        }) ??
        false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

Future<int?> _installedPackageVersionCode(String packageName) async {
  if (!_canUseAndroidPackageBridge || packageName.trim().isEmpty) return null;

  try {
    final value = await _nativeChannel.invokeMethod<Object?>(
      'installedVersionCode',
      {'packageName': packageName},
    );
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}

Future<InstalledPackageMatch?> _resolveInstalledPackageByName(
  String appName,
) async {
  if (!_canUseAndroidPackageBridge || appName.trim().isEmpty) return null;

  try {
    final payload = await _nativeChannel.invokeMethod<Object?>(
      'resolveInstalledPackageByName',
      {'appName': appName},
    );
    if (payload is! Map) return null;
    final map = Map<Object?, Object?>.from(payload);
    final packageName = _stringValue(map['packageName']);
    if (packageName == null || packageName.trim().isEmpty) return null;
    return InstalledPackageMatch(
      packageName: packageName,
      versionCode: _intValue(map['versionCode']) ?? 1,
    );
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}

Future<Map<String, String>> _packageAliases() async {
  if (!_canUseAndroidPackageBridge) return const {};

  try {
    final payload = await _nativeChannel.invokeMethod<Object?>(
      'packageAliases',
    );
    if (payload is Map) {
      return payload.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    }
  } on MissingPluginException {
    return const {};
  } on PlatformException {
    return const {};
  }
  return const {};
}

Future<void> _rememberPackageAlias(String key, String packageName) async {
  if (!_canUseAndroidPackageBridge ||
      key.trim().isEmpty ||
      packageName.trim().isEmpty) {
    return;
  }

  try {
    await _nativeChannel.invokeMethod<void>('rememberPackageAlias', {
      'key': key,
      'packageName': packageName,
    });
  } on MissingPluginException {
    return;
  } on PlatformException {
    return;
  }
}

Future<List<AdminUploadFile>> _pickAndUploadAdminFile({
  required String endpoint,
  required String token,
  required String fieldName,
  required String mimeType,
  bool allowMultiple = false,
}) async {
  if (!_canUseAndroidPackageBridge) {
    throw Exception('File upload is available on Android only.');
  }

  final uploadResult = await _nativeChannel
      .invokeMethod<Object?>('pickAndUpload', {
        'endpoint': '$_apiBaseUrl$endpoint',
        'token': token,
        'fieldName': fieldName,
        'mimeType': mimeType,
        'allowMultiple': allowMultiple,
      });
  final resultMap = uploadResult is Map
      ? Map<Object?, Object?>.from(uploadResult)
      : const <Object?, Object?>{};
  final response = uploadResult is String
      ? uploadResult
      : _stringValue(resultMap['response']);
  if (response == null || response.isEmpty) return [];

  final decoded = jsonDecode(response);
  final payload = decoded is Map<String, dynamic>
      ? decoded
      : <String, dynamic>{};
  final files = payload['files'] is List ? payload['files'] as List : const [];
  final selectedFiles = resultMap['selectedFiles'] is List
      ? resultMap['selectedFiles'] as List
      : const [];

  final uploads = <AdminUploadFile>[];
  for (var index = 0; index < files.length; index += 1) {
    final file = files[index];
    if (file is! Map) continue;
    final url = _stringValue(file['url']);
    if (url == null || url.isEmpty) continue;
    final selected = index < selectedFiles.length && selectedFiles[index] is Map
        ? Map<Object?, Object?>.from(selectedFiles[index] as Map)
        : const <Object?, Object?>{};
    uploads.add(
      AdminUploadFile(
        url: url,
        sizeBytes: _intValue(file['size']) ?? _intValue(selected['size']),
        packageName: _stringValue(selected['packageName']),
        versionCode: _intValue(selected['versionCode']),
        versionName: _stringValue(selected['versionName']),
      ),
    );
  }

  return uploads;
}

bool get _canUseAndroidPackageBridge {
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}

double _ratingForName(String name) {
  final seed = name.codeUnits.fold<int>(0, (sum, code) => sum + code);
  return 4.1 + (seed % 8) / 10;
}

IconData _iconFor(String type, String category, String name) {
  final text = '$type $category $name'.toLowerCase();
  if (type == 'games') return Icons.sports_esports;
  if (type == 'books') return Icons.menu_book;
  if (text.contains('shopping') || text.contains('market')) {
    return Icons.storefront;
  }
  if (text.contains('productivity')) return Icons.auto_awesome;
  if (text.contains('social')) return Icons.groups;
  if (text.contains('finance')) return Icons.trending_up;
  return Icons.apps;
}

Color _colorFor(String category, String name) {
  final text = '$category $name'.toLowerCase();
  if (text.contains('alibaba') || text.contains('shopping')) {
    return const Color(0xFFFF6A00);
  }
  if (text.contains('game') || text.contains('action')) {
    return const Color(0xFF2F80ED);
  }
  if (text.contains('book')) return const Color(0xFF184E77);
  if (text.contains('social')) return const Color(0xFF050505);
  if (text.contains('productivity')) return const Color(0xFF111827);
  return const Color(0xFF1769D2);
}

List<String> _permissionsFor(StoreItem item) {
  final text = '${item.type} ${item.category} ${item.name}'.toLowerCase();
  if (item.type == 'books') return const ['Storage', 'Network access'];
  if (text.contains('shopping') || text.contains('market')) {
    return const ['Camera', 'Notifications', 'Network access'];
  }
  if (text.contains('social') || text.contains('video')) {
    return const ['Camera', 'Microphone', 'Notifications'];
  }
  if (text.contains('finance') || text.contains('invest')) {
    return const ['Network access', 'Notifications'];
  }
  if (item.type == 'games') {
    return const ['Network access', 'Storage', 'Notifications'];
  }
  return const ['Network access', 'Notifications'];
}

extension _StringFallback on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

const _items = <StoreItem>[
  StoreItem(
    name: 'ChatGPT',
    category: 'Productivity',
    summary: 'Write, learn, plan, and explore ideas with an AI assistant.',
    rating: 4.8,
    icon: Icons.auto_awesome,
    color: Color(0xFF111827),
    type: 'apps',
    installed: true,
    size: '156 MB',
    version: '3.2.1',
    downloads: '500M+',
  ),
  StoreItem(
    name: 'TikTok - Videos, Shop & LIVE',
    category: 'Social',
    summary: 'Short videos, creators, shops, and live moments in one place.',
    rating: 4.6,
    icon: Icons.music_note,
    color: Color(0xFF050505),
    type: 'apps',
    installed: true,
    updateAvailable: true,
    size: '210 MB',
    version: '38.4.0',
    downloads: '1B+',
  ),
  StoreItem(
    name: 'Alibaba.com - B2B marketplace',
    category: 'Shopping',
    summary: 'Source products, compare suppliers, and manage orders.',
    rating: 4.5,
    icon: Icons.storefront,
    color: Color(0xFFFF6A00),
    type: 'apps',
    installed: true,
    size: '124 MB',
    version: '26.21.2',
    downloads: '500M+',
  ),
  StoreItem(
    name: 'OLX Lebanon',
    category: 'Shopping',
    summary: 'Buy and sell cars, homes, electronics, and local finds.',
    rating: 4.3,
    icon: Icons.sell,
    color: Color(0xFF37A7B9),
    type: 'apps',
    installed: true,
    size: '72 MB',
    version: '12.8.4',
    downloads: '5M+',
  ),
  StoreItem(
    name: 'MAF Carrefour Online Shopping',
    category: 'Shopping',
    summary: 'Groceries, offers, delivery slots, and household essentials.',
    rating: 4.3,
    icon: Icons.shopping_basket,
    color: Color(0xFF0E5CA8),
    type: 'apps',
    size: '88 MB',
    version: '8.9.1',
    downloads: '10M+',
  ),
  StoreItem(
    name: 'Notion Calendar',
    category: 'Productivity',
    summary: 'A focused calendar for work, life, and shared plans.',
    rating: 4.7,
    icon: Icons.calendar_month,
    color: Color(0xFF111111),
    type: 'apps',
    installed: true,
    size: '67 MB',
    version: '2.14.0',
    downloads: '1M+',
  ),
  StoreItem(
    name: 'Clash of Clans',
    category: 'Strategy',
    summary: 'Build, battle, and defend your village with your clan.',
    rating: 4.5,
    icon: Icons.shield,
    color: Color(0xFFB85B22),
    type: 'games',
    size: '316 MB',
    version: '18.0.2',
    downloads: '500M+',
  ),
  StoreItem(
    name: '8 Ball Pool',
    category: 'Sports',
    summary: 'Play classic billiards against friends and online rivals.',
    rating: 4.8,
    icon: Icons.sports_bar,
    color: Color(0xFF0A92D5),
    type: 'games',
    size: '182 MB',
    version: '56.3.1',
    downloads: '1B+',
  ),
  StoreItem(
    name: 'War Drone: 3D Shooting Games',
    category: 'Action',
    summary: 'Deploy drones and protect troops in fast missions.',
    rating: 4.7,
    icon: Icons.flight_takeoff,
    color: Color(0xFF5D718C),
    type: 'games',
    size: '401 MB',
    version: '7.1.0',
    downloads: '10M+',
  ),
  StoreItem(
    name: 'RFS - Real Flight Simulator',
    category: 'Simulation',
    summary: 'Pilot aircraft and land at airports around the world.',
    rating: 4.2,
    icon: Icons.airplanemode_active,
    color: Color(0xFF2F80ED),
    type: 'games',
    price: '\$0.99',
    size: '512 MB',
    version: '2.7.4',
    downloads: '5M+',
  ),
  StoreItem(
    name: 'Project Hail Mary: A Novel',
    category: 'Science Fiction',
    summary: 'A survival story across space, memory, and impossible odds.',
    rating: 4.9,
    icon: Icons.menu_book,
    color: Color(0xFF184E77),
    type: 'books',
    price: '\$13.99',
    size: 'Ebook',
    version: 'Book',
    downloads: 'Top read',
  ),
  StoreItem(
    name: 'Exodus: The Archimedes Engine',
    category: 'Science Fiction',
    summary: 'A sweeping new space opera with political stakes.',
    rating: 4.4,
    icon: Icons.book,
    color: Color(0xFFC1121F),
    type: 'books',
    price: '\$14.99',
    size: 'Ebook',
    version: 'Book',
    downloads: 'New',
  ),
];

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({
    super.key,
    required this.api,
    required this.onSessionChanged,
  });

  final MatjariApi api;
  final ValueChanged<AuthSession> onSessionChanged;

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _pendingOtp;
  AuthSession? _pendingSession;
  String _pendingDestination = '';
  GoogleProfile? _googleRegistrationProfile;
  bool _registerMode = false;
  bool _loading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'App settings',
                onPressed: () => showAppSettingsSheet(context),
                icon: const Icon(Icons.more_vert),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: const [
                  MatjariMark(size: 86),
                  SizedBox(height: 16),
                  Text(
                    'Matjari',
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Your private Android store',
                    style: TextStyle(color: _muted, fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            if (_pendingSession != null)
              _OtpCard(
                destination: _pendingDestination,
                loading: _loading,
                onVerify: _verifyOtp,
                onBack: () => setState(() {
                  _pendingSession = null;
                  _pendingOtp = null;
                  _pendingDestination = '';
                }),
              )
            else if (_registerMode)
              _RegisterCard(
                initialProfile: _googleRegistrationProfile,
                loading: _loading,
                onRegister: _completeRegistration,
                onBackToLogin: () => setState(() {
                  _registerMode = false;
                  _googleRegistrationProfile = null;
                }),
              )
            else
              _LoginCard(
                identifierController: _identifierController,
                passwordController: _passwordController,
                loading: _loading,
                onLogin: _login,
                onRegister: () => setState(() => _registerMode = true),
                onGoogle: _loginByGoogle,
                onForgotPassword: _forgotPassword,
              ),
            const SizedBox(height: 22),
            const Text(
              'Admin signs in from the same form using admin / 123456.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _login() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;
    if (identifier.isEmpty || password.isEmpty) {
      _showSnack(context, 'Enter your email and password.');
      return;
    }
    setState(() => _loading = true);
    try {
      final session = await _authenticate(identifier, password);
      await _beginOtp(session);
    } catch (error) {
      if (mounted) _showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _completeRegistration(RegisterFormData data) async {
    setState(() => _loading = true);
    try {
      final session = await widget.api.register(
        email: data.email,
        password: data.password,
        fullName: data.fullName,
        username: data.username,
        phoneNumber: data.phoneNumber,
        avatarUrl: data.avatarUrl,
      );
      await _beginOtp(session);
    } catch (error) {
      if (mounted) _showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<AuthSession> _authenticate(String identifier, String password) async {
    if (identifier.toLowerCase() == 'admin') {
      return widget.api.adminLogin(username: 'admin', password: password);
    }
    try {
      return await widget.api.login(
        email: identifier.toLowerCase(),
        identifier: identifier,
        password: password,
      );
    } catch (error) {
      if (identifier.contains('@')) rethrow;
      return widget.api.adminLogin(username: identifier, password: password);
    }
  }

  Future<void> _loginByGoogle() async {
    setState(() => _loading = true);
    try {
      final profile = await _googleProfile();
      if (profile == null) return;
      final payload = await widget.api.googleLogin(
        email: profile.email,
        fullName: profile.name,
        avatarUrl: profile.avatarUrl,
      );
      if (payload['needs_registration'] == true) {
        if (!mounted) return;
        setState(() {
          _googleRegistrationProfile = profile;
          _registerMode = true;
        });
        _showSnack(context, 'Complete your phone number and password.');
        return;
      }
      final session = widget.api.sessionFromPayload(payload);
      await _beginOtp(session);
    } catch (error) {
      if (mounted) _showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<GoogleProfile?> _googleProfile() async {
    try {
      final google = GoogleSignIn.instance;
      await google.initialize();
      final account = await google.authenticate();
      final auth = account.authentication;
      final credential = firebase_auth.GoogleAuthProvider.credential(
        idToken: auth.idToken,
      );
      await firebase_auth.FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      return GoogleProfile(
        email: account.email,
        name: account.displayName ?? account.email.split('@').first,
        avatarUrl: account.photoUrl ?? avatarForEmail(account.email),
      );
    } catch (error) {
      if (mounted) _showSnack(context, 'Google login failed: $error');
      return null;
    }
  }

  Future<void> _beginOtp(AuthSession session) async {
    final otp = _generateOtp();
    final message = 'Matjari OTP: $otp';
    var sent = false;
    final destination = session.phoneNumber.ifEmpty(session.email);
    if (_looksLikePhone(session.phoneNumber)) {
      sent = await widget.api.sendWhatsAppOtp(
        numberphone: session.phoneNumber,
        message: message,
      );
    }
    if (!mounted) return;
    setState(() {
      _pendingSession = session;
      _pendingOtp = otp;
      _pendingDestination = destination;
    });
    _showSnack(
      context,
      sent
          ? 'OTP sent on WhatsApp.'
          : 'OTP ready for testing: $otp. Add a valid WhatsApp number to send it.',
    );
  }

  void _verifyOtp(String value) {
    final session = _pendingSession;
    if (session == null) return;
    if (value.trim() != _pendingOtp) {
      _showSnack(context, 'Invalid OTP.');
      return;
    }
    widget.onSessionChanged(session);
    _showSnack(context, 'Welcome ${session.name}.');
  }

  void _forgotPassword() {
    _showSnack(
      context,
      'Password reset flow is ready for backend email/WhatsApp recovery.',
    );
  }

  String _generateOtp() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (100000 + (now % 900000)).toString();
  }

  bool _looksLikePhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 8;
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.identifierController,
    required this.passwordController,
    required this.loading,
    required this.onLogin,
    required this.onRegister,
    required this.onGoogle,
    required this.onForgotPassword,
  });

  final TextEditingController identifierController;
  final TextEditingController passwordController;
  final bool loading;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback onGoogle;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Welcome back',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Login to continue to the store.',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: identifierController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Email or username',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passwordController,
            obscureText: true,
            onSubmitted: (_) => onLogin(),
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: loading ? null : onLogin,
            icon: const Icon(Icons.login),
            label: Text(loading ? 'Please wait' : 'Login'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: loading ? null : onGoogle,
            icon: const Icon(Icons.account_circle_outlined),
            label: const Text('Login by Google'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: loading ? null : onRegister,
            child: const Text('Register'),
          ),
          TextButton(
            onPressed: loading ? null : onForgotPassword,
            child: const Text('Forget password'),
          ),
        ],
      ),
    );
  }
}

class _RegisterCard extends StatefulWidget {
  const _RegisterCard({
    this.initialProfile,
    required this.loading,
    required this.onRegister,
    required this.onBackToLogin,
  });

  final GoogleProfile? initialProfile;
  final bool loading;
  final ValueChanged<RegisterFormData> onRegister;
  final VoidCallback onBackToLogin;

  @override
  State<_RegisterCard> createState() => _RegisterCardState();
}

class _RegisterCardState extends State<_RegisterCard> {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _avatarController = TextEditingController();
  String _countryCode = '+961';

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    if (profile != null) {
      _emailController.text = profile.email;
      _nameController.text = profile.name;
      _usernameController.text = profile.email.split('@').first.toLowerCase();
      _avatarController.text = profile.avatarUrl;
    }
    _emailController.addListener(_syncAvatarAndUsername);
  }

  @override
  void dispose() {
    _emailController.removeListener(_syncAvatarAndUsername);
    _emailController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  void _syncAvatarAndUsername() {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    if (_avatarController.text.trim().isEmpty) {
      _avatarController.text = avatarForEmail(email);
    }
    if (_usernameController.text.trim().isEmpty && email.contains('@')) {
      _usernameController.text = email.split('@').first.toLowerCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _avatarController.text.trim();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back to login',
                onPressed: widget.onBackToLogin,
                icon: const Icon(Icons.arrow_back),
              ),
              const Expanded(
                child: Text(
                  'Create account',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: CircleAvatar(
              radius: 42,
              backgroundColor: _brandBlue,
              backgroundImage: avatar.isEmpty ? null : NetworkImage(avatar),
              child: avatar.isEmpty
                  ? const Icon(Icons.person, color: Colors.white, size: 42)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.alternate_email),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 104,
                child: DropdownButtonFormField<String>(
                  initialValue: _countryCode,
                  decoration: const InputDecoration(labelText: 'Code'),
                  items: const [
                    DropdownMenuItem(value: '+961', child: Text('LB +961')),
                    DropdownMenuItem(value: '+1', child: Text('US +1')),
                    DropdownMenuItem(value: '+971', child: Text('AE +971')),
                    DropdownMenuItem(value: '+966', child: Text('SA +966')),
                    DropdownMenuItem(value: '+20', child: Text('EG +20')),
                  ],
                  onChanged: (value) =>
                      setState(() => _countryCode = value ?? '+961'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _avatarController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Profile image URL',
              prefixIcon: Icon(Icons.image_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm password',
              prefixIcon: Icon(Icons.lock_reset),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: widget.loading ? null : _submit,
            icon: const Icon(Icons.person_add_alt_1),
            label: Text(widget.loading ? 'Please wait' : 'Register'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final email = _emailController.text.trim().toLowerCase();
    final username = _usernameController.text.trim().toLowerCase();
    final phone = _normalizedPhone();
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    if (!email.contains('@') ||
        username.isEmpty ||
        phone.length < 8 ||
        name.isEmpty) {
      _showSnack(context, 'Complete email, username, phone, and name.');
      return;
    }
    if (password.length < 6 || password != confirm) {
      _showSnack(context, 'Passwords must match and be 6+ characters.');
      return;
    }
    widget.onRegister(
      RegisterFormData(
        email: email,
        username: username,
        phoneNumber: phone,
        fullName: name,
        password: password,
        avatarUrl: _avatarController.text.trim().ifEmpty(avatarForEmail(email)),
      ),
    );
  }

  String _normalizedPhone() {
    final digits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final country = _countryCode.replaceAll(RegExp(r'[^0-9]'), '');
    final local = digits.replaceFirst(RegExp(r'^0+'), '');
    return '+$country$local';
  }
}

class _OtpCard extends StatefulWidget {
  const _OtpCard({
    required this.destination,
    required this.loading,
    required this.onVerify,
    required this.onBack,
  });

  final String destination;
  final bool loading;
  final ValueChanged<String> onVerify;
  final VoidCallback onBack;

  @override
  State<_OtpCard> createState() => _OtpCardState();
}

class _OtpCardState extends State<_OtpCard> {
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IconButton(
            alignment: Alignment.centerLeft,
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back),
          ),
          const Text(
            'OTP verification',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter the OTP you received for ${widget.destination}.',
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: widget.onVerify,
            decoration: const InputDecoration(
              labelText: 'OTP code',
              prefixIcon: Icon(Icons.password_outlined),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: widget.loading
                ? null
                : () => widget.onVerify(_otpController.text),
            icon: const Icon(Icons.verified_user_outlined),
            label: Text(widget.loading ? 'Please wait' : 'Verify'),
          ),
        ],
      ),
    );
  }
}

class MatjariShell extends StatefulWidget {
  const MatjariShell({super.key});

  @override
  State<MatjariShell> createState() => _MatjariShellState();
}

class _MatjariShellState extends State<MatjariShell>
    with WidgetsBindingObserver {
  final MatjariApi _api = MatjariApi();
  final Map<String, int> _installedBuilds = {};
  final Map<String, double> _downloadProgress = {};
  final Map<String, String> _downloadPackageAliases = {};
  final Set<String> _locallyRemoved = {};
  final ValueNotifier<int> _statusRevision = ValueNotifier<int>(0);
  List<StoreItem> _latestItems = const [];
  String _lastInstallScanSignature = '';
  bool _installScanRunning = false;
  late Future<StoreData> _storeFuture;
  AuthSession? _session;
  int _bottomIndex = 1;
  int _topIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nativeChannel.setMethodCallHandler(_handleNativeMethodCall);
    unawaited(_loadPackageAliases());
    _storeFuture = _api.fetchStoreData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nativeChannel.setMethodCallHandler(null);
    _statusRevision.dispose();
    super.dispose();
  }

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    if (call.method != 'downloadProgress') return;
    final args = call.arguments is Map
        ? Map<Object?, Object?>.from(call.arguments as Map)
        : <Object?, Object?>{};
    final downloadId = _stringValue(args['downloadId']);
    if (downloadId == null || downloadId.isEmpty) return;

    final progress = _doubleValue(args['progress']);
    if (progress == null) return;

    _notifyStoreStatusChanged(() {
      _downloadProgress[downloadId] = progress.clamp(0.0, 1.0).toDouble();
    });
  }

  Future<void> _loadPackageAliases() async {
    final aliases = await _packageAliases();
    if (!mounted || aliases.isEmpty) return;
    _notifyStoreStatusChanged(() {
      _downloadPackageAliases
        ..clear()
        ..addAll(aliases);
    });
    _lastInstallScanSignature = '';
    unawaited(_refreshInstalledPackages(_latestItems));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _lastInstallScanSignature = '';
    unawaited(_refreshInstalledPackages(_latestItems));
  }

  void _refreshStore() {
    _lastInstallScanSignature = '';
    setState(() {
      _storeFuture = _api.fetchStoreData();
    });
  }

  void _setSession(AuthSession session) {
    setState(() => _session = session);
    unawaited(_loadUserLibrary(session));
  }

  void _clearSession() {
    _notifyStoreStatusChanged(() {
      _session = null;
      _installedBuilds.clear();
      _locallyRemoved.clear();
    });
    _showSnack(context, 'Signed out.');
  }

  Future<void> _loadUserLibrary(AuthSession session) async {
    try {
      final library = await _api.fetchUserLibrary(session.token);
      if (!mounted) return;
      _notifyStoreStatusChanged(() {
        _installedBuilds
          ..clear()
          ..addAll(library);
        _locallyRemoved.clear();
      });
      _lastInstallScanSignature = '';
      unawaited(_refreshInstalledPackages(_latestItems));
    } catch (error) {
      if (mounted) _showSnack(context, 'Could not sync library: $error');
    }
  }

  String _itemKey(StoreItem item) {
    return item.id.ifEmpty(item.packageName).ifEmpty(item.name);
  }

  String _installPackageName(StoreItem item) {
    return _downloadPackageAliases[_itemKey(item)] ?? item.packageName;
  }

  void _rememberResolvedPackage(StoreItem item, String packageName) {
    final key = _itemKey(item);
    if (packageName.trim().isEmpty) return;
    _downloadPackageAliases[key] = packageName;
    unawaited(_rememberPackageAlias(key, packageName));
  }

  Future<InstalledPackageMatch?> _resolveInstalledMatch(StoreItem item) async {
    final directPackageName = _installPackageName(item).trim();
    if (directPackageName.isNotEmpty) {
      final versionCode = await _installedPackageVersionCode(directPackageName);
      if (versionCode != null) {
        return InstalledPackageMatch(
          packageName: directPackageName,
          versionCode: versionCode,
        );
      }
    }

    final match = await _resolveInstalledPackageByName(item.name);
    if (match != null) {
      _rememberResolvedPackage(item, match.packageName);
    }
    return match;
  }

  int? _installedBuild(StoreItem item) {
    final key = _itemKey(item);
    if (_locallyRemoved.contains(key)) return null;
    final localBuild = _installedBuilds[key];
    if (localBuild != null) return localBuild;
    if (!item.installed) return null;
    if (item.updateAvailable || item.forceUpdate) {
      return item.versionCode > 1 ? item.versionCode - 1 : 0;
    }
    return item.versionCode;
  }

  bool _needsUpdate(StoreItem item) {
    final installedBuild = _installedBuild(item);
    return installedBuild != null && item.versionCode > installedBuild;
  }

  double? _progressFor(StoreItem item) {
    return _downloadProgress[_itemKey(item)];
  }

  bool _canUninstall(StoreItem item) {
    return _installedBuild(item) != null;
  }

  String _actionLabelFor(StoreItem item) {
    final progress = _progressFor(item);
    if (progress != null) {
      return '${(progress * 100).clamp(0, 100).round()}%';
    }
    final installedBuild = _installedBuild(item);
    if (installedBuild != null) {
      return _needsUpdate(item) ? 'Update' : 'Open';
    }
    if (item.type == 'books' && item.price != null) return item.price!;
    return 'Download';
  }

  void _notifyStoreStatusChanged(VoidCallback update) {
    if (!mounted) return;
    setState(update);
    _statusRevision.value += 1;
  }

  void _handleStoreAction(StoreItem item) {
    unawaited(_handleStoreActionAsync(item));
  }

  Future<void> _handleStoreActionAsync(StoreItem item) async {
    final key = _itemKey(item);
    if (_downloadProgress.containsKey(key)) return;

    final installedBuild = _installedBuild(item);
    if (installedBuild != null && !_needsUpdate(item)) {
      final match = await _resolveInstalledMatch(item);
      final opened =
          match != null && await _openInstalledPackage(match.packageName);
      final token = _session?.token;
      if (opened && token != null) {
        unawaited(
          _api.openUserApp(token: token, item: item).catchError((Object _) {}),
        );
      }
      if (!mounted) return;
      if (opened) {
        _showSnack(context, 'Opened ${item.name}.');
      } else {
        _notifyStoreStatusChanged(() {
          _installedBuilds.remove(key);
          _locallyRemoved.add(key);
        });
        _showSnack(context, '${item.name} is not installed on this device.');
      }
      return;
    }

    _startDownload(item, updating: installedBuild != null);
  }

  void _startDownload(StoreItem item, {required bool updating}) {
    unawaited(_startDownloadAsync(item, updating: updating));
  }

  Future<void> _startDownloadAsync(
    StoreItem item, {
    required bool updating,
  }) async {
    final key = _itemKey(item);
    _notifyStoreStatusChanged(() {
      _downloadProgress[key] = 0.0;
    });

    try {
      if (!_hasDirectDownload(item)) {
        _notifyStoreStatusChanged(() {
          _downloadProgress.remove(key);
          _installedBuilds[key] = item.versionCode;
          _locallyRemoved.remove(key);
        });
        final token = _session?.token;
        if (token != null) {
          unawaited(_syncInstalledApp(token: token, item: item));
        }
        _showSnack(
          context,
          '${updating ? 'Updated' : 'Installed'} ${item.name}.',
        );
        return;
      }

      final result = await _downloadAndInstallApk(
        url: item.fileUrl!.trim(),
        fileName: item.name,
        downloadId: key,
      );
      final opened = result?['opened'] == true;
      final actualPackageName = _stringValue(result?['packageName']);
      if (actualPackageName != null && actualPackageName.isNotEmpty) {
        _rememberResolvedPackage(item, actualPackageName);
      }

      if (!mounted) return;
      _notifyStoreStatusChanged(() {
        _downloadProgress.remove(key);
        _locallyRemoved.remove(key);
      });

      final token = _session?.token;
      if (token != null) {
        unawaited(_api.recordDownload(item, token).catchError((Object _) {}));
      }

      _showSnack(
        context,
        opened
            ? 'Installer opened for ${item.name}.'
            : 'Downloaded ${item.name}, but installer could not open.',
      );
    } catch (error) {
      if (!mounted) return;
      _notifyStoreStatusChanged(() {
        _downloadProgress.remove(key);
      });
      _showSnack(context, 'Download failed: $error');
    }
  }

  bool _hasDirectDownload(StoreItem item) {
    return (item.fileUrl?.trim().isNotEmpty ?? false);
  }

  Future<void> _syncInstalledApp({
    required String token,
    required StoreItem item,
  }) async {
    try {
      await Future.wait([
        _api.recordDownload(item, token),
        _api.saveUserApp(token: token, item: item),
      ]);
    } catch (_) {
      // Local install state stays usable if the API is temporarily offline.
    }
  }

  void _handleUninstall(StoreItem item) {
    unawaited(_handleUninstallAsync(item));
  }

  Future<void> _handleUninstallAsync(StoreItem item) async {
    final key = _itemKey(item);
    final match = await _resolveInstalledMatch(item);
    final opened = match != null && await _uninstallPackage(match.packageName);
    if (!mounted) return;

    if (opened) {
      _showSnack(context, 'Uninstaller opened for ${item.name}.');
      return;
    }

    _notifyStoreStatusChanged(() {
      _downloadProgress.remove(key);
      _installedBuilds.remove(key);
      _locallyRemoved.add(key);
    });
    final token = _session?.token;
    if (token != null) {
      unawaited(
        _api
            .uninstallUserApp(token: token, item: item)
            .catchError((Object _) {}),
      );
    }
    _showSnack(context, '${item.name} removed from your Matjari library.');
  }

  void _maybeRefreshInstalledPackages(List<StoreItem> items) {
    if (!_canUseAndroidPackageBridge || items.isEmpty || _installScanRunning) {
      return;
    }

    final signature = items
        .map((item) => '${_installPackageName(item)}:${item.versionCode}')
        .where((value) => !value.startsWith(':'))
        .join('|');
    if (signature.isEmpty || signature == _lastInstallScanSignature) return;

    _lastInstallScanSignature = signature;
    unawaited(_refreshInstalledPackages(items));
  }

  Future<void> _refreshInstalledPackages(List<StoreItem> items) async {
    if (!_canUseAndroidPackageBridge || items.isEmpty || _installScanRunning) {
      return;
    }

    _installScanRunning = true;
    final scannedKeys = <String>{};
    final installed = <String, int>{};

    try {
      for (final item in items) {
        final key = _itemKey(item);
        final match = await _resolveInstalledMatch(item);
        if (match == null) {
          final packageName = _installPackageName(item);
          if (packageName.trim().isEmpty) continue;
        }
        scannedKeys.add(key);
        if (match != null) installed[key] = match.versionCode;
      }
    } finally {
      _installScanRunning = false;
    }

    if (!mounted || scannedKeys.isEmpty) return;

    _notifyStoreStatusChanged(() {
      for (final key in scannedKeys) {
        final versionCode = installed[key];
        if (versionCode == null) {
          _installedBuilds.remove(key);
        } else {
          _installedBuilds[key] = versionCode;
          _locallyRemoved.remove(key);
        }
      }
    });

    final token = _session?.token;
    if (token != null) {
      for (final item in items) {
        final key = _itemKey(item);
        if (installed.containsKey(key)) {
          unawaited(
            _api
                .saveUserApp(token: token, item: item)
                .catchError((Object _) {}),
          );
        }
      }
    }
  }

  void _openDetails(StoreItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AppDetailsPage(
          item: item,
          api: _api,
          session: _session,
          statusRevision: _statusRevision,
          actionLabelFor: _actionLabelFor,
          progressFor: _progressFor,
          canUninstall: _canUninstall,
          onAction: _handleStoreAction,
          onUninstall: _handleUninstall,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return AuthGatePage(api: _api, onSessionChanged: _setSession);
    }

    return FutureBuilder<StoreData>(
      future: _storeFuture,
      initialData: StoreData.fallback('Loading Matjari API...'),
      builder: (context, snapshot) {
        final store = snapshot.data ?? StoreData.fallback();
        _latestItems = store.items;
        if (snapshot.connectionState == ConnectionState.done) {
          _maybeRefreshInstalledPackages(store.items);
        }
        final pages = <Widget>[
          StoreFeedPage(
            feedType: 'games',
            items: store.items,
            categories: store.categories,
            selectedTopIndex: _topIndex,
            onTopChanged: (value) => setState(() => _topIndex = value),
            onItemSelected: _openDetails,
            actionLabelFor: _actionLabelFor,
            progressFor: _progressFor,
            canUninstall: _canUninstall,
            onAction: _handleStoreAction,
            onUninstall: _handleUninstall,
          ),
          StoreFeedPage(
            feedType: 'apps',
            items: store.items,
            categories: store.categories,
            selectedTopIndex: _topIndex,
            onTopChanged: (value) => setState(() => _topIndex = value),
            onItemSelected: _openDetails,
            actionLabelFor: _actionLabelFor,
            progressFor: _progressFor,
            canUninstall: _canUninstall,
            onAction: _handleStoreAction,
            onUninstall: _handleUninstall,
          ),
          SearchPage(
            items: store.items,
            categories: store.categories,
            onItemSelected: _openDetails,
            actionLabelFor: _actionLabelFor,
            progressFor: _progressFor,
            canUninstall: _canUninstall,
            onAction: _handleStoreAction,
            onUninstall: _handleUninstall,
          ),
          BooksPage(
            items: store.items,
            onItemSelected: _openDetails,
            actionLabelFor: _actionLabelFor,
            progressFor: _progressFor,
            canUninstall: _canUninstall,
            onAction: _handleStoreAction,
            onUninstall: _handleUninstall,
          ),
          YouPage(
            api: _api,
            items: store.items,
            session: _session,
            onSessionChanged: _setSession,
            onLogout: _clearSession,
            onItemSelected: _openDetails,
            onRefresh: _refreshStore,
            actionLabelFor: _actionLabelFor,
            progressFor: _progressFor,
            canUninstall: _canUninstall,
            onAction: _handleStoreAction,
            onUninstall: _handleUninstall,
          ),
        ];

        return Scaffold(
          body: SafeArea(
            child: Column(children: [Expanded(child: pages[_bottomIndex])]),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _bottomIndex,
            onDestinationSelected: (value) =>
                setState(() => _bottomIndex = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.sports_esports_outlined),
                selectedIcon: Icon(Icons.sports_esports),
                label: 'Games',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'Apps',
              ),
              NavigationDestination(
                icon: Icon(Icons.search),
                selectedIcon: Icon(Icons.search),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Icon(Icons.bookmark_border),
                selectedIcon: Icon(Icons.bookmark),
                label: 'Books',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'You',
              ),
            ],
          ),
        );
      },
    );
  }
}

class ApiStatusBanner extends StatelessWidget {
  const ApiStatusBanner({
    super.key,
    required this.store,
    required this.onRefresh,
  });

  final StoreData store;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final color = store.connected
        ? const Color(0xFFE7F6ED)
        : const Color(0xFFFFF4D7);
    final textColor = store.connected
        ? const Color(0xFF137333)
        : const Color(0xFF8A5A00);
    final label = store.connected ? 'Live API' : 'Offline fallback';

    return Material(
      color: color,
      child: InkWell(
        onTap: onRefresh,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Icon(
                store.connected
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined,
                size: 18,
                color: textColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$label - ${store.message ?? _apiBaseUrl}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.refresh, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}

class StoreFeedPage extends StatelessWidget {
  const StoreFeedPage({
    super.key,
    required this.feedType,
    required this.items,
    required this.categories,
    required this.selectedTopIndex,
    required this.onTopChanged,
    required this.onItemSelected,
    required this.actionLabelFor,
    required this.progressFor,
    required this.canUninstall,
    required this.onAction,
    required this.onUninstall,
  });

  final String feedType;
  final List<StoreItem> items;
  final List<StoreCategory> categories;
  final int selectedTopIndex;
  final ValueChanged<int> onTopChanged;
  final ValueChanged<StoreItem> onItemSelected;
  final StoreItemLabelBuilder actionLabelFor;
  final StoreItemProgressBuilder progressFor;
  final StoreItemPredicate canUninstall;
  final ValueChanged<StoreItem> onAction;
  final ValueChanged<StoreItem> onUninstall;

  List<StoreItem> get _feedItems =>
      items.where((item) => item.type == feedType).toList();

  @override
  Widget build(BuildContext context) {
    final feedItems = _feedItems;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StoreHeader(),
              TopTabs(
                labels: const [
                  'For you',
                  'Top charts',
                  'Other devices',
                  'Kids',
                ],
                selectedIndex: selectedTopIndex,
                onChanged: onTopChanged,
              ),
              const Divider(height: 1),
            ],
          ),
        ),
        if (selectedTopIndex == 1)
          SliverToBoxAdapter(
            child: TopChartsContent(
              items: feedItems,
              onItemSelected: onItemSelected,
              actionLabelFor: actionLabelFor,
              progressFor: progressFor,
              canUninstall: canUninstall,
              onAction: onAction,
              onUninstall: onUninstall,
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: StoreHeroBanner(
              title: feedType == 'apps'
                  ? 'Fresh apps picked for you'
                  : 'New games to play this week',
              subtitle: feedType == 'apps'
                  ? 'Smart tools, shopping, social, and everyday favorites'
                  : 'Action, strategy, puzzle, and simulator highlights',
              icon: feedType == 'apps' ? Icons.apps : Icons.sports_esports,
            ),
          ),
          SliverToBoxAdapter(
            child: SectionBlock(
              eyebrow: 'Sponsored',
              title: 'Suggested for you',
              items: feedItems.take(3).toList(),
              onItemSelected: onItemSelected,
              actionLabelFor: actionLabelFor,
              progressFor: progressFor,
              canUninstall: canUninstall,
              onAction: onAction,
              onUninstall: onUninstall,
            ),
          ),
          SliverToBoxAdapter(
            child: HorizontalSection(
              title: feedType == 'apps'
                  ? 'More apps to try'
                  : 'Non-stop action',
              items: feedItems.reversed.take(5).toList(),
              onItemSelected: onItemSelected,
              actionLabelFor: actionLabelFor,
              progressFor: progressFor,
              canUninstall: canUninstall,
              onAction: onAction,
              onUninstall: onUninstall,
            ),
          ),
          SliverToBoxAdapter(
            child: SectionBlock(
              title: feedType == 'apps'
                  ? 'Innovation corner'
                  : 'Recommended for you',
              subtitle: feedType == 'apps'
                  ? 'Big ideas from up-and-coming companies'
                  : null,
              items: items
                  .where((item) => item.type != 'books')
                  .skip(feedType == 'apps' ? 4 : 6)
                  .take(3)
                  .toList(),
              onItemSelected: onItemSelected,
              actionLabelFor: actionLabelFor,
              progressFor: progressFor,
              canUninstall: canUninstall,
              onAction: onAction,
              onUninstall: onUninstall,
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }
}

class StoreHeader extends StatelessWidget {
  const StoreHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          const MatjariMark(size: 44),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Matjari',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
          ),
          BadgeIcon(
            icon: Icons.check_circle_outline,
            count: '1',
            onTap: () => _showSnack(context, 'No pending approvals.'),
          ),
          BadgeIcon(
            icon: Icons.notifications_none,
            count: '3',
            onTap: () => _showSnack(context, 'You have 3 store alerts.'),
          ),
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFF263238),
            child: Text('M', style: TextStyle(color: Colors.white)),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => showAppSettingsSheet(context),
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
    );
  }
}

class MatjariMark extends StatelessWidget {
  const MatjariMark({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _brandBlue,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.shopping_bag_rounded,
            size: size * 0.72,
            color: Colors.white,
          ),
          Positioned(
            bottom: size * 0.20,
            child: Text(
              'M',
              style: TextStyle(
                color: _brandBlue,
                fontSize: size * 0.28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Positioned(
            right: size * 0.12,
            top: size * 0.12,
            child: Container(
              width: size * 0.22,
              height: size * 0.22,
              decoration: const BoxDecoration(
                color: Color(0xFFFFC107),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BadgeIcon extends StatelessWidget {
  const BadgeIcon({
    super.key,
    required this.icon,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Open alerts',
      child: IconButton(
        onPressed: onTap,
        icon: Badge(
          label: Text(count),
          backgroundColor: const Color(0xFFD93025),
          child: Icon(icon, size: 28),
        ),
      ),
    );
  }
}

class TopTabs extends StatelessWidget {
  const TopTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemBuilder: (context, index) {
          final selected = selectedIndex == index;
          return InkWell(
            onTap: () => onChanged(index),
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: index == 2 ? 132 : 108,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    labels[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? _brandBlue : _ink,
                      fontSize: 16,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 13),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 3,
                    width: selected ? 84 : 0,
                    decoration: BoxDecoration(
                      color: _brandBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemCount: labels.length,
      ),
    );
  }
}

class StoreHeroBanner extends StatelessWidget {
  const StoreHeroBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
      child: Container(
        height: 164,
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFF0B3D5C),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -12,
              top: -12,
              child: Icon(icon, size: 126, color: const Color(0xFFFFD166)),
            ),
            Positioned(
              left: 0,
              right: 92,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _TinyPill(text: 'Fresh Drops'),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFE8F2FF)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFD7C8FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF3F236D),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class TopChartsContent extends StatelessWidget {
  const TopChartsContent({
    super.key,
    required this.items,
    required this.onItemSelected,
    required this.actionLabelFor,
    required this.progressFor,
    required this.canUninstall,
    required this.onAction,
    required this.onUninstall,
  });

  final List<StoreItem> items;
  final ValueChanged<StoreItem> onItemSelected;
  final StoreItemLabelBuilder actionLabelFor;
  final StoreItemProgressBuilder progressFor;
  final StoreItemPredicate canUninstall;
  final ValueChanged<StoreItem> onAction;
  final ValueChanged<StoreItem> onUninstall;

  @override
  Widget build(BuildContext context) {
    final ranked = [...items]..sort((a, b) => b.rating.compareTo(a.rating));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  selected: true,
                  label: const Text('Phone'),
                  avatar: const Icon(Icons.check, size: 18),
                  onSelected: (_) {},
                ),
                const SizedBox(width: 10),
                FilterChip(
                  selected: true,
                  label: const Text('Top free'),
                  avatar: const Icon(Icons.check, size: 18),
                  onSelected: (_) {},
                ),
                const SizedBox(width: 10),
                ActionChip(
                  label: const Text('Categories'),
                  avatar: const Icon(Icons.tune, size: 18),
                  onPressed: () => showCategorySheet(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          for (final entry in ranked.asMap().entries)
            RankedAppTile(
              rank: entry.key + 1,
              item: entry.value,
              onTap: () => onItemSelected(entry.value),
              actionLabel: actionLabelFor(entry.value),
              progress: progressFor(entry.value),
              canUninstall: canUninstall(entry.value),
              onAction: () => onAction(entry.value),
              onUninstall: () => onUninstall(entry.value),
            ),
        ],
      ),
    );
  }
}

class SectionBlock extends StatelessWidget {
  const SectionBlock({
    super.key,
    required this.title,
    required this.items,
    required this.onItemSelected,
    required this.actionLabelFor,
    required this.progressFor,
    required this.canUninstall,
    required this.onAction,
    required this.onUninstall,
    this.eyebrow,
    this.subtitle,
  });

  final String? eyebrow;
  final String title;
  final String? subtitle;
  final List<StoreItem> items;
  final ValueChanged<StoreItem> onItemSelected;
  final StoreItemLabelBuilder actionLabelFor;
  final StoreItemProgressBuilder progressFor;
  final StoreItemPredicate canUninstall;
  final ValueChanged<StoreItem> onAction;
  final ValueChanged<StoreItem> onUninstall;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            eyebrow: eyebrow,
            title: title,
            subtitle: subtitle,
            onSeeMore: () => showFullListPage(
              context: context,
              title: title,
              items: items,
              onItemSelected: onItemSelected,
              actionLabelFor: actionLabelFor,
              progressFor: progressFor,
              canUninstall: canUninstall,
              onAction: onAction,
              onUninstall: onUninstall,
            ),
          ),
          const SizedBox(height: 14),
          for (final item in items)
            AppListTile(
              item: item,
              onTap: () => onItemSelected(item),
              actionLabel: actionLabelFor(item),
              progress: progressFor(item),
              canUninstall: canUninstall(item),
              onAction: () => onAction(item),
              onUninstall: () => onUninstall(item),
            ),
        ],
      ),
    );
  }
}

class HorizontalSection extends StatelessWidget {
  const HorizontalSection({
    super.key,
    required this.title,
    required this.items,
    required this.onItemSelected,
    this.actionLabelFor,
    this.progressFor,
    this.canUninstall,
    this.onAction,
    this.onUninstall,
  });

  final String title;
  final List<StoreItem> items;
  final ValueChanged<StoreItem> onItemSelected;
  final StoreItemLabelBuilder? actionLabelFor;
  final StoreItemProgressBuilder? progressFor;
  final StoreItemPredicate? canUninstall;
  final ValueChanged<StoreItem>? onAction;
  final ValueChanged<StoreItem>? onUninstall;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SectionHeader(
              title: title,
              onSeeMore:
                  actionLabelFor == null ||
                      progressFor == null ||
                      canUninstall == null ||
                      onAction == null ||
                      onUninstall == null
                  ? null
                  : () => showFullListPage(
                      context: context,
                      title: title,
                      items: items,
                      onItemSelected: onItemSelected,
                      actionLabelFor: actionLabelFor!,
                      progressFor: progressFor!,
                      canUninstall: canUninstall!,
                      onAction: onAction!,
                      onUninstall: onUninstall!,
                    ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 214,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemBuilder: (context, index) {
                final item = items[index];
                return AppCard(item: item, onTap: () => onItemSelected(item));
              },
              separatorBuilder: (_, _) => const SizedBox(width: 18),
              itemCount: items.length,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.onSeeMore,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final VoidCallback? onSeeMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(color: _ink),
                  children: [
                    if (eyebrow != null)
                      TextSpan(
                        text: '$eyebrow - ',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    TextSpan(
                      text: title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'See more',
          onPressed: onSeeMore ?? () => showCategorySheet(context),
          icon: const Icon(Icons.arrow_forward),
        ),
      ],
    );
  }
}

class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.item,
    required this.onTap,
    this.actionLabel,
    this.progress,
    this.canUninstall = false,
    this.onAction,
    this.onUninstall,
  });

  final StoreItem item;
  final VoidCallback onTap;
  final String? actionLabel;
  final double? progress;
  final bool canUninstall;
  final VoidCallback? onAction;
  final VoidCallback? onUninstall;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel ?? _defaultActionText(item);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StoreIcon(item: item, size: 62),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${item.category} - ${item.summary}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      RatingPill(rating: item.rating),
                      if (item.installed) const StatusPill(text: 'Installed'),
                      if (item.updateAvailable)
                        const StatusPill(text: 'Update'),
                      if (item.price != null) StatusPill(text: item.price!),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StoreActionControls(
              label: label,
              progress: progress,
              canUninstall: canUninstall,
              onAction:
                  onAction ?? () => _showSnack(context, '$label selected.'),
              onUninstall:
                  onUninstall ??
                  () => _showSnack(context, 'Uninstall ${item.name}.'),
            ),
          ],
        ),
      ),
    );
  }
}

class RankedAppTile extends StatelessWidget {
  const RankedAppTile({
    super.key,
    required this.rank,
    required this.item,
    required this.onTap,
    this.actionLabel,
    this.progress,
    this.canUninstall = false,
    this.onAction,
    this.onUninstall,
  });

  final int rank;
  final StoreItem item;
  final VoidCallback onTap;
  final String? actionLabel;
  final double? progress;
  final bool canUninstall;
  final VoidCallback? onAction;
  final VoidCallback? onUninstall;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel ?? _defaultActionText(item);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: _muted),
              ),
            ),
            const SizedBox(width: 14),
            StoreIcon(item: item, size: 64),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      RatingPill(rating: item.rating),
                      if (item.installed) const StatusPill(text: 'Installed'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            StoreActionControls(
              compact: true,
              label: label,
              progress: progress,
              canUninstall: canUninstall,
              onAction:
                  onAction ?? () => _showSnack(context, '$label selected.'),
              onUninstall:
                  onUninstall ??
                  () => _showSnack(context, 'Uninstall ${item.name}.'),
            ),
          ],
        ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.item, required this.onTap});

  final StoreItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 138,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StoreIcon(item: item, size: 118),
            const SizedBox(height: 10),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                height: 1.15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            RatingPill(rating: item.rating),
          ],
        ),
      ),
    );
  }
}

class StoreIcon extends StatelessWidget {
  const StoreIcon({super.key, required this.item, this.size = 64});

  final StoreItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: item.color,
        borderRadius: BorderRadius.circular(size >= 96 ? 8 : 14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: item.iconUrl == null
          ? Icon(item.icon, color: Colors.white, size: size * 0.48)
          : ClipRRect(
              borderRadius: BorderRadius.circular(size >= 96 ? 8 : 14),
              child: Image.network(
                item.iconUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Icon(item.icon, color: Colors.white, size: size * 0.48),
              ),
            ),
    );
  }
}

class RatingPill extends StatelessWidget {
  const RatingPill({super.key, required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.star, size: 14, color: _brandBlue),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13, color: _muted)),
    );
  }
}

class StoreActionControls extends StatelessWidget {
  const StoreActionControls({
    super.key,
    required this.label,
    required this.onAction,
    this.progress,
    this.canUninstall = false,
    this.onUninstall,
    this.compact = false,
  });

  final String label;
  final double? progress;
  final bool canUninstall;
  final VoidCallback onAction;
  final VoidCallback? onUninstall;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 84.0 : 104.0;
    final value = progress?.clamp(0.0, 1.0).toDouble();

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (value != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: const Color(0xFFE4E9EF),
                color: _brandBlue,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _brandBlue,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ] else
            SizedBox(
              height: 36,
              child: FilledButton.tonal(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                child: FittedBox(child: Text(label)),
              ),
            ),
          if (canUninstall) ...[
            const SizedBox(height: 2),
            IconButton(
              tooltip: 'Remove from library',
              onPressed: onUninstall,
              icon: const Icon(Icons.delete_outline, size: 19),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}

class AppDetailsPage extends StatelessWidget {
  const AppDetailsPage({
    super.key,
    required this.item,
    required this.api,
    required this.session,
    required this.statusRevision,
    required this.actionLabelFor,
    required this.progressFor,
    required this.canUninstall,
    required this.onAction,
    required this.onUninstall,
  });

  final StoreItem item;
  final MatjariApi api;
  final AuthSession? session;
  final ValueListenable<int> statusRevision;
  final StoreItemLabelBuilder actionLabelFor;
  final StoreItemProgressBuilder progressFor;
  final StoreItemPredicate canUninstall;
  final ValueChanged<StoreItem> onAction;
  final ValueChanged<StoreItem> onUninstall;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Share',
            onPressed: () => _showSnack(context, 'Share link copied.'),
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: 'More options',
            onPressed: () => _showSnack(context, 'App options opened.'),
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: statusRevision,
        builder: (context, _, _) {
          final currentProgress = progressFor(item);
          final progressValue = currentProgress?.clamp(0.0, 1.0).toDouble();
          final actionText = actionLabelFor(item);
          final uninstallReady = canUninstall(item);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StoreIcon(item: item, size: 88),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.category,
                          style: const TextStyle(
                            color: _brandBlue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.summary,
                          style: const TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: progressValue == null
                          ? () => onAction(item)
                          : null,
                      child: Text(actionText),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _showSnack(context, 'Auto-update toggled.'),
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('Auto'),
                  ),
                ],
              ),
              if (progressValue != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFE4E9EF),
                    color: _brandBlue,
                  ),
                ),
              ],
              if (uninstallReady) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => onUninstall(item),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Uninstall'),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InfoMetric(
                    label: 'Rating',
                    value: item.rating.toStringAsFixed(1),
                  ),
                  InfoMetric(label: 'Downloads', value: item.downloads),
                  InfoMetric(label: 'Size', value: item.size),
                  InfoMetric(label: 'Version', value: item.version),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                'Screenshots',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 172,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) =>
                      ScreenshotPreview(item: item, index: index),
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemCount: 4,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'About this app',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                item.summary,
                style: const TextStyle(color: _muted, height: 1.45),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  StatusPill(text: item.category),
                  const StatusPill(text: 'Phone'),
                  const StatusPill(text: 'Android'),
                  if (item.updateAvailable)
                    const StatusPill(text: 'Update available'),
                ],
              ),
              const SizedBox(height: 28),
              AppInfoPanel(item: item),
              const SizedBox(height: 22),
              CompatibilityPanel(item: item),
              const SizedBox(height: 22),
              PermissionsPanel(item: item),
              const SizedBox(height: 28),
              const Text(
                'Ratings and reviews',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              RatingSummary(rating: item.rating),
              const SizedBox(height: 22),
              ReviewsPanel(item: item, api: api, session: session),
            ],
          );
        },
      ),
    );
  }
}

class InfoMetric extends StatelessWidget {
  const InfoMetric({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class AppInfoPanel extends StatelessWidget {
  const AppInfoPanel({super.key, required this.item});

  final StoreItem item;

  @override
  Widget build(BuildContext context) {
    return DetailsSection(
      title: 'App info',
      children: [
        DetailsRow(label: 'Version', value: item.version),
        DetailsRow(label: 'Updated on', value: item.updatedOn),
        DetailsRow(label: 'Downloads', value: item.downloads),
        const DetailsRow(label: 'Required OS', value: 'Android 5.0 and up'),
        DetailsRow(label: 'Offered by', value: item.offeredBy),
        DetailsRow(label: 'Released on', value: item.releasedOn),
      ],
    );
  }
}

class CompatibilityPanel extends StatelessWidget {
  const CompatibilityPanel({super.key, required this.item});

  final StoreItem item;

  @override
  Widget build(BuildContext context) {
    return DetailsSection(
      title: 'Compatibility for your active devices',
      trailing: const Icon(Icons.info_outline, color: _muted),
      children: [
        const DetailsRow(label: 'This device', value: 'Works on your device'),
        DetailsRow(label: 'Platform', value: item.platform.toUpperCase()),
        DetailsRow(label: 'Installed version', value: item.version),
      ],
    );
  }
}

class PermissionsPanel extends StatelessWidget {
  const PermissionsPanel({super.key, required this.item});

  final StoreItem item;

  @override
  Widget build(BuildContext context) {
    final permissions = _permissionsFor(item);
    return DetailsSection(
      title: 'App permissions',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final permission in permissions) StatusPill(text: permission),
          ],
        ),
      ],
    );
  }
}

class DetailsSection extends StatelessWidget {
  const DetailsSection({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _line)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class DetailsRow extends StatelessWidget {
  const DetailsRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class ScreenshotPreview extends StatelessWidget {
  const ScreenshotPreview({super.key, required this.item, required this.index});

  final StoreItem item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final titles = ['Home', 'Charts', 'Details', 'Reviews'];
    final imageUrl = index < item.screenshotUrls.length
        ? item.screenshotUrls[index]
        : null;
    return Container(
      width: 118,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: index.isEven ? _softBlue : const Color(0xFFFFF4D7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => StoreIcon(item: item, size: 36),
                ),
              ),
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: StoreIcon(item: item, size: 36),
            ),
          const Spacer(),
          Text(
            titles[index],
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Container(height: 7, width: 78, color: Colors.white),
          const SizedBox(height: 6),
          Container(height: 7, width: 56, color: Colors.white),
        ],
      ),
    );
  }
}

class RatingSummary extends StatelessWidget {
  const RatingSummary({super.key, required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 54,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.star, color: _brandBlue, size: 17),
                  Icon(Icons.star, color: _brandBlue, size: 17),
                  Icon(Icons.star, color: _brandBlue, size: 17),
                  Icon(Icons.star, color: _brandBlue, size: 17),
                  Icon(Icons.star_half, color: _brandBlue, size: 17),
                ],
              ),
              const SizedBox(height: 4),
              const Text('85,994', style: TextStyle(color: _muted)),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            children: [
              for (var i = 5; i >= 1; i--)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(width: 18, child: Text('$i')),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            minHeight: 10,
                            value: i == 5 ? 0.78 : (6 - i) * 0.07,
                            backgroundColor: const Color(0xFFE4E9EF),
                            color: _brandBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class ReviewsPanel extends StatefulWidget {
  const ReviewsPanel({
    super.key,
    required this.item,
    required this.api,
    required this.session,
  });

  final StoreItem item;
  final MatjariApi api;
  final AuthSession? session;

  @override
  State<ReviewsPanel> createState() => _ReviewsPanelState();
}

class _ReviewsPanelState extends State<ReviewsPanel> {
  int _revision = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReviewComposer(
          item: widget.item,
          api: widget.api,
          session: widget.session,
          onSubmitted: () => setState(() => _revision++),
        ),
        const SizedBox(height: 22),
        ApiReviews(
          key: ValueKey('${widget.item.id}-$_revision'),
          item: widget.item,
          api: widget.api,
        ),
      ],
    );
  }
}

class ReviewComposer extends StatefulWidget {
  const ReviewComposer({
    super.key,
    required this.item,
    required this.api,
    required this.session,
    required this.onSubmitted,
  });

  final StoreItem item;
  final MatjariApi api;
  final AuthSession? session;
  final VoidCallback onSubmitted;

  @override
  State<ReviewComposer> createState() => _ReviewComposerState();
}

class _ReviewComposerState extends State<ReviewComposer> {
  final _commentController = TextEditingController();
  int _rating = 5;
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.session == null) {
      return _ReviewNotice(
        icon: Icons.login_outlined,
        text: 'Sign in to write a review.',
      );
    }

    if (widget.item.id.isEmpty) {
      return _ReviewNotice(
        icon: Icons.cloud_off_outlined,
        text: 'Connect to the API before reviewing this item.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Write a review',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var index = 1; index <= 5; index++)
                IconButton(
                  tooltip: 'Rate $index stars',
                  onPressed: _submitting
                      ? null
                      : () => setState(() => _rating = index),
                  icon: Icon(
                    index <= _rating ? Icons.star : Icons.star_border,
                    color: _brandBlue,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Review',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              label: Text(_submitting ? 'Sending' : 'Submit review'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      _showSnack(context, 'Write a short review first.');
      return;
    }

    final session = widget.session;
    if (session == null) return;

    setState(() => _submitting = true);
    try {
      await widget.api.submitReview(
        token: session.token,
        item: widget.item,
        rating: _rating,
        comment: comment,
      );
      _commentController.clear();
      widget.onSubmitted();
      if (mounted) _showSnack(context, 'Review submitted.');
    } catch (error) {
      if (mounted) _showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _ReviewNotice extends StatelessWidget {
  const _ReviewNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8D49B)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8A5A00)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF6F4A00),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ApiReviews extends StatelessWidget {
  const ApiReviews({super.key, required this.item, required this.api});

  final StoreItem item;
  final MatjariApi api;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: api.fetchReviews(item.id),
      builder: (context, snapshot) {
        final reviews = snapshot.data ?? const <Map<String, dynamic>>[];
        if (reviews.isEmpty) {
          return const Column(
            children: [
              ReviewTile(
                name: 'Sai',
                date: '2026-06-01',
                comment:
                    'Clean design, fast browsing, and the download status is easy to understand.',
              ),
              ReviewTile(
                name: 'Mary Winholtz',
                date: '2026-06-23',
                comment:
                    'The categories are clear and the app page feels familiar.',
              ),
            ],
          );
        }

        return Column(
          children: [
            for (final review in reviews)
              ReviewTile(
                name: _reviewName(review),
                date:
                    _stringValue(review['created_at'])?.split('T').first ?? '',
                comment: _stringValue(review['comment']) ?? '',
              ),
          ],
        );
      },
    );
  }

  static String _reviewName(Map<String, dynamic> review) {
    final user = review['user'] is Map<String, dynamic>
        ? review['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    return _stringValue(user['full_name']) ??
        _stringValue(user['email']) ??
        'Matjari user';
  }
}

class ReviewTile extends StatelessWidget {
  const ReviewTile({
    super.key,
    required this.name,
    required this.date,
    required this.comment,
  });

  final String name;
  final String date;
  final String comment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFEAF1F8),
                child: Text(name.characters.first),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Review options',
                onPressed: () => _showSnack(context, 'Review options opened.'),
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                const Icon(Icons.star, color: _brandBlue, size: 16),
              const SizedBox(width: 10),
              Text(date, style: const TextStyle(color: _muted)),
            ],
          ),
          const SizedBox(height: 8),
          Text(comment, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 12),
          const Text(
            'Was this review helpful?',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton(onPressed: () {}, child: const Text('Yes')),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () {}, child: const Text('No')),
            ],
          ),
        ],
      ),
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.items,
    required this.categories,
    required this.onItemSelected,
    required this.actionLabelFor,
    required this.progressFor,
    required this.canUninstall,
    required this.onAction,
    required this.onUninstall,
  });

  final List<StoreItem> items;
  final List<StoreCategory> categories;
  final ValueChanged<StoreItem> onItemSelected;
  final StoreItemLabelBuilder actionLabelFor;
  final StoreItemProgressBuilder progressFor;
  final StoreItemPredicate canUninstall;
  final ValueChanged<StoreItem> onAction;
  final ValueChanged<StoreItem> onUninstall;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = widget.items
        .where(
          (item) =>
              item.name.toLowerCase().contains(_query.toLowerCase()) ||
              item.category.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        TextField(
          onChanged: (value) => setState(() => _query = value.trim()),
          decoration: InputDecoration(
            hintText: 'Search apps, games, and books',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'Voice search',
              onPressed: () =>
                  _showSnack(context, 'Voice search is coming soon.'),
              icon: const Icon(Icons.mic_none),
            ),
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const SectionHeader(title: 'Categories'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final category
                in widget.categories.map((item) => item.name).take(12))
              ActionChip(
                backgroundColor: Colors.white,
                side: const BorderSide(color: _line),
                labelStyle: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                ),
                label: Text(category),
                onPressed: () => setState(() => _query = category),
              ),
          ],
        ),
        const SizedBox(height: 28),
        SectionHeader(title: _query.isEmpty ? 'More apps to try' : 'Results'),
        const SizedBox(height: 12),
        for (final item in results)
          AppListTile(
            item: item,
            onTap: () => widget.onItemSelected(item),
            actionLabel: widget.actionLabelFor(item),
            progress: widget.progressFor(item),
            canUninstall: widget.canUninstall(item),
            onAction: () => widget.onAction(item),
            onUninstall: () => widget.onUninstall(item),
          ),
      ],
    );
  }
}

class BooksPage extends StatelessWidget {
  const BooksPage({
    super.key,
    required this.items,
    required this.onItemSelected,
    required this.actionLabelFor,
    required this.progressFor,
    required this.canUninstall,
    required this.onAction,
    required this.onUninstall,
  });

  final List<StoreItem> items;
  final ValueChanged<StoreItem> onItemSelected;
  final StoreItemLabelBuilder actionLabelFor;
  final StoreItemProgressBuilder progressFor;
  final StoreItemPredicate canUninstall;
  final ValueChanged<StoreItem> onAction;
  final ValueChanged<StoreItem> onUninstall;

  @override
  Widget build(BuildContext context) {
    final books = items.where((item) => item.type == 'books').toList();
    final visibleBooks = books.isEmpty
        ? _items.where((item) => item.type == 'books').toList()
        : books;
    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search Books',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: const Icon(Icons.mic_none),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        TopTabs(
          labels: const ['Ebooks', 'Audiobooks', 'Comics', 'Genres'],
          selectedIndex: 0,
          onChanged: (_) {},
        ),
        const Divider(height: 1),
        HorizontalSection(
          title: 'Try before you buy',
          items: visibleBooks,
          onItemSelected: onItemSelected,
          actionLabelFor: actionLabelFor,
          progressFor: progressFor,
          canUninstall: canUninstall,
          onAction: onAction,
          onUninstall: onUninstall,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
          child: Container(
            height: 220,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFF335C67),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Books to read this week',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Fresh fiction, practical guides, and editor picks.',
                        style: TextStyle(color: Color(0xFFE8F2FF)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                for (final book in visibleBooks.take(2))
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: StoreIcon(item: book, size: 76),
                  ),
              ],
            ),
          ),
        ),
        SectionBlock(
          title: 'Read it before you watch it',
          items: visibleBooks,
          onItemSelected: onItemSelected,
          actionLabelFor: actionLabelFor,
          progressFor: progressFor,
          canUninstall: canUninstall,
          onAction: onAction,
          onUninstall: onUninstall,
        ),
      ],
    );
  }
}

class YouPage extends StatelessWidget {
  const YouPage({
    super.key,
    required this.api,
    required this.items,
    required this.session,
    required this.onSessionChanged,
    required this.onLogout,
    required this.onItemSelected,
    required this.onRefresh,
    required this.actionLabelFor,
    required this.progressFor,
    required this.canUninstall,
    required this.onAction,
    required this.onUninstall,
  });

  final MatjariApi api;
  final List<StoreItem> items;
  final AuthSession? session;
  final ValueChanged<AuthSession> onSessionChanged;
  final VoidCallback onLogout;
  final ValueChanged<StoreItem> onItemSelected;
  final VoidCallback onRefresh;
  final StoreItemLabelBuilder actionLabelFor;
  final StoreItemProgressBuilder progressFor;
  final StoreItemPredicate canUninstall;
  final ValueChanged<StoreItem> onAction;
  final ValueChanged<StoreItem> onUninstall;

  @override
  Widget build(BuildContext context) {
    final installed = items.where(canUninstall).toList();
    final visibleInstalled = installed.isEmpty
        ? items.take(4).toList()
        : installed;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'You',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Settings',
              onPressed: () => showAppSettingsSheet(context),
              icon: const Icon(Icons.more_vert),
            ),
          ],
        ),
        const SizedBox(height: 18),
        AccountSummaryCard(session: session, onLogout: onLogout),
        const SizedBox(height: 22),
        OverviewRow(
          icon: Icons.verified_user_outlined,
          title: 'Your device is protected',
          subtitle: 'No harmful apps found',
          action: 'Details',
          color: Color(0xFF188038),
          onTap: () => _showSnack(context, 'Device protection looks good.'),
        ),
        OverviewRow(
          icon: Icons.system_update_alt,
          title: 'Updates available',
          subtitle:
              '${items.where((item) => item.forceUpdate || item.updateAvailable).length} apps need attention',
          action: 'Refresh',
          color: Color(0xFFF29900),
          onTap: onRefresh,
        ),
        OverviewRow(
          icon: Icons.storage_outlined,
          title: 'Storage',
          subtitle: 'Review installed apps and remove what you do not need',
          action: 'Manage',
          color: _brandBlue,
          onTap: () => showFullListPage(
            context: context,
            title: 'Installed apps',
            items: visibleInstalled,
            onItemSelected: onItemSelected,
            actionLabelFor: actionLabelFor,
            progressFor: progressFor,
            canUninstall: canUninstall,
            onAction: onAction,
            onUninstall: onUninstall,
          ),
        ),
        OverviewRow(
          icon: Icons.rate_review_outlined,
          title: 'Your contributions',
          subtitle: 'Reviews help people trust the store',
          action: 'Write review',
          color: Color(0xFF6C3DD9),
          onTap: () =>
              _showSnack(context, 'Open an app page to write a review.'),
        ),
        OverviewRow(
          icon: Icons.info_outline,
          title: 'App settings',
          subtitle: 'Version, API, privacy, and store information',
          action: 'Settings',
          color: Color(0xFF455A64),
          onTap: () => showAppSettingsSheet(context),
        ),
        if (session?.role == 'admin') ...[
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AdminDashboardPage(
                  api: api,
                  apps: items.where((item) => item.type != 'books').toList(),
                  session: session!,
                  onChanged: onRefresh,
                ),
              ),
            ),
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: const Text('Admin dashboard'),
          ),
          const SizedBox(height: 18),
        ],
        const SizedBox(height: 26),
        SectionHeader(
          title: 'Installed apps (${visibleInstalled.length})',
          onSeeMore: () => showFullListPage(
            context: context,
            title: 'Installed apps',
            items: visibleInstalled,
            onItemSelected: onItemSelected,
            actionLabelFor: actionLabelFor,
            progressFor: progressFor,
            canUninstall: canUninstall,
            onAction: onAction,
            onUninstall: onUninstall,
          ),
        ),
        const SizedBox(height: 10),
        for (final item in visibleInstalled)
          AppListTile(
            item: item,
            onTap: () => onItemSelected(item),
            actionLabel: actionLabelFor(item),
            progress: progressFor(item),
            canUninstall: canUninstall(item),
            onAction: () => onAction(item),
            onUninstall: () => onUninstall(item),
          ),
      ],
    );
  }
}

class AccountPanel extends StatefulWidget {
  const AccountPanel({
    super.key,
    required this.api,
    required this.session,
    required this.onSessionChanged,
    required this.onLogout,
  });

  final MatjariApi api;
  final AuthSession? session;
  final ValueChanged<AuthSession> onSessionChanged;
  final VoidCallback onLogout;

  @override
  State<AccountPanel> createState() => _AccountPanelState();
}

class _AccountPanelState extends State<AccountPanel> {
  final _emailController = TextEditingController(text: 'user@matjari.local');
  final _nameController = TextEditingController(text: 'Matjari User');
  final _passwordController = TextEditingController(text: '123456');
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    if (session != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE7F6ED),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFB9E4C9)),
        ),
        child: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.person)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${session.role} - ${session.email.ifEmpty('local session')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: widget.onLogout,
              child: const Text('Logout'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'User account',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Full name'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : () => _login(register: false),
                  child: const Text('Login'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _loading ? null : () => _login(register: true),
                  child: Text(_loading ? 'Please wait' : 'Register'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _login({required bool register}) async {
    setState(() => _loading = true);
    try {
      final session = register
          ? await widget.api.register(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              fullName: _nameController.text.trim(),
            )
          : await widget.api.login(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );
      widget.onSessionChanged(session);
      if (mounted) _showSnack(context, 'Signed in as ${session.name}.');
    } catch (error) {
      if (mounted) _showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({
    super.key,
    required this.api,
    required this.onSessionChanged,
  });

  final MatjariApi api;
  final ValueChanged<AuthSession> onSessionChanged;

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController(text: '123456');
  bool _loading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin login')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          const MatjariMark(size: 64),
          const SizedBox(height: 18),
          const Text(
            'Sign in to manage Matjari',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _loading ? null : _login,
            icon: const Icon(Icons.login),
            label: Text(_loading ? 'Signing in' : 'Login'),
          ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      final session = await widget.api.adminLogin(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      widget.onSessionChanged(session);
      if (!mounted) return;
      Navigator.pop(context);
      _showSnack(context, 'Admin login successful.');
    } catch (error) {
      if (mounted) _showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class OverviewRow extends StatelessWidget {
  const OverviewRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String action;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(subtitle, style: const TextStyle(color: _muted)),
                    const SizedBox(height: 12),
                    Text(
                      action,
                      style: const TextStyle(
                        color: _brandBlue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AccountSummaryCard extends StatelessWidget {
  const AccountSummaryCard({
    super.key,
    required this.session,
    required this.onLogout,
  });

  final AuthSession? session;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final current = session;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F2FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC9DCF8)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _brandBlue,
            foregroundColor: Colors.white,
            child: Text((current?.name ?? 'M').characters.first),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current?.name ?? 'Matjari User',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  '${current?.role ?? 'user'} - ${current?.email ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          OutlinedButton(onPressed: onLogout, child: const Text('Logout')),
        ],
      ),
    );
  }
}

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({
    super.key,
    required this.api,
    required this.apps,
    required this.session,
    required this.onChanged,
  });

  final MatjariApi api;
  final List<StoreItem> apps;
  final AuthSession session;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin dashboard')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          const SectionHeader(
            title: 'Manage applications',
            subtitle: 'Upload, edit, update, and review store listings.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => _showEditSheet(
                  context,
                  api: api,
                  session: session,
                  onSaved: onChanged,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add app'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AdminAnalyticsPage(api: api, session: session),
                  ),
                ),
                icon: const Icon(Icons.bar_chart),
                label: const Text('Analytics'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          for (final app in apps)
            AdminAppRow(
              item: app,
              onEdit: () => _showEditSheet(
                context,
                item: app,
                api: api,
                session: session,
                onSaved: onChanged,
              ),
              onUpdate: () => _showUpdateSheet(
                context,
                app: app,
                api: api,
                session: session,
                onSaved: onChanged,
              ),
              onDelete: () => _confirmDeleteApp(
                context,
                app: app,
                api: api,
                session: session,
                onDeleted: onChanged,
              ),
            ),
        ],
      ),
    );
  }
}

class AdminAnalyticsPage extends StatelessWidget {
  const AdminAnalyticsPage({
    super.key,
    required this.api,
    required this.session,
  });

  final MatjariApi api;
  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads analytics')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: api.fetchAnalytics(session.token),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final payload = snapshot.data ?? const <String, dynamic>{};
          final summary = payload['summary'] is Map<String, dynamic>
              ? payload['summary'] as Map<String, dynamic>
              : <String, dynamic>{};
          final apps = payload['apps'] is List
              ? (payload['apps'] as List)
                    .whereType<Map<String, dynamic>>()
                    .toList()
              : <Map<String, dynamic>>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  AnalyticsMetric(
                    label: 'Apps',
                    value: '${summary['apps_count'] ?? 0}',
                  ),
                  AnalyticsMetric(
                    label: 'Active',
                    value: '${summary['active_apps_count'] ?? 0}',
                  ),
                  AnalyticsMetric(
                    label: 'Downloads',
                    value: '${summary['downloads_count'] ?? 0}',
                  ),
                  AnalyticsMetric(
                    label: 'Installs',
                    value: '${summary['installs_count'] ?? 0}',
                  ),
                  AnalyticsMetric(
                    label: 'Reviews',
                    value: '${summary['reviews_count'] ?? 0}',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'By app'),
              const SizedBox(height: 12),
              for (final app in apps)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: _line),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.analytics_outlined, color: _brandBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _stringValue(app['name']) ?? 'App',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${app['downloads_count'] ?? 0} downloads - ${app['installs_count'] ?? 0} installs - ${app['reviews_count'] ?? 0} reviews',
                              style: const TextStyle(color: _muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class AnalyticsMetric extends StatelessWidget {
  const AnalyticsMetric({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: _muted)),
        ],
      ),
    );
  }
}

class AdminAppRow extends StatelessWidget {
  const AdminAppRow({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onUpdate,
    required this.onDelete,
  });

  final StoreItem item;
  final VoidCallback onEdit;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          StoreIcon(item: item, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.category} - ${item.version} - Android',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit app',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Release update',
                onPressed: onUpdate,
                icon: const Icon(Icons.system_update_alt),
              ),
              IconButton(
                tooltip: 'Delete app',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmDeleteApp(
  BuildContext context, {
  required StoreItem app,
  required MatjariApi api,
  required AuthSession session,
  required VoidCallback onDeleted,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete app'),
      content: Text(
        'Delete ${app.name} and its downloads, reviews, and updates?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    await api.deleteApp(token: session.token, app: app);
    onDeleted();
    if (context.mounted) _showSnack(context, 'App deleted.');
  } catch (error) {
    if (context.mounted) _showSnack(context, error.toString());
  }
}

void _showUpdateSheet(
  BuildContext context, {
  required StoreItem app,
  required MatjariApi api,
  required AuthSession session,
  required VoidCallback onSaved,
}) {
  final versionController = TextEditingController(text: app.version);
  final versionCodeController = TextEditingController(
    text: '${app.versionCode + 1}',
  );
  final fileUrlController = TextEditingController(text: app.fileUrl ?? '');
  final changelogController = TextEditingController();
  var forceUpdate = app.forceUpdate;
  var saving = false;
  var uploadingFile = false;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Release update',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(app.name, style: const TextStyle(color: _muted)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: versionController,
                    decoration: const InputDecoration(labelText: 'Version'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: versionCodeController,
                    decoration: const InputDecoration(labelText: 'Build'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: fileUrlController,
              decoration: const InputDecoration(
                labelText: 'New APK / file URL',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: saving || uploadingFile
                  ? null
                  : () async {
                      setSheetState(() => uploadingFile = true);
                      try {
                        final uploads = await _pickAndUploadAdminFile(
                          endpoint: '/api/uploads/app-file',
                          token: session.token,
                          fieldName: 'file',
                          mimeType: 'application/vnd.android.package-archive',
                        );
                        if (uploads.isNotEmpty) {
                          final upload = uploads.first;
                          fileUrlController.text = upload.url;
                          if (upload.versionName != null) {
                            versionController.text = upload.versionName!;
                          }
                          if (upload.versionCode != null) {
                            versionCodeController.text =
                                '${upload.versionCode}';
                          }
                          if (context.mounted) {
                            _showSnack(context, 'APK uploaded.');
                          }
                        }
                      } catch (error) {
                        if (context.mounted) {
                          _showSnack(context, error.toString());
                        }
                      } finally {
                        if (sheetContext.mounted) {
                          setSheetState(() => uploadingFile = false);
                        }
                      }
                    },
              icon: const Icon(Icons.upload_file),
              label: Text(uploadingFile ? 'Uploading APK' : 'Upload APK'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: changelogController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Changelog'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Force update'),
              value: forceUpdate,
              onChanged: (value) => setSheetState(() => forceUpdate = value),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: saving ? null : 1.0,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      setSheetState(() => saving = true);
                      try {
                        await api.releaseUpdate(
                          token: session.token,
                          app: app,
                          versionName: versionController.text.trim(),
                          versionCode:
                              int.tryParse(versionCodeController.text.trim()) ??
                              app.versionCode + 1,
                          fileUrl: fileUrlController.text.trim(),
                          forceUpdate: forceUpdate,
                          changelog: changelogController.text.trim(),
                        );
                        onSaved();
                        if (context.mounted) {
                          Navigator.pop(sheetContext);
                          _showSnack(context, 'Update released.');
                        }
                      } catch (error) {
                        if (context.mounted) {
                          _showSnack(context, error.toString());
                        }
                      } finally {
                        if (sheetContext.mounted) {
                          setSheetState(() => saving = false);
                        }
                      }
                    },
              icon: const Icon(Icons.system_update_alt),
              label: Text(saving ? 'Releasing' : 'Release update'),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showEditSheet(
  BuildContext context, {
  StoreItem? item,
  required MatjariApi api,
  required AuthSession session,
  required VoidCallback onSaved,
}) {
  final nameController = TextEditingController(text: item?.name ?? '');
  final packageController = TextEditingController(
    text:
        item?.packageName.ifEmpty('com.matjari.example') ??
        'com.matjari.example',
  );
  final descriptionController = TextEditingController(
    text: item?.summary ?? '',
  );
  final versionController = TextEditingController(
    text: item?.version ?? '1.0.0',
  );
  final versionCodeController = TextEditingController(
    text: '${item?.versionCode ?? 1}',
  );
  final sizeController = TextEditingController(text: item?.size ?? 'Unknown');
  final iconUrlController = TextEditingController(text: item?.iconUrl ?? '');
  final fileUrlController = TextEditingController(text: item?.fileUrl ?? '');
  final screenshotsController = TextEditingController(
    text: item?.screenshotUrls.join('\n') ?? '',
  );
  var forceUpdate = item?.forceUpdate ?? false;
  var saving = false;
  var uploadingIcon = false;
  var uploadingFile = false;
  var uploadingScreenshots = false;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              item == null ? 'Add app' : 'Edit app',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(labelText: 'App name'),
              controller: nameController,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(labelText: 'Package name'),
              controller: packageController,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(labelText: 'Description'),
              controller: descriptionController,
              minLines: 2,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Version'),
                    controller: versionController,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Build'),
                    controller: versionCodeController,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(labelText: 'Size'),
              controller: sizeController,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(labelText: 'Icon URL'),
              controller: iconUrlController,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: saving || uploadingIcon
                  ? null
                  : () async {
                      setSheetState(() => uploadingIcon = true);
                      try {
                        final uploads = await _pickAndUploadAdminFile(
                          endpoint: '/api/uploads/icon',
                          token: session.token,
                          fieldName: 'icon',
                          mimeType: 'image/*',
                        );
                        if (uploads.isNotEmpty) {
                          iconUrlController.text = uploads.first.url;
                          if (context.mounted) {
                            _showSnack(context, 'Icon uploaded.');
                          }
                        }
                      } catch (error) {
                        if (context.mounted) {
                          _showSnack(context, error.toString());
                        }
                      } finally {
                        if (sheetContext.mounted) {
                          setSheetState(() => uploadingIcon = false);
                        }
                      }
                    },
              icon: const Icon(Icons.image_outlined),
              label: Text(uploadingIcon ? 'Uploading icon' : 'Upload icon'),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(labelText: 'APK / file URL'),
              controller: fileUrlController,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: saving || uploadingFile
                  ? null
                  : () async {
                      setSheetState(() => uploadingFile = true);
                      try {
                        final uploads = await _pickAndUploadAdminFile(
                          endpoint: '/api/uploads/app-file',
                          token: session.token,
                          fieldName: 'file',
                          mimeType: 'application/vnd.android.package-archive',
                        );
                        if (uploads.isNotEmpty) {
                          final upload = uploads.first;
                          fileUrlController.text = upload.url;
                          if (upload.packageName != null) {
                            packageController.text = upload.packageName!;
                          }
                          if (upload.versionName != null) {
                            versionController.text = upload.versionName!;
                          }
                          if (upload.versionCode != null) {
                            versionCodeController.text =
                                '${upload.versionCode}';
                          }
                          if (upload.displaySize != null) {
                            sizeController.text = upload.displaySize!;
                          }
                          if (context.mounted) {
                            _showSnack(context, 'APK uploaded.');
                          }
                        }
                      } catch (error) {
                        if (context.mounted) {
                          _showSnack(context, error.toString());
                        }
                      } finally {
                        if (sheetContext.mounted) {
                          setSheetState(() => uploadingFile = false);
                        }
                      }
                    },
              icon: const Icon(Icons.upload_file),
              label: Text(uploadingFile ? 'Uploading APK' : 'Upload APK'),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Screenshot URLs',
                helperText: 'One URL per line',
              ),
              controller: screenshotsController,
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: saving || uploadingScreenshots
                  ? null
                  : () async {
                      setSheetState(() => uploadingScreenshots = true);
                      try {
                        final uploads = await _pickAndUploadAdminFile(
                          endpoint: '/api/uploads/screenshots',
                          token: session.token,
                          fieldName: 'screenshots',
                          mimeType: 'image/*',
                          allowMultiple: true,
                        );
                        if (uploads.isNotEmpty) {
                          final urls = uploads.map((upload) => upload.url);
                          final current = screenshotsController.text.trim();
                          screenshotsController.text = [
                            if (current.isNotEmpty) current,
                            ...urls,
                          ].join('\n');
                          if (context.mounted) {
                            _showSnack(context, 'Screenshots uploaded.');
                          }
                        }
                      } catch (error) {
                        if (context.mounted) {
                          _showSnack(context, error.toString());
                        }
                      } finally {
                        if (sheetContext.mounted) {
                          setSheetState(() => uploadingScreenshots = false);
                        }
                      }
                    },
              icon: const Icon(Icons.collections_outlined),
              label: Text(
                uploadingScreenshots
                    ? 'Uploading screenshots'
                    : 'Upload screenshots',
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Force update'),
              value: forceUpdate,
              onChanged: (value) => setSheetState(() => forceUpdate = value),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: saving
                  ? null
                  : item == null
                  ? 0.0
                  : 1.0,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      setSheetState(() => saving = true);
                      try {
                        await api.saveApp(
                          token: session.token,
                          existing: item,
                          name: nameController.text.trim(),
                          packageName: packageController.text.trim(),
                          description: descriptionController.text.trim(),
                          platform: 'android',
                          versionName: versionController.text.trim(),
                          versionCode:
                              int.tryParse(versionCodeController.text.trim()) ??
                              1,
                          size: sizeController.text.trim().ifEmpty('Unknown'),
                          iconUrl: iconUrlController.text.trim(),
                          fileUrl: fileUrlController.text.trim(),
                          screenshotUrls: _lines(screenshotsController.text),
                          forceUpdate: forceUpdate,
                        );
                        onSaved();
                        if (context.mounted) {
                          Navigator.pop(sheetContext);
                          _showSnack(context, 'App saved to backend.');
                        }
                      } catch (error) {
                        if (context.mounted) {
                          _showSnack(context, error.toString());
                        }
                      } finally {
                        if (sheetContext.mounted) {
                          setSheetState(() => saving = false);
                        }
                      }
                    },
              icon: const Icon(Icons.save_outlined),
              label: Text(saving ? 'Saving' : 'Save'),
            ),
          ],
        ),
      ),
    ),
  );
}

void showCategorySheet(
  BuildContext context, {
  List<StoreCategory> categories = _fallbackCategories,
}) {
  const fallbackNames = [
    'All categories',
    'Android Auto',
    'Art & Design',
    'Auto & Vehicles',
    'Beauty',
    'Books & Reference',
    'Business',
    'Communication',
    'Education',
    'Entertainment',
    'Finance',
    'Food & Drink',
    'Health & Fitness',
    'Maps & Navigation',
    'Productivity',
    'Shopping',
    'Social',
    'Tools',
    'Travel & Local',
    'Weather',
  ];
  final appCategories = categories.isEmpty
      ? fallbackNames
      : ['All categories', ...categories.map((category) => category.name)];

  showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        itemBuilder: (context, index) => ListTile(
          selected: index == 0,
          selectedTileColor: const Color(0xFFCDEBFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Text(appCategories[index]),
          onTap: () => Navigator.pop(context),
        ),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemCount: appCategories.length,
      ),
    ),
  );
}

void showFullListPage({
  required BuildContext context,
  required String title,
  required List<StoreItem> items,
  required ValueChanged<StoreItem> onItemSelected,
  required StoreItemLabelBuilder actionLabelFor,
  required StoreItemProgressBuilder progressFor,
  required StoreItemPredicate canUninstall,
  required ValueChanged<StoreItem> onAction,
  required ValueChanged<StoreItem> onUninstall,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Text(
                  'No items yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted),
                ),
              )
            else
              for (final item in items)
                AppListTile(
                  item: item,
                  onTap: () => onItemSelected(item),
                  actionLabel: actionLabelFor(item),
                  progress: progressFor(item),
                  canUninstall: canUninstall(item),
                  onAction: () => onAction(item),
                  onUninstall: () => onUninstall(item),
                ),
          ],
        ),
      ),
    ),
  );
}

void showAppSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const Row(
            children: [
              MatjariMark(size: 52),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Matjari',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Private Android app store',
                      style: TextStyle(color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const DetailsRow(label: 'Version', value: _appVersionName),
          const DetailsRow(label: 'Build', value: '$_appBuildNumber'),
          const DetailsRow(label: 'API', value: _apiBaseUrl),
          const DetailsRow(label: 'Install mode', value: 'Direct APK'),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy'),
            subtitle: const Text(
              'OTP sign-in and library sync are used for your store account.',
            ),
            onTap: () => _showSnack(context, 'Privacy information opened.'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('About Matjari'),
            subtitle: const Text(
              'Designed for private APK distribution without Play Store publishing.',
            ),
            onTap: () => _showSnack(
              context,
              'Matjari version $_appVersionName+$_appBuildNumber.',
            ),
          ),
        ],
      ),
    ),
  );
}

String _defaultActionText(StoreItem item) {
  if (item.updateAvailable) return 'Update';
  if (item.installed) return 'Open';
  if (item.type == 'books' && item.price != null) return item.price!;
  return 'Download';
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

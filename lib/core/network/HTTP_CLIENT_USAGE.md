# HTTP Client Usage Guide

## 📁 Location

```
lib/core/network/
├── http_client_interface.dart  # Interface definition
└── http_client.dart            # Implementation with Dio
```

## 🎯 Basic Usage

### 1. **Simple GET Request**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:defyx_vpn/core/network/http_client.dart';

class MyService {
  final IHttpClient _httpClient;

  MyService(this._httpClient);

  Future<Map<String, dynamic>> fetchData() async {
    try {
      final response = await _httpClient.get('/api/data');
      return response.data;
    } on NetworkException catch (e) {
      print('Network error: ${e.message}');
      rethrow;
    }
  }
}

// Provider
final myServiceProvider = Provider<MyService>((ref) {
  final httpClient = ref.watch(httpClientProvider);
  return MyService(httpClient);
});
```

### 2. **POST Request with Data**

```dart
Future<void> sendData(Map<String, dynamic> data) async {
  final httpClient = ref.read(httpClientProvider);

  try {
    final response = await httpClient.post(
      '/api/users',
      data: data,
    );

    print('Success: ${response.data}');
  } on BadRequestException catch (e) {
    print('Invalid data: ${e.message}');
  } on UnauthorizedException catch (e) {
    print('Not authenticated: ${e.message}');
  } on NetworkException catch (e) {
    print('Network error: ${e.message}');
  }
}
```

### 3. **GET with Query Parameters**

```dart
Future<List<Server>> searchServers(String country) async {
  final httpClient = ref.read(httpClientProvider);

  final response = await httpClient.get(
    '/api/servers',
    queryParameters: {
      'country': country,
      'active': true,
    },
  );

  return (response.data as List)
      .map((json) => Server.fromJson(json))
      .toList();
}
```

### 4. **Custom Options**

```dart
Future<void> uploadFile(String filePath) async {
  final httpClient = ref.read(httpClientProvider);

  final formData = FormData.fromMap({
    'file': await MultipartFile.fromFile(filePath),
  });

  await httpClient.post(
    '/api/upload',
    data: formData,
    options: Options(
      headers: {'Authorization': 'Bearer $token'},
      contentType: 'multipart/form-data',
    ),
    onSendProgress: (sent, total) {
      print('Upload progress: ${(sent / total * 100).toStringAsFixed(0)}%');
    },
  );
}
```

### 5. **Download File**

```dart
Future<void> downloadVpnConfig(String configId) async {
  final httpClient = ref.read(httpClientProvider);

  await httpClient.download(
    '/api/configs/$configId',
    '/storage/vpn_config.ovpn',
    onReceiveProgress: (received, total) {
      if (total != -1) {
        print('Download: ${(received / total * 100).toStringAsFixed(0)}%');
      }
    },
  );
}
```

### 6. **Check Network Connectivity**

```dart
Future<bool> isOnline() async {
  final httpClient = ref.read(httpClientProvider);
  return await httpClient.checkConnectivity();
}

// Usage in widget
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () async {
        final httpClient = ref.read(httpClientProvider);
        final isConnected = await httpClient.checkConnectivity();

        if (!isConnected) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No internet connection')),
          );
          return;
        }

        // Proceed with operation
      },
      child: Text('Check Connection'),
    );
  }
}
```

### 7. **Custom Timeout**

```dart
Future<void> quickPing() async {
  final httpClient = ref.read(httpClientProvider);

  try {
    await httpClient.get(
      '/api/ping',
      options: Options(
        sendTimeout: Duration(seconds: 5),
        receiveTimeout: Duration(seconds: 5),
      ),
    );
  } on NetworkException catch (e) {
    print('Timeout or error: ${e.message}');
  }
}
```

### 8. **Cancel Request**

```dart
import 'package:dio/dio.dart';

class DataLoader {
  CancelToken? _cancelToken;

  Future<void> loadData() async {
    // Cancel previous request if exists
    _cancelToken?.cancel('New request started');

    _cancelToken = CancelToken();
    final httpClient = ref.read(httpClientProvider);

    try {
      final response = await httpClient.get(
        '/api/data',
        cancelToken: _cancelToken,
      );
      print('Data loaded: ${response.data}');
    } on NetworkException catch (e) {
      if (e.message.contains('cancelled')) {
        print('Request cancelled');
      } else {
        print('Error: ${e.message}');
      }
    }
  }

  void cancelLoading() {
    _cancelToken?.cancel('User cancelled');
  }
}
```

## 🔧 Advanced Configuration

### Custom HTTP Client with Base URL

```dart
final apiHttpClientProvider = Provider<IHttpClient>((ref) {
  return HttpClient(
    baseUrl: 'https://api.defyxvpn.com/v1',
    headers: {
      'X-API-Key': 'your-api-key',
      'Accept': 'application/json',
    },
    connectTimeout: Duration(seconds: 15),
    receiveTimeout: Duration(seconds: 15),
  );
});
```

### Multiple HTTP Clients

```dart
// API Client
final apiClientProvider = Provider<IHttpClient>((ref) {
  return HttpClient(
    baseUrl: 'https://api.defyxvpn.com',
    connectTimeout: Duration(seconds: 30),
  );
});

// CDN Client
final cdnClientProvider = Provider<IHttpClient>((ref) {
  return HttpClient(
    baseUrl: 'https://cdn.defyxvpn.com',
    connectTimeout: Duration(minutes: 2), // Longer for large files
  );
});

// Usage
class FlowLineService {
  final IHttpClient _apiClient;
  final IHttpClient _cdnClient;

  FlowLineService(this._apiClient, this._cdnClient);

  Future<void> fetchConfig() async {
    // Fetch metadata from API
    final metadata = await _apiClient.get('/configs/metadata');

    // Download config from CDN
    await _cdnClient.download(
      metadata.data['config_url'],
      '/storage/config.json',
    );
  }
}
```

## ⚠️ Error Handling

```dart
Future<void> handleAllErrors() async {
  final httpClient = ref.read(httpClientProvider);

  try {
    await httpClient.get('/api/data');
  } on BadRequestException catch (e) {
    // 400 - Invalid request
    print('Bad request: ${e.message}');
  } on UnauthorizedException catch (e) {
    // 401 - Not logged in
    print('Please login: ${e.message}');
    // Navigate to login screen
  } on ForbiddenException catch (e) {
    // 403 - No permission
    print('Access denied: ${e.message}');
  } on NotFoundException catch (e) {
    // 404 - Resource not found
    print('Not found: ${e.message}');
  } on ServerException catch (e) {
    // 500+ - Server error
    print('Server error: ${e.message}');
  } on NetworkException catch (e) {
    // Network errors (timeout, connection, etc.)
    print('Network error: ${e.message}');
  } catch (e) {
    // Unexpected errors
    print('Unexpected error: $e');
  }
}
```

## 📝 Integration Examples

### FlowLine Service Example

```dart
import 'package:defyx_vpn/core/network/http_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final flowlineApiProvider = Provider<IHttpClient>((ref) {
  return HttpClient(
    baseUrl: 'https://api.defyxvpn.com/v1',
  );
});

class FlowlineService {
  final IHttpClient _httpClient;

  FlowlineService(this._httpClient);

  Future<Map<String, dynamic>> fetchFlowline() async {
    try {
      final response = await _httpClient.get('/flowline');
      return response.data;
    } on NetworkException catch (e) {
      print('Failed to fetch flowline: ${e.message}');
      rethrow;
    }
  }

  Future<List<VpnServer>> getServers({String? country}) async {
    final response = await _httpClient.get(
      '/servers',
      queryParameters: country != null ? {'country': country} : null,
    );

    return (response.data as List)
        .map((json) => VpnServer.fromJson(json))
        .toList();
  }
}
```

## 🎯 Benefits

✅ **Clean Architecture**: Separated interface and implementation
✅ **Testable**: Easy to mock `IHttpClient` for testing
✅ **Reusable**: Use across your entire project
✅ **Type Safe**: Full Dart type safety
✅ **Error Handling**: Custom exceptions for different error types
✅ **Logging**: Automatic request/response logging in debug mode
✅ **Configurable**: Custom timeouts, headers, base URLs
✅ **Connectivity Check**: Built-in network connectivity testing

## 🔒 Security Tips

1. **Never hardcode API keys in code**

```dart
// ❌ Bad
final client = HttpClient(
  headers: {'API-Key': 'secret123'},
);

// ✅ Good - Use environment variables or secure storage
final apiKey = await ref.read(secureStorageProvider).read('api_key');
final client = HttpClient(
  headers: {'API-Key': apiKey},
);
```

2. **Validate SSL certificates in production**

```dart
// Already handled by Dio's default configuration
```

3. **Use HTTPS only**

```dart
final client = HttpClient(
  baseUrl: 'https://api.defyxvpn.com', // ✅ Always use HTTPS
);
```

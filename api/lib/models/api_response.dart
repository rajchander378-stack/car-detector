import 'dart:convert';

class ApiResponse {
  final bool success;
  final Map<String, dynamic>? data;
  final String? error;

  ApiResponse({required this.success, this.data, this.error});

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      if (data != null) 'data': data,
      if (error != null) 'error': error,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory ApiResponse.ok(Map<String, dynamic> data) =>
      ApiResponse(success: true, data: data);

  factory ApiResponse.error(String message) =>
      ApiResponse(success: false, error: message);
}

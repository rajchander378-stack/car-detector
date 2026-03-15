import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../config.dart';

Middleware authMiddleware() {
  return (Handler innerHandler) {
    return (Request request) {
      // Always allow health checks
      if (request.url.path == 'health') {
        return innerHandler(request);
      }

      // If no secret configured, run in open/dev mode
      if (!Config.authEnabled) {
        return innerHandler(request);
      }

      final proxySecret =
          request.headers['x-api-secret'] ?? '';

      if (proxySecret != Config.apiSecret) {
        return Response.forbidden(
          jsonEncode({
            'success': false,
            'error': 'Unauthorized',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      return innerHandler(request);
    };
  };
}

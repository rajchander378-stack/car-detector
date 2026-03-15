import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'handlers/identify_handler.dart';
import 'middleware/auth_middleware.dart';

Handler buildRouter() {
  final router = Router();

  router.get('/health', (Request request) {
    return Response.ok(
      jsonEncode({'status': 'ok'}),
      headers: {'content-type': 'application/json'},
    );
  });

  router.post('/identify', identifyHandler);

  // CORS + auth + logging pipeline
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsMiddleware())
      .addMiddleware(authMiddleware())
      .addHandler(router.call);

  return handler;
}

Middleware _corsMiddleware() {
  return createMiddleware(
    responseHandler: (Response response) {
      return response.change(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers':
            'Content-Type, X-API-Secret',
      });
    },
  );
}

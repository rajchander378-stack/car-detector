import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'handlers/identify_handler.dart';
import 'handlers/stripe_handler.dart';
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

  // Stripe endpoints
  router.post('/create-checkout-session', createCheckoutSession);
  router.post('/stripe-webhook', stripeWebhook);

  // CORS + auth + logging pipeline
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsMiddleware())
      .addMiddleware(authMiddleware())
      .addHandler(router.call);

  return handler;
}

Middleware _corsMiddleware() {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, X-API-Secret, Stripe-Signature',
    'Access-Control-Max-Age': '86400',
  };

  return createMiddleware(
    requestHandler: (Request request) {
      // Respond to preflight OPTIONS requests immediately with 200
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: corsHeaders);
      }
      return null;
    },
    responseHandler: (Response response) {
      return response.change(headers: corsHeaders);
    },
  );
}

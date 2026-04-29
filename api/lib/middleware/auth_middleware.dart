import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../config.dart';

Middleware authMiddleware() {
  return (Handler innerHandler) {
    return (Request request) {
      // Always allow health checks, Stripe webhooks, and checkout session creation.
      // Checkout is called directly from browser/Flutter — no server-side secret available.
      // Security is enforced by Stripe (real payment required) and the signed webhook.
      if (request.url.path == 'health' ||
          request.url.path == 'stripe-webhook' ||
          request.url.path == 'create-checkout-session') {
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

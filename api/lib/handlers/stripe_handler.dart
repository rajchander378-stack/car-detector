import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import '../config.dart';

/// Scan pack definitions: id → (scans, price in pence, display name)
const Map<String, ({int scans, int pricePence, String name})> scanPacks = {
  'pack_10': (scans: 10, pricePence: 300, name: '10 Scan Pack'),
  'pack_50': (scans: 50, pricePence: 1200, name: '50 Scan Pack'),
  'pack_100': (scans: 100, pricePence: 2000, name: '100 Scan Pack'),
};

/// POST /create-checkout-session
///
/// Body: { "pack_id": "pack_10", "user_uid": "abc123", "user_email": "user@example.com" }
/// Returns: { "checkout_url": "https://checkout.stripe.com/..." }
Future<Response> createCheckoutSession(Request request) async {
  if (!Config.stripeEnabled) {
    return Response(503,
      body: jsonEncode({'error': 'Stripe is not configured'}),
      headers: {'content-type': 'application/json'},
    );
  }

  try {
    final body = jsonDecode(await request.readAsString());
    final packId = body['pack_id'] as String?;
    final userUid = body['user_uid'] as String?;
    final userEmail = body['user_email'] as String?;

    if (packId == null || userUid == null) {
      return Response(400,
        body: jsonEncode({'error': 'Missing pack_id or user_uid'}),
        headers: {'content-type': 'application/json'},
      );
    }

    final pack = scanPacks[packId];
    if (pack == null) {
      return Response(400,
        body: jsonEncode({'error': 'Invalid pack_id'}),
        headers: {'content-type': 'application/json'},
      );
    }

    // Create Stripe Checkout Session via REST API
    final params = {
      'mode': 'payment',
      'success_url': '${Config.baseUrl}/dashboard.html?purchase=success',
      'cancel_url': '${Config.baseUrl}/pricing.html?purchase=cancelled',
      'client_reference_id': userUid,
      'metadata[pack_id]': packId,
      'metadata[scans]': pack.scans.toString(),
      'metadata[user_uid]': userUid,
      'line_items[0][price_data][currency]': 'gbp',
      'line_items[0][price_data][unit_amount]': pack.pricePence.toString(),
      'line_items[0][price_data][product_data][name]': pack.name,
      'line_items[0][price_data][product_data][description]':
          '${pack.scans} vehicle scan credits for AutoSpotter',
      'line_items[0][quantity]': '1',
    };

    if (userEmail != null && userEmail.isNotEmpty) {
      params['customer_email'] = userEmail;
    }

    final response = await http.post(
      Uri.parse('https://api.stripe.com/v1/checkout/sessions'),
      headers: {
        'Authorization': 'Bearer ${Config.stripeSecretKey}',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: params.entries.map((e) =>
        '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}'
      ).join('&'),
    );

    if (response.statusCode != 200) {
      stderr.writeln('Stripe error: ${response.body}');
      return Response(502,
        body: jsonEncode({'error': 'Failed to create checkout session'}),
        headers: {'content-type': 'application/json'},
      );
    }

    final session = jsonDecode(response.body);
    return Response.ok(
      jsonEncode({'checkout_url': session['url']}),
      headers: {'content-type': 'application/json'},
    );
  } catch (e) {
    stderr.writeln('Checkout error: $e');
    return Response.internalServerError(
      body: jsonEncode({'error': 'Internal server error'}),
      headers: {'content-type': 'application/json'},
    );
  }
}

/// POST /stripe-webhook
///
/// Handles Stripe webhook events. Verifies signature if webhook secret is set.
/// On checkout.session.completed, credits the user's scan_credits in Firestore
/// via the Firebase REST API.
Future<Response> stripeWebhook(Request request) async {
  try {
    final payload = await request.readAsString();

    // Verify webhook signature if secret is configured
    if (Config.stripeWebhookSecret.isNotEmpty) {
      final signature = request.headers['stripe-signature'] ?? '';
      if (!_verifyStripeSignature(payload, signature, Config.stripeWebhookSecret)) {
        return Response(400,
          body: jsonEncode({'error': 'Invalid signature'}),
          headers: {'content-type': 'application/json'},
        );
      }
    }

    final event = jsonDecode(payload);
    final eventType = event['type'] as String?;

    if (eventType == 'checkout.session.completed') {
      final session = event['data']['object'] as Map<String, dynamic>;
      final metadata = session['metadata'] as Map<String, dynamic>? ?? {};
      final userUid = metadata['user_uid'] as String?;
      final scans = int.tryParse(metadata['scans']?.toString() ?? '') ?? 0;
      final packId = metadata['pack_id'] as String?;

      if (userUid != null && scans > 0) {
        // Credit the user via Firestore REST API
        await _creditUserScans(userUid, scans, packId ?? '', session['id'] as String? ?? '');
        stdout.writeln('Credited $scans scans to user $userUid');
      }
    }

    return Response.ok(
      jsonEncode({'received': true}),
      headers: {'content-type': 'application/json'},
    );
  } catch (e) {
    stderr.writeln('Webhook error: $e');
    return Response.internalServerError(
      body: jsonEncode({'error': 'Webhook processing failed'}),
      headers: {'content-type': 'application/json'},
    );
  }
}

/// Credit scan credits to a user via Firestore REST API.
/// Uses the default service account credentials on Cloud Run.
Future<void> _creditUserScans(String uid, int scans, String packId, String sessionId) async {
  // Get access token from metadata server (available on Cloud Run)
  String accessToken;
  try {
    final tokenResponse = await http.get(
      Uri.parse('http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token'),
      headers: {'Metadata-Flavor': 'Google'},
    );
    accessToken = jsonDecode(tokenResponse.body)['access_token'] as String;
  } catch (e) {
    stderr.writeln('Failed to get access token: $e');
    return;
  }

  final projectId = 'car-detector-833e5';

  // Read current credits
  final docUrl = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/users/$uid';
  final getResponse = await http.get(
    Uri.parse(docUrl),
    headers: {'Authorization': 'Bearer $accessToken'},
  );

  int currentCredits = 0;
  if (getResponse.statusCode == 200) {
    final doc = jsonDecode(getResponse.body);
    final fields = doc['fields'] as Map<String, dynamic>? ?? {};
    if (fields.containsKey('scan_credits')) {
      currentCredits = int.tryParse(fields['scan_credits']['integerValue']?.toString() ?? '0') ?? 0;
    }
  }

  // Update credits
  final newCredits = currentCredits + scans;
  final patchResponse = await http.patch(
    Uri.parse('$docUrl?updateMask.fieldPaths=scan_credits'),
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'fields': {
        'scan_credits': {'integerValue': newCredits.toString()},
      },
    }),
  );

  if (patchResponse.statusCode != 200) {
    stderr.writeln('Failed to update credits: ${patchResponse.body}');
    return;
  }

  // Log the purchase in a subcollection
  final purchaseUrl = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/users/$uid/purchases';
  await http.post(
    Uri.parse(purchaseUrl),
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'fields': {
        'pack_id': {'stringValue': packId},
        'scans_credited': {'integerValue': scans.toString()},
        'stripe_session_id': {'stringValue': sessionId},
        'purchased_at': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
      },
    }),
  );
}

/// Verify Stripe webhook signature (simplified HMAC-SHA256 check).
bool _verifyStripeSignature(String payload, String sigHeader, String secret) {
  if (sigHeader.isEmpty) return false;

  try {
    // Parse the signature header: t=timestamp,v1=signature
    final parts = <String, String>{};
    for (final part in sigHeader.split(',')) {
      final kv = part.split('=');
      if (kv.length == 2) parts[kv[0]] = kv[1];
    }

    final timestamp = parts['t'];
    final expectedSig = parts['v1'];
    if (timestamp == null || expectedSig == null) return false;

    // Compute expected signature
    final signedPayload = '$timestamp.$payload';
    final hmac = _hmacSha256(secret, signedPayload);

    return hmac == expectedSig;
  } catch (e) {
    return false;
  }
}

/// Compute HMAC-SHA256 hex digest.
String _hmacSha256(String key, String message) {
  final hmacInstance = Hmac(sha256, utf8.encode(key));
  final digest = hmacInstance.convert(utf8.encode(message));
  return digest.toString();
}

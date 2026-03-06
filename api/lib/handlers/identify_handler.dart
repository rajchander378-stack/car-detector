import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:shelf/shelf.dart';
import '../config.dart';
import '../models/api_response.dart';
import '../services/gemini_service.dart';
import '../services/image_processor.dart';
import '../services/valuation_service.dart';

Future<Response> identifyHandler(Request request) async {
  if (Config.geminiApiKey.isEmpty) {
    return _jsonResponse(
      500,
      ApiResponse.error('GEMINI_API_KEY not configured'),
    );
  }

  // Parse multipart form data
  final contentType = request.headers['content-type'] ?? '';
  if (!contentType.startsWith('multipart/form-data')) {
    return _jsonResponse(
      400,
      ApiResponse.error(
        'Expected multipart/form-data with an "image" field',
      ),
    );
  }

  final boundary = _extractBoundary(contentType);
  if (boundary == null) {
    return _jsonResponse(400, ApiResponse.error('Invalid multipart boundary'));
  }

  final bodyBytes = await request.read().expand((b) => b).toList();
  final imageBytes = _extractFilePart(bodyBytes, boundary, 'image');
  if (imageBytes == null || imageBytes.isEmpty) {
    return _jsonResponse(
      400,
      ApiResponse.error('No "image" field found in multipart body'),
    );
  }

  // Write uploaded bytes to a temp file
  final uniqueId =
      '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
  final tempDir = Directory.systemTemp;
  final tempFile = File('${tempDir.path}/upload_$uniqueId.jpg');

  try {
    await tempFile.writeAsBytes(imageBytes);

    // Optimise image
    final processor = ImageProcessor();
    final optimised = await processor.optimise(tempFile, suffix: uniqueId);

    // Identify with Gemini
    final gemini = GeminiService(apiKey: Config.geminiApiKey);
    final identification = await gemini.identifyCar(optimised.file);

    // Build response data
    final data = <String, dynamic>{
      'identification': identification.toJson(),
      'image_quality': optimised.quality.toJson(),
    };

    // Optional valuation
    final includeValuation =
        request.url.queryParameters['includeValuation'] == 'true';

    if (includeValuation &&
        identification.numberPlate != null &&
        identification.numberPlate!.isNotEmpty &&
        Config.ukvdApiKey.isNotEmpty) {
      try {
        final valuationService = ValuationService(apiKey: Config.ukvdApiKey);
        final valuation =
            await valuationService.getValuation(identification.numberPlate!);
        data['valuation'] = valuation.toJson();
      } catch (e) {
        data['valuation_error'] = e.toString();
      }
    }

    return _jsonResponse(200, ApiResponse.ok(data));
  } catch (e) {
    return _jsonResponse(
      500,
      ApiResponse.error('Processing failed: ${e.toString()}'),
    );
  } finally {
    // Clean up temp files
    try {
      if (await tempFile.exists()) await tempFile.delete();
    } catch (_) {}
    try {
      final optimisedFile =
          File('${tempDir.path}/optimised_car_$uniqueId.jpg');
      if (await optimisedFile.exists()) await optimisedFile.delete();
    } catch (_) {}
  }
}

Response _jsonResponse(int statusCode, ApiResponse body) {
  return Response(
    statusCode,
    body: body.toJsonString(),
    headers: {'content-type': 'application/json'},
  );
}

String? _extractBoundary(String contentType) {
  final match = RegExp(r'boundary=(.+)$').firstMatch(contentType);
  if (match == null) return null;
  var boundary = match.group(1)!.trim();
  // Remove surrounding quotes if present
  if (boundary.startsWith('"') && boundary.endsWith('"')) {
    boundary = boundary.substring(1, boundary.length - 1);
  }
  return boundary;
}

List<int>? _extractFilePart(
    List<int> body, String boundary, String fieldName) {
  // Convert to string to find headers, then extract binary content
  final bodyStr = latin1.decode(body);
  final delimiterStr = '--$boundary';

  final parts = bodyStr.split(delimiterStr);
  for (final part in parts) {
    if (part.trim() == '--' || part.trim().isEmpty) continue;

    // Check if this part has the field name we want
    final namePattern = RegExp(
      r'Content-Disposition:\s*form-data;\s*name="' +
          RegExp.escape(fieldName) +
          r'"',
      caseSensitive: false,
    );
    if (!namePattern.hasMatch(part)) continue;

    // Find the blank line separating headers from content
    final headerEnd = part.indexOf('\r\n\r\n');
    if (headerEnd == -1) continue;

    final contentStart = headerEnd + 4;
    // Content goes until the end, minus trailing \r\n
    var content = part.substring(contentStart);
    if (content.endsWith('\r\n')) {
      content = content.substring(0, content.length - 2);
    }

    // Convert back to bytes using latin1 to preserve binary data
    return latin1.encode(content);
  }
  return null;
}

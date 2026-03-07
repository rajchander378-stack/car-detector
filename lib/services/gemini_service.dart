import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_ai/firebase_ai.dart';
import '../models/car_identification.dart';

class GeminiTimeoutException implements Exception {
  final String message;
  GeminiTimeoutException([this.message = 'Request timed out']);
  @override
  String toString() => message;
}

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  static const String _systemPrompt = '''
You are a vehicle identification system. Analyse the provided
image of a car and identify it as accurately as possible.
Be specific about the generation and facelift where visual
evidence supports it. Use UK English spelling.
If you cannot identify the car, set identified to false.
For year, provide a range if exact year is uncertain.
Only identify trim level if visual evidence supports it.
''';

  static final Schema _carSchema = Schema.object(
    properties: {
      'identified': Schema.boolean(
        description: 'Whether a car was successfully identified',
      ),
      'confidence': Schema.number(
        description: 'Confidence score from 0.0 to 1.0',
      ),
      'make': Schema.string(
        description: 'Car manufacturer e.g. BMW, Toyota, Ford',
        nullable: true,
      ),
      'model': Schema.string(
        description: 'Car model name e.g. 3 Series, Corolla',
        nullable: true,
      ),
      'year_min': Schema.integer(
        description: 'Earliest likely model year',
        nullable: true,
      ),
      'year_max': Schema.integer(
        description: 'Latest likely model year',
        nullable: true,
      ),
      'generation': Schema.string(
        description:
            'Generation or facelift designation e.g. G20, Mk8',
        nullable: true,
      ),
      'trim': Schema.string(
        description:
            'Trim level if identifiable e.g. M Sport, ST-Line',
        nullable: true,
      ),
      'body_style': Schema.string(
        description: 'Body type: saloon, hatchback, estate, coupe, convertible, suv, mpv, or pickup',
        nullable: true,
      ),
      'colour': Schema.string(
        description: 'Exterior colour of the vehicle',
        nullable: true,
      ),
      'distinguishing_features': Schema.array(
        items: Schema.string(
          description: 'A notable visual feature',
        ),
        description: 'List of notable visual features observed',
        nullable: true,
      ),
      'notes': Schema.string(
        description:
            'Any relevant observations or uncertainty notes',
        nullable: true,
      ),
      'error': Schema.string(
        description:
            'Error description if identification failed',
        nullable: true,
      ),
      'number_plate': Schema.string(
        description:
            'Vehicle registration / number plate text if visible '
            'and legible. Return null if not visible or too blurry.',
        nullable: true,
      ),
    },
    optionalProperties: [
      'make', 'model', 'year_min', 'year_max', 'generation',
      'trim', 'body_style', 'colour', 'distinguishing_features',
      'notes', 'error', 'number_plate'
    ],
  );

  late final GenerativeModel _model =
      FirebaseAI.googleAI().generativeModel(
    model: 'gemini-2.5-flash',
    systemInstruction: Content.text(_systemPrompt),
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: _carSchema,
      temperature: 0.1,
    ),
  );

  static const Duration requestTimeout = Duration(seconds: 30);

  Future<CarIdentification> identifyCar(File imageFile) async {
    try {
      final Uint8List imageBytes = await imageFile.readAsBytes();

      final ext = imageFile.path.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

      final prompt = [
        Content.multi([
          InlineDataPart(mimeType, imageBytes),
          TextPart(
            'Identify this car. Be as specific as possible '
            'about make, model, year range, and trim level. '
            'Also read the number plate if visible and legible.'
          ),
        ]),
      ];

      final response = await _model
          .generateContent(prompt)
          .timeout(requestTimeout, onTimeout: () {
        throw GeminiTimeoutException();
      });

      final responseText = response.text;
      if (responseText == null || responseText.isEmpty) {
        return CarIdentification(
          identified: false,
          confidence: 0.0,
          error: 'Empty response from Gemini',
        );
      }

      final jsonData = jsonDecode(responseText)
          as Map<String, dynamic>;

      return CarIdentification.fromJson(jsonData);

    } on GeminiTimeoutException {
      rethrow;
    } catch (e) {
      return CarIdentification(
        identified: false,
        confidence: 0.0,
        error: 'Error: ${e.toString()}',
      );
    }
  }
}
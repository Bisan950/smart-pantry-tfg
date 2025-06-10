import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiAIService {
  static final GeminiAIService _instance = GeminiAIService._internal();
  factory GeminiAIService() => _instance;
  GeminiAIService._internal();

  late GenerativeModel _model;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY no configurada en .env');
    }

    _model = GenerativeModel(
      model: 'gemini-1.5-pro',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topP: 0.8,
        topK: 40,
        maxOutputTokens: 2048,
      ),
    );

    _isInitialized = true;
  }

  Future<String> generateText(String prompt) async {
    if (!_isInitialized) {
      throw StateError('GeminiAIService no está inicializado');
    }

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      
      if (response.candidates.isEmpty) {
        throw Exception('No se recibió respuesta de Gemini');
      }

      return response.candidates.first.content.parts
          .whereType<TextPart>()
          .map((part) => part.text)
          .join();
    } catch (e) {
      throw Exception('Error generando texto con Gemini: $e');
    }
  }
}
// lib/services/ocr_service.dart - Corregido

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:intl/intl.dart';
import '../services/camera_service.dart';
// Añadir esta importación para ResolutionPreset


/// Servicio para gestionar reconocimiento óptico de caracteres (OCR)
/// especializado en detectar fechas de caducidad en envases
class OCRService {
  // Singleton para acceso global al servicio
  static final OCRService _instance = OCRService._internal();
  factory OCRService() => _instance;
  OCRService._internal();
  
  // Instancia del servicio de cámara
  final _cameraService = CameraService();
  
  // Instancia del detector de texto de ML Kit
  final _textRecognizer = TextRecognizer();
  
  // Patrones de fechas comunes en español (DD/MM/YYYY, MM/YYYY, etc.)
  final List<RegExp> _datePatterns = [
    // Formato DD/MM/YYYY o DD-MM-YYYY
    RegExp(r'(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})'),
    
    // Formato MM/YYYY o MM-YYYY
    RegExp(r'(\d{1,2})[/.-](\d{2,4})'),
    
    // Formato "consumir antes de" o "fecha de caducidad" seguido de fecha
    RegExp(r'(?:consumir|cons|cad|caducidad|vence)(?:.{1,10})(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})', caseSensitive: false),
    
    // Textos como "Best before" seguido de fecha
    RegExp(r'(?:best before|consumir antes de|consumir preferentemente antes del)(?:.{1,10})(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})', caseSensitive: false),
    
    // Texto "EXP" o "CAD" seguido de fecha
    RegExp(r'(?:exp|cad)[.: ]?(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})', caseSensitive: false),
    
    // Formato solo numérico como DDMMYYYY o DDMMYY
    RegExp(r'(\d{2})(\d{2})(\d{2,4})'),
    
    // Formato año-mes-día (ISO)
    RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})'),
    
    // Mes escrito en texto, como "15 ENE 2023" o "15 de enero de 2023"
    RegExp(r'(\d{1,2})[ ]?(?:de)?[ ]?(ene|feb|mar|abr|may|jun|jul|ago|sep|oct|nov|dic|enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)[ ]?(?:de)?[ ]?(\d{2,4})', caseSensitive: false),
    
    // Formato de fecha en inglés MM/DD/YYYY
    RegExp(r'(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})'),
  ];
  
  // Mapeo de abreviaturas de meses a números
  final Map<String, int> _monthNameToNumber = {
    'ene': 1, 'enero': 1, 'jan': 1, 'january': 1,
    'feb': 2, 'febrero': 2, 'february': 2,
    'mar': 3, 'marzo': 3, 'march': 3,
    'abr': 4, 'abril': 4, 'apr': 4, 'april': 4,
    'may': 5, 'mayo': 5,
    'jun': 6, 'junio': 6, 'june': 6,
    'jul': 7, 'julio': 7, 'july': 7,
    'ago': 8, 'agosto': 8, 'aug': 8, 'august': 8,
    'sep': 9, 'septiembre': 9, 'september': 9,
    'oct': 10, 'octubre': 10, 'october': 10,
    'nov': 11, 'noviembre': 11, 'november': 11,
    'dic': 12, 'diciembre': 12, 'dec': 12, 'december': 12,
  };
  
  /// Método para detectar fechas en una imagen
Future<List<DateTime>> detectDatesInImage(File imageFile) async {
  try {
    // Procesar la imagen directamente con el reconocedor de texto
    // Ya que enhanceImageForOCR no está disponible
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await _textRecognizer.processImage(inputImage)
        .timeout(const Duration(seconds: 15), onTimeout: () {
      throw TimeoutException('Tiempo excedido al procesar imagen');
    });
    
    if (kDebugMode) {
      print('Texto reconocido: ${recognizedText.text}');
    }
    
    // Almacenar todas las fechas encontradas
    final List<DateTime> detectedDates = [];
    
    // Buscar patrones de fechas en el texto reconocido
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text;
        final dates = _extractDatesFromText(text);
        detectedDates.addAll(dates);
      }
    }
    
    // Filtrar fechas inválidas (muy antiguas o muy futuras)
    return _filterValidDates(detectedDates);
  } catch (e) {
    if (kDebugMode) {
      print('Error al detectar fechas en imagen: $e');
    }
    return [];
  }
}
  
  /// Método para extraer fechas de un texto
  List<DateTime> _extractDatesFromText(String text) {
    final List<DateTime> dates = [];
    
    // Normalizar el texto (eliminar caracteres extraños, etc.)
    final normalizedText = _normalizeText(text);
    
    // Probar cada patrón de fecha
    for (final pattern in _datePatterns) {
      try {
        final matches = pattern.allMatches(normalizedText);
        
        for (final match in matches) {
          // Intentar diferentes interpretaciones según el formato
          final possibleDate = _interpretDateMatch(match, pattern);
          
          if (possibleDate != null) {
            dates.add(possibleDate);
          }
        }
      } catch (e) {
        // Capturar errores individuales para cada patrón, pero continuar con los demás
        if (kDebugMode) {
          print('Error al aplicar patrón: ${pattern.pattern}: $e');
        }
      }
    }
    
    return dates;
  }
  
  /// Normalizar texto para mejorar la detección de fechas
  String _normalizeText(String text) {
    // Verificar que el texto no sea nulo
    if (text.isEmpty) return "";
    
    // Convertir a minúsculas
    String normalized = text.toLowerCase();
    
    // Reemplazar caracteres que puedan confundirse
    normalized = normalized
        .replaceAll('o', '0')
        .replaceAll('O', '0')
        .replaceAll('l', '1')
        .replaceAll('I', '1')
        .replaceAll('i', '1')
        .replaceAll('S', '5')
        .replaceAll('s', '5')
        .replaceAll('B', '8')
        .replaceAll('b', '8');
    
    // Normalizar separadores de fecha
    normalized = normalized
        .replaceAll(' / ', '/')
        .replaceAll(' - ', '-')
        .replaceAll(' . ', '.');
    
    return normalized;
  }
  
  /// Interpretar una coincidencia de fecha y convertirla a DateTime
  DateTime? _interpretDateMatch(RegExpMatch match, RegExp pattern) {
    try {
      // Verificar que los grupos que vamos a utilizar existan
      if (match.groupCount == 0) return null;
      
      // Diferentes interpretaciones según el patrón
      final patternString = pattern.pattern;
      
      // Formato DD/MM/YYYY o DD-MM-YYYY
      if (patternString.contains(r'(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})')) {
        // Verificar que existan los grupos necesarios
        if (match.groupCount < 3 || match.group(1) == null || 
            match.group(2) == null || match.group(3) == null) {
          return null;
        }
        
        // Extraer componentes
        final day = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        int year = int.parse(match.group(3)!);
        
        // Corregir año de 2 dígitos
        if (year < 100) {
          year += year < 50 ? 2000 : 1900;
        }
        
        // Validar componentes
        if (_isValidDateComponents(day, month, year)) {
          return DateTime(year, month, day);
        }
        
        // Intentar invertir día y mes (formato estadounidense MM/DD/YYYY)
        if (_isValidDateComponents(month, day, year)) {
          return DateTime(year, day, month);
        }
      }
      
      // Formato MM/YYYY o MM-YYYY
      else if (patternString.contains(r'(\d{1,2})[/.-](\d{2,4})')) {
        // Verificar que existan los grupos necesarios
        if (match.groupCount < 2 || match.group(1) == null || match.group(2) == null) {
          return null;
        }
        
        final month = int.parse(match.group(1)!);
        int year = int.parse(match.group(2)!);
        
        // Corregir año de 2 dígitos
        if (year < 100) {
          year += year < 50 ? 2000 : 1900;
        }
        
        // Validar componentes
        if (month >= 1 && month <= 12 && year >= 2000 && year <= 2100) {
          // Para formatos MM/YYYY, usar el último día del mes
          return DateTime(year, month + 1, 0);
        }
      }
      
      // Formato "consumir antes de" o similar
      else if (patternString.contains('consumir') || 
               patternString.contains('caducidad') || 
               patternString.contains('best before')) {
        // Extraer componentes - pueden estar en diferentes grupos según el patrón
        if (match.groupCount >= 3 && 
            match.group(match.groupCount - 2) != null && 
            match.group(match.groupCount - 1) != null && 
            match.group(match.groupCount) != null) {
          
          int day = int.parse(match.group(match.groupCount - 2)!);
          int month = int.parse(match.group(match.groupCount - 1)!);
          int year = int.parse(match.group(match.groupCount)!);
          
          // Corregir año de 2 dígitos
          if (year < 100) {
            year += year < 50 ? 2000 : 1900;
          }
          
          // Validar componentes
          if (_isValidDateComponents(day, month, year)) {
            return DateTime(year, month, day);
          }
        }
      }
      
      // Formato solo numérico como DDMMYYYY o DDMMYY
      else if (patternString.contains(r'(\d{2})(\d{2})(\d{2,4})')) {
        // Verificar que existan los grupos necesarios
        if (match.groupCount < 3 || match.group(1) == null || 
            match.group(2) == null || match.group(3) == null) {
          return null;
        }
        
        final day = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        int year = int.parse(match.group(3)!);
        
        // Corregir año de 2 dígitos
        if (year < 100) {
          year += year < 50 ? 2000 : 1900;
        }
        
        // Validar componentes
        if (_isValidDateComponents(day, month, year)) {
          return DateTime(year, month, day);
        }
      }
      
      // Formato año-mes-día (ISO)
      else if (patternString.contains(r'(\d{4})-(\d{1,2})-(\d{1,2})')) {
        // Verificar que existan los grupos necesarios
        if (match.groupCount < 3 || match.group(1) == null || 
            match.group(2) == null || match.group(3) == null) {
          return null;
        }
        
        final year = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        final day = int.parse(match.group(3)!);
        
        // Validar componentes
        if (_isValidDateComponents(day, month, year)) {
          return DateTime(year, month, day);
        }
      }
      
      // Mes escrito en texto, como "15 ENE 2023"
      else if (patternString.contains('ene|feb|mar|abr') || 
               patternString.contains('enero|febrero')) {
        // Verificar que existan los grupos necesarios
        if (match.groupCount < 3 || match.group(1) == null || 
            match.group(2) == null || match.group(3) == null) {
          return null;
        }
        
        final day = int.parse(match.group(1)!);
        final monthName = match.group(2)!.toLowerCase();
        int year = int.parse(match.group(3)!);
        
        // Obtener número de mes
        final month = _monthNameToNumber[monthName];
        
        // Corregir año de 2 dígitos
        if (year < 100) {
          year += year < 50 ? 2000 : 1900;
        }
        
        // Validar componentes
        if (month != null && _isValidDateComponents(day, month, year)) {
          return DateTime(year, month, day);
        }
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error al interpretar fecha: $e');
      }
      return null;
    }
  }
  
  /// Verificar si los componentes de fecha son válidos
  bool _isValidDateComponents(int day, int month, int year) {
    // Validaciones básicas
    if (month < 1 || month > 12) return false;
    if (day < 1) return false;
    if (year < 2000 || year > 2100) return false;
    
    // Verificar número de días según el mes
    try {
      final daysInMonth = DateTime(year, month + 1, 0).day;
      return day <= daysInMonth;
    } catch (e) {
      // Si ocurre un error al calcular los días del mes, asumir que la fecha es inválida
      if (kDebugMode) {
        print('Error al validar componentes: $e');
      }
      return false;
    }
  }
  
  /// Filtrar fechas válidas (eliminar muy antiguas o muy futuras)
  List<DateTime> _filterValidDates(List<DateTime> dates) {
    final now = DateTime.now();
    final minDate = now.subtract(const Duration(days: 30)); // Un mes en el pasado
    final maxDate = now.add(const Duration(days: 365 * 5)); // 5 años en el futuro
    
    // Filtrar fechas fuera de rango y ordenar por cercanía a hoy
    final validDates = dates
        .where((date) => date.isAfter(minDate) && date.isBefore(maxDate))
        .toList();
    
    // Ordenar por proximidad al futuro (fechas de caducidad cercanas primero)
    validDates.sort((a, b) => a.compareTo(b));
    
    return validDates;
  }
  
  

/// Método para capturar una imagen para OCR
Future<File?> captureImageForOCR() async {
  try {
    // Inicializar la cámara si no está inicializada
    final cameraInitialized = await _cameraService.initializeCamera().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Tiempo excedido al inicializar la cámara');
      }
    );
    
    if (!cameraInitialized) {
      return null;
    }
    
    // Tomar la foto
    final photo = await _cameraService.takePhoto().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        throw TimeoutException('Tiempo excedido al tomar la foto');
      }
    );
    
    if (photo == null) {
      return null;
    }
    
    // No necesitamos rotar la imagen ya que rotateImageIfNeeded no está disponible
    return photo;
  } catch (e) {
    if (kDebugMode) {
      print('Error al capturar imagen para OCR: $e');
    }
    return null;
  } finally {
    // Liberar recursos de la cámara
    await _cameraService.dispose();
  }
}
  /// Método para interpretar y formatear fecha para mostrar al usuario
  String formatDetectedDate(DateTime date) {
    try {
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      if (kDebugMode) {
        print('Error al formatear fecha: $e');
      }
      // Formateo manual como respaldo
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
  }
  
  /// Método para identificar el tipo de fecha (caducidad, consumo preferente, etc.)
  String identifyDateType(String surroundingText) {
    if (surroundingText.isEmpty) return 'Fecha detectada';
    
    surroundingText = surroundingText.toLowerCase();
    
    if (surroundingText.contains('cad') || 
        surroundingText.contains('caduc') || 
        surroundingText.contains('venc') ||
        surroundingText.contains('exp')) {
      return 'Fecha de caducidad';
    } else if (surroundingText.contains('consumir preferentemente') || 
               surroundingText.contains('cons. pref') || 
               surroundingText.contains('best before')) {
      return 'Consumir preferentemente antes de';
    } else if (surroundingText.contains('fab') || 
               surroundingText.contains('fabric') || 
               surroundingText.contains('elab') ||
               surroundingText.contains('prod')) {
      return 'Fecha de fabricación';
    } else {
      return 'Fecha detectada';
    }
  }
  
  /// Liberar recursos
  Future<void> dispose() async {
    try {
      await _textRecognizer.close();
    } catch (e) {
      if (kDebugMode) {
        print('Error al cerrar el reconocedor de texto: $e');
      }
    }
  }
  
  /// Guardar imagen capturada con anotaciones de fechas detectadas
  Future<File?> saveAnnotatedImage(File originalImage, List<DateTime> detectedDates) async {
    // En una implementación más completa, aquí dibujaríamos rectángulos 
    // alrededor de las fechas detectadas en la imagen
    // Por ahora, simplemente devolvemos la imagen original
    return originalImage;
  }
}
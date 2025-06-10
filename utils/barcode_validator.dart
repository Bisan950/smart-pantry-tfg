// lib/utils/barcode_validator.dart

/// Validador de códigos de barras con soporte para múltiples formatos
class BarcodeValidator {
  /// Verifica si un código de barras es válido
  bool isValid(String barcode) {
    if (barcode.isEmpty) return false;
    
    // Limpiar el código de barras
    final cleanBarcode = _cleanBarcode(barcode);
    
    if (cleanBarcode.isEmpty) return false;
    
    // Verificar formato según la longitud
    switch (cleanBarcode.length) {
      case 8:
        return _isValidEAN8(cleanBarcode);
      case 12:
        return _isValidUPC(cleanBarcode);
      case 13:
        return _isValidEAN13(cleanBarcode);
      case 14:
        return _isValidGTIN14(cleanBarcode);
      default:
        // Para códigos de otras longitudes, verificar formatos especiales
        return _isValidOtherFormat(cleanBarcode);
    }
  }

  /// Limpia el código de barras eliminando caracteres no válidos
  String _cleanBarcode(String barcode) {
    return barcode.replaceAll(RegExp(r'[^\d\-A-Za-z]'), '');
  }

  /// Valida código EAN-8
  bool _isValidEAN8(String barcode) {
    if (!_isNumeric(barcode) || barcode.length != 8) return false;
    return _validateEANChecksum(barcode);
  }

  /// Valida código UPC-A (12 dígitos)
  bool _isValidUPC(String barcode) {
    if (!_isNumeric(barcode) || barcode.length != 12) return false;
    return _validateUPCChecksum(barcode);
  }

  /// Valida código EAN-13
  bool _isValidEAN13(String barcode) {
    if (!_isNumeric(barcode) || barcode.length != 13) return false;
    return _validateEANChecksum(barcode);
  }

  /// Valida código GTIN-14
  bool _isValidGTIN14(String barcode) {
    if (!_isNumeric(barcode) || barcode.length != 14) return false;
    return _validateGTIN14Checksum(barcode);
  }

  /// Valida otros formatos de códigos de barras
  bool _isValidOtherFormat(String barcode) {
    // Code 39, Code 128, ISBN, etc.
    if (barcode.length >= 4 && barcode.length <= 20) {
      return _isAlphanumeric(barcode);
    }
    return false;
  }

  /// Verifica si una cadena contiene solo números
  bool _isNumeric(String str) {
    return RegExp(r'^\d+$').hasMatch(str);
  }

  /// Verifica si una cadena contiene solo caracteres alfanuméricos
  bool _isAlphanumeric(String str) {
    return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(str);
  }

  /// Valida checksum para códigos EAN-8 y EAN-13
  bool _validateEANChecksum(String barcode) {
    int sum = 0;
    
    for (int i = 0; i < barcode.length - 1; i++) {
      int digit = int.parse(barcode[i]);
      
      if (i % 2 == 0) {
        sum += digit;
      } else {
        sum += digit * 3;
      }
    }
    
    int checkDigit = (10 - (sum % 10)) % 10;
    int providedCheckDigit = int.parse(barcode[barcode.length - 1]);
    
    return checkDigit == providedCheckDigit;
  }

  /// Valida checksum para códigos UPC-A
  bool _validateUPCChecksum(String barcode) {
    int sum = 0;
    
    for (int i = 0; i < 11; i++) {
      int digit = int.parse(barcode[i]);
      
      if (i % 2 == 0) {
        sum += digit * 3;
      } else {
        sum += digit;
      }
    }
    
    int checkDigit = (10 - (sum % 10)) % 10;
    int providedCheckDigit = int.parse(barcode[11]);
    
    return checkDigit == providedCheckDigit;
  }

  /// Valida checksum para códigos GTIN-14
  bool _validateGTIN14Checksum(String barcode) {
    int sum = 0;
    
    for (int i = 0; i < 13; i++) {
      int digit = int.parse(barcode[i]);
      
      if (i % 2 == 0) {
        sum += digit * 3;
      } else {
        sum += digit;
      }
    }
    
    int checkDigit = (10 - (sum % 10)) % 10;
    int providedCheckDigit = int.parse(barcode[13]);
    
    return checkDigit == providedCheckDigit;
  }

  /// Normaliza un código de barras
  String normalize(String barcode) {
    final cleanBarcode = _cleanBarcode(barcode);
    
    // Para UPC-A, convertir a EAN-13 añadiendo un 0 al principio
    if (cleanBarcode.length == 12 && _isValidUPC(cleanBarcode)) {
      return '0$cleanBarcode';
    }
    
    return cleanBarcode;
  }

  /// Verifica si dos códigos de barras son equivalentes
  bool areEquivalent(String barcode1, String barcode2) {
    final norm1 = normalize(barcode1);
    final norm2 = normalize(barcode2);
    
    return norm1 == norm2;
  }

  /// Obtiene el tipo de código de barras
  String getBarcodeType(String barcode) {
    if (!isValid(barcode)) return 'unknown';
    
    final cleanBarcode = _cleanBarcode(barcode);
    
    switch (cleanBarcode.length) {
      case 8:
        return 'EAN-8';
      case 12:
        return 'UPC-A';
      case 13:
        if (cleanBarcode.startsWith('978') || cleanBarcode.startsWith('979')) {
          return 'ISBN-13';
        }
        return 'EAN-13';
      case 14:
        return 'GTIN-14';
      case 10:
        return 'ISBN-10';
      default:
        if (_isNumeric(cleanBarcode)) {
          return 'Numeric';
        }
        return 'Alphanumeric';
    }
  }

  /// Obtiene el país de origen del código de barras (para EAN/UPC)
  String getCountryFromBarcode(String barcode) {
    if (barcode.length < 3) return 'Desconocido';
    
    final prefix = barcode.substring(0, 3);
    
    final countryMap = {
      // España
      '840': 'España', '841': 'España', '842': 'España', '843': 'España',
      '844': 'España', '845': 'España', '846': 'España', '847': 'España',
      '848': 'España', '849': 'España',
      
      // Francia
      '300': 'Francia', '301': 'Francia', '302': 'Francia', '303': 'Francia',
      '304': 'Francia', '305': 'Francia', '306': 'Francia', '307': 'Francia',
      '308': 'Francia', '309': 'Francia',
      
      // Alemania
      '400': 'Alemania', '401': 'Alemania', '402': 'Alemania', '403': 'Alemania',
      '404': 'Alemania', '405': 'Alemania', '406': 'Alemania', '407': 'Alemania',
      '408': 'Alemania', '409': 'Alemania', '440': 'Alemania',
      
      // Estados Unidos y Canadá
      '000': 'Estados Unidos', '001': 'Estados Unidos', '002': 'Estados Unidos',
      '003': 'Estados Unidos', '004': 'Estados Unidos', '005': 'Estados Unidos',
      '006': 'Estados Unidos', '007': 'Estados Unidos', '008': 'Estados Unidos',
      '009': 'Estados Unidos', '010': 'Estados Unidos', '011': 'Estados Unidos',
      '012': 'Estados Unidos', '013': 'Estados Unidos', '019': 'Estados Unidos',
      '020': 'Estados Unidos', '021': 'Estados Unidos', '022': 'Estados Unidos',
      '023': 'Estados Unidos', '024': 'Estados Unidos', '025': 'Estados Unidos',
      '026': 'Estados Unidos', '027': 'Estados Unidos', '028': 'Estados Unidos',
      '029': 'Estados Unidos', '030': 'Estados Unidos', '031': 'Estados Unidos',
      '032': 'Estados Unidos', '033': 'Estados Unidos', '034': 'Estados Unidos',
      '035': 'Estados Unidos', '036': 'Estados Unidos', '037': 'Estados Unidos',
      '038': 'Estados Unidos', '039': 'Estados Unidos',
      
      // Reino Unido
      '500': 'Reino Unido', '501': 'Reino Unido', '502': 'Reino Unido',
      '503': 'Reino Unido', '504': 'Reino Unido', '505': 'Reino Unido',
      '506': 'Reino Unido', '507': 'Reino Unido', '508': 'Reino Unido',
      '509': 'Reino Unido',
      
      // Italia
      '800': 'Italia', '801': 'Italia', '802': 'Italia', '803': 'Italia',
      '804': 'Italia', '805': 'Italia', '806': 'Italia', '807': 'Italia',
      '808': 'Italia', '809': 'Italia', '810': 'Italia', '811': 'Italia',
      '812': 'Italia', '813': 'Italia', '814': 'Italia', '815': 'Italia',
      '816': 'Italia', '817': 'Italia', '818': 'Italia', '819': 'Italia',
      
      // Japón
      '450': 'Japón', '451': 'Japón', '452': 'Japón', '453': 'Japón',
      '454': 'Japón', '455': 'Japón', '456': 'Japón', '457': 'Japón',
      '458': 'Japón', '459': 'Japón',
    };
    
    return countryMap[prefix] ?? 'Desconocido';
  }

  /// Genera un código de barras EAN-13 válido para pruebas
  String generateTestBarcode() {
    final random = DateTime.now().millisecondsSinceEpoch;
    final baseCode = '84${random.toString().substring(random.toString().length - 10)}';
    
    // Calcular dígito de control
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      int digit = int.parse(baseCode[i]);
      if (i % 2 == 0) {
        sum += digit;
      } else {
        sum += digit * 3;
      }
    }
    
    int checkDigit = (10 - (sum % 10)) % 10;
    return '$baseCode$checkDigit';
  }

  /// Obtiene información básica del código de barras
  Map<String, dynamic> getInfo(String barcode) {
    final type = getBarcodeType(barcode);
    final normalized = normalize(barcode);
    final country = getCountryFromBarcode(normalized);
    
    return {
      'original_code': barcode,
      'normalized_code': normalized,
      'type': type,
      'is_valid': isValid(barcode),
      'country': country,
    };
  }
}
// lib/screens/inventory/enhanced_barcode_scanner_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../config/theme.dart';
import '../../models/product_model.dart';
import '../../services/improved_barcode_service.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/loading_indicator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class EnhancedBarcodeScannerScreen extends StatefulWidget {
  const EnhancedBarcodeScannerScreen({super.key});

  @override
  State<EnhancedBarcodeScannerScreen> createState() => _EnhancedBarcodeScannerScreenState();
}

class _EnhancedBarcodeScannerScreenState extends State<EnhancedBarcodeScannerScreen> 
    with TickerProviderStateMixin, WidgetsBindingObserver {
  
  final ImprovedBarcodeService _barcodeService = ImprovedBarcodeService();
  
  // Controllers
  MobileScannerController? _mobileScannerController;
  late AnimationController _scanLineController;
  late AnimationController _pulseController;
  late Animation<double> _scanLineAnimation;
  late Animation<double> _pulseAnimation;
  
  // Estados
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _hasPermission = false;
  bool _hasFlash = false;
  bool _isFlashOn = false;
  String? _errorMessage;
  Product? _detectedProduct;
  
  // Control de detección
  String? _lastDetectedBarcode;
  DateTime? _lastDetectionTime;
  Timer? _detectionCooldownTimer;
  bool _isInCooldown = false;
  
  // Estadísticas de detección
  int _detectionAttempts = 0;
  int _successfulDetections = 0;
  
  // UI States
  bool _showSuccessEffect = false;
  bool _showConfidenceIndicator = false;
  double _detectionConfidence = 0.0;

  @override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  
  _initAnimations();
  _initializeService(); // NUEVO: Inicializar servicio primero
}

// NUEVO: Método para inicializar el servicio
Future<void> _initializeService() async {
  try {
    print('🚀 Inicializando servicio de códigos de barras...');
    
    // Inicializar el servicio
    await _barcodeService.initialize();
    
    // Verificar diagnóstico
    final diagnosis = await _barcodeService.quickDiagnosis();
    print('📋 Diagnóstico rápido: $diagnosis');
    
    // Solicitar permisos después
    await _requestCameraPermission();
    
  } catch (e) {
    print('💥 Error inicializando servicio: $e');
    if (mounted) {
      setState(() {
        _errorMessage = 'Error inicializando servicio: $e';
      });
    }
  }
}

void _initAnimations() {
  // Animación de línea de escaneo
  _scanLineController = AnimationController(
    duration: const Duration(milliseconds: 2000),
    vsync: this,
  );
  
  _scanLineAnimation = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(CurvedAnimation(
    parent: _scanLineController,
    curve: Curves.easeInOut,
  ));
  
  // Animación de pulso para efectos
  _pulseController = AnimationController(
    duration: const Duration(milliseconds: 1000),
    vsync: this,
  );
  
  _pulseAnimation = Tween<double>(
    begin: 1.0,
    end: 1.2,
  ).animate(CurvedAnimation(
    parent: _pulseController,
    curve: Curves.elasticOut,
  ));
  
  _scanLineController.repeat(reverse: true);
}

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    _scanLineController.dispose();
    _pulseController.dispose();
    _detectionCooldownTimer?.cancel();
    
    _disposeCamera();
    super.dispose();
  }

  Future<void> _disposeCamera() async {
    if (_mobileScannerController != null) {
      try {
        await _mobileScannerController!.dispose();
      } catch (e) {
        print('Error al liberar cámara: $e');
      }
      _mobileScannerController = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    } else if (state == AppLifecycleState.paused) {
      _disposeCamera();
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    }
  }

  Future<void> _requestCameraPermission() async {
    try {
      final hasPermission = await _barcodeService.requestCameraPermission();
      
      if (mounted) {
        setState(() {
          _hasPermission = hasPermission;
          _errorMessage = hasPermission ? null : 'Permisos de cámara requeridos';
        });
        
        if (hasPermission) {
          await _initializeCamera();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasPermission = false;
          _errorMessage = 'Error al solicitar permisos: $e';
        });
      }
    }
  }

  Future<void> _initializeCamera() async {
    if (!_hasPermission || _mobileScannerController != null) return;
    
    try {
      _mobileScannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
        returnImage: false,
        formats: [
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.code128,
          BarcodeFormat.code39,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
        ],
      );
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _hasFlash = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al inicializar escáner: $e';
          _isCameraInitialized = false;
        });
      }
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isProcessing || _isInCooldown) return;
    
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    final barcode = barcodes.first;
    final barcodeValue = barcode.rawValue;
    
    if (barcodeValue == null || barcodeValue.isEmpty) return;
    
    // Evitar detecciones duplicadas recientes
    if (_lastDetectedBarcode == barcodeValue) {
      final now = DateTime.now();
      if (_lastDetectionTime != null && 
          now.difference(_lastDetectionTime!).inSeconds < 2) {
        return;
      }
    }
    
    _lastDetectedBarcode = barcodeValue;
    _lastDetectionTime = DateTime.now();
    
    _processDetectedBarcode(barcodeValue);
  }

  Future<void> _processDetectedBarcode(String barcodeValue) async {
  if (_isProcessing || _isInCooldown) return;
  
  setState(() {
    _isProcessing = true;
    _detectionAttempts++;
  });
  
  try {
    print('🔍 === PROCESANDO CÓDIGO: $barcodeValue ===');
    
    // Efecto visual
    _showDetectionEffect();
    
    // Diagnóstico rápido
    final diagnosis = await _barcodeService.quickDiagnosis();
    print('📊 Estado del servicio: ${diagnosis['service_initialized']}');
    print('📊 APIs disponibles: ${diagnosis['total_apis']}');
    
    // TIMEOUT MÁS LARGO para dar tiempo a las APIs
    final productInfo = await _barcodeService.getEnhancedProductInfo(barcodeValue)
        .timeout(Duration(seconds: 30));
    
    if (productInfo != null && mounted) {
      print('✅ Información del producto obtenida:');
      print('   - Nombre: ${productInfo.name}');
      print('   - Categoría: ${productInfo.category}');
      print('   - Confianza: ${productInfo.confidence}');
      print('   - Fuente: ${productInfo.source}');
      
      // Crear producto
      final product = await _barcodeService.createEnhancedProductFromBarcode(barcodeValue);
      
      if (product != null && mounted) {
        setState(() {
          _detectedProduct = product;
          _detectionConfidence = productInfo.confidence;
          _successfulDetections++;
          _showConfidenceIndicator = true;
        });
        
        _showSuccessMessage(product.name, productInfo.confidence);
        _startCooldownTimer();
        
        // Retornar producto después de breve pausa
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context, product);
          }
        });
        
        return;
      } else {
        print('⚠️ No se pudo crear producto desde la información obtenida');
        // Intentar con información básica
        _showAddManuallyDialogWithInfo(barcodeValue, productInfo);
        return;
      }
    }
    
    // Si llegamos aquí, no se encontró información
    print('❌ No se encontró información del producto');
    if (mounted) {
      _showNotFoundDialog(barcodeValue);
    }
    
  } catch (e) {
    print('💥 Error crítico procesando código: $e');
    if (mounted) {
      if (e is TimeoutException) {
        _showTimeoutDialog(barcodeValue);
      } else {
        _showErrorMessage('Error procesando código: ${e.toString()}');
      }
    }
  } finally {
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }
}

void _showAddManuallyDialogWithInfo(String barcode, ProductInfo productInfo) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      ),
      title: Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.successGreen),
          SizedBox(width: 8),
          Text('Información parcial'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Código: $barcode'),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Información encontrada:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text('• Nombre: ${productInfo.name}'),
                Text('• Categoría: ${productInfo.category}'),
                if (productInfo.brand.isNotEmpty)
                  Text('• Marca: ${productInfo.brand}'),
                Text('• Confianza: ${(productInfo.confidence * 100).round()}%'),
              ],
            ),
          ),
          SizedBox(height: 8),
          Text(
            '¿Quieres usar esta información o editarla?',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _resetScanner();
          },
          child: Text('Escanear otro'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pop(context, barcode); // Para edición manual
          },
          child: Text('Editar'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            // Crear producto con la información parcial
            final product = await _barcodeService.createEnhancedProductFromBarcode(barcode);
            if (product != null && mounted) {
              Navigator.pop(context, product);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.successGreen,
          ),
          child: Text('Usar información'),
        ),
      ],
    ),
  );
}

void _showTimeoutDialog(String barcode) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      ),
      title: Row(
        children: [
          Icon(Icons.access_time, color: AppTheme.warningOrange),
          SizedBox(width: 8),
          Text('Tiempo de espera agotado'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Código: $barcode'),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warningOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'La consulta tardó demasiado tiempo.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8),
                Text(
                  '• Verifica tu conexión a internet\n'
                  '• Inténtalo de nuevo\n'
                  '• O añade el producto manualmente',
                  style: TextStyle(fontSize: 12, color: AppTheme.mediumGrey),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _resetScanner();
          },
          child: Text('Intentar de nuevo'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pop(context, barcode);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.warningOrange,
          ),
          child: Text('Añadir manualmente'),
        ),
      ],
    ),
  );
}

void _showNotFoundDialog(String barcode) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      ),
      title: Row(
        children: [
          Icon(Icons.search_off, color: AppTheme.coralMain),
          SizedBox(width: 8),
          Text('Producto no encontrado'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Código escaneado: $barcode'),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.lightGrey,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Este código no está en nuestras bases de datos.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8),
                Text(
                  '• Verifica que el código sea correcto\n'
                  '• Prueba a escanear de nuevo\n'
                  '• O añádelo manualmente',
                  style: TextStyle(fontSize: 12, color: AppTheme.mediumGrey),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _resetScanner();
          },
          child: Text('Escanear otro'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pop(context, barcode); // Devolver código para entrada manual
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.coralMain,
          ),
          child: Text('Añadir manualmente'),
        ),
      ],
    ),
  );
}




  void _showDetectionEffect() {
    HapticFeedback.mediumImpact();
    
    setState(() {
      _showSuccessEffect = true;
    });
    
    _pulseController.forward().then((_) {
      _pulseController.reverse();
    });
    
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showSuccessEffect = false;
        });
      }
    });
  }

  void _showSuccessMessage(String productName, double confidence) {
    final confidencePercentage = (confidence * 100).round();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Producto detectado',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('$productName ($confidencePercentage% confianza)'),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.successGreen,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.errorRed,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _startCooldownTimer() {
    setState(() {
      _isInCooldown = true;
    });
    
    _detectionCooldownTimer?.cancel();
    _detectionCooldownTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isInCooldown = false;
        });
      }
    });
  }

  void _showAddManuallyDialog(String barcode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        ),
        title: Row(
          children: [
            Icon(Icons.help_outline, color: AppTheme.coralMain),
            SizedBox(width: 8),
            Text('Producto no encontrado'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Código detectado: $barcode'),
            SizedBox(height: 8),
            Text('Este producto no está en nuestras bases de datos.'),
            SizedBox(height: 4),
            Text('¿Quieres añadirlo manualmente?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetScanner();
            },
            child: Text('Continuar escaneando'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, barcode);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.coralMain,
            ),
            child: Text('Añadir manualmente'),
          ),
        ],
      ),
    );
  }

  void _resetScanner() {
    setState(() {
      _detectedProduct = null;
      _showConfidenceIndicator = false;
      _detectionConfidence = 0.0;
      _isInCooldown = false;
    });
    _detectionCooldownTimer?.cancel();
  }

  void _toggleFlash() {
    if (_mobileScannerController != null && _hasFlash) {
      _mobileScannerController!.toggleTorch();
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    }
  }

  void _showQuickDiagnosis() async {
  final diagnosis = await _barcodeService.quickDiagnosis();
  
  if (!mounted) return;
  
  final isHealthy = diagnosis['service_initialized'] == true && 
                   diagnosis['total_apis'] > 0 && 
                   diagnosis['database_ready'] == true;
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isHealthy ? Icons.check_circle : Icons.warning,
            color: Colors.white,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isHealthy ? 'Servicio funcionando correctamente' : 'Servicio con problemas',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('APIs: ${diagnosis['total_apis']} | Caché: ${diagnosis['session_cache_size']}'),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: isHealthy ? AppTheme.successGreen : AppTheme.warningOrange,
      duration: Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: CustomAppBar(
      title: 'Escáner Mejorado',
      actions: [
        if (_hasFlash)
          IconButton(
            icon: Icon(
              _isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: _isFlashOn ? AppTheme.yellowAccent : null,
            ),
            onPressed: _toggleFlash,
          ),
        // Botón de diagnóstico rápido
        IconButton(
          icon: Icon(Icons.health_and_safety),
          onPressed: _showQuickDiagnosis,
          tooltip: 'Diagnóstico rápido',
        ),
        IconButton(
          icon: Icon(Icons.info_outline),
          onPressed: _showStatsDialog,
          tooltip: 'Estadísticas completas',
        ),
      ],
    ),
    body: _buildBody(),
  );
}

  Widget _buildStatSection(String title, List<Widget> stats) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: AppTheme.coralMain,
        ),
      ),
      SizedBox(height: 8),
      ...stats,
    ],
  );
}

  Widget _buildBody() {
    if (_errorMessage != null) {
      return _buildErrorView();
    }
    
    if (!_hasPermission) {
      return _buildPermissionView();
    }
    
    if (!_isCameraInitialized) {
      return Center(
        child: LoadingIndicator(
          message: 'Inicializando escáner...',
          color: AppTheme.coralMain,
        ),
      );
    }
    
    return _buildScannerView();
  }

  Widget _buildScannerView() {
    return Stack(
      children: [
        // Scanner
        if (_mobileScannerController != null)
          MobileScanner(
            controller: _mobileScannerController!,
            onDetect: _onBarcodeDetected,
          ),
        
        // Overlay oscuro
        Container(
          color: Colors.black.withOpacity(0.5),
        ),
        
        // Marco de escaneo
        Center(
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _showSuccessEffect ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _showSuccessEffect 
                        ? AppTheme.successGreen 
                        : AppTheme.coralMain,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: _showSuccessEffect ? [
                      BoxShadow(
                        color: AppTheme.successGreen.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ] : null,
                  ),
                ),
              );
            },
          ),
        ),
        
        // Línea de escaneo animada
        Center(
          child: SizedBox(
            width: 280,
            height: 280,
            child: AnimatedBuilder(
              animation: _scanLineAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: ScanLinePainter(
                    progress: _scanLineAnimation.value,
                    color: _showSuccessEffect 
                      ? AppTheme.successGreen 
                      : AppTheme.coralMain,
                  ),
                );
              },
            ),
          ),
        ),
        
        // Indicadores de estado
        _buildStatusIndicators(),
        
        // Botones de acción
        _buildActionButtons(),
        
        // Overlay de procesamiento
        if (_isProcessing)
          _buildProcessingOverlay(),
      ],
    );
  }

  Widget _buildStatusIndicators() {
    return Positioned(
      top: 20,
      left: 20,
      right: 20,
      child: Column(
        children: [
          // Estado del escáner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isInCooldown 
                    ? Icons.pause_circle_filled 
                    : Icons.qr_code_scanner,
                  color: _isInCooldown 
                    ? AppTheme.yellowAccent 
                    : AppTheme.successGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _isInCooldown 
                    ? 'Esperando...' 
                    : 'Escaneando automáticamente',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // Indicador de confianza
          if (_showConfidenceIndicator) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getConfidenceColor().withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getConfidenceIcon(),
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Confianza: ${(_detectionConfidence * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Positioned(
      bottom: 30,
      left: 20,
      right: 20,
      child: Column(
        children: [
          // Estadísticas de detección
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Detecciones: $_successfulDetections/$_detectionAttempts',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Botón añadir manualmente
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.edit, color: Colors.white),
              label: Text('Añadir manualmente', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.coralMain,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.coralMain),
              SizedBox(height: 16),
              Text(
                'Procesando código...',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Consultando múltiples bases de datos',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.mediumGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_outlined,
              size: 64,
              color: AppTheme.errorRed,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _requestCameraPermission,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.coralMain,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.coralMain.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.camera_alt,
                size: 64,
                color: AppTheme.coralMain,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Permisos de cámara requeridos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Para escanear códigos de barras necesitamos acceso a tu cámara',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.mediumGrey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _requestCameraPermission,
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                label: const Text('Conceder permisos', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.coralMain,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRestartServiceDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Reiniciar Servicio'),
      content: Text('¿Estás seguro de que quieres reiniciar el servicio de códigos de barras? Esto limpiará el caché y reinicializará las APIs.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            await _restartService();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.coralMain,
          ),
          child: Text('Reiniciar'),
        ),
      ],
    ),
  );
}

Future<void> _restartService() async {
  try {
    // Mostrar indicador de carga
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Reiniciando servicio...'),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
    
    // Reiniciar servicio
    await _barcodeService.resetService();
    
    // Resetear estadísticas locales
    setState(() {
      _detectionAttempts = 0;
      _successfulDetections = 0;
      _detectedProduct = null;
      _showConfidenceIndicator = false;
      _detectionConfidence = 0.0;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Servicio reiniciado correctamente'),
            ],
          ),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
    
  } catch (e) {
    print('Error reiniciando servicio: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error reiniciando servicio: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }
}

  void _showStatsDialog() async {
  try {
    // Obtener diagnóstico completo
    final diagnosis = await _barcodeService.quickDiagnosis();
    final stats = await _barcodeService.getServiceStats();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Estado del Escáner'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Estado del servicio
              _buildStatSection('Estado del Servicio', [
                _buildStatRow('Servicio inicializado', diagnosis['service_initialized'].toString()),
                _buildStatRow('APIs disponibles', '${diagnosis['total_apis']}'),
                _buildStatRow('Base de datos', diagnosis['database_ready'].toString()),
                _buildStatRow('Región actual', diagnosis['current_region']),
              ]),
              
              SizedBox(height: 16),
              
              // Estadísticas de sesión
              _buildStatSection('Estadísticas de Sesión', [
                _buildStatRow('Detecciones exitosas', '$_successfulDetections'),
                _buildStatRow('Intentos totales', '$_detectionAttempts'),
                _buildStatRow('Tasa de éxito', _detectionAttempts > 0 
                    ? '${((_successfulDetections / _detectionAttempts) * 100).round()}%' 
                    : '0%'),
                _buildStatRow('Caché de sesión', '${diagnosis['session_cache_size']}'),
              ]),
              
              SizedBox(height: 16),
              
              // APIs activas
              _buildStatSection('APIs Activas', 
                (diagnosis['working_apis'] as List).map((api) => 
                  _buildStatRow(api.toString(), '✅ Activa')
                ).toList()
              ),
              
              SizedBox(height: 16),
              
              // Botón de reinicio
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    _showRestartServiceDialog();
                  },
                  icon: Icon(Icons.refresh),
                  label: Text('Reiniciar Servicio'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.coralMain,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  } catch (e) {
    print('Error obteniendo estadísticas: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando estadísticas'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }
}

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  List<Widget> _buildAPIStats(Map<String, dynamic> apiStats) {
    if (apiStats.isEmpty) {
      return [
        Text(
          'No hay estadísticas disponibles',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.mediumGrey,
          ),
        ),
      ];
    }

    return apiStats.entries.map((entry) {
      final stats = entry.value as Map<String, dynamic>? ?? {};
      final successRate = ((stats['success_rate'] ?? 0.0) as double) * 100;
      
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                entry.key,
                style: TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: successRate > 50 ? AppTheme.successGreen : AppTheme.errorRed,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${successRate.round()}%',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Color _getConfidenceColor() {
    if (_detectionConfidence > 0.8) return AppTheme.successGreen;
    if (_detectionConfidence > 0.6) return AppTheme.yellowAccent;
    if (_detectionConfidence > 0.4) return AppTheme.warningOrange;
    return AppTheme.errorRed;
  }

  IconData _getConfidenceIcon() {
    if (_detectionConfidence > 0.8) return Icons.verified;
    if (_detectionConfidence > 0.6) return Icons.check_circle_outline;
    if (_detectionConfidence > 0.4) return Icons.help_outline;
    return Icons.warning_outlined;
  }
}

// Custom painter para la línea de escaneo
class ScanLinePainter extends CustomPainter {
  final double progress;
  final Color color;
  
  ScanLinePainter({required this.progress, required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          color.withOpacity(0.3),
          color,
          color.withOpacity(0.3),
          Colors.transparent,
        ],
        stops: [0.0, 0.2, 0.5, 0.8, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 3));
    
    final y = progress * size.height;
    
    canvas.drawLine(
      Offset(20, y),
      Offset(size.width - 20, y),
      paint..strokeWidth = 3,
    );
    
    // Efectos adicionales en las esquinas
    final cornerPaint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    
    final cornerSize = 20.0;
    
    // Esquina superior izquierda
    canvas.drawLine(Offset(20, 20), Offset(20 + cornerSize, 20), cornerPaint);
    canvas.drawLine(Offset(20, 20), Offset(20, 20 + cornerSize), cornerPaint);
    
    // Esquina superior derecha
    canvas.drawLine(Offset(size.width - 20, 20), Offset(size.width - 20 - cornerSize, 20), cornerPaint);
    canvas.drawLine(Offset(size.width - 20, 20), Offset(size.width - 20, 20 + cornerSize), cornerPaint);
    
    // Esquina inferior izquierda
    canvas.drawLine(Offset(20, size.height - 20), Offset(20 + cornerSize, size.height - 20), cornerPaint);
    canvas.drawLine(Offset(20, size.height - 20), Offset(20, size.height - 20 - cornerSize), cornerPaint);
    
    // Esquina inferior derecha
    canvas.drawLine(Offset(size.width - 20, size.height - 20), Offset(size.width - 20 - cornerSize, size.height - 20), cornerPaint);
    canvas.drawLine(Offset(size.width - 20, size.height - 20), Offset(size.width - 20, size.height - 20 - cornerSize), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant ScanLinePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
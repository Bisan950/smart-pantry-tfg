// lib/screens/inventory/barcode_scanner_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import '../../config/theme.dart';
import '../../models/product_model.dart';
import '../../services/barcode_service.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/loading_indicator.dart';
import 'add_product_screen.dart';
import 'expiry_date_scanner_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// Clase CustomPainter para dibujar la línea de escaneo
class ScanLinePainter extends CustomPainter {
  final double progress;
  final Color color;
  
  ScanLinePainter({
    required this.progress,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          color.withOpacity(0.8),
          color,
          color.withOpacity(0.8),
          Colors.transparent,
        ],
        stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 2));
    
    // Calcular la posición Y de la línea basada en el progreso
    final y = progress * size.height;
    
    // Dibujar la línea
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      paint..strokeWidth = 2,
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  final BarcodeService _barcodeService = BarcodeService();
  
  // Controlador de MobileScanner
  MobileScannerController? _mobileScannerController;
  bool _isCameraInitialized = false;
  
  // Estados
  bool _isProcessingBarcode = false;
  bool _hasPermission = false;
  String? _errorMessage;
  Product? _scannedProduct;
  
  // Capacidades del dispositivo
  bool _hasFlash = false;
  bool _isFlashOn = false;
  
  // Animaciones para efectos visuales
  late AnimationController _scanAnimationController;
  late Animation<double> _scanAnimation;
  bool _showScanEffect = false;
  
  // Timer para escaneo continuo
  Timer? _scanTimer;
  bool _isScanning = false;
  int _scanAttempts = 0;
  final int _maxScanAttemptsBeforePause = 10;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Inicializar controladores de animación con una duración más lenta para mejor visualización
    _scanAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scanAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scanAnimationController,
      curve: Curves.easeInOut,
    ));
    
    // Iniciar la animación con un ciclo repetitivo
    _scanAnimationController.repeat(reverse: true);
    
    _requestCameraPermission(); // Primero solicitar permisos
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // Detener el timer de escaneo continuo
    _stopContinuousScanning();
    
    // Detener animación
    _scanAnimationController.stop();
    _scanAnimationController.dispose();
    
    // Liberar recursos de MobileScanner
    if (_mobileScannerController != null) {
      try {
        _mobileScannerController!.dispose();
      } catch (e) {
        print('Error al liberar MobileScanner en dispose: $e');
      }
      _mobileScannerController = null;
    }
    
    super.dispose();
  }

  // Método para apagar el flash de forma segura
  Future<void> _turnOffFlash() async {
    if (_mobileScannerController != null && _isFlashOn) {
      try {
        if (_mobileScannerController!.torchEnabled) {
          await _mobileScannerController!.toggleTorch();
        }
        _isFlashOn = false;
      } catch (e) {
        print('Error al apagar el flash: $e');
      }
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Cuando la app vuelve a primer plano, reiniciar cámara con un retraso
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _initializeCamera();
        }
      });
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Cuando la app pasa a segundo plano, liberar recursos
      _turnOffFlash();
      _stopContinuousScanning();
      _scanAnimationController.stop();
      
      // Liberar recursos de MobileScanner
      if (_mobileScannerController != null) {
        try {
          _mobileScannerController!.dispose();
        } catch (e) {
          print('Error al liberar MobileScanner en cambio de ciclo de vida: $e');
        }
        _mobileScannerController = null;
        _isCameraInitialized = false;
      }
    }
  }
  
  // Iniciar escaneo continuo
  void _startContinuousScanning() {
    if (_isScanning) return;
    
    _isScanning = true;
    _scanAttempts = 0;
    
    // Iniciar el timer para escanear cada cierto tiempo
    _scanTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (!mounted || _isProcessingBarcode) return;
      
      _scanAttempts++;
      
      // Hacer una pausa después de cierto número de intentos para no sobrecargar la CPU
      if (_scanAttempts >= _maxScanAttemptsBeforePause) {
        _scanAttempts = 0;
        // Pequeña pausa
        _scanTimer?.cancel();
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _isScanning) {
            _scanTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
              if (!mounted || _isProcessingBarcode) return;
              _scanBarcodeFromCamera();
            });
          }
        });
      } else {
        _scanBarcodeFromCamera();
      }
    });
  }
  
  // Detener escaneo continuo
  void _stopContinuousScanning() {
    _isScanning = false;
    _scanTimer?.cancel();
    _scanTimer = null;
  }
  
  Future<void> _requestCameraPermission() async {
    try {
      // Usar permission_handler directamente o tu BarcodeService
      final hasPermission = await _barcodeService.requestCameraPermission();
      
      if (mounted) {
        setState(() {
          _hasPermission = hasPermission;
          _errorMessage = hasPermission ? null : 'No se tienen permisos para acceder a la cámara';
        });
        
        if (hasPermission) {
          // Inicializar con retraso para asegurar que los permisos se aplican correctamente
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _initializeCamera();
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasPermission = false;
          _errorMessage = 'Error al solicitar permisos de cámara: $e';
        });
      }
    }
  }
  
  Future<void> _initializeCamera() async {
    try {
      if (!_hasPermission) {
        return;
      }
      
      // Asegurar que no hay un controlador activo
      if (_mobileScannerController != null) {
        try {
          _mobileScannerController!.dispose();
        } catch (e) {
          print('Error al liberar controlador de MobileScanner: $e');
        }
        _mobileScannerController = null;
      }
      
      // Esperar un momento para asegurar que los recursos anteriores se liberaron
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Crear un nuevo controlador
      _mobileScannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false, // Iniciar siempre con flash apagado
      );
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          // La mayoría de dispositivos tienen flash
          _hasFlash = true;
          _isFlashOn = false;
          
          // Reiniciar animación solo si no estaba ya corriendo
          if (!_scanAnimationController.isAnimating) {
            _scanAnimationController.repeat(reverse: true);
          }
        });
        
        // Iniciar el escaneo continuo automáticamente después de un breve retraso
        // Este retraso es importante para permitir que el widget MobileScanner se inicialice
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _mobileScannerController != null) {
            _startContinuousScanning();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al inicializar el escáner: $e';
          _isCameraInitialized = false;
        });
      }
      print('Error detallado al inicializar MobileScanner: $e');
    }
  }
  
  void _playScanEffect() {
    HapticFeedback.mediumImpact();
    
    setState(() {
      _showScanEffect = true;
    });
    
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showScanEffect = false;
        });
      }
    });
  }
  
  // Método para capturar y procesar la imagen para detectar códigos de barras
  Future<void> _scanBarcodeFromCamera() async {
    if (_isProcessingBarcode || !_isCameraInitialized || _mobileScannerController == null) {
      return;
    }
    
    setState(() {
      _isProcessingBarcode = true;
    });
    
    try {
      // En una implementación real, aquí analizarías la imagen para detectar un código de barras
      // Para este ejemplo, simulamos la detección con una probabilidad baja
      final random = Random();
      
      // Probabilidad de detectar un código (5% para pruebas)
      if (random.nextDouble() < 0.05) {
        // Simular una pequeña pausa como si estuviéramos procesando
        await Future.delayed(const Duration(milliseconds: 300));
        
        // Obtener un código de barras aleatorio de los ejemplos
        final demoBarcode = [
          '8410188012912', // Zumo Don Simón
          '8480000118127', // Leche Hacendado
          '8410668004672', // Galletas María
          '8480000591470', // Pan de molde
          '8480000503199',  // Agua mineral
        ][random.nextInt(5)];
        
        _playScanEffect();
        
        final product = await _barcodeService.createProductFromBarcode(demoBarcode);
        
        if (product != null) {
          if (mounted) {
            setState(() {
              _scannedProduct = product;
              _isProcessingBarcode = false;
            });
          }
          
          // Mostrar mensaje de éxito
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Producto encontrado: ${product.name}'),
              backgroundColor: AppTheme.successGreen,
              duration: const Duration(seconds: 2),
            ),
          );
          
          // Detener el escaneo continuo
          _stopContinuousScanning();
          
          // Devolver el producto a la pantalla anterior
          Navigator.pop(context, product);
          return;
        } else {
          if (mounted) {
            setState(() {
              _isProcessingBarcode = false;
            });
            
            _showAddManuallyDialog(demoBarcode);
            return;
          }
        }
      }
      
      // No se detectó código, seguir escaneando
      if (mounted) {
        setState(() {
          _isProcessingBarcode = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingBarcode = false;
        });
        
        print('Error al escanear código de barras: $e');
      }
    }
  }
  
  void _showAddManuallyDialog(String barcode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          ),
          title: Text(
            'Producto no encontrado',
            style: TextStyle(
              color: AppTheme.coralMain,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Este producto no está en nuestra base de datos. '
            '¿Quieres añadirlo manualmente?'
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                // Volver a empezar a escanear
                if (mounted) {
                  setState(() {
                    _errorMessage = null;
                  });
                  
                  // Reiniciar el escaneo continuo
                  _startContinuousScanning();
                }
              },
              child: Text(
                'Cancelar',
                style: TextStyle(color: AppTheme.mediumGrey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.coralMain,
                foregroundColor: AppTheme.pureWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                
                // Detener el escaneo continuo
                _stopContinuousScanning();
                
                // Devolver el código de barras a la pantalla anterior
                Navigator.pop(context, barcode);
              },
              child: const Text('Añadir'),
            ),
          ],
        );
      },
    );
  }
  
  void _navigateToAddProduct({String? barcode}) async {
    // Detener el escaneo continuo
    _stopContinuousScanning();
    
    // Liberar recursos de MobileScanner antes de navegar
    if (_mobileScannerController != null) {
      try {
        await _turnOffFlash();
        _mobileScannerController!.dispose();
      } catch (e) {
        print('Error al liberar MobileScanner en navegación: $e');
      }
      _mobileScannerController = null;
      _isCameraInitialized = false;
    }_mobileScannerController!.dispose();
    
    // Cerrar la pantalla de escaneo y abrir la de añadir producto
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddProductScreen(
          barcodeValue: barcode,
          productToEdit: null,
        ),
      ),
    );
    
    // Si se añadió correctamente, volver a la pantalla de inventario
    if (result == true) {
      Navigator.pop(context, true);
    } else {
      // Volver a escanear - limpiar estado y reinicializar cámara
      if (mounted) {
        setState(() {
          _errorMessage = null;
          _scannedProduct = null;
        });
        
        // Retraso para asegurar liberación de recursos
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _initializeCamera();
          }
        });
      }
    }
  }
  
  void _navigateToExpiryDateScanner() async {
    if (_scannedProduct == null) {
      return;
    }
    
    // Detener el escaneo continuo
    _stopContinuousScanning();
    
    // Liberar recursos de MobileScanner antes de navegar
    if (_mobileScannerController != null) {
      try {
        await _turnOffFlash();
        _mobileScannerController!.dispose();
      } catch (e) {
        print('Error al liberar MobileScanner en navegación: $e');
      }
      _mobileScannerController = null;
      _isCameraInitialized = false;
    }
    
    // Navegar a la pantalla de escaneo de fecha de caducidad
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExpiryDateScannerScreen(
          product: _scannedProduct!,
        ),
      ),
    );
    
    // Si se procesó correctamente, volver a la pantalla de inventario
    if (result == true) {
      Navigator.pop(context, true);
    } else {
      // Volver a escanear con estado limpio
      if (mounted) {
        setState(() {
          _scannedProduct = null;
          _errorMessage = null;
        });
        
        // Retraso para asegurar liberación de recursos
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _initializeCamera();
          }
        });
      }
    }
  }
  
  void _toggleFlash() {
    if (_mobileScannerController != null && _hasFlash) {
      try {
        _mobileScannerController!.toggleTorch();
        
        if (mounted) {
          setState(() {
            _isFlashOn = !_isFlashOn;
          });
        }
      } catch (e) {
        print('Error al cambiar el flash: $e');
        
        // Intentar recuperar si hay error
        _isFlashOn = false;
      }
    }
  }
  
  // Método para forzar la detección (para pruebas)
  void _forceDetection() {
    _stopContinuousScanning();
    
    _playScanEffect();
    
    // Simular una detección
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      
      // Obtener un código aleatorio
      final random = Random();
      final demoBarcode = [
        '8410188012912', // Zumo Don Simón
        '8480000118127', // Leche Hacendado
        '8410668004672', // Galletas María
        '8480000591470', // Pan de molde
        '8480000503199',  // Agua mineral
      ][random.nextInt(5)];
      
      final product = await _barcodeService.createProductFromBarcode(demoBarcode);
      
      if (product != null && mounted) {
        setState(() {
          _scannedProduct = product;
        });
        
        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Producto encontrado: ${product.name}'),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 2),
          ),
        );
        
        Navigator.pop(context, product);
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Escanear código de barras',
        actions: [
          if (_hasFlash)
            IconButton(
              icon: Icon(
                _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                color: _isFlashOn ? AppTheme.yellowAccent : null,
              ),
              onPressed: _toggleFlash,
              tooltip: 'Activar/desactivar flash',
            ),
        ],
      ),
      body: _buildBody(),
      resizeToAvoidBottomInset: false, // Evitar resize cuando aparece el teclado
    );
  }

  Widget _buildBody() {
    // Si se ha encontrado un producto, mostrar sus detalles
    if (_scannedProduct != null) {
      return _buildProductFoundView();
    }
    
    // Si hay un error, mostrar mensaje
    if (_errorMessage != null) {
      return _buildErrorView();
    }
    
    // Si no tenemos permiso, mostrar solicitud
    if (!_hasPermission) {
      return _buildRequestPermissionView();
    }
    
    // Si estamos procesando, mostrar indicador
    if (_isProcessingBarcode) {
      return Center(
        child: LoadingIndicator(
          message: 'Procesando código...',
          color: AppTheme.coralMain,
        ),
      );
    }
    
    // Mostrar escáner
    return _buildCameraView();
  }
  
  Widget _buildCameraView() {
    if (!_hasPermission) {
      return _buildRequestPermissionView();
    }

    return Container(
      color: Colors.black,
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Scanner con callback para detección
          if (_mobileScannerController != null)
            MobileScanner(
              controller: _mobileScannerController!,
              onDetect: (capture) {
                final barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && !_isProcessingBarcode) {
                  for (final barcode in barcodes) {
                    final rawValue = barcode.rawValue;
                    if (rawValue != null && rawValue.isNotEmpty) {
                      // Procesar código detectado
                      _processBarcodeValue(rawValue);
                      break;
                    }
                  }
                }
              },
            ),
          
          // 2. Capa de oscurecimiento
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
          
          // 3. Ventana de escaneo transparente
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(
                  color: AppTheme.coralMain,
                  width: 3.0,
                ),
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              ),
            ),
          ),
          
          // 4. Línea de escaneo
          Center(
            child: SizedBox(
              width: 250,
              height: 250,
              child: AnimatedBuilder(
                animation: _scanAnimation,
                builder: (context, child) {
                  return Padding(
                    padding: const EdgeInsets.all(10),
                    child: CustomPaint(
                      size: const Size(230, 230),
                      painter: ScanLinePainter(
                        progress: _scanAnimation.value,
                        color: AppTheme.coralMain,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          
          // 5. Efecto de detección exitosa
          if (_showScanEffect)
            Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppTheme.successGreen,
                    width: 3.0,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.successGreen.withOpacity(0.5),
                      spreadRadius: 10,
                      blurRadius: 15,
                    ),
                  ],
                ),
              ),
            ),
          
          // 6. Mensaje de estado
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                ),
                child: Text(
                  'Escaneando automáticamente...',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          
          // 7. Texto de instrucción
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 120, left: 20, right: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppTheme.peachLight,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Alinea el código de barras dentro del recuadro',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.pureWhite,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // 8. Botón de añadir manualmente
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30, left: 20, right: 20),
              child: SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Añadir manualmente',
                  onPressed: () => _navigateToAddProduct(),
                  type: ButtonType.secondary,
                  icon: Icons.edit_rounded,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processBarcodeValue(String barcodeValue) async {
    if (_isProcessingBarcode || !mounted) {
      return;
    }
    
    setState(() {
      _isProcessingBarcode = true;
    });
    
    try {
      _playScanEffect();
      
      final product = await _barcodeService.createProductFromBarcode(barcodeValue);
      
      if (product != null) {
        if (mounted) {
          setState(() {
            _scannedProduct = product;
            _isProcessingBarcode = false;
          });
        }
        
        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Producto encontrado: ${product.name}'),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Detener el escaneo continuo
        _stopContinuousScanning();
        
        // Devolver el producto a la pantalla anterior
        Navigator.pop(context, product);
      } else {
        if (mounted) {
          setState(() {
            _isProcessingBarcode = false;
          });
          
          _showAddManuallyDialog(barcodeValue);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingBarcode = false;
        });
        print('Error al procesar código de barras: $e');
      }
    }
  }
  
  Widget _buildProductFoundView() {
    final product = _scannedProduct!;
    
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tarjeta de producto
          Card(
            elevation: AppTheme.elevationTiny,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categoría
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingMedium,
                      vertical: AppTheme.spacingSmall,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.peachLight.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
                    ),
                    child: Text(
                      product.category,
                      style: TextStyle(
                        color: AppTheme.coralMain,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),
                  
                  // Nombre
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLarge),
                  
                  // Cantidad
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.peachLight.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                        ),
                        child: Icon(Icons.scale_rounded, color: AppTheme.coralMain),
                      ),
                      const SizedBox(width: AppTheme.spacingMedium),
                      Text(
                        '${product.quantity} ${product.unit}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),
                  
                  // Ubicación
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.peachLight.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                        ),
                        child: Icon(Icons.place_rounded, color: AppTheme.coralMain),
                      ),
                      const SizedBox(width: AppTheme.spacingMedium),
                      Text(
                        product.location,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),
                  
                  // Fecha de caducidad
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.peachLight.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                        ),
                        child: Icon(Icons.calendar_today_rounded, color: AppTheme.coralMain),
                      ),
                      const SizedBox(width: AppTheme.spacingMedium),
                      Text(
                        product.expiryDate != null
                            ? '${product.expiryDate!.day}/${product.expiryDate!.month}/${product.expiryDate!.year}'
                            : 'Sin fecha de caducidad',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingXLarge),
          
          // Botones de acción
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Editar',
                  onPressed: () => _navigateToAddProduct(),
                  type: ButtonType.secondary,
                  icon: Icons.edit_rounded,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMedium),
              Expanded(
                child: CustomButton(
                  text: 'Escanear fecha',
                  onPressed: _navigateToExpiryDateScanner,
                  type: ButtonType.primary,
                  icon: Icons.calendar_today_rounded,
                ),
              ),
            ],
          ),
         
          const SizedBox(height: AppTheme.spacingLarge),
         
          // Botón para volver a escanear
          Center(
            child: CustomButton(
              text: 'Escanear otro',
              onPressed: () {
                if (mounted) {
                  setState(() {
                    _scannedProduct = null;
                  });
                }
                _initializeCamera();
              },
              type: ButtonType.text,
              icon: Icons.qr_code_scanner_rounded,
            ),
          ),
        ],
      ),
    );
  }
 
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLarge),
        child: Card(
          elevation: AppTheme.elevationTiny,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 70,
                  color: AppTheme.errorRed,
                ),
                const SizedBox(height: AppTheme.spacingMedium),
                Text(
                  _errorMessage ?? 'Error desconocido',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppTheme.spacingLarge),
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    text: 'Intentar de nuevo',
                    onPressed: () {
                      if (mounted) {
                        setState(() {
                          _errorMessage = null;
                        });
                      }
                      _initializeCamera();
                    },
                    type: ButtonType.primary,
                    icon: Icons.refresh_rounded,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMedium),
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    text: 'Añadir manualmente',
                    onPressed: () => _navigateToAddProduct(),
                    type: ButtonType.secondary,
                    icon: Icons.edit_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
 
  Widget _buildRequestPermissionView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLarge),
        child: Card(
          elevation: AppTheme.elevationTiny,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.peachLight.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    size: 60,
                    color: AppTheme.coralMain,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMedium),
                Text(
                  'Se necesita acceso a la cámara para escanear códigos de barras',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppTheme.spacingLarge),
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    text: 'Permitir acceso',
                    onPressed: () async {
                      final granted = await _barcodeService.requestCameraPermission();
                      if (granted && mounted) {
                        setState(() {
                          _hasPermission = true;
                        });
                        _initializeCamera();
                      }
                    },
                    type: ButtonType.primary,
                    icon: Icons.check_rounded,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMedium),
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    text: 'Añadir manualmente',
                    onPressed: () => _navigateToAddProduct(),
                    type: ButtonType.secondary,
                    icon: Icons.edit_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
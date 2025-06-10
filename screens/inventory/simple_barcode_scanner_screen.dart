// lib/screens/inventory/simple_barcode_scanner_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'dart:async';
import '../../config/theme.dart';
import '../../services/camera_service.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../utils/snackbar_utils.dart';

class SimpleBarcodeScannerScreen extends StatefulWidget {
  const SimpleBarcodeScannerScreen({super.key});

  @override
  State<SimpleBarcodeScannerScreen> createState() => _SimpleBarcodeScannerScreenState();
}

class _SimpleBarcodeScannerScreenState extends State<SimpleBarcodeScannerScreen> with WidgetsBindingObserver {
  final CameraService _cameraService = CameraService();
  
  // Controlador de cámara
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  
  // Detector de códigos de barras
  final BarcodeScanner _barcodeScanner = GoogleMlKit.vision.barcodeScanner();
  bool _isScanning = false;
  
  // Estados
  bool _hasPermission = false;
  String? _errorMessage;
  bool _isFlashOn = false;
  bool _showScanEffect = false;
  
  // Control de escaneo
  DateTime _lastScanTime = DateTime.now();
  Timer? _scanTimer;
  
  // Bloqueo para evitar múltiples popups
  bool _isNavigatingBack = false;
  
  // Flag para evitar múltiples inicializaciones simultáneas
  bool _isCameraInitializing = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Pequeño retraso para asegurar que el widget esté completamente montado
    Future.delayed(const Duration(milliseconds: 100), _initializeCamera);
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopScanning();
    _scanTimer?.cancel();
    
    // Manejo seguro de la cámara
    if (_cameraController != null) {
      if (_isFlashOn) {
        try {
          _cameraController!.setFlashMode(FlashMode.off).catchError((e) {
            print('Error al apagar flash en dispose: $e');
          });
        } catch (e) {
          print('Error al apagar flash en dispose: $e');
        }
      }
      
      try {
        _cameraController!.dispose().catchError((e) {
          print('Error al disponer controller en dispose: $e');
        });
      } catch (e) {
        print('Error al disponer controller en dispose: $e');
      }
      _cameraController = null;
    }
    
    _cameraService.dispose();
    
    // Cerrar el detector de códigos de barras
    try {
      _barcodeScanner.close().catchError((e) {
        print('Error al cerrar barcodeScanner: $e');
      });
    } catch (e) {
      print('Error al cerrar barcodeScanner: $e');
    }
    
    super.dispose();
  }
  
  void _stopScanning() {
    // Cancelar timer existente
    _scanTimer?.cancel();
    _scanTimer = null;
    
    // Asegurarse de apagar el flash si está encendido
    if (_isFlashOn && _cameraController != null && _cameraController!.value.isInitialized) {
      try {
        _cameraController!.setFlashMode(FlashMode.off).catchError((e) {
          print('Error al apagar flash en stopScanning: $e');
        });
        _isFlashOn = false;
      } catch (e) {
        print('Error al apagar flash en stopScanning: $e');
      }
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    
    // Verificar si tenemos controlador antes de hacer algo
    if (_cameraController == null) return;
    
    if (state == AppLifecycleState.resumed) {
      // La app volvió a primer plano, reinicializar la cámara
      _initializeCamera();
    } else if (state == AppLifecycleState.inactive || 
              state == AppLifecycleState.paused || 
              state == AppLifecycleState.detached) {
      // La app fue minimizada o perdió el foco, liberar recursos
      _stopScanning();
      
      // Apagar el flash si está encendido
      if (_isFlashOn && _cameraController != null && _cameraController!.value.isInitialized) {
        try {
          _cameraController!.setFlashMode(FlashMode.off).catchError((e) {
            print('Error al apagar flash en pausa: $e');
          });
          _isFlashOn = false;
        } catch (e) {
          print('Error al apagar flash en pausa: $e');
        }
      }
      
      // Liberar cámara
      if (_cameraController != null) {
        try {
          _cameraController!.dispose().catchError((e) {
            print('Error al disponer cámara en pausa: $e');
          });
        } catch (e) {
          print('Error al disponer cámara en pausa: $e');
        }
        _cameraController = null;
      }
      
      _isCameraInitialized = false;
    }
  }

  // Método modificado: Escaneo continuo sin límite de intentos
  void _startPeriodicScanning() {
    // Cancelar timer existente
    _scanTimer?.cancel();
    
    // Crear un nuevo timer con intervalo de 1.5 segundos
    _scanTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      if (!mounted || _isNavigatingBack) {
        timer.cancel();
        return;
      }
      
      // Verificar si la cámara sigue inicializada
      if (!_isCameraInitialized || _cameraController == null || 
          !_cameraController!.value.isInitialized) {
        timer.cancel();
        if (mounted) {
          // Intentar reinicializar la cámara
          _initializeCamera();
        }
        return;
      }
      
      // Verificar si podemos escanear (solo basado en el tiempo desde el último escaneo)
      if (!_isScanning && 
          DateTime.now().difference(_lastScanTime).inMilliseconds > 1500) {
        await _scanImage();
      }
    });
  }
  
  Future<void> _initializeCamera() async {
    if (!mounted) return;
    
    // Evitar doble inicialización
    if (_isCameraInitializing) return;
    
    _isCameraInitializing = true;
    
    // Cancelar cualquier timer existente
    _scanTimer?.cancel();
    
    try {
      // Verificar permisos
      final hasPermission = await _cameraService.requestCameraPermission();
      
      if (!mounted) return;
      
      setState(() {
        _hasPermission = hasPermission;
        _errorMessage = hasPermission ? null : 'No se tienen permisos para acceder a la cámara';
      });
      
      if (!hasPermission) {
        _isCameraInitializing = false;
        return;
      }
      
      // Limpiar recursos existentes
      if (_cameraController != null) {
        try {
          await _cameraController!.dispose().catchError((e) {
            print('Error al disponer controlador existente: $e');
          });
        } catch (e) {
          print('Error al disponer controlador existente: $e');
        }
        _cameraController = null;
      }
      
      // Inicializar la cámara con timeout de 10 segundos
      final initialized = await _cameraService.initializeCamera(
        resolution: ResolutionPreset.medium // Usar resolución media para mejor rendimiento
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('Timeout al inicializar la cámara');
          return false;
        }
      );
      
      if (!mounted) return;
      
      if (!initialized) {
        setState(() {
          _errorMessage = 'No se pudo inicializar la cámara';
        });
        _isCameraInitializing = false;
        return;
      }
      
      // Obtener controlador
      final controller = _cameraService.cameraController;
      if (controller == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Error al obtener el controlador de la cámara';
          });
        }
        _isCameraInitializing = false;
        return;
      }
      
      // Verificar que el controlador esté inicializado
      if (!controller.value.isInitialized) {
        if (mounted) {
          setState(() {
            _errorMessage = 'El controlador no está inicializado correctamente';
          });
        }
        _isCameraInitializing = false;
        return;
      }
      
      // Asegurarse de que el flash esté apagado al iniciar
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (e) {
        print('Error no crítico al configurar flash: $e');
      }
      
      if (!mounted) return;
      
      setState(() {
        _cameraController = controller;
        _isCameraInitialized = true;
        _isFlashOn = false;
      });
      
      // Iniciar escaneo periódico usando Timer
      _startPeriodicScanning();
    } catch (e) {
      print('Error general al inicializar la cámara: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al inicializar la cámara: $e';
        });
      }
    } finally {
      _isCameraInitializing = false;
    }
  }
  
  Future<void> _scanImage() async {
    if (_isScanning || !_isCameraInitialized || _cameraController == null || 
        !_cameraController!.value.isInitialized || _isNavigatingBack) {
      return;
    }
    
    _isScanning = true;
    _lastScanTime = DateTime.now();
    
    XFile? photo;
    File? tempFile;
    
    try {
      // Tomar una foto
      photo = await _cameraController!.takePicture().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          throw TimeoutException('Timeout al tomar foto');
        }
      );
      
      tempFile = File(photo.path);
      
      if (!mounted || _isNavigatingBack) return;
      
      // Verificar tamaño del archivo
      final fileSize = await tempFile.length();
      if (fileSize <= 0) {
        print('Archivo de imagen vacío o inválido. Tamaño: $fileSize bytes');
        return;
      }
      
      // Usar un bloque try/catch separado para el procesamiento con ML Kit
      try {
        // Procesar la imagen
        final inputImage = InputImage.fromFilePath(photo.path);
        final barcodes = await _barcodeScanner.processImage(inputImage)
            .timeout(const Duration(seconds: 10)); // Aumentar timeout
        
        if (!mounted || _isNavigatingBack) return;
        
        if (barcodes.isNotEmpty) {
          for (final barcode in barcodes) {
            if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
              // Para evitar múltiples intentos de navegación
              if (_isNavigatingBack) return;
              _isNavigatingBack = true;
              
              // Detener el escaneo
              _stopScanning();
              
              // Apagar el flash si está encendido
              if (_isFlashOn) {
                try {
                  await _cameraController!.setFlashMode(FlashMode.off);
                  _isFlashOn = false;
                } catch (e) {
                  print('Error al apagar el flash: $e');
                }
              }
              
              // Efecto visual y háptico
              try {
                HapticFeedback.mediumImpact();
              } catch (e) {
                print('Error no crítico con haptic feedback: $e');
              }
              
              if (!mounted) return;
              
              setState(() {
                _showScanEffect = true;
              });
              
              // Esperar un momento para mostrar el efecto
              await Future.delayed(const Duration(milliseconds: 500));
              
              if (!mounted) return;
              
              // Devolver el código detectado y salir
              Navigator.pop(context, barcode.rawValue);
              return;
            }
          }
        }
      } catch (mlKitError) {
        print('Error en ML Kit al procesar la imagen: $mlKitError');
        // No lanzar la excepción para evitar que la app se cierre
      }
    } catch (e) {
      print('Error general al escanear imagen: $e');
    } finally {
      // IMPORTANTE: Asegurarse de eliminar el archivo temporal SIEMPRE
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (e) {
        print('Error al eliminar archivo temporal: $e');
      }
      
      // Solo actualizar el estado si todavía estamos montados
      if (mounted && !_isNavigatingBack) {
        _isScanning = false;
      }
    }
  }
  
  void _toggleFlash() {
    if (!_isCameraInitialized || _cameraController == null || 
        !_cameraController!.value.isInitialized) {
      return;
    }
    
    try {
      if (_isFlashOn) {
        _cameraController!.setFlashMode(FlashMode.off);
      } else {
        _cameraController!.setFlashMode(FlashMode.torch);
      }
      
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      SnackBarUtils.showError(context, 'Error al cambiar el flash');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Asegurarse de detener el escaneo antes de salir
        _stopScanning();
        return true;
      },
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'Escanear código de barras',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              _stopScanning(); // Asegurarse de detener el escaneo antes de salir
              Navigator.pop(context);
            },
            tooltip: 'Volver',
          ),
          actions: [
            if (_isCameraInitialized)
              IconButton(
                icon: Icon(_isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded),
                onPressed: _toggleFlash,
                tooltip: 'Activar/desactivar flash',
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }
  
  Widget _buildBody() {
    // Si hay un error, mostrar mensaje
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 70,
              color: AppTheme.errorRed,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeCamera,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                ),
              ),
              child: const Text('Reintentar'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver'),
            ),
          ],
        ),
      );
    }
    
    // Si no tenemos permiso, mostrar solicitud
    if (!_hasPermission) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt_rounded,
              size: 70,
              color: AppTheme.darkGrey,
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingLarge),
              child: Text(
                'Se necesita acceso a la cámara para escanear',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeCamera,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                ),
              ),
              child: const Text('Permitir acceso'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver'),
            ),
          ],
        ),
      );
    }
    
    // Si estamos inicializando, mostrar indicador de carga
    if (!_isCameraInitialized || _cameraController == null) {
      return Center(
        child: LoadingIndicator(
          message: 'Inicializando cámara...',
          color: AppTheme.coralMain,
        ),
      );
    }
    
    // Mostrar la vista previa de la cámara
    return Stack(
      children: [
        // Vista previa de la cámara a pantalla completa
        SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: CameraPreview(_cameraController!),
        ),
        
        // Overlay con guía para escaneo
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Cuadro de escaneo
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _showScanEffect ? AppTheme.successGreen : AppTheme.coralMain,
                    width: 3.0,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                  boxShadow: _showScanEffect
                      ? [
                          BoxShadow(
                            color: AppTheme.successGreen.withOpacity(0.5),
                            spreadRadius: 10,
                            blurRadius: 15,
                          ),
                        ]
                      : null,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Instrucciones
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMedium,
                  vertical: AppTheme.spacingSmall,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                ),
                child: const Text(
                  'Alinea el código de barras dentro del recuadro',
                  style: TextStyle(
                    color: AppTheme.pureWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Botón para volver (alternativa a AppBar)
        Positioned(
          bottom: AppTheme.spacingLarge,
          left: 0,
          right: 0,
          child: Center(
            child: TextButton.icon(
              onPressed: () {
                _stopScanning(); // Detener escaneo antes de salir
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Cancelar'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.pureWhite,
                backgroundColor: AppTheme.coralMain.withOpacity(0.8),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMedium,
                  vertical: AppTheme.spacingSmall,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
// lib/services/camera_service.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart' as camera;

/// Servicio para gestionar funcionalidades relacionadas con la cámara
class CameraService {
  // Singleton para acceso global al servicio
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();
  
  // Variables para la gestión de la cámara
  List<CameraDescription>? _cameras;
  CameraController? _controller;
  bool _isInitialized = false;
  
  // Flag para evitar múltiples inicializaciones simultáneas
  bool _isInitializing = false;
  
  // Método correcto para obtener cámaras disponibles
Future<List<CameraDescription>> get availableCameras async {
  if (_cameras != null && _cameras!.isNotEmpty) return _cameras!;
  
  try {
    // Usa la función global de la biblioteca camera, no el getter
    _cameras = await camera.availableCameras();
    return _cameras!;
  } catch (e) {
    if (kDebugMode) {
      print('Error al obtener cámaras disponibles: $e');
    }
    return [];
  }
}
  
  // Inicializar cámara con mejor manejo de errores y configuración segura
  Future<bool> initializeCamera({
    CameraLensDirection direction = CameraLensDirection.back, 
    ResolutionPreset resolution = ResolutionPreset.medium
  }) async {
    // Evitar múltiples inicializaciones simultáneas
    if (_isInitializing) {
      return false;
    }
    
    _isInitializing = true;
    
    // Si ya tenemos una cámara inicializada, intenta liberar recursos primero
    if (_controller != null) {
      try {
        // Intenta apagar el flash si la cámara está inicializada
        if (_isInitialized) {
          await _controller!.setFlashMode(FlashMode.off)
              .timeout(const Duration(milliseconds: 300))
              .catchError((e) {
                print('Error no crítico al apagar flash: $e');
              });
        }
        
        await _controller!.dispose()
            .timeout(const Duration(seconds: 2))
            .catchError((e) {
              print('Error al liberar controlador existente: $e');
            });
      } catch (e) {
        print('Error general al liberar recursos existentes: $e');
      } finally {
        _controller = null;
        _isInitialized = false;
      }
    }
    
    try {
      // Obtener cámaras disponibles con timeout
      List<CameraDescription> cameras = [];
      try {
        cameras = await availableCameras
            .timeout(const Duration(seconds: 5), onTimeout: () {
              throw TimeoutException('Timeout al obtener cámaras disponibles');
            });
      } catch (e) {
        print('Error al obtener cámaras: $e');
        _isInitializing = false;
        return false;
      }
      
      if (cameras.isEmpty) {
        print('No se encontraron cámaras disponibles');
        _isInitializing = false;
        return false;
      }
      
      // Buscar la cámara con la dirección solicitada
      CameraDescription? camera;
      try {
        camera = cameras.firstWhere(
          (cam) => cam.lensDirection == direction,
          orElse: () => cameras.first,
        );
      } catch (e) {
        print('Error al seleccionar cámara: $e');
        if (cameras.isNotEmpty) {
          camera = cameras.first;
        } else {
          _isInitializing = false;
          return false;
        }
      }
      
      // Inicializar el controlador con configuración segura
      try {
        _controller = CameraController(
          camera,
          resolution,
          enableAudio: false, // No necesitamos audio para escaneo
          imageFormatGroup: ImageFormatGroup.jpeg,
        );
        
        // Usar timeout más largo para dispositivos lentos
        await _controller!.initialize().timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw TimeoutException('Timeout al inicializar cámara');
          }
        );
        
        // Configuración segura: primero verificar si el controlador sigue inicializado
        if (!_controller!.value.isInitialized) {
          print('Controlador inicializado pero value.isInitialized es falso');
          await _controller!.dispose().catchError((e) {
            print('Error al disponer controlador incorrecto: $e');
          });
          _controller = null;
          _isInitializing = false;
          return false;
        }
        
        // Configurar flash, enfoque y exposición con manejo de errores individual
        try {
          await _controller!.setFlashMode(FlashMode.off);
        } catch (flashError) {
          print('Error no crítico al configurar flash: $flashError');
          // Continuar a pesar del error
        }
        
        try {
          await _controller!.setFocusMode(FocusMode.auto);
        } catch (focusError) {
          print('Error no crítico al configurar enfoque: $focusError');
          // Continuar a pesar del error
        }
        
        try {
          await _controller!.setExposureMode(ExposureMode.auto);
        } catch (exposureError) {
          print('Error no crítico al configurar exposición: $exposureError');
          // Continuar a pesar del error
        }
        
        _isInitialized = true;
        _isInitializing = false;
        return true;
      } catch (e) {
        print('Error al inicializar controlador: $e');
        
        // Intento de limpieza
        if (_controller != null) {
          try {
            await _controller!.dispose().catchError((disposeError) {
              print('Error secundario al disponer controlador: $disposeError');
            });
          } catch (disposeError) {
            print('Error al hacer dispose del controlador: $disposeError');
          }
          _controller = null;
        }
        
        _isInitialized = false;
        _isInitializing = false;
        return false;
      }
    } catch (e) {
      print('Error general al inicializar cámara: $e');
      _isInitialized = false;
      _isInitializing = false;
      return false;
    }
  }

  /// Método para mejorar la imagen para OCR
Future<File?> enhanceImageForOCR(File imageFile) async {
  try {
    // Leer la imagen
    final Uint8List imageBytes = await imageFile.readAsBytes();
    final img.Image? originalImage = img.decodeImage(imageBytes);
    
    if (originalImage == null) {
      return null;
    }
    
    // Aplicar mejoras para OCR
    // 1. Convertir a escala de grises para mejor reconocimiento de texto
    final img.Image grayscale = img.grayscale(originalImage);
    
    // 2. Aumentar contraste para mejor detección de bordes
    final img.Image enhanced = img.contrast(grayscale, contrast: 1.5);
    
    // Guardar la imagen mejorada
    final List<int> enhancedBytes = img.encodeJpg(enhanced, quality: 90);
    
    // Crear un archivo de salida
    final tempDir = await getTemporaryDirectory();
    final targetPath = path.join(tempDir.path, 'enhanced_${path.basename(imageFile.path)}');
    final enhancedFile = File(targetPath);
    
    // Escribir los datos mejorados al archivo
    await enhancedFile.writeAsBytes(enhancedBytes);
    
    return enhancedFile;
  } catch (e) {
    if (kDebugMode) {
      print('Error al mejorar imagen para OCR: $e');
    }
    return null;
  }
}

/// Método para rotar una imagen si es necesario
Future<File?> rotateImageIfNeeded(File imageFile) async {
  try {
    // Leer la imagen
    final Uint8List imageBytes = await imageFile.readAsBytes();
    final img.Image? originalImage = img.decodeImage(imageBytes);
    
    if (originalImage == null) {
      return null;
    }
    
    // Verificar orientación EXIF y rotar si es necesario
    // En una implementación real, aquí verificaríamos los datos EXIF
    // Por ahora, asumiremos que no es necesario rotar
    
    // Crear un archivo de salida
    final tempDir = await getTemporaryDirectory();
    final targetPath = path.join(tempDir.path, 'rotated_${path.basename(imageFile.path)}');
    final rotatedFile = File(targetPath);
    
    // Escribir la imagen (posiblemente rotada) al archivo
    await rotatedFile.writeAsBytes(imageBytes);
    
    return rotatedFile;
  } catch (e) {
    if (kDebugMode) {
      print('Error al rotar imagen: $e');
    }
    return null;
  }
}
  
  // Obtener el controlador de la cámara
  CameraController? get cameraController => _isInitialized ? _controller : null;
  
  // Liberar recursos de la cámara con manejo mejorado de errores
  Future<void> dispose() async {
    // Si no hay controlador, no hay nada que hacer
    if (_controller == null) {
      _isInitialized = false;
      return;
    }
    
    try {
      // Primero intentar pausar la cámara si está en streaming
      if (_isInitialized && _controller!.value.isInitialized) {
        try {
          if (_controller!.value.isStreamingImages) {
            await _controller!.stopImageStream().timeout(
              const Duration(milliseconds: 500),
              onTimeout: () {
                print('Timeout al detener stream de imágenes');
                // Continuar con el proceso de dispose
              }
            ).catchError((e) {
              print('Error no crítico al detener stream: $e');
              // Continuar con el proceso de dispose
            });
          }
        } catch (streamError) {
          print('Error al verificar/detener stream: $streamError');
          // Continuar con el proceso de dispose
        }
        
        // Luego apagar el flash si está encendido
        try {
          await _controller!.setFlashMode(FlashMode.off).timeout(
            const Duration(milliseconds: 300),
            onTimeout: () {
              print('Timeout al apagar flash');
              // Continuar con el proceso de dispose
            }
          ).catchError((e) {
            print('Error no crítico al apagar flash: $e');
            // Continuar con el proceso de dispose
          });
        } catch (flashError) {
          print('Error al apagar flash: $flashError');
          // Continuar con el proceso de dispose
        }
      }
      
      // Finalmente, liberar el controlador
      try {
        await _controller!.dispose().timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            print('Timeout al disponer controlador');
            // Regresar de todas formas, no podemos hacer más
          }
        );
      } catch (disposeError) {
        print('Error al disponer controlador: $disposeError');
        // Continuar, no hay más opciones
      }
    } catch (e) {
      print('Error general en dispose: $e');
    } finally {
      // Independientemente de lo que haya pasado, marcar como no inicializado
      _controller = null;
      _isInitialized = false;
    }
  }
  
  /// Método para tomar una foto con mejor manejo de errores
  Future<File?> takePhoto({ResolutionPreset resolution = ResolutionPreset.medium}) async {
    File? tempFile;
    File? savedFile;
    
    try {
      // Verificar si la cámara está lista para uso
      if (!_isInitialized || _controller == null) {
        final initialized = await initializeCamera(resolution: resolution);
        if (!initialized) {
          print('No se pudo inicializar la cámara para tomar foto');
          return null;
        }
      }
      
      // Verificar nuevamente que el controlador esté listo
      if (_controller == null || !_controller!.value.isInitialized) {
        print('Controlador de cámara no está inicializado');
        return null;
      }
      
      // Intentar tomar la foto con manejo de errores
      XFile? xFile;
      try {
        xFile = await _controller!.takePicture().timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException('Timeout al tomar foto')
        );
      } catch (e) {
        print('Error al tomar la foto: $e');
        return null;
      }
      
      tempFile = File(xFile.path);
      
      // Verificar que el archivo existe y no está vacío
      if (!await tempFile.exists()) {
        print('El archivo de imagen no existe después de takePicture()');
        return null;
      }
      
      final fileSize = await tempFile.length();
      if (fileSize <= 0) {
        print('El archivo de imagen está vacío: $fileSize bytes');
        await tempFile.delete().catchError((e) {
          print('Error al eliminar archivo vacío: $e');
        });
        return null;
      }
      
      // Crear nombre seguro para la foto
      try {
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'photo_${timestamp}_${tempFile.hashCode}.jpg';
        final targetPath = path.join(tempDir.path, fileName);
        
        // Copiar el archivo a la ubicación deseada
        savedFile = await tempFile.copy(targetPath);
      } catch (e) {
        print('Error al guardar imagen: $e');
        
        // Intentar eliminar el archivo temporal si existe
        if (await tempFile.exists()) {
          await tempFile.delete().catchError((e) => 
            print('Error al eliminar archivo temporal en error: $e'));
        }
        return null;
      }
      
      return savedFile;
    } catch (e) {
      print('Error general al tomar foto: $e');
      return null;
    } finally {
      // IMPORTANTE: Limpiar archivos temporales
      if (tempFile != null) {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (e) {
          print('Error al eliminar archivo temporal en finally: $e');
        }
      }
    }
  }
  
  /// Método para comprobar los permisos de cámara
  Future<bool> checkCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      return status.isGranted;
    } catch (e) {
      if (kDebugMode) {
        print('Error al comprobar permisos de cámara: $e');
      }
      return false;
    }
  }
  
  /// Método para solicitar permisos de cámara
  Future<bool> requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      return status.isGranted;
    } catch (e) {
      if (kDebugMode) {
        print('Error al solicitar permisos de cámara: $e');
      }
      return false;
    }
  }
  
  /// Método para limpiar archivos temporales de la cámara
  Future<void> cleanupTemporaryFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final directory = Directory(tempDir.path);
      final files = directory.listSync();
      
      // Eliminar archivos temporales relacionados con la cámara
      for (final file in files) {
        if (file is File) {
          final fileName = path.basename(file.path).toLowerCase();
          // Verificar si es un archivo temporal de la cámara
          if (fileName.startsWith('photo_') || 
              fileName.startsWith('image_') || 
              fileName.endsWith('.jpg') ||
              fileName.contains('scan_') ||
              fileName.contains('barcode_')) {
            try {
              await file.delete();
              print('Archivo temporal eliminado: $fileName');
            } catch (e) {
              print('Error al eliminar archivo temporal: $fileName - $e');
            }
          }
        }
      }
    } catch (e) {
      print('Error general al limpiar archivos temporales: $e');
    }
  }
}
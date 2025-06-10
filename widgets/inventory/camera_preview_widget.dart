// lib/widgets/camera_preview_widget.dart

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../services/camera_service.dart';

class CameraPreviewWidget extends StatefulWidget {
  final Function(CameraController?)? onControllerInitialized;
  final bool showControls;

  const CameraPreviewWidget({
    super.key, 
    this.onControllerInitialized,
    this.showControls = true,
  });

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget> {
  final CameraService _cameraService = CameraService();
  CameraController? _controller;
  bool _isInitializing = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isInitializing = true;
      _hasError = false;
    });

    try {
      final initialized = await _cameraService.initializeCamera();
      if (initialized) {
        _controller = _cameraService.cameraController;
        if (widget.onControllerInitialized != null) {
          widget.onControllerInitialized!(_controller);
        }
      } else {
        _hasError = true;
      }
    } catch (e) {
      _hasError = true;
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hasError || _controller == null || !_controller!.value.isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No se pudo inicializar la cámara',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeCamera,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // Vista previa de la cámara que ocupa todo el espacio disponible
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.previewSize!.height,
              height: _controller!.value.previewSize!.width,
              child: CameraPreview(_controller!),
            ),
          ),
        ),
        
        // Controles de la cámara (si están habilitados)
        if (widget.showControls)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FloatingActionButton(
              onPressed: () async {
                final image = await _cameraService.takePhoto();
                if (context.mounted) {
                  // Aquí podrías navegar a otra pantalla con la imagen
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(image != null 
                        ? 'Foto tomada correctamente' 
                        : 'Error al tomar la foto'),
                    ),
                  );
                }
              },
              child: const Icon(Icons.camera_alt),
            ),
          ),
      ],
    );
  }
}
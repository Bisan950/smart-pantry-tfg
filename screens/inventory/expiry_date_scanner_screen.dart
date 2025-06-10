// lib/screens/inventory/expiry_date_scanner_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../config/theme.dart';
import '../../models/product_model.dart';
import '../../services/inventory_service.dart';
import '../../services/ocr_service.dart';
import '../../services/camera_service.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/loading_indicator.dart';

class ExpiryDateScannerScreen extends StatefulWidget {
  final Product product;

  const ExpiryDateScannerScreen({
    super.key,
    required this.product,
  });

  @override
  State<ExpiryDateScannerScreen> createState() => _ExpiryDateScannerScreenState();
}

class _ExpiryDateScannerScreenState extends State<ExpiryDateScannerScreen> with WidgetsBindingObserver {
  final OCRService _ocrService = OCRService();
  final CameraService _cameraService = CameraService();
  final InventoryService _inventoryService = InventoryService();
  
  // Controlador de cámara
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  
  // Estados
  bool _isProcessing = false;
  bool _hasPermission = false;
  String? _errorMessage;
  File? _capturedImage;
  List<DateTime>? _detectedDates;
  DateTime? _selectedDate;
  
  // Capacidades del dispositivo
  bool _hasFlash = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Gestionar el ciclo de vida de la app para evitar problemas con la cámara
    if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    } else if (state == AppLifecycleState.paused) {
      _disposeCamera();
    }
  }
  
  Future<void> _initializeCamera() async {
    try {
      // Verificar permisos
      final hasPermission = await _cameraService.checkCameraPermission();
      
      setState(() {
        _hasPermission = hasPermission;
        _errorMessage = hasPermission ? null : 'No se tienen permisos para acceder a la cámara';
      });
      
      if (!hasPermission) {
        return;
      }
      
      // Inicializar la cámara
      final initialized = await _cameraService.initializeCamera();
      if (!initialized) {
        setState(() {
          _errorMessage = 'No se pudo inicializar la cámara';
        });
        return;
      }
      
      // Obtener controlador
      final controller = _cameraService.cameraController;
      if (controller == null) {
        setState(() {
          _errorMessage = 'Error al obtener el controlador de la cámara';
        });
        return;
      }
      
      bool hasFlash = false;
      try {
        // Verificamos si podemos cambiar el modo del flash
        // Si no causa error, asumimos que tiene flash
        await controller.setFlashMode(FlashMode.torch);
        await controller.setFlashMode(FlashMode.off);
        hasFlash = true;
      } catch (e) {
        // Si ocurre un error, el dispositivo probablemente no tiene flash
        hasFlash = false;
        print('Error al verificar flash: $e');
      }
      
      setState(() {
        _cameraController = controller;
        _isCameraInitialized = true;
        _hasFlash = hasFlash;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al inicializar la cámara: $e';
      });
    }
  }
  
  void _disposeCamera() {
    if (_cameraController != null) {
      _cameraService.dispose();
      _cameraController = null;
    }
    _isCameraInitialized = false;
  }
  
  Future<void> _captureImage() async {
    if (!_isCameraInitialized || _cameraController == null || _isProcessing) {
      return;
    }
    
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });
    
    try {
      // Capturar imagen
      final image = await _cameraService.takePhoto();
      
      if (image == null) {
        setState(() {
          _errorMessage = 'No se pudo capturar la imagen';
          _isProcessing = false;
        });
        return;
      }
      
      setState(() {
        _capturedImage = image;
        _isProcessing = false;
      });
      
      // Procesar la imagen para detectar fechas
      _processImage(image);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al capturar imagen: $e';
        _isProcessing = false;
      });
    }
  }
  
  Future<void> _processImage(File imageFile) async {
    setState(() {
      _isProcessing = true;
    });
    
    try {
      // Detectar fechas en la imagen
      final dates = await _ocrService.detectDatesInImage(imageFile);
      
      setState(() {
        _detectedDates = dates;
        _isProcessing = false;
        
        // Si solo hay una fecha, seleccionarla automáticamente
        if (dates.length == 1) {
          _selectedDate = dates.first;
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al procesar la imagen: $e';
        _isProcessing = false;
      });
    }
  }
  
  Future<void> _saveExpiryDate() async {
    if (_selectedDate == null) {
      return;
    }
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      // Actualizar el producto con la nueva fecha de caducidad
      final updatedProduct = widget.product.copyWith(
        expiryDate: _selectedDate,
      );
      
      // Guardar en la base de datos
      await _inventoryService.updateProduct(updatedProduct);
      
      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Fecha de caducidad actualizada correctamente'),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          ),
          margin: const EdgeInsets.all(AppTheme.spacingMedium),
        ),
      );
      
      // Volver a la pantalla anterior con resultado positivo
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al guardar la fecha: $e';
        _isProcessing = false;
      });
    }
  }
  
  void _toggleFlash() {
    if (_cameraController != null && _hasFlash) {
      if (_cameraController!.value.flashMode == FlashMode.off) {
        _cameraController!.setFlashMode(FlashMode.torch);
      } else {
        _cameraController!.setFlashMode(FlashMode.off);
      }
    }
  }
  
  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }
  
  Future<void> _selectDateManually() async {
    // Mostrar selector de fecha
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.coralMain,
              onPrimary: AppTheme.pureWhite,
              onSurface: AppTheme.darkGrey,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.coralMain,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
  
  void _retakePhoto() {
    setState(() {
      _capturedImage = null;
      _detectedDates = null;
      _selectedDate = null;
      _errorMessage = null;
    });
    
    // Reiniciar la cámara
    _initializeCamera();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Escanear fecha de caducidad',
        actions: [
          if (_isCameraInitialized && _capturedImage == null && _hasFlash)
            IconButton(
              icon: Icon(
                _cameraController?.value.flashMode == FlashMode.torch 
                    ? Icons.flash_on_rounded 
                    : Icons.flash_off_rounded,
                color: _cameraController?.value.flashMode == FlashMode.torch 
                    ? AppTheme.yellowAccent 
                    : null,
              ),
              onPressed: _toggleFlash,
              tooltip: 'Activar/desactivar flash',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    // Si hay una imagen capturada, mostrar los resultados
    if (_capturedImage != null) {
      return _buildImageProcessingView();
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
    if (_isProcessing) {
      return Center(
        child: Card(
          elevation: AppTheme.elevationSmall,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          ),
          child: const Padding(
            padding: EdgeInsets.all(AppTheme.spacingLarge),
            child: LoadingIndicator(message: 'Procesando...'),
          ),
        ),
      );
    }
    
    // Mostrar vista de cámara
    return _buildCameraView();
  }
  
  Widget _buildCameraView() {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(
        child: LoadingIndicator(message: 'Inicializando cámara...'),
      );
    }
    
    return Stack(
      children: [
        // Vista de la cámara
        SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: CameraPreview(_cameraController!),
        ),
        
        // Overlay de guía
        Center(
          child: Container(
            width: 280,
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppTheme.coralMain,
                width: 3.0,
              ),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            ),
          ),
        ),
        
        // Texto de instrucción
        Positioned(
          bottom: 130,
          left: 0,
          right: 0,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLarge),
            padding: const EdgeInsets.symmetric(
              vertical: AppTheme.spacingMedium,
              horizontal: AppTheme.spacingLarge,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            ),
            child: const Text(
              'Alinea la fecha de caducidad dentro del recuadro',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        
        // Botones para capturar
        Positioned(
          bottom: AppTheme.spacingLarge,
          left: 0,
          right: 0,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(
                  width: 140,
                  child: CustomButton(
                    text: 'Seleccionar',
                    onPressed: _selectDateManually,
                    type: ButtonType.secondary,
                    icon: Icons.calendar_today_rounded,
                  ),
                ),
                Container(
                  height: 70,
                  width: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.coralMain,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.camera_alt_rounded,
                      size: 36,
                      color: AppTheme.pureWhite,
                    ),
                    onPressed: _captureImage,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildImageProcessingView() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen capturada
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              child: Image.file(
                _capturedImage!,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingLarge),
          
          // Información del producto
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMedium),
            decoration: BoxDecoration(
              color: AppTheme.peachLight.withOpacity(0.3),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.inventory_2_rounded,
                  color: AppTheme.coralMain,
                ),
                const SizedBox(width: AppTheme.spacingMedium),
                Expanded(
                  child: Text(
                    widget.product.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingLarge),
          
          // Fechas detectadas o mensaje
          Expanded(
            flex: 2,
            child: _isProcessing
                ? Center(
                    child: Card(
                      elevation: AppTheme.elevationSmall,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(AppTheme.spacingLarge),
                        child: LoadingIndicator(message: 'Detectando fechas...'),
                      ),
                    ),
                  )
                : _buildDatesSection(),
          ),
          
          const SizedBox(height: AppTheme.spacingLarge),
          
          // Botones de acción
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Otra foto',
                  onPressed: _retakePhoto,
                  type: ButtonType.secondary,
                  icon: Icons.refresh_rounded,
                ),
              ),
              const SizedBox(width: AppTheme.spacingLarge),
              Expanded(
                child: CustomButton(
                  text: 'Guardar',
                  onPressed: _selectedDate != null ? _saveExpiryDate : null,
                  type: ButtonType.primary,
                  icon: Icons.check_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildDatesSection() {
    if (_errorMessage != null) {
      return Center(
        child: Card(
          elevation: AppTheme.elevationSmall,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppTheme.errorRed,
                ),
                const SizedBox(height: AppTheme.spacingMedium),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    if (_detectedDates == null || _detectedDates!.isEmpty) {
      return Center(
        child: Card(
          elevation: AppTheme.elevationSmall,
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
                  padding: const EdgeInsets.all(AppTheme.spacingMedium),
                  decoration: BoxDecoration(
                    color: AppTheme.peachLight.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    size: 48,
                    color: AppTheme.coralMain,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMedium),
                Text(
                  'No se detectaron fechas en la imagen',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppTheme.spacingLarge),
                CustomButton(
                  text: 'Seleccionar manualmente',
                  onPressed: _selectDateManually,
                  type: ButtonType.secondary,
                  icon: Icons.calendar_today_rounded,
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
          child: Text(
            'Fechas detectadas:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.coralMain,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingMedium),
        Expanded(
          child: ListView.builder(
            itemCount: _detectedDates!.length,
            itemBuilder: (context, index) {
              final date = _detectedDates![index];
              final isSelected = _selectedDate == date;
              
              return Card(
                elevation: isSelected ? AppTheme.elevationMedium : AppTheme.elevationTiny,
                color: isSelected 
                    ? AppTheme.coralMain.withOpacity(0.1) 
                    : null,
                margin: const EdgeInsets.only(
                  bottom: AppTheme.spacingMedium,
                  left: AppTheme.spacingSmall,
                  right: AppTheme.spacingSmall,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                  side: isSelected 
                      ? BorderSide(color: AppTheme.coralMain, width: 2) 
                      : BorderSide.none,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMedium,
                    vertical: AppTheme.spacingSmall,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? AppTheme.coralMain 
                          : AppTheme.peachLight.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.calendar_today_rounded,
                      color: isSelected ? AppTheme.pureWhite : AppTheme.coralMain,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    '${date.day}/${date.month}/${date.year}',
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppTheme.coralMain : null,
                    ),
                  ),
                  subtitle: Text(
                    _getDaysUntilExpiry(date),
                    style: TextStyle(
                      color: _getExpiryColor(date),
                    ),
                  ),
                  trailing: isSelected 
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.coralMain,
                        ) 
                      : const Icon(
                          Icons.radio_button_unchecked_rounded,
                          color: AppTheme.lightGrey,
                        ),
                  onTap: () => _selectDate(date),
                ),
              );
            },
          ),
        ),
        if (_detectedDates!.isNotEmpty)
          Center(
            child: TextButton.icon(
              icon: const Icon(
                Icons.edit_calendar_rounded,
                color: AppTheme.coralMain,
              ),
              label: const Text(
                'Seleccionar otra fecha',
                style: TextStyle(color: AppTheme.coralMain),
              ),
              onPressed: _selectDateManually,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMedium,
                  vertical: AppTheme.spacingSmall,
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  Color _getExpiryColor(DateTime date) {
    final now = DateTime.now();
    final daysUntil = date.difference(now).inDays;
    
    if (daysUntil < 0) {
      return AppTheme.errorRed;
    } else if (daysUntil < 3) {
      return AppTheme.warningOrange;
    } else if (daysUntil < 7) {
      return AppTheme.yellowAccent;
    } else {
      return AppTheme.successGreen;
    }
  }
  
  String _getDaysUntilExpiry(DateTime date) {
    final now = DateTime.now();
    final daysUntil = date.difference(now).inDays;
    
    if (daysUntil < 0) {
      return 'Caducado hace ${-daysUntil} días';
    } else if (daysUntil == 0) {
      return 'Caduca hoy';
    } else if (daysUntil == 1) {
      return 'Caduca mañana';
    } else {
      return 'Caduca en $daysUntil días';
    }
  }
  
  Widget _buildErrorView() {
    return Center(
      child: Card(
        elevation: AppTheme.elevationSmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        ),
        margin: const EdgeInsets.all(AppTheme.spacingLarge),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMedium),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 60,
                  color: AppTheme.errorRed,
                ),
              ),
              const SizedBox(height: AppTheme.spacingLarge),
              Text(
                _errorMessage ?? 'Error desconocido',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppTheme.spacingXLarge),
              CustomButton(
                text: 'Intentar de nuevo',
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                  });
                  _initializeCamera();
                },
                type: ButtonType.primary,
                icon: Icons.refresh_rounded,
              ),
              const SizedBox(height: AppTheme.spacingLarge),
              CustomButton(
                text: 'Seleccionar manualmente',
                onPressed: _selectDateManually,
                type: ButtonType.secondary,
                icon: Icons.calendar_today_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildRequestPermissionView() {
    return Center(
      child: Card(
        elevation: AppTheme.elevationSmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        ),
        margin: const EdgeInsets.all(AppTheme.spacingLarge),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingLarge),
                decoration: BoxDecoration(
                  color: AppTheme.peachLight.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 60,
                  color: AppTheme.coralMain,
                ),
              ),
              const SizedBox(height: AppTheme.spacingLarge),
              Text(
                'Se necesita acceso a la cámara para escanear fechas de caducidad',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppTheme.spacingLarge),
              const Text(
                'Concede permiso para poder escanear automáticamente las fechas de tus productos',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.mediumGrey),
              ),
              const SizedBox(height: AppTheme.spacingXLarge),
              CustomButton(
                text: 'Permitir acceso',
                onPressed: () async {
                  final granted = await _cameraService.requestCameraPermission();
                  if (granted) {
                    _initializeCamera();
                  }
                },
                type: ButtonType.primary,
                icon: Icons.check_rounded,
              ),
              const SizedBox(height: AppTheme.spacingLarge),
              CustomButton(
                text: 'Seleccionar manualmente',
                onPressed: _selectDateManually,
                type: ButtonType.secondary,
                icon: Icons.calendar_today_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
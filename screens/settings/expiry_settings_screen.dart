// lib/screens/settings/expiry_settings_screen.dart

import 'package:flutter/material.dart';
import '../../models/expiry_settings_model.dart';
import '../../services/expiry_settings_service.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/custom_button.dart';
import '../../config/theme.dart';

class ExpirySettingsScreen extends StatefulWidget {
  const ExpirySettingsScreen({super.key});

  @override
  State<ExpirySettingsScreen> createState() => _ExpirySettingsScreenState();
}

class _ExpirySettingsScreenState extends State<ExpirySettingsScreen> {
  final ExpirySettingsService _settingsService = ExpirySettingsService();
  late Future<ExpirySettings> _settingsFuture;
  
  // Controladores para los campos
  final TextEditingController _warningDaysController = TextEditingController();
  final TextEditingController _criticalDaysController = TextEditingController();
  bool _notificationsEnabled = true;
  
  @override
  void initState() {
    super.initState();
    _settingsFuture = _settingsService.getSettings();
    _loadSettings();
  }
  
  void _loadSettings() async {
    final settings = await _settingsFuture;
    setState(() {
      _warningDaysController.text = settings.warningDays.toString();
      _criticalDaysController.text = settings.criticalDays.toString();
      _notificationsEnabled = settings.notificationsEnabled;
    });
  }
  
  void _saveSettings() async {
    try {
      // Validar los valores ingresados
      final warningDays = int.tryParse(_warningDaysController.text) ?? 7;
      final criticalDays = int.tryParse(_criticalDaysController.text) ?? 3;
      
      // Asegurar que warning es mayor que critical
      if (warningDays < criticalDays) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'El umbral de advertencia debe ser mayor que el umbral crítico',
              style: const TextStyle(color: AppTheme.pureWhite),
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
            ),
          ),
        );
        return;
      }
      
      // Obtener configuraciones actuales
      final currentSettings = await _settingsFuture;
      
      // Crear nuevas configuraciones
      final newSettings = currentSettings.copyWith(
        warningDays: warningDays,
        criticalDays: criticalDays,
        notificationsEnabled: _notificationsEnabled,
      );
      
      // Guardar configuraciones
      await _settingsService.saveSettings(newSettings);
      
      // Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppTheme.pureWhite),
                const SizedBox(width: AppTheme.spacingSmall),
                const Text(
                  'Configuraciones guardadas correctamente',
                  style: TextStyle(color: AppTheme.pureWhite),
                ),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      // Mostrar mensaje de error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_rounded, color: AppTheme.pureWhite),
                const SizedBox(width: AppTheme.spacingSmall),
                Text(
                  'Error al guardar: $e',
                  style: const TextStyle(color: AppTheme.pureWhite),
                ),
              ],
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
            ),
          ),
        );
      }
    }
  }
  
  @override
  void dispose() {
    _warningDaysController.dispose();
    _criticalDaysController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Configuración de Caducidad',
      ),
      body: FutureBuilder<ExpirySettings>(
        future: _settingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppTheme.coralMain,
              ),
            );
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded, 
                    size: 48, 
                    color: AppTheme.errorRed,
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),
                  Text(
                    'Error: ${snapshot.error}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.errorRed,
                    ),
                  ),
                ],
              ),
            );
          }
          
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            ),
            padding: const EdgeInsets.all(AppTheme.spacingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Umbrales de caducidad',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.coralMain,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLarge),
                
                // Umbral de advertencia
                Card(
                  elevation: AppTheme.elevationTiny,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingMedium),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: AppTheme.yellowAccent,
                              size: 24,
                            ),
                            const SizedBox(width: AppTheme.spacingSmall),
                            Text(
                              'Advertencia temprana (días)',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingMedium),
                        TextField(
                          controller: _warningDaysController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            fillColor: Theme.of(context).colorScheme.surface,
                            hintText: 'Días para mostrar advertencia (ej: 7)',
                            prefixIcon: Icon(
                              Icons.calendar_today_rounded,
                              color: AppTheme.mediumGrey,
                            ),
                          ),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLarge),
                
                // Umbral crítico
                Card(
                  elevation: AppTheme.elevationTiny,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingMedium),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.error_rounded,
                              color: AppTheme.errorRed,
                              size: 24,
                            ),
                            const SizedBox(width: AppTheme.spacingSmall),
                            Text(
                              'Umbral crítico (días)',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingMedium),
                        TextField(
                          controller: _criticalDaysController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            fillColor: Theme.of(context).colorScheme.surface,
                            hintText: 'Días para mostrar alerta crítica (ej: 3)',
                            prefixIcon: Icon(
                              Icons.calendar_today_rounded,
                              color: AppTheme.mediumGrey,
                            ),
                          ),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLarge),
                
                // Switch para notificaciones
                Card(
                  elevation: AppTheme.elevationTiny,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingMedium),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_rounded,
                          color: AppTheme.coralMain,
                          size: 24,
                        ),
                        const SizedBox(width: AppTheme.spacingSmall),
                        Expanded(
                          child: Text(
                            'Notificaciones de caducidad',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Switch(
                          value: _notificationsEnabled,
                          onChanged: (value) {
                            setState(() {
                              _notificationsEnabled = value;
                            });
                          },
                          activeColor: AppTheme.coralMain,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const Spacer(),
                
               // Botón de guardar
CustomButton(
  text: 'Guardar configuración',
  onPressed: _saveSettings,
  type: ButtonType.primary,
  icon: Icons.save_rounded,
  // Eliminar el parámetro fullWidth que no está definido
),
              ],
            ),
          );
        },
      ),
    );
  }
}
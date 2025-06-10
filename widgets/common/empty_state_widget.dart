import 'package:flutter/material.dart';
import '../../config/theme.dart';
import 'custom_button.dart';

/// EmptyStateWidget - Widget para mostrar estados vacíos en la aplicación SmartPantry
///
/// Se utiliza cuando no hay datos que mostrar en una sección o pantalla,
/// ofreciendo un mensaje claro y una acción opcional para solucionar la situación.
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final String? secondaryButtonText; // Añadido para botón secundario
  final VoidCallback? onSecondaryButtonPressed; // Añadido para botón secundario
  final double? iconSize;
  final ButtonType buttonType;
  final ButtonType secondaryButtonType; // Tipo para el botón secundario

  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.buttonText,
    this.onButtonPressed,
    this.secondaryButtonText, // Opcional
    this.onSecondaryButtonPressed, // Opcional
    this.iconSize = 80.0,
    this.buttonType = ButtonType.primary,
    this.secondaryButtonType = ButtonType.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      // Wrap with SingleChildScrollView to prevent overflow
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingLarge,
            vertical: AppTheme.spacingXLarge,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: iconSize,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
              ),
              const SizedBox(height: AppTheme.spacingLarge),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingMedium),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (buttonText != null && onButtonPressed != null) ...[
                const SizedBox(height: AppTheme.spacingLarge),
                CustomButton(
                  text: buttonText!,
                  onPressed: onButtonPressed!,
                  type: buttonType,
                  isFullWidth: false,
                  icon: _getButtonIcon(buttonText),
                ),
              ],
              // Botón secundario (si está definido)
              if (secondaryButtonText != null && onSecondaryButtonPressed != null) ...[
                const SizedBox(height: AppTheme.spacingMedium),
                CustomButton(
                  text: secondaryButtonText!,
                  onPressed: onSecondaryButtonPressed!,
                  type: secondaryButtonType,
                  isFullWidth: false,
                  icon: _getButtonIcon(secondaryButtonText),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData? _getButtonIcon(String? text) {
    // Determinar icono apropiado basado en el contexto
    if (text == null) return null;
    
    if (text.toLowerCase().contains('añadir')) {
      return Icons.add;
    } else if (text.toLowerCase().contains('buscar')) {
      return Icons.search;
    } else if (text.toLowerCase().contains('actualizar')) {
      return Icons.refresh;
    } else if (text.toLowerCase().contains('generar')) {
      return Icons.smart_toy; // Icono para IA/generación
    }
    return null;
  }
}
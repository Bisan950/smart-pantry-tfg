import 'package:flutter/material.dart';
import '../../config/theme.dart';
import 'custom_button.dart';

/// CustomErrorWidget - Widget para mostrar estados de error en la aplicación SmartPantry
/// 
/// Se utiliza cuando ocurre un error en la aplicación para mostrar un mensaje
/// claro y ofrecer opciones para solucionarlo.
class CustomErrorWidget extends StatelessWidget {
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final bool showIcon;
  final IconData? customIcon;
  final bool isConnectivityError;

  const CustomErrorWidget({
    super.key,
    this.title = 'Algo salió mal',
    required this.message,
    this.buttonText = 'Reintentar',
    this.onButtonPressed,
    this.showIcon = true,
    this.customIcon,
    this.isConnectivityError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingLarge,
          vertical: AppTheme.spacingXLarge,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showIcon) ...[
              Icon(
                customIcon ?? _getIcon(),
                size: 70,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: AppTheme.spacingLarge),
            ],
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
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
                type: ButtonType.primary,
                isFullWidth: false,
                icon: _getButtonIcon(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    if (isConnectivityError) {
      return Icons.wifi_off_rounded;
    }
    return Icons.error_outline_rounded;
  }

  IconData? _getButtonIcon() {
    if (buttonText?.toLowerCase().contains('reintentar') ?? false) {
      return Icons.refresh;
    } else if (buttonText?.toLowerCase().contains('contactar') ?? false) {
      return Icons.mail_outline;
    }
    return null;
  }
}
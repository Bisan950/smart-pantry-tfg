// lib/widgets/common/error_boundary.dart

import 'package:flutter/material.dart';
import '../../config/theme.dart';

class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final String? fallbackTitle;
  final String? fallbackMessage;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallbackTitle,
    this.fallbackMessage,
  });

  @override
  ErrorBoundaryState createState() => ErrorBoundaryState();
}

class ErrorBoundaryState extends State<ErrorBoundary> {
  bool hasError = false;
  dynamic error;
  StackTrace? stackTrace;
  
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      // UI para mostrar cuando ocurre un error, actualizado con el nuevo diseño
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacingLarge),
            margin: const EdgeInsets.all(AppTheme.spacingLarge),
            decoration: BoxDecoration(
              color: AppTheme.pureWhite,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.darkGrey.withOpacity(0.08),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded, // Usando iconos redondeados
                  color: AppTheme.errorRed,
                  size: 60,
                ),
                const SizedBox(height: AppTheme.spacingMedium),
                Text(
                  widget.fallbackTitle ?? 'Ocurrió un error',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingSmall),
                Text(
                  widget.fallbackMessage ?? 
                      'Encontramos un problema al mostrar esta pantalla.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.mediumGrey,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (error != null) ...[
                  const SizedBox(height: AppTheme.spacingMedium),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMedium),
                    decoration: BoxDecoration(
                      color: AppTheme.lightGrey,
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                    ),
                    child: Text(
                      error.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.errorRed,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.spacingXLarge),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          hasError = false;
                          error = null;
                          stackTrace = null;
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded), // Usando iconos redondeados
                      label: const Text('Reintentar'),
                      // No necesito establecer el estilo aquí ya que usará el elevatedButtonTheme del theme.dart
                    ),
                    const SizedBox(width: AppTheme.spacingMedium),
                    OutlinedButton.icon(
                      onPressed: () {
                        // Navegar a la pantalla principal o reiniciar la app
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/dashboard', // O la ruta principal de tu app
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.home_rounded), // Usando iconos redondeados
                      label: const Text('Ir al inicio'),
                      // No necesito establecer el estilo aquí ya que usará el outlinedButtonTheme del theme.dart
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Si no hay error, muestra el widget hijo normalmente
    return widget.child;
  }

  // Este método atrapa errores en el árbol de widgets
  static ErrorBoundaryState? of(BuildContext context) {
    return context.findAncestorStateOfType<ErrorBoundaryState>();
  }

  // Método para reportar errores manualmente desde cualquier parte de la app
  void reportError(dynamic error, StackTrace stackTrace) {
    setState(() {
      hasError = true;
      this.error = error;
      this.stackTrace = stackTrace;
    });
  }
}

// Widget que permite envolver un builder con manejo de errores
class ErrorBoundaryBuilder extends StatelessWidget {
  final Widget Function(BuildContext) builder;
  final String? fallbackTitle;
  final String? fallbackMessage;

  const ErrorBoundaryBuilder({
    super.key,
    required this.builder,
    this.fallbackTitle,
    this.fallbackMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      fallbackTitle: fallbackTitle,
      fallbackMessage: fallbackMessage,
      child: Builder(builder: builder),
    );
  }
}
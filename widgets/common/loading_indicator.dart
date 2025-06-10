// lib/widgets/common/loading_indicator.dart
import 'package:flutter/material.dart';
import '../../config/theme.dart';

class LoadingIndicator extends StatelessWidget {
  final Color? color;
  final double size;
  final double strokeWidth;
  final String? message;
  final bool useAnimatedDots; // Nueva opción para usar puntos animados

  const LoadingIndicator({
    super.key,
    this.color,
    this.size = 40.0,
    this.strokeWidth = 3.0, // Reducido para un aspecto más ligero
    this.message,
    this.useAnimatedDots = false, // Por defecto, usar el indicador circular
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicatorColor = color ?? AppTheme.coralMain; // Usando el color coral principal
    
    // Contenido principal que depende de si hay un mensaje o no
    Widget content;
    
    if (message == null) {
      // Sin mensaje, solo el indicador
      content = _buildLoadingIndicator(indicatorColor);
    } else {
      // Con mensaje, indicador + texto
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLoadingIndicator(indicatorColor),
          const SizedBox(height: AppTheme.spacingMedium),
          Text(
            message!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.mediumGrey, // Color de texto más suave
              letterSpacing: 0.2, // Ligero espaciado entre letras
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    
    // Contenedor con fondo sutilmente redondeado (si hay mensaje)
    if (message != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingLarge,
            vertical: AppTheme.spacingLarge,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor, // Fondo adaptable al tema
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            boxShadow: [
              BoxShadow(
                color: AppTheme.darkGrey.withOpacity(0.05), // Sombra muy sutil
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: content,
        ),
      );
    }
    
    // Sin mensaje, solo el centro
    return Center(child: content);
  }
  
  // Método para construir el indicador según el tipo seleccionado
  Widget _buildLoadingIndicator(Color color) {
    if (useAnimatedDots) {
      return _buildAnimatedDots(color);
    } else {
      return SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          color: color,
          strokeWidth: strokeWidth,
          // Estilo redondeado para los extremos
          strokeCap: StrokeCap.round,
        ),
      );
    }
  }
  
  // Método para construir los puntos animados (versión alternativa)
  Widget _buildAnimatedDots(Color color) {
    return SizedBox(
      width: size * 1.5,
      height: size * 0.5,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _AnimatedDot(color: color, beginDelay: 0),
          SizedBox(width: size * 0.15),
          _AnimatedDot(color: color, beginDelay: 0.2),
          SizedBox(width: size * 0.15),
          _AnimatedDot(color: color, beginDelay: 0.4),
        ],
      ),
    );
  }
}

// Widget para un punto animado que se usa en la versión alternativa
class _AnimatedDot extends StatefulWidget {
  final Color color;
  final double beginDelay;
  
  const _AnimatedDot({
    required this.color,
    required this.beginDelay,
  });
  
  @override
  _AnimatedDotState createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    
    _animation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1.5)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.5, end: 1)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1),
        weight: 50,
      ),
    ]).animate(_controller);
    
    // Añade delay inicial
    Future.delayed(Duration(milliseconds: (widget.beginDelay * 1000).toInt()), () {
      if (mounted) {
        _controller.repeat();
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
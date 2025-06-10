import 'package:flutter/material.dart';
import '../../config/theme.dart';

class TimeIndicator extends StatelessWidget {
  final int minutes;
  final String label;
  final bool showLabel;
  final Color? color;
  final double size;

  const TimeIndicator({
    super.key,
    required this.minutes,
    this.label = 'min',
    this.showLabel = true,
    this.color,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = color ?? theme.textTheme.bodyMedium?.color;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.access_time_rounded,
          size: size,
          color: color ?? AppTheme.coralMain,
        ),
        const SizedBox(width: AppTheme.spacingXSmall),
        Text(
          showLabel ? '$minutes $label' : '$minutes',
          style: theme.textTheme.bodySmall?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
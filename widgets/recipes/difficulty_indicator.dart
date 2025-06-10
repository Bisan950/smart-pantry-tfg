import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/recipe_model.dart';

class DifficultyIndicator extends StatelessWidget {
  final dynamic difficulty; // Can accept either DifficultyLevel enum or String
  final double size;
  final bool showLabel;

  const DifficultyIndicator({
    super.key,
    required this.difficulty,
    this.size = 16,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Configuración según nivel de dificultad
    late final Color dotColor;
    late final String label;
    late final int dotCount;
    
    // Handle both String and DifficultyLevel types
    if (difficulty is DifficultyLevel) {
      switch (difficulty as DifficultyLevel) {
        case DifficultyLevel.easy:
          dotColor = AppTheme.successGreen;
          label = 'Fácil';
          dotCount = 1;
          break;
        case DifficultyLevel.medium:
          dotColor = AppTheme.yellowAccent;
          label = 'Media';
          dotCount = 2;
          break;
        case DifficultyLevel.hard:
          dotColor = AppTheme.coralMain;
          label = 'Difícil';
          dotCount = 3;
          break;
      }
    } else if (difficulty is String) {
      // Handle string-based difficulty
      final diffString = (difficulty as String).toLowerCase();
      if (diffString == 'fácil' || diffString == 'facil' || diffString == 'easy') {
        dotColor = AppTheme.successGreen;
        label = 'Fácil';
        dotCount = 1;
      } else if (diffString == 'media' || diffString == 'medium') {
        dotColor = AppTheme.yellowAccent;
        label = 'Media';
        dotCount = 2;
      } else if (diffString == 'difícil' || diffString == 'dificil' || diffString == 'hard') {
        dotColor = AppTheme.coralMain;
        label = 'Difícil';
        dotCount = 3;
      } else {
        // Default for unknown values
        dotColor = AppTheme.yellowAccent;
        label = 'Media';
        dotCount = 2;
      }
    } else {
      // Default values if type is unexpected
      dotColor = AppTheme.yellowAccent;
      label = 'Media';
      dotCount = 2;
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: List.generate(3, (index) {
            return Container(
              width: size,
              height: size,
              margin: EdgeInsets.only(right: index < 2 ? 2 : 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < dotCount ? dotColor : AppTheme.lightGrey.withOpacity(0.3),
                boxShadow: index < dotCount ? [
                  BoxShadow(
                    color: dotColor.withOpacity(0.2),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ] : null,
              ),
            );
          }),
        ),
        if (showLabel) ...[
          const SizedBox(width: AppTheme.spacingXSmall),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: dotColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
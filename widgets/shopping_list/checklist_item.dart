import 'package:flutter/material.dart';
import '../../config/theme.dart';

class ChecklistItem extends StatelessWidget {
  final String text;
  final bool isChecked;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;
  final bool showDeleteOption;

  const ChecklistItem({
    super.key,
    required this.text,
    required this.isChecked,
    required this.onToggle,
    this.onDelete,
    this.showDeleteOption = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: AppTheme.spacingSmall / 2,
      ),
      child: Row(
        children: [
          // Checkbox
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isChecked ? AppTheme.coralMain : Colors.transparent,
                border: Border.all(
                  color: isChecked ? AppTheme.coralMain : AppTheme.mediumGrey,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                boxShadow: isChecked ? [
                  BoxShadow(
                    color: AppTheme.coralMain.withOpacity(0.2),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ] : null,
              ),
              child: isChecked
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: AppTheme.pureWhite,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: AppTheme.spacingSmall),
          
          // Text
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                decoration: isChecked ? TextDecoration.lineThrough : null,
                color: isChecked 
                    ? theme.brightness == Brightness.light
                        ? AppTheme.mediumGrey
                        : AppTheme.mediumGrey
                    : theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
          
          // Delete button
          if (showDeleteOption && onDelete != null)
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: theme.brightness == Brightness.light
                        ? AppTheme.mediumGrey
                        : AppTheme.mediumGrey,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
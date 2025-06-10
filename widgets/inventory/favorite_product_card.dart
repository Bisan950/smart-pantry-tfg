// lib/widgets/inventory/favorite_product_card.dart

import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/product_model.dart';

// Widget personalizado optimizado para mostrar un producto favorito
class FavoriteProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onAddToInventory;
  final VoidCallback onAddToShoppingList; 
  final VoidCallback onRemoveFromFavorites;
  final bool isProcessing; // Nuevo parámetro para estado de procesamiento

  const FavoriteProductCard({
    super.key,
    required this.product,
    required this.onAddToInventory,
    required this.onAddToShoppingList,
    required this.onRemoveFromFavorites,
    this.isProcessing = false, // Valor por defecto
  });

  @override
  Widget build(BuildContext context) {
    // Cache de valores calculados para optimización
    final hasAdditionalInfo = _hasAdditionalInfo();
    final hasNutritionalData = product.nutritionalInfo != null && 
                               _hasNutritionalData(product.nutritionalInfo!);
    
    return Card(
      elevation: AppTheme.elevationSmall,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      ),
      // Optimización: usar AnimatedOpacity solo cuando sea necesario
      child: AnimatedOpacity(
        opacity: isProcessing ? 0.7 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Optimización de tamaño
            children: [
              _buildHeader(context),
              
              if (hasAdditionalInfo) ...[
                const SizedBox(height: AppTheme.spacingMedium),
                
                // Información básica (cantidad y fecha)
                if (product.quantity > 0 || product.expiryDate != null)
                  _buildBasicInfo(context),
                
                const SizedBox(height: AppTheme.spacingMedium),
                _buildInfoSummaryChips(context),
                
                // Información nutricional
                if (hasNutritionalData) ...[
                  const SizedBox(height: AppTheme.spacingMedium),
                  _buildNutritionalInfo(context),
                ],
              ],
              
              const SizedBox(height: AppTheme.spacingLarge),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  // Header con nombre, categoría y botón eliminar
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.favorite_rounded,
          color: AppTheme.coralMain,
          size: 24,
        ),
        const SizedBox(width: AppTheme.spacingMedium),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                product.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2, // Permitir hasta 2 líneas para nombres largos
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.category_rounded,
                    size: 16,
                    color: AppTheme.coralMain,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      product.category,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.mediumGrey,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildDeleteButton(),
      ],
    );
  }

  // Botón de eliminar con estado de procesamiento
  Widget _buildDeleteButton() {
    return IconButton(
      icon: isProcessing 
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.errorRed),
            ),
          )
        : const Icon(
            Icons.delete_outline_rounded,
            color: AppTheme.errorRed,
            size: 24,
          ),
      onPressed: isProcessing ? null : onRemoveFromFavorites,
      tooltip: isProcessing ? 'Procesando...' : 'Eliminar de favoritos',
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.errorRed.withOpacity(0.1),
        disabledBackgroundColor: AppTheme.mediumGrey.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusPill),
        ),
      ),
    );
  }

  // Botones de acción optimizados
  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        // Botón inventario
        Expanded(
          child: OutlinedButton.icon(
            icon: isProcessing 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.coralMain),
                  ),
                )
              : const Icon(Icons.inventory_2_rounded),
            label: Text(isProcessing ? 'Procesando...' : 'Al Inventario'),
            onPressed: isProcessing ? null : onAddToInventory,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.coralMain,
              disabledForegroundColor: AppTheme.mediumGrey,
              side: BorderSide(
                color: isProcessing ? AppTheme.mediumGrey : AppTheme.coralMain,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              ),
              padding: const EdgeInsets.symmetric(
                vertical: AppTheme.spacingMedium,
              ),
            ),
          ),
        ),
        
        const SizedBox(width: AppTheme.spacingMedium),
        
        // Botón lista de compras
        Expanded(
          child: FilledButton.icon(
            icon: isProcessing 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.pureWhite),
                  ),
                )
              : const Icon(Icons.shopping_cart_rounded),
            label: Text(isProcessing ? 'Procesando...' : 'Comprar'),
            onPressed: isProcessing ? null : onAddToShoppingList,
            style: FilledButton.styleFrom(
              backgroundColor: isProcessing ? AppTheme.mediumGrey : AppTheme.coralMain,
              foregroundColor: AppTheme.pureWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              ),
              padding: const EdgeInsets.symmetric(
                vertical: AppTheme.spacingMedium,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Verificar si el producto tiene información adicional guardada
  bool _hasAdditionalInfo() {
    return product.quantity > 0 || 
           product.maxQuantity > 0 || 
           product.expiryDate != null || 
           product.nutritionalInfo != null ||
           product.imageUrl.isNotEmpty ||
           product.notes.isNotEmpty;
  }

  // Verificar si tiene datos nutricionales válidos
  bool _hasNutritionalData(NutritionalInfo nutritionalInfo) {
    return (nutritionalInfo.calories != null && nutritionalInfo.calories! > 0) ||
           (nutritionalInfo.proteins != null && nutritionalInfo.proteins! > 0) ||
           (nutritionalInfo.carbohydrates != null && nutritionalInfo.carbohydrates! > 0) ||
           (nutritionalInfo.fats != null && nutritionalInfo.fats! > 0);
  }

  // Información básica del producto (cantidad, fecha de caducidad)
  Widget _buildBasicInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: AppTheme.coralMain.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(color: AppTheme.coralMain.withOpacity(0.2)),
      ),
      child: IntrinsicHeight( // Optimización para altura uniforme
        child: Row(
          children: [
            // Cantidad
            if (product.quantity > 0) ...[
              Expanded(
                child: _buildInfoItem(
                  context,
                  Icons.scale_rounded,
                  'Cantidad',
                  '${product.quantity} ${product.unit}',
                  AppTheme.coralMain,
                ),
              ),
            ],
            
            // Separador si ambos están presentes
            if (product.quantity > 0 && product.expiryDate != null)
              Container(
                width: 1,
                color: AppTheme.coralMain.withOpacity(0.3),
                margin: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMedium,
                  vertical: 4,
                ),
              ),
            
            // Fecha de caducidad
            if (product.expiryDate != null) ...[
              Expanded(
                child: _buildInfoItem(
                  context,
                  Icons.event_note_rounded,
                  _getExpiryLabel(),
                  _formatExpiryDate(),
                  _getExpiryColor(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Widget reutilizable para items de información
  Widget _buildInfoItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.mediumGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Métodos para fecha de caducidad (optimizados con cache)
  Color _getExpiryColor() {
    if (product.expiryDate == null) return AppTheme.mediumGrey;
    
    final daysUntilExpiry = product.daysUntilExpiry;
    if (daysUntilExpiry < 0) return AppTheme.errorRed;
    if (daysUntilExpiry <= 3) return AppTheme.warningOrange;
    return AppTheme.successGreen;
  }

  String _getExpiryLabel() {
    if (product.expiryDate == null) return 'Caducidad';
    
    final daysUntilExpiry = product.daysUntilExpiry;
    if (daysUntilExpiry < 0) return 'Caducado';
    if (daysUntilExpiry <= 3) return 'Caduca pronto';
    return 'Caduca en';
  }

  String _formatExpiryDate() {
    if (product.expiryDate == null) return '';
    
    final daysUntilExpiry = product.daysUntilExpiry;
    if (daysUntilExpiry < 0) {
      return '${(-daysUntilExpiry)} días';
    } else if (daysUntilExpiry == 0) {
      return 'Hoy';
    } else if (daysUntilExpiry == 1) {
      return 'Mañana';
    } else if (daysUntilExpiry <= 7) {
      return '$daysUntilExpiry días';
    } else {
      final date = product.expiryDate!;
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // Información nutricional optimizada
  Widget _buildNutritionalInfo(BuildContext context) {
    final nutritionalInfo = product.nutritionalInfo;
    if (nutritionalInfo == null) return const SizedBox.shrink();
    
    // Pre-calcular valores para evitar recalcular en cada build
    final macroWidgets = <Widget>[];
    
    // Fila 1: Calorías y Proteínas
    final row1Widgets = <Widget>[];
    if (nutritionalInfo.calories != null && nutritionalInfo.calories! > 0) {
      row1Widgets.add(Expanded(
        child: _buildMacroItem(
          'Calorías',
          '${nutritionalInfo.calories} kcal',
          Icons.local_fire_department_rounded,
          AppTheme.warningOrange,
        ),
      ));
    }
    
    if (nutritionalInfo.proteins != null && nutritionalInfo.proteins! > 0) {
      if (row1Widgets.isNotEmpty) {
        row1Widgets.add(const SizedBox(width: AppTheme.spacingSmall));
      }
      row1Widgets.add(Expanded(
        child: _buildMacroItem(
          'Proteínas',
          '${nutritionalInfo.proteins?.toStringAsFixed(1)}g',
          Icons.fitness_center_rounded,
          AppTheme.coralMain,
        ),
      ));
    }
    
    if (row1Widgets.isNotEmpty) {
      macroWidgets.add(Row(children: row1Widgets));
    }

    // Fila 2: Carbohidratos y Grasas
    final row2Widgets = <Widget>[];
    if (nutritionalInfo.carbohydrates != null && nutritionalInfo.carbohydrates! > 0) {
      row2Widgets.add(Expanded(
        child: _buildMacroItem(
          'Carbohidratos',
          '${nutritionalInfo.carbohydrates?.toStringAsFixed(1)}g',
          Icons.grain_rounded,
          AppTheme.successGreen,
        ),
      ));
    }
    
    if (nutritionalInfo.fats != null && nutritionalInfo.fats! > 0) {
      if (row2Widgets.isNotEmpty) {
        row2Widgets.add(const SizedBox(width: AppTheme.spacingSmall));
      }
      row2Widgets.add(Expanded(
        child: _buildMacroItem(
          'Grasas',
          '${nutritionalInfo.fats?.toStringAsFixed(1)}g',
          Icons.water_drop_rounded,
          AppTheme.softTeal,
        ),
      ));
    }
    
    if (row2Widgets.isNotEmpty) {
      if (macroWidgets.isNotEmpty) {
        macroWidgets.add(const SizedBox(height: AppTheme.spacingSmall));
      }
      macroWidgets.add(Row(children: row2Widgets));
    }

    // Fila 3: Fibra y Azúcar (si están disponibles)
    final row3Widgets = <Widget>[];
    if (nutritionalInfo.fiber != null && nutritionalInfo.fiber! > 0) {
      row3Widgets.add(Expanded(
        child: _buildMacroItem(
          'Fibra',
          '${nutritionalInfo.fiber?.toStringAsFixed(1)}g',
          Icons.eco_rounded,
          AppTheme.successGreen.withOpacity(0.8),
        ),
      ));
    }
    
    if (nutritionalInfo.sugar != null && nutritionalInfo.sugar! > 0) {
      if (row3Widgets.isNotEmpty) {
        row3Widgets.add(const SizedBox(width: AppTheme.spacingSmall));
      }
      row3Widgets.add(Expanded(
        child: _buildMacroItem(
          'Azúcar',
          '${nutritionalInfo.sugar?.toStringAsFixed(1)}g',
          Icons.cake_rounded,
          AppTheme.warningOrange.withOpacity(0.8),
        ),
      ));
    }
    
    if (row3Widgets.isNotEmpty) {
      if (macroWidgets.isNotEmpty) {
        macroWidgets.add(const SizedBox(height: AppTheme.spacingSmall));
      }
      macroWidgets.add(Row(children: row3Widgets));
    }

    if (macroWidgets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: AppTheme.softTeal.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(color: AppTheme.softTeal.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Título
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.analytics_rounded,
                size: 18,
                color: AppTheme.softTeal,
              ),
              const SizedBox(width: 8),
              Text(
                'Información Nutricional',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.softTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          ...macroWidgets,
        ],
      ),
    );
  }

  // Widget optimizado para macronutrientes
  Widget _buildMacroItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSmall,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Chips de información guardada (optimizado)
  Widget _buildInfoSummaryChips(BuildContext context) {
    final infoChips = <Widget>[];

    // Pre-calcular todos los chips necesarios
    if (product.quantity > 0) {
      infoChips.add(_buildInfoChip(
        Icons.scale_rounded,
        'Cantidad',
        AppTheme.coralMain,
      ));
    }

    if (product.expiryDate != null) {
      final daysUntilExpiry = product.daysUntilExpiry;
      Color expiryColor = AppTheme.successGreen;
      String expiryLabel = 'Caducidad';
      
      if (daysUntilExpiry < 0) {
        expiryColor = AppTheme.errorRed;
        expiryLabel = 'Caducado';
      } else if (daysUntilExpiry <= 3) {
        expiryColor = AppTheme.warningOrange;
        expiryLabel = 'Caduca pronto';
      }
      
      infoChips.add(_buildInfoChip(
        Icons.event_note_rounded,
        expiryLabel,
        expiryColor,
      ));
    }

    if (product.nutritionalInfo != null && 
        _hasNutritionalData(product.nutritionalInfo!)) {
      infoChips.add(_buildInfoChip(
        Icons.analytics_rounded,
        'Macros',
        AppTheme.softTeal,
      ));
    }

    if (product.imageUrl.isNotEmpty) {
      infoChips.add(_buildInfoChip(
        Icons.photo_rounded,
        'Imagen',
        AppTheme.coralMain.withOpacity(0.8),
      ));
    }

    if (infoChips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: AppTheme.spacingSmall,
      ),
      decoration: BoxDecoration(
        color: AppTheme.softTeal.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(color: AppTheme.softTeal.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: AppTheme.softTeal,
              ),
              const SizedBox(width: 6),
              Text(
                'Información guardada:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.softTeal,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Wrap(
            spacing: AppTheme.spacingSmall,
            runSpacing: 4,
            children: infoChips,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
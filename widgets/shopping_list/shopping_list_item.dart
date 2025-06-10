// lib/widgets/shopping_list_item_improved.dart - COMPONENTE MEJORADO

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';

class ShoppingListItemImproved extends StatefulWidget {
  final String productId;
  final String productName;
  final String quantity;
  final String? unit;
  final bool isPurchased;
  final bool isSelected;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onAddToInventory;
  final VoidCallback? onToggleSelection;
  final String? category;
  final String? location;
  final String? notes;
  final int? priority;

  const ShoppingListItemImproved({
    super.key,
    required this.productId,
    required this.productName,
    required this.quantity,
    this.unit,
    required this.isPurchased,
    this.isSelected = false,
    required this.onToggle,
    required this.onDelete,
    this.onEdit,
    this.onAddToInventory,
    this.onToggleSelection,
    this.category,
    this.location,
    this.notes,
    this.priority,
  });

  @override
  State<ShoppingListItemImproved> createState() => _ShoppingListItemImprovedState();
}

class _ShoppingListItemImprovedState extends State<ShoppingListItemImproved>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.fastOutSlowIn,
    ));

    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Color _getPriorityColor() {
    switch (widget.priority) {
      case 1: return AppTheme.successGreen;
      case 2: return AppTheme.softTeal;
      case 3: return AppTheme.yellowAccent;
      case 4: return AppTheme.errorRed;
      default: return AppTheme.softTeal;
    }
  }

  String _getPriorityLabel() {
    switch (widget.priority) {
      case 1: return 'Baja';
      case 2: return 'Normal';
      case 3: return 'Alta';
      case 4: return 'Urgente';
      default: return 'Normal';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Dismissible(
        key: Key('${widget.productId}-${DateTime.now().millisecondsSinceEpoch}'),
        background: _buildDismissBackground(),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) => _showDeleteConfirmation(),
        onDismissed: (_) => widget.onDelete(),
        child: Card(
          elevation: widget.isSelected ? AppTheme.elevationMedium : AppTheme.elevationTiny,
          margin: const EdgeInsets.symmetric(
           horizontal: AppTheme.spacingMedium,
           vertical: AppTheme.spacingSmall,
         ),
         shape: RoundedRectangleBorder(
           borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
           side: BorderSide(
             color: widget.isSelected 
               ? AppTheme.coralMain 
               : Colors.transparent,
             width: 2,
           ),
         ),
         child: InkWell(
           onTap: () {
             HapticFeedback.lightImpact();
             widget.onToggleSelection?.call();
           },
           onLongPress: () {
             HapticFeedback.mediumImpact();
             widget.onToggleSelection?.call();
           },
           borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
           child: Container(
             padding: const EdgeInsets.all(AppTheme.spacingMedium),
             decoration: BoxDecoration(
               gradient: widget.isSelected
                 ? LinearGradient(
                     colors: [
                       AppTheme.coralMain.withOpacity(0.1),
                       AppTheme.coralMain.withOpacity(0.05),
                     ],
                   )
                 : widget.isPurchased
                   ? LinearGradient(
                       colors: [
                         AppTheme.successGreen.withOpacity(0.08),
                         AppTheme.successGreen.withOpacity(0.04),
                       ],
                     )
                   : null,
               borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
             ),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 _buildMainRow(),
                 
                 if (_hasAdditionalInfo()) ...[
                   const SizedBox(height: AppTheme.spacingSmall),
                   _buildAdditionalInfo(),
                 ],
               ],
             ),
           ),
         ),
       ),
     ),
   );
 }

 Widget _buildDismissBackground() {
   return Container(
     margin: const EdgeInsets.symmetric(
       horizontal: AppTheme.spacingMedium,
       vertical: AppTheme.spacingSmall,
     ),
     decoration: BoxDecoration(
       gradient: LinearGradient(
         colors: [
           AppTheme.errorRed.withOpacity(0.8),
           AppTheme.errorRed,
         ],
       ),
       borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
     ),
     child: const Padding(
       padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingLarge),
       child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceBetween,
         children: [
           _DismissIcon(Icons.delete_sweep_rounded, 'Eliminar'),
           _DismissIcon(Icons.delete_forever_rounded, 'Borrar'),
         ],
       ),
     ),
   );
 }

 Widget _buildMainRow() {
   return Row(
     crossAxisAlignment: CrossAxisAlignment.start,
     children: [
       _buildCheckbox(),
       const SizedBox(width: AppTheme.spacingMedium),
       Expanded(child: _buildProductInfo()),
       const SizedBox(width: AppTheme.spacingSmall),
       _buildActionButtons(),
     ],
   );
 }

 Widget _buildCheckbox() {
   return GestureDetector(
     onTap: () {
       HapticFeedback.selectionClick();
       widget.onToggle();
     },
     child: AnimatedContainer(
       duration: const Duration(milliseconds: 300),
       width: 24,
       height: 24,
       decoration: BoxDecoration(
         color: widget.isPurchased 
           ? AppTheme.successGreen 
           : widget.isSelected
             ? AppTheme.coralMain
             : Colors.transparent,
         border: Border.all(
           color: widget.isPurchased 
             ? AppTheme.successGreen
             : widget.isSelected
               ? AppTheme.coralMain
               : AppTheme.mediumGrey,
           width: 2,
         ),
         borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
         boxShadow: (widget.isPurchased || widget.isSelected) ? [
           BoxShadow(
             color: (widget.isPurchased ? AppTheme.successGreen : AppTheme.coralMain)
                 .withOpacity(0.3),
             blurRadius: 4,
             offset: const Offset(0, 2),
           ),
         ] : null,
       ),
       child: (widget.isPurchased || widget.isSelected)
         ? const Icon(
             Icons.check_rounded,
             size: 16,
             color: AppTheme.pureWhite,
           )
         : null,
     ),
   );
 }

 Widget _buildProductInfo() {
   return Column(
     crossAxisAlignment: CrossAxisAlignment.start,
     children: [
       Row(
         children: [
           if (widget.isPurchased)
             Container(
               width: 16,
               height: 16,
               margin: const EdgeInsets.only(right: AppTheme.spacingSmall),
               decoration: BoxDecoration(
                 color: AppTheme.successGreen,
                 shape: BoxShape.circle,
                 boxShadow: [
                   BoxShadow(
                     color: AppTheme.successGreen.withOpacity(0.3),
                     blurRadius: 4,
                     offset: const Offset(0, 2),
                   ),
                 ],
               ),
               child: const Icon(
                 Icons.check_rounded,
                 size: 10,
                 color: AppTheme.pureWhite,
               ),
             ),
           
           Expanded(
             child: Text(
               widget.productName,
               style: TextStyle(
                 decoration: widget.isPurchased 
                   ? TextDecoration.lineThrough 
                   : null,
                 decorationColor: AppTheme.mediumGrey,
                 decorationThickness: 2,
                 color: widget.isPurchased 
                   ? AppTheme.mediumGrey
                   : widget.isSelected 
                     ? AppTheme.coralMain
                     : AppTheme.darkGrey,
                 fontWeight: FontWeight.w600,
                 fontSize: 16,
                 height: 1.3,
               ),
               maxLines: 2,
               overflow: TextOverflow.ellipsis,
             ),
           ),
         ],
       ),
       
       const SizedBox(height: AppTheme.spacingSmall),
       
       _buildInfoTags(),
     ],
   );
 }

 Widget _buildInfoTags() {
   return Wrap(
     spacing: AppTheme.spacingSmall,
     runSpacing: 4,
     children: [
       _buildInfoTag(
         text: widget.unit != null 
           ? '${widget.quantity} ${widget.unit}' 
           : widget.quantity,
         color: AppTheme.peachLight,
         icon: Icons.shopping_basket_outlined,
       ),
       
       if (widget.category != null)
         _buildInfoTag(
           text: widget.category!,
           color: AppTheme.softTeal,
           icon: Icons.category_outlined,
         ),
       
       if (widget.location != null && widget.location!.isNotEmpty)
         _buildInfoTag(
           text: widget.location!,
           color: AppTheme.yellowAccent,
           icon: Icons.location_on_outlined,
         ),
         
       if (widget.priority != null && widget.priority! >= 3)
         _buildInfoTag(
           text: _getPriorityLabel(),
           color: _getPriorityColor(),
           icon: Icons.priority_high_rounded,
         ),
     ],
   );
 }

 Widget _buildInfoTag({
   required String text,
   required Color color,
   required IconData icon,
 }) {
   return Container(
     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
     decoration: BoxDecoration(
       color: widget.isPurchased
         ? AppTheme.lightGrey.withOpacity(0.4)
         : color.withOpacity(0.2),
       borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
       border: Border.all(
         color: widget.isPurchased
           ? AppTheme.lightGrey.withOpacity(0.6)
           : color.withOpacity(0.4),
       ),
     ),
     child: Row(
       mainAxisSize: MainAxisSize.min,
       children: [
         Icon(
           icon,
           size: 10,
           color: widget.isPurchased 
             ? AppTheme.mediumGrey
             : color,
         ),
         const SizedBox(width: 4),
         Text(
           text,
           style: TextStyle(
             fontSize: 10,
             fontWeight: FontWeight.w600,
             color: widget.isPurchased 
               ? AppTheme.mediumGrey
               : AppTheme.darkGrey,
           ),
         ),
       ],
     ),
   );
 }

 Widget _buildActionButtons() {
   return Column(
     children: [
       _buildMainActionButton(),
       const SizedBox(height: AppTheme.spacingSmall),
       _buildSecondaryActions(),
     ],
   );
 }

 Widget _buildMainActionButton() {
   return GestureDetector(
     onTap: () {
       HapticFeedback.lightImpact();
       widget.onToggle();
     },
     child: AnimatedContainer(
       duration: const Duration(milliseconds: 300),
       padding: const EdgeInsets.symmetric(
         horizontal: AppTheme.spacingMedium,
         vertical: AppTheme.spacingSmall,
       ),
       decoration: BoxDecoration(
         gradient: LinearGradient(
           colors: widget.isPurchased 
             ? [AppTheme.successGreen, AppTheme.successGreen.withOpacity(0.8)]
             : [AppTheme.coralMain, AppTheme.coralMain.withOpacity(0.8)],
         ),
         borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
         boxShadow: [
           BoxShadow(
             color: (widget.isPurchased 
               ? AppTheme.successGreen
               : AppTheme.coralMain
             ).withOpacity(0.3),
             blurRadius: 6,
             offset: const Offset(0, 2),
           ),
         ],
       ),
       child: Row(
         mainAxisSize: MainAxisSize.min,
         children: [
           Icon(
             widget.isPurchased 
               ? Icons.check_circle_rounded 
               : Icons.add_shopping_cart_rounded,
             color: AppTheme.pureWhite,
             size: 14,
           ),
           const SizedBox(width: 4),
           Text(
             widget.isPurchased ? 'Listo' : 'Añadir',
             style: const TextStyle(
               color: AppTheme.pureWhite,
               fontWeight: FontWeight.bold,
               fontSize: 11,
             ),
           ),
         ],
       ),
     ),
   );
 }

 Widget _buildSecondaryActions() {
   return Row(
     mainAxisSize: MainAxisSize.min,
     children: [
       if (widget.onEdit != null)
         _buildSecondaryButton(
           icon: Icons.edit_rounded,
           color: AppTheme.softTeal,
           onTap: () {
             HapticFeedback.lightImpact();
             widget.onEdit!();
           },
         ),
       
       if (widget.onEdit != null && widget.isPurchased && widget.onAddToInventory != null)
         const SizedBox(width: AppTheme.spacingSmall),
       
       if (widget.isPurchased && widget.onAddToInventory != null)
         _buildSecondaryButton(
           icon: Icons.inventory_2_rounded,
           color: AppTheme.yellowAccent,
           onTap: () {
             HapticFeedback.lightImpact();
             widget.onAddToInventory!();
           },
         ),
     ],
   );
 }

 Widget _buildSecondaryButton({
   required IconData icon,
   required Color color,
   required VoidCallback onTap,
 }) {
   return GestureDetector(
     onTap: onTap,
     child: Container(
       width: 28,
       height: 28,
       decoration: BoxDecoration(
         color: color.withOpacity(0.2),
         borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
         border: Border.all(
           color: color.withOpacity(0.5),
         ),
       ),
       child: Icon(
         icon,
         color: color,
         size: 14,
       ),
     ),
   );
 }

 bool _hasAdditionalInfo() {
   return widget.notes != null && widget.notes!.isNotEmpty;
 }

 Widget _buildAdditionalInfo() {
   if (!_hasAdditionalInfo()) return const SizedBox.shrink();
   
   return Container(
     padding: const EdgeInsets.all(AppTheme.spacingSmall),
     decoration: BoxDecoration(
       color: AppTheme.backgroundGrey.withOpacity(0.3),
       borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
       border: Border.all(
         color: AppTheme.lightGrey.withOpacity(0.4),
       ),
     ),
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         const Row(
           children: [
             Icon(
               Icons.info_outline_rounded,
               size: 14,
               color: AppTheme.softTeal,
             ),
             SizedBox(width: AppTheme.spacingSmall),
             Text(
               'Notas',
               style: TextStyle(
                 fontSize: 12,
                 fontWeight: FontWeight.w600,
                 color: AppTheme.darkGrey,
               ),
             ),
           ],
         ),
         const SizedBox(height: 4),
         Text(
           widget.notes!,
           style: const TextStyle(
             fontSize: 11,
             color: AppTheme.darkGrey,
             height: 1.3,
           ),
         ),
       ],
     ),
   );
 }

 Future<bool> _showDeleteConfirmation() async {
   HapticFeedback.mediumImpact();
   
   return await showDialog<bool>(
     context: context,
     barrierDismissible: false,
     builder: (BuildContext context) {
       return AlertDialog(
         shape: RoundedRectangleBorder(
           borderRadius: BorderRadius.circular(AppTheme.borderRadiusXLarge),
         ),
         elevation: AppTheme.elevationHigh,
         backgroundColor: AppTheme.pureWhite,
         title: Row(
           children: [
             Container(
               padding: const EdgeInsets.all(AppTheme.spacingMedium),
               decoration: BoxDecoration(
                 color: AppTheme.errorRed.withOpacity(0.1),
                 borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
               ),
               child: const Icon(
                 Icons.delete_forever_rounded,
                 color: AppTheme.errorRed,
                 size: 24,
               ),
             ),
             const SizedBox(width: AppTheme.spacingMedium),
             const Expanded(
               child: Text(
                 "Confirmar eliminación",
                 style: TextStyle(
                   fontSize: 18,
                   fontWeight: FontWeight.bold,
                 ),
               ),
             ),
           ],
         ),
         content: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             RichText(
               text: TextSpan(
                 style: const TextStyle(
                   color: AppTheme.darkGrey,
                   fontSize: 16,
                   height: 1.5,
                 ),
                 children: [
                   const TextSpan(text: "¿Estás seguro de que quieres eliminar "),
                   TextSpan(
                     text: "'${widget.productName}'",
                     style: const TextStyle(
                       fontWeight: FontWeight.bold,
                       color: AppTheme.coralMain,
                     ),
                   ),
                   const TextSpan(text: " de tu lista de compras?"),
                 ],
               ),
             ),
             const SizedBox(height: AppTheme.spacingMedium),
             Container(
               padding: const EdgeInsets.all(AppTheme.spacingMedium),
               decoration: BoxDecoration(
                 color: AppTheme.yellowAccent.withOpacity(0.1),
                 borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                 border: Border.all(
                   color: AppTheme.yellowAccent.withOpacity(0.4),
                 ),
               ),
               child: const Row(
                 children: [
                   Icon(
                     Icons.info_outline_rounded,
                     color: AppTheme.yellowAccent,
                     size: 20,
                   ),
                   SizedBox(width: AppTheme.spacingSmall),
                   Expanded(
                     child: Text(
                       "Esta acción no se puede deshacer",
                       style: TextStyle(
                         color: AppTheme.darkGrey,
                         fontSize: 14,
                         fontWeight: FontWeight.w600,
                       ),
                     ),
                   ),
                 ],
               ),
             ),
           ],
         ),
         actions: [
           TextButton(
             onPressed: () {
               HapticFeedback.lightImpact();
               Navigator.of(context).pop(false);
             },
             style: TextButton.styleFrom(
               padding: const EdgeInsets.symmetric(
                 horizontal: AppTheme.spacingLarge,
                 vertical: AppTheme.spacingMedium,
               ),
               shape: RoundedRectangleBorder(
                 borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
               ),
             ),
             child: const Text(
               "Cancelar",
               style: TextStyle(
                 color: AppTheme.mediumGrey,
                 fontWeight: FontWeight.w600,
                 fontSize: 16,
               ),
             ),
           ),
           ElevatedButton(
             onPressed: () {
               HapticFeedback.heavyImpact();
               Navigator.of(context).pop(true);
             },
             style: ElevatedButton.styleFrom(
               backgroundColor: AppTheme.errorRed,
               foregroundColor: AppTheme.pureWhite,
               elevation: AppTheme.elevationMedium,
               padding: const EdgeInsets.symmetric(
                 horizontal: AppTheme.spacingLarge,
                 vertical: AppTheme.spacingMedium,
               ),
               shape: RoundedRectangleBorder(
                 borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
               ),
             ),
             child: const Text(
               "Eliminar",
               style: TextStyle(
                 fontWeight: FontWeight.bold,
                 fontSize: 16,
               ),
             ),
           ),
         ],
       );
     },
   ) ?? false;
 }
}

class _DismissIcon extends StatelessWidget {
 final IconData icon;
 final String label;

 const _DismissIcon(this.icon, this.label);

 @override
 Widget build(BuildContext context) {
   return Column(
     mainAxisAlignment: MainAxisAlignment.center,
     children: [
       Container(
         padding: const EdgeInsets.all(AppTheme.spacingMedium),
         decoration: BoxDecoration(
           color: AppTheme.pureWhite.withOpacity(0.25),
           shape: BoxShape.circle,
           border: Border.all(
             color: AppTheme.pureWhite.withOpacity(0.4),
             width: 2,
           ),
         ),
         child: Icon(
           icon,
           color: AppTheme.pureWhite,
           size: 24,
         ),
       ),
       const SizedBox(height: AppTheme.spacingSmall),
       Text(
         label,
         style: TextStyle(
           color: AppTheme.pureWhite,
           fontSize: 12,
           fontWeight: FontWeight.bold,
           shadows: [
             Shadow(
               color: Colors.black.withOpacity(0.6),
               offset: const Offset(0, 2),
               blurRadius: 4,
             ),
           ],
         ),
       ),
     ],
   );
 }
}
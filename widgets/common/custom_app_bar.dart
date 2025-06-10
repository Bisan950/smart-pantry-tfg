import 'package:flutter/material.dart';

/// CustomAppBar - Barra de aplicación personalizada para SmartPantry
/// 
/// Proporciona una barra de aplicación con estilos consistentes con el diseño de la aplicación,
/// incluye opciones para título, acciones y opciones de navegación.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool centerTitle;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final double? elevation;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double height;
  final bool showDivider;
  final double titleSpacing;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.centerTitle = true,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.elevation,
    this.bottom,
    this.backgroundColor,
    this.foregroundColor,
    this.height = kToolbarHeight,
    this.showDivider = false,
    this.titleSpacing = NavigationToolbar.kMiddleSpacing,
  });

  @override
  Size get preferredSize => Size.fromHeight(height + (bottom?.preferredSize.height ?? 0.0));

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBar(
          title: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: foregroundColor ?? Theme.of(context).appBarTheme.foregroundColor,
            ),
          ),
          centerTitle: centerTitle,
          leading: leading,
          automaticallyImplyLeading: automaticallyImplyLeading,
          actions: actions,
          elevation: elevation ?? 0,
          backgroundColor: backgroundColor ?? Theme.of(context).appBarTheme.backgroundColor,
          foregroundColor: foregroundColor ?? Theme.of(context).appBarTheme.foregroundColor,
          bottom: bottom,
          titleSpacing: titleSpacing,
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
          ),
      ],
    );
  }
}
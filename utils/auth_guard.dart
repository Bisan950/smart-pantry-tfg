// lib/utils/auth_guard.dart - Corregido con mejor manejo de withOpacity

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/routes.dart';
import '../config/theme.dart';

class AuthGuard extends StatelessWidget {
  final Widget child;

  const AuthGuard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Si el proveedor aún está inicializándose, mostrar pantalla de carga
    if (!authProvider.isInitialized) {
      return _buildLoadingScreen();
    }

    // Si el usuario no está autenticado, redirigir a la pantalla de bienvenida
    if (!authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(Routes.welcome);
      });
      
      // Mostrar un indicador de carga mientras se redirige
      return _buildLoadingScreen();
    }

    // Si el usuario está autenticado, mostrar la pantalla protegida
    return child;
  }
  
  // Pantalla de carga mejorada
  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Color(0xFFFFF0EB), // Usando color hexadecimal en lugar de withOpacity
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo mientras carga
              CircleAvatar(
                radius: 40,
                backgroundColor: AppTheme.coralMain,
                child: Icon(
                  Icons.kitchen_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              SizedBox(height: 20),
              // Indicador de carga
              CircularProgressIndicator(
                color: AppTheme.coralMain,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// lib/screens/settings/avatar_selection_screen.dart - ARREGLADO COMPLETAMENTE
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/avatar_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/avatar_selector.dart';
import '../../services/avatar_service.dart';

class AvatarSelectionScreen extends StatefulWidget {
  const AvatarSelectionScreen({super.key});

  @override
  State<AvatarSelectionScreen> createState() => _AvatarSelectionScreenState();
}

class _AvatarSelectionScreenState extends State<AvatarSelectionScreen> {
  AvatarModel? _selectedAvatar;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    // Inicializar con el avatar actual del usuario
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentAvatarId = authProvider.user?.avatarId;
    
    if (currentAvatarId != null) {
      // Cargar el avatar actual si existe
      _loadCurrentAvatar(currentAvatarId);
    }
  }

  Future<void> _loadCurrentAvatar(String avatarId) async {
    try {
      final avatarService = AvatarService();
      final avatar = await avatarService.getAvatarById(avatarId);
      if (avatar != null && mounted) {
        setState(() {
          _selectedAvatar = avatar;
        });
      }
    } catch (e) {
      print('Error cargando avatar actual: $e');
    }
  }

  void _onAvatarSelected(AvatarModel avatar) {
    setState(() {
      _selectedAvatar = avatar;
    });
  }

  Future<void> _saveAvatar() async {
    if (_selectedAvatar == null) return;
    
    setState(() => _isUpdating = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // ESTO ES CLAVE: Usar el método updateAvatar del AuthProvider
      final success = await authProvider.updateAvatar(_selectedAvatar!.id);
      
      if (success && mounted) {
        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Avatar actualizado: ${_selectedAvatar!.name}'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Regresar con éxito
        Navigator.of(context).pop(true);
      } else if (mounted) {
        // Mostrar error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al actualizar avatar'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Avatar'),
        elevation: 0,
      ),
      body: _isUpdating
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Guardando avatar...'),
                ],
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  // Selector de avatares - Usar Expanded para evitar overflow
                  Expanded(
                    child: AvatarSelector(
                      selectedAvatarId: _selectedAvatar?.id,
                      onAvatarSelected: _onAvatarSelected,
                      showCategories: true,
                      showSearch: true,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(
                color: Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Botón cancelar
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              // Botón guardar
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _selectedAvatar != null ? _saveAvatar : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: FittedBox(
                    child: Text(
                      _selectedAvatar != null 
                          ? 'Guardar' 
                          : 'Selecciona Avatar'
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
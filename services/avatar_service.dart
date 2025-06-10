// lib/services/avatar_service.dart
import '../models/avatar_model.dart';
import '../../config/avatar_config.dart'; // NUEVO: Importar configuración

/// Servicio para gestionar los avatares disponibles en la aplicación
class AvatarService {
  // Singleton
  static final AvatarService _instance = AvatarService._internal();
  factory AvatarService() => _instance;
  AvatarService._internal();

  // Cache de avatares
  List<AvatarModel>? _cachedAvatars;

  /// Obtiene todos los avatares disponibles
  /// Ahora utiliza la configuración centralizada
  Future<List<AvatarModel>> getAllAvatars() async {
    if (_cachedAvatars != null) {
      return _cachedAvatars!;
    }

    // Usar la configuración centralizada
    _cachedAvatars = AvatarConfig.generateAvatars();
    return _cachedAvatars!;
  }

  /// Obtiene avatares por categoría
  Future<List<AvatarModel>> getAvatarsByCategory(String category) async {
    return AvatarConfig.getAvatarsByCategory(category);
  }

  /// Obtiene todas las categorías disponibles
  Future<List<String>> getCategories() async {
    return AvatarConfig.getAvailableCategories();
  }

  /// Obtiene un avatar por su ID
  Future<AvatarModel?> getAvatarById(String id) async {
    return AvatarConfig.getAvatarById(id);
  }

  /// Obtiene avatares gratuitos
  Future<List<AvatarModel>> getFreeAvatars() async {
    return AvatarConfig.getFreeAvatars();
  }

  /// Obtiene avatares premium
  Future<List<AvatarModel>> getPremiumAvatars() async {
    return AvatarConfig.getPremiumAvatars();
  }

  /// Busca avatares por nombre
  Future<List<AvatarModel>> searchAvatars(String query) async {
    return AvatarConfig.searchAvatars(query);
  }

  /// Obtiene un avatar aleatorio
  Future<AvatarModel> getRandomAvatar() async {
    return AvatarConfig.getRandomAvatar();
  }

  /// Obtiene estadísticas de avatares
  Future<Map<String, int>> getAvatarStats() async {
    return AvatarConfig.getAvatarStats();
  }

  /// Limpia el cache de avatares (útil para refrescar)
  void clearCache() {
    _cachedAvatars = null;
  }

  /// Valida si un avatar existe
  Future<bool> avatarExists(String id) async {
    final avatar = await getAvatarById(id);
    return avatar != null;
  }

  /// Obtiene avatares sugeridos basados en una categoría
  Future<List<AvatarModel>> getSuggestedAvatars(String? currentAvatarId, [int limit = 6]) async {
    final allAvatars = await getAllAvatars();
    
    // Si no hay avatar actual, devolver algunos aleatorios
    if (currentAvatarId == null) {
      allAvatars.shuffle();
      return allAvatars.take(limit).toList();
    }
    
    final currentAvatar = await getAvatarById(currentAvatarId);
    if (currentAvatar == null) {
      allAvatars.shuffle();
      return allAvatars.take(limit).toList();
    }
    
    // Sugerir avatares de la misma categoría
    final sameCategory = await getAvatarsByCategory(currentAvatar.category);
    sameCategory.removeWhere((avatar) => avatar.id == currentAvatarId);
    sameCategory.shuffle();
    
    if (sameCategory.length >= limit) {
      return sameCategory.take(limit).toList();
    }
    
    // Si no hay suficientes de la misma categoría, agregar otros
    final others = allAvatars.where((avatar) => 
      avatar.category != currentAvatar.category && avatar.id != currentAvatarId
    ).toList();
    others.shuffle();
    
    final suggested = <AvatarModel>[];
    suggested.addAll(sameCategory);
    suggested.addAll(others.take(limit - sameCategory.length));
    
    return suggested;
  }
}
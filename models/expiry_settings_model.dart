// lib/models/expiry_settings_model.dart

class ExpirySettings {
  final int warningDays; // Días para considerar "por caducar"
  final int criticalDays; // Días para considerar "crítico"
  final bool notificationsEnabled; // Si las notificaciones están habilitadas
  final String userId; // Usuario al que pertenecen las configuraciones

  const ExpirySettings({
    this.warningDays = 7, // Por defecto 7 días
    this.criticalDays = 3, // Por defecto 3 días
    this.notificationsEnabled = true,
    required this.userId,
  });

  // Factory para crear configuraciones desde un mapa
  factory ExpirySettings.fromMap(Map<String, dynamic> map) {
    return ExpirySettings(
      warningDays: map['warningDays'] ?? 7,
      criticalDays: map['criticalDays'] ?? 3,
      notificationsEnabled: map['notificationsEnabled'] ?? true,
      userId: map['userId'] ?? '',
    );
  }

  // Método para convertir a mapa
  Map<String, dynamic> toMap() {
    return {
      'warningDays': warningDays,
      'criticalDays': criticalDays,
      'notificationsEnabled': notificationsEnabled,
      'userId': userId,
    };
  }

  // Método para crear una copia con algunos campos modificados
  ExpirySettings copyWith({
    int? warningDays,
    int? criticalDays,
    bool? notificationsEnabled,
    String? userId,
  }) {
    return ExpirySettings(
      warningDays: warningDays ?? this.warningDays,
      criticalDays: criticalDays ?? this.criticalDays,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      userId: userId ?? this.userId,
    );
  }
}
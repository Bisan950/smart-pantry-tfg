class WidgetConfiguration {
  final String id;
  final String name;
  final bool isVisible;
  final int order;
  final Map<String, dynamic> settings;

  const WidgetConfiguration({
    required this.id,
    required this.name,
    this.isVisible = true,
    this.order = 0,
    this.settings = const {},
  });

  factory WidgetConfiguration.fromMap(Map<String, dynamic> map) {
    return WidgetConfiguration(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      isVisible: map['isVisible'] ?? true,
      order: map['order'] ?? 0,
      settings: Map<String, dynamic>.from(map['settings'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isVisible': isVisible,
      'order': order,
      'settings': settings,
    };
  }

  WidgetConfiguration copyWith({
    String? id,
    String? name,
    bool? isVisible,
    int? order,
    Map<String, dynamic>? settings,
  }) {
    return WidgetConfiguration(
      id: id ?? this.id,
      name: name ?? this.name,
      isVisible: isVisible ?? this.isVisible,
      order: order ?? this.order,
      settings: settings ?? this.settings,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WidgetConfiguration && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'WidgetConfiguration(id: $id, name: $name, isVisible: $isVisible, order: $order)';
  }
}
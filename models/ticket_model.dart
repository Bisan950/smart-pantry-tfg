// lib/models/ticket_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class TicketModel {
  final String id;
  final String userId;
  final String storeName;
  final DateTime purchaseDate;
  final String imageUrl;
  final List<TicketItem> items;
  final double totalAmount;
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TicketAnalysisStatus analysisStatus;
  final Map<String, dynamic>? rawAnalysisData;

  const TicketModel({
    required this.id,
    required this.userId,
    required this.storeName,
    required this.purchaseDate,
    required this.imageUrl,
    required this.items,
    required this.totalAmount,
    this.currency = 'EUR',
    required this.createdAt,
    required this.updatedAt,
    this.analysisStatus = TicketAnalysisStatus.pending,
    this.rawAnalysisData,
  });

  factory TicketModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return TicketModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      storeName: data['storeName'] ?? '',
      purchaseDate: (data['purchaseDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: data['imageUrl'] ?? '',
      items: (data['items'] as List<dynamic>?)
          ?.map((item) => TicketItem.fromMap(item as Map<String, dynamic>))
          .toList() ?? [],
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      currency: data['currency'] ?? 'EUR',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      analysisStatus: TicketAnalysisStatus.values.firstWhere(
        (status) => status.name == data['analysisStatus'],
        orElse: () => TicketAnalysisStatus.pending,
      ),
      rawAnalysisData: data['rawAnalysisData'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'storeName': storeName,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'imageUrl': imageUrl,
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      'currency': currency,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'analysisStatus': analysisStatus.name,
      'rawAnalysisData': rawAnalysisData,
    };
  }

  TicketModel copyWith({
    String? id,
    String? userId,
    String? storeName,
    DateTime? purchaseDate,
    String? imageUrl,
    List<TicketItem>? items,
    double? totalAmount,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
    TicketAnalysisStatus? analysisStatus,
    Map<String, dynamic>? rawAnalysisData,
  }) {
    return TicketModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      storeName: storeName ?? this.storeName,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      imageUrl: imageUrl ?? this.imageUrl,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      analysisStatus: analysisStatus ?? this.analysisStatus,
      rawAnalysisData: rawAnalysisData ?? this.rawAnalysisData,
    );
  }
}

class TicketItem {
  final String name;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double totalPrice;
  final String? category;
  final String? brand;

  const TicketItem({
    required this.name,
    required this.quantity,
    this.unit = 'unidades',
    required this.unitPrice,
    required this.totalPrice,
    this.category,
    this.brand,
  });

  factory TicketItem.fromMap(Map<String, dynamic> map) {
    return TicketItem(
      name: map['name'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: map['unit'] ?? 'unidades',
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0.0,
      category: map['category'],
      brand: map['brand'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'category': category,
      'brand': brand,
    };
  }
}

enum TicketAnalysisStatus {
  pending,
  analyzing,
  completed,
  failed,
}
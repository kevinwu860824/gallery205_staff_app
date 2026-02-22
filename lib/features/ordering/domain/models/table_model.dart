// lib/features/ordering/domain/models/table_model.dart

import 'package:flutter/foundation.dart';

enum TableStatus {
  empty,      // 空桌
  occupied,   // 用餐中 (有進行中的訂單)
}

class TableModel {
  final String tableName;
  final String areaId;
  final String? shape; // 'circle', 'square', 'rectangle'
  final double x;
  final double y;
  final int rotation;
  
  // 動態狀態
  final TableStatus status;
  final String? currentOrderGroupId; // 主單 ID (通常是最新的一個)
  final List<String> activeOrderGroupIds; // 該桌所有進行中的訂單 ID (多單時使用)
  final int? colorIndex; // Smart Color Assignment

  TableModel({
    required this.tableName,
    required this.areaId,
    this.shape,
    this.x = 0,
    this.y = 0,
    this.rotation = 0,
    this.status = TableStatus.empty,
    this.currentOrderGroupId,
    this.activeOrderGroupIds = const [],
    this.colorIndex,
  });

  factory TableModel.fromMap(Map<String, dynamic> map, {
    TableStatus status = TableStatus.empty,
    String? currentOrderGroupId,
    List<String> activeOrderGroupIds = const [],
    int? colorIndex,
  }) {
    return TableModel(
      tableName: map['table_name'] ?? '',
      areaId: map['area_id'] ?? '',
      shape: map['shape'],
      x: (map['x'] as num?)?.toDouble() ?? 0.0,
      y: (map['y'] as num?)?.toDouble() ?? 0.0,
      rotation: (map['rotation'] as num?)?.toInt() ?? 0,
      status: status,
      currentOrderGroupId: currentOrderGroupId,
      activeOrderGroupIds: activeOrderGroupIds,
      colorIndex: colorIndex,
    );
  }
}

class AreaModel {
  final String id; // area_id (名稱)
  final int sortOrder;

  AreaModel({required this.id, required this.sortOrder});

  factory AreaModel.fromMap(Map<String, dynamic> map) {
    return AreaModel(
      id: map['area_id'] ?? '',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
  
  String get name => id;
}

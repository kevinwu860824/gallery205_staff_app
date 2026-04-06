import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';

class LocalDbService {
  static Database? _database;

  // Singleton pattern
  static final LocalDbService _instance = LocalDbService._internal();
  factory LocalDbService() => _instance;
  LocalDbService._internal();

  // Stream for notify changes
  final _printTaskUpdateController = StreamController<void>.broadcast();
  Stream<void> get onPrintTaskUpdate => _printTaskUpdateController.stream;

  // Stream for table updates
  final _tableUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onTableUpdate => _tableUpdateController.stream;

  void notifyTableUpdate(Map<String, dynamic> data) {
    _tableUpdateController.add(data);
  }

  // 取得資料庫實例
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'gallery_pos.db');
    return await openDatabase(
      path,
      version: 10,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Schema 建立（全新安裝）
  // ─────────────────────────────────────────────────────────────

  Future<void> _createDB(Database db, int version) async {
    // v1 tables
    await db.execute('''
      CREATE TABLE local_orders (
        id TEXT PRIMARY KEY,
        shop_id TEXT,
        table_names TEXT,
        people_count INTEGER,
        items_json TEXT,
        status TEXT,
        created_at TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE local_print_tasks (
        id TEXT PRIMARY KEY,
        order_group_id TEXT,
        content_json TEXT,
        printer_ip TEXT,
        status TEXT,
        error_message TEXT,
        created_at TEXT
      )
    ''');

    // v2 tables
    await _createV2Tables(db);

    // v4 tables
    await _createV4Tables(db);
    
    // v5 alterations
    await _migrateToV5(db);

    // v6 alterations
    await _migrateToV6(db);

    // v7 alterations
    await _migrateToV7(db);
  }

  // ─────────────────────────────────────────────────────────────
  // Migration（既有安裝升版）
  // ─────────────────────────────────────────────────────────────

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createV2Tables(db);
    }
    if (oldVersion < 3) {
      await _migrateToV3(db);
    }
    if (oldVersion < 4) {
      await _createV4Tables(db);
    }
    if (oldVersion < 5) {
      await _migrateToV5(db);
    }
    if (oldVersion < 6) {
      await _migrateToV6(db);
    }
    if (oldVersion < 7) {
      await _migrateToV7(db);
    }
    if (oldVersion < 8) {
      await _migrateToV8(db);
    }
    if (oldVersion < 9) {
      await _migrateToV9(db);
    }
    if (oldVersion < 10) {
      await _migrateToV10(db);
    }
  }

  Future<void> _createV2Tables(Database db) async {
    // 桌況快照（Hub 維護，Client 讀取）
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_tables (
        table_name TEXT PRIMARY KEY,
        area_id TEXT,
        status TEXT,
        current_order_group_id TEXT,
        color_index INTEGER,
        pax_adult INTEGER,
        updated_at TEXT
      )
    ''');

    // 菜單快照（Hub 啟動時從 Supabase 拉取）
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_menu_items (
        id TEXT PRIMARY KEY,
        category_id TEXT,
        name TEXT,
        price REAL,
        items_json TEXT,
        updated_at TEXT
      )
    ''');

    // 待上傳訂單 header
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_order_groups (
        id TEXT PRIMARY KEY,
        shop_id TEXT,
        table_names TEXT,
        pax_adult INTEGER,
        staff_name TEXT,
        tax_snapshot TEXT,
        color_index INTEGER,
        service_fee_rate REAL DEFAULT 0,
        discount_amount REAL DEFAULT 0,
        final_amount REAL,
        status TEXT DEFAULT 'dining',
        note TEXT,
        open_id TEXT,
        created_at TEXT,
        updated_at TEXT,
        merged_target_id TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // 待上傳訂單明細
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_order_items (
        id TEXT PRIMARY KEY,
        order_group_id TEXT,
        item_id TEXT,
        item_name TEXT,
        quantity INTEGER,
        price REAL,
        modifiers TEXT,
        note TEXT,
        target_print_category_ids TEXT,
        status TEXT DEFAULT 'new',
        print_status TEXT DEFAULT 'pending',
        created_at TEXT,
        updated_at TEXT,
        original_table_name TEXT,
        original_price REAL,
        is_synced INTEGER DEFAULT 0,
        print_jobs TEXT DEFAULT '{}'
      )
    ''');

    // 待上傳結帳記錄
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_checkouts (
        id TEXT PRIMARY KEY,
        order_group_id TEXT,
        payment_method TEXT,
        final_amount REAL,
        discount_amount REAL,
        service_fee_rate REAL,
        buyer_ubn TEXT,
        carrier_num TEXT,
        carrier_type TEXT,
        checkout_time TEXT,
        payments_json TEXT,
        open_id TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');
  }

  // ─────────────────────────────────────────────────────────────
  // Migration v2 → v3：對齊欄位名稱至 Supabase schema
  // ─────────────────────────────────────────────────────────────

  Future<void> _migrateToV3(Database db) async {
    // 檢查 pending_order_items 是否還是舊欄位名稱（menu_item_id / modifiers_json）
    final cols = await db.rawQuery('PRAGMA table_info(pending_order_items)');
    final colNames = cols.map((c) => c['name'] as String).toSet();
    final needsRename = colNames.contains('menu_item_id');

    if (needsRename) {
      // 舊版裝置：重建資料表並搬移資料
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_order_items_v3 (
          id TEXT PRIMARY KEY,
          order_group_id TEXT,
          item_id TEXT,
          item_name TEXT,
          quantity INTEGER,
          price REAL,
          modifiers TEXT,
          note TEXT,
          target_print_category_ids TEXT,
          status TEXT DEFAULT 'new',
          print_status TEXT DEFAULT 'pending',
          created_at TEXT,
          updated_at TEXT,
          is_synced INTEGER DEFAULT 0
        )
      ''');

      await db.execute('''
        INSERT INTO pending_order_items_v3
          (id, order_group_id, item_id, item_name, quantity, price,
           modifiers, note, target_print_category_ids,
           status, print_status, created_at, updated_at, is_synced)
        SELECT id, order_group_id, menu_item_id, item_name, quantity, price,
               modifiers_json, note, target_print_category_ids,
               'new', 'pending', created_at, NULL, is_synced
        FROM pending_order_items
      ''');

      await db.execute('DROP TABLE pending_order_items');
      await db.execute(
          'ALTER TABLE pending_order_items_v3 RENAME TO pending_order_items');
    }
    // 新版裝置（v2 已用正確欄位名稱）：略過資料表重建

    // pending_order_groups：新增欄位（欄位已存在時 ignore）
    for (final sql in [
      "ALTER TABLE pending_order_groups ADD COLUMN status TEXT DEFAULT 'dining'",
      'ALTER TABLE pending_order_groups ADD COLUMN open_id TEXT',
      'ALTER TABLE pending_order_groups ADD COLUMN updated_at TEXT',
    ]) {
      try {
        await db.execute(sql);
      } catch (_) {} // 欄位已存在時 SQLite 會丟錯，直接 ignore
    }

    // pending_checkouts：新增 open_id 欄位
    try {
      await db.execute('ALTER TABLE pending_checkouts ADD COLUMN open_id TEXT');
    } catch (_) {}
  }

  Future<void> _migrateToV7(Database db) async {
    try {
      await db.execute('ALTER TABLE pending_order_items ADD COLUMN original_table_name TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE pending_order_groups ADD COLUMN merged_target_id TEXT');
    } catch (_) {}
  }

  Future<void> _migrateToV8(Database db) async {
    try {
      await db.execute('ALTER TABLE pending_order_groups ADD COLUMN note TEXT');
    } catch (_) {}
  }

  Future<void> _migrateToV9(Database db) async {
    try {
      await db.execute('ALTER TABLE pending_order_items ADD COLUMN original_price REAL');
    } catch (_) {}
  }

  Future<void> _migrateToV10(Database db) async {
    try {
      await db.execute("ALTER TABLE pending_order_items ADD COLUMN print_jobs TEXT DEFAULT '{}'");
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────
  // Migration v5 → v6：新增 pax 同步欄位
  // ─────────────────────────────────────────────────────────────

  Future<void> _migrateToV6(Database db) async {
    try {
      await db.execute(
          'ALTER TABLE pending_order_groups ADD COLUMN pax INTEGER DEFAULT 0');
    } catch (_) {}
    try {
      await db.execute(
          'ALTER TABLE pending_order_groups ADD COLUMN pax_child INTEGER DEFAULT 0');
    } catch (_) {}

    // Data cleanup: initialize pax from pax_adult for existing rows
    try {
      await db.execute(
          'UPDATE pending_order_groups SET pax = pax_adult WHERE (pax IS NULL OR pax = 0) AND pax_adult > 0');
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────
  // Migration v4 → v5：新增 pending_order_groups 結帳準備欄位
  // ─────────────────────────────────────────────────────────────

  Future<void> _migrateToV5(Database db) async {
    for (final sql in [
      'ALTER TABLE pending_order_groups ADD COLUMN service_fee_rate REAL DEFAULT 0',
      'ALTER TABLE pending_order_groups ADD COLUMN discount_amount REAL DEFAULT 0',
      'ALTER TABLE pending_order_groups ADD COLUMN final_amount REAL',
    ]) {
      try {
        await db.execute(sql);
      } catch (_) {}
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Migration v3 → v4：新增 pending_receipt_prints 表
  // ─────────────────────────────────────────────────────────────

  Future<void> _createV4Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_receipt_prints (
        id TEXT PRIMARY KEY,
        table_names TEXT,
        final_amount REAL,
        checkout_time TEXT,
        needs_invoice INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');
  }

  // ─────────────────────────────────────────────────────────────
  // 待補印結帳（v4）
  // ─────────────────────────────────────────────────────────────

  Future<void> addPendingReceiptPrint(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('pending_receipt_prints', data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getPendingReceiptPrints() async {
    final db = await database;
    return await db.query('pending_receipt_prints', orderBy: 'created_at ASC');
  }

  Future<void> removePendingReceiptPrint(String orderGroupId) async {
    final db = await database;
    await db.delete('pending_receipt_prints',
        where: 'id = ?', whereArgs: [orderGroupId]);
  }

  // ─────────────────────────────────────────────────────────────
  // 列印狀態（Hub 模式）
  // ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchFailedPrintItemsLocal() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT i.*, g.table_names AS group_table_names
      FROM pending_order_items i
      JOIN pending_order_groups g ON g.id = i.order_group_id
      WHERE i.print_status = 'failed'
        AND g.status != 'cancelled'
      ORDER BY i.created_at DESC
      LIMIT 50
    ''');
    return rows.map((row) {
      final map = Map<String, dynamic>.from(row);
      try { map['modifiers'] = jsonDecode(map['modifiers'] as String? ?? '[]'); } catch (_) { map['modifiers'] = []; }
      try { map['target_print_category_ids'] = jsonDecode(map['target_print_category_ids'] as String? ?? '[]'); } catch (_) { map['target_print_category_ids'] = []; }
      try { map['print_jobs'] = jsonDecode(map['print_jobs'] as String? ?? '{}'); } catch (_) { map['print_jobs'] = {}; }
      String tableNameStr = '';
      try { tableNameStr = (jsonDecode(map['group_table_names'] as String? ?? '[]') as List).join(','); } catch (_) {}
      map['_table_name_str'] = tableNameStr;
      return map;
    }).toList();
  }

  Future<void> updatePrintJobsLocal(Map<String, Map<String, dynamic>> itemPrintJobs) async {
    if (itemPrintJobs.isEmpty) return;
    final db = await database;
    for (final entry in itemPrintJobs.entries) {
      await db.update(
        'pending_order_items',
        {'print_jobs': jsonEncode(entry.value)},
        where: 'id = ?',
        whereArgs: [entry.key],
      );
    }
  }

  Future<void> updatePrintStatusLocal(List<String> itemIds, String status) async {
    if (itemIds.isEmpty) return;
    final db = await database;
    final placeholders = itemIds.map((_) => '?').join(',');
    await db.rawUpdate(
      'UPDATE pending_order_items SET print_status = ? WHERE id IN ($placeholders)',
      [status, ...itemIds],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 列印任務（v1）
  // ─────────────────────────────────────────────────────────────

  Future<void> insertPrintTask(Map<String, dynamic> task) async {
    final db = await database;
    await db.insert('local_print_tasks', task,
        conflictAlgorithm: ConflictAlgorithm.replace);
    _printTaskUpdateController.add(null);
  }

  Future<void> updatePrintTaskStatus(String id, String status,
      {String? error}) async {
    final db = await database;
    await db.update(
      'local_print_tasks',
      {'status': status, 'error_message': error},
      where: 'id = ?',
      whereArgs: [id],
    );
    _printTaskUpdateController.add(null);
  }

  Future<List<Map<String, dynamic>>> getFailedPrintTasks() async {
    final db = await database;
    return await db.query(
      'local_print_tasks',
      where: 'status = ?',
      whereArgs: ['failed'],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> clearSuccessfulTasks() async {
    final db = await database;
    await db.delete('local_print_tasks',
        where: 'status = ?', whereArgs: ['success']);
  }

  // ─────────────────────────────────────────────────────────────
  // 離線訂單佇列（v1）
  // ─────────────────────────────────────────────────────────────

  Future<void> insertOfflineOrder(Map<String, dynamic> order) async {
    final db = await database;
    await db.insert('local_orders', order,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedOrders() async {
    final db = await database;
    return await db.query(
      'local_orders',
      where: 'is_synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> markOrderAsSynced(String id) async {
    final db = await database;
    await db.update(
      'local_orders',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteOfflineOrder(String id) async {
    final db = await database;
    await db.delete('local_orders', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────────────────────────────
  // 桌況快照（v2）
  // ─────────────────────────────────────────────────────────────

  Future<void> upsertCachedTable(Map<String, dynamic> table) async {
    final db = await database;
    await db.insert('cached_tables', table,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Picks the least-used color index (0–8) among currently occupied tables.
  /// Call this before seating a new group so each table group has a unique color.
  Future<int> pickColorIndex() async {
    const int colorCount = 9;
    final db = await database;
    final rows = await db.query(
      'cached_tables',
      columns: ['color_index'],
      where: 'status = ? AND color_index IS NOT NULL',
      whereArgs: ['occupied'],
    );
    final usedCounts = List<int>.filled(colorCount, 0);
    for (final row in rows) {
      final idx = row['color_index'] as int?;
      if (idx != null && idx >= 0 && idx < colorCount) {
        usedCounts[idx]++;
      }
    }
    // Pick the color used least (excluding index 8 = light grey as last resort)
    int best = 0;
    int bestCount = usedCounts[0];
    for (int i = 1; i < colorCount - 1; i++) {
      if (usedCounts[i] < bestCount) {
        bestCount = usedCounts[i];
        best = i;
      }
    }
    return best;
  }


  Future<List<Map<String, dynamic>>> getCachedTables() async {
    final db = await database;
    return await db.query('cached_tables');
  }

  Future<Map<String, dynamic>?> getCachedTable(String tableName) async {
    final db = await database;
    final rows = await db.query(
      'cached_tables',
      where: 'table_name = ?',
      whereArgs: [tableName],
    );
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  Future<void> clearCachedTable(String tableName) async {
    final db = await database;
    await db.update(
      'cached_tables',
      {
        'status': 'empty',
        'current_order_group_id': null,
        'color_index': null,
        'pax_adult': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'table_name = ?',
      whereArgs: [tableName],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 菜單快照（v2）
  // ─────────────────────────────────────────────────────────────

  Future<void> upsertCachedMenuItem(Map<String, dynamic> item) async {
    final db = await database;
    await db.insert('cached_menu_items', item,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getCachedMenuItems() async {
    final db = await database;
    return await db.query('cached_menu_items');
  }

  Future<void> clearCachedMenu() async {
    final db = await database;
    await db.delete('cached_menu_items');
  }

  // ─────────────────────────────────────────────────────────────
  // 待上傳訂單 header（v2）
  // ─────────────────────────────────────────────────────────────

  Future<void> insertPendingOrderGroup(Map<String, dynamic> group) async {
    final db = await database;
    final Map<String, dynamic> data = Map<String, dynamic>.from(group);

    // Ensure JSON fields are stringified for SQLite
    if (data['table_names'] != null && data['table_names'] is! String) {
      data['table_names'] = jsonEncode(data['table_names']);
    }
    if (data['tax_snapshot'] != null && data['tax_snapshot'] is! String) {
      data['tax_snapshot'] = jsonEncode(data['tax_snapshot']);
    }

    // Ensure pax field is populated (total count)
    if (data['pax'] == null && data['pax_adult'] != null) {
      data['pax'] = (data['pax_adult'] as int) + (data['pax_child'] ?? 0);
    }

    await db.insert('pending_order_groups', data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getPendingOrderGroup(String id) async {
    final db = await database;
    final rows = await db.query(
      'pending_order_groups',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;

    final map = Map<String, dynamic>.from(rows.first);
    if (map['table_names'] != null && map['table_names'] is String) {
      try {
        map['table_names'] = jsonDecode(map['table_names']);
      } catch (_) {}
    }
    if (map['tax_snapshot'] != null && map['tax_snapshot'] is String) {
      try {
        map['tax_snapshot'] = jsonDecode(map['tax_snapshot']);
      } catch (_) {}
    }
    return map;
  }

  Future<void> updatePendingOrderGroupPax(String id,
      {int? pax, int? adult, int? child}) async {
    final db = await database;
    final Map<String, dynamic> updates = {};
    if (pax != null) updates['pax'] = pax;
    if (adult != null) updates['pax_adult'] = adult;
    if (child != null) updates['pax_child'] = child;

    if (updates.isNotEmpty) {
      await db.update('pending_order_groups', updates,
          where: 'id = ?', whereArgs: [id]);
    }
  }

  /// 取得所有進行中（dining / pending）的訂單群組，同時 JOIN 品項，
  /// 回傳格式與 Supabase order_groups 相容，供 OrderHistoryScreen 使用。
  Future<List<Map<String, dynamic>>> getAllActivePendingOrderGroupsWithItems() async {
    final db = await database;
    final groups = await db.query(
      'pending_order_groups',
      where: "status != ? AND status != ? AND status != ?",
      whereArgs: ['cancelled', 'merged', 'completed'],
      orderBy: 'created_at DESC',
    );

    final result = <Map<String, dynamic>>[];
    for (final raw in groups) {
      final map = Map<String, dynamic>.from(raw);

      // Parse JSON string fields
      if (map['table_names'] is String) {
        try { map['table_names'] = jsonDecode(map['table_names'] as String); } catch (_) {}
      }
      if (map['tax_snapshot'] is String) {
        try { map['tax_snapshot'] = jsonDecode(map['tax_snapshot'] as String); } catch (_) {}
      }

      // Fetch items and attach in Supabase-compatible format
      final items = await db.query(
        'pending_order_items',
        where: 'order_group_id = ?',
        whereArgs: [map['id']],
      );
      map['order_items'] = items.map((i) => {
        'price': i['price'],
        'quantity': i['quantity'],
        'status': i['status'],
      }).toList();

      // Ensure pax field
      map['pax'] = map['pax_adult'] ?? 0;

      result.add(map);
    }
    return result;
  }

  /// 回傳每張桌子目前所有進行中訂單 ID 的 Map（用於拆單後多訂單選擇）。
  Future<Map<String, List<String>>> getActiveGroupIdsByTable() async {
    final db = await database;
    final groups = await db.query(
      'pending_order_groups',
      columns: ['id', 'table_names'],
      where: "status != ? AND status != ? AND status != ?",
      whereArgs: ['cancelled', 'merged', 'completed'],
      orderBy: 'created_at ASC',
    );
    final result = <String, List<String>>{};
    for (final g in groups) {
      final id = g['id'] as String;
      final tables = List<String>.from(
          jsonDecode(g['table_names'] as String? ?? '[]'));
      for (final t in tables) {
        result.putIfAbsent(t, () => []).add(id);
      }
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getUnsyncedOrderGroups() async {
    final db = await database;
    return await db.query(
      'pending_order_groups',
      where: 'is_synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> markOrderGroupSynced(String id) async {
    final db = await database;
    await db.update(
      'pending_order_groups',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 待上傳訂單明細（v2）
  // ─────────────────────────────────────────────────────────────

  Future<void> insertPendingOrderItem(Map<String, dynamic> item) async {
    final db = await database;
    final Map<String, dynamic> data = Map<String, dynamic>.from(item);

    // Ensure JSON fields are stringified for SQLite
    if (data['modifiers'] != null && data['modifiers'] is! String) {
      data['modifiers'] = jsonEncode(data['modifiers']);
    }
    if (data['target_print_category_ids'] != null &&
        data['target_print_category_ids'] is! String) {
      data['target_print_category_ids'] =
          jsonEncode(data['target_print_category_ids']);
    }

    await db.insert('pending_order_items', data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getPendingOrderItems(
      String orderGroupId) async {
    final db = await database;
    final rows = await db.query(
      'pending_order_items',
      where: 'order_group_id = ?',
      whereArgs: [orderGroupId],
    );

    return rows.map((row) {
      final map = Map<String, dynamic>.from(row);
      if (map['modifiers'] != null && map['modifiers'] is String) {
        try {
          map['modifiers'] = jsonDecode(map['modifiers']);
        } catch (_) {}
      }
      if (map['target_print_category_ids'] != null &&
          map['target_print_category_ids'] is String) {
        try {
          map['target_print_category_ids'] =
              jsonDecode(map['target_print_category_ids']);
        } catch (_) {}
      }
      return map;
    }).toList();
  }

  Future<void> markOrderItemsSynced(String orderGroupId) async {
    final db = await database;
    await db.update(
      'pending_order_items',
      {'is_synced': 1},
      where: 'order_group_id = ?',
      whereArgs: [orderGroupId],
    );
  }

  /// Hub 同步用：取得所有未同步的訂單（含明細與結帳記錄）
  /// 包含兩種情況：
  /// 1. group 本身未同步（is_synced=0）
  /// 2. group 已同步但有未同步的 checkout（group 先同步完，checkout 之後才進來）
  Future<List<Map<String, dynamic>>> getUnsyncedOrderGroupsWithCheckout() async {
    final db = await database;
    final groups = await db.rawQuery('''
      SELECT DISTINCT pg.* FROM pending_order_groups pg
      LEFT JOIN pending_checkouts pc ON pc.order_group_id = pg.id AND pc.is_synced = 0
      WHERE pg.is_synced = 0 OR pc.id IS NOT NULL
      ORDER BY pg.created_at ASC
    ''');
    final result = <Map<String, dynamic>>[];
    for (final groupRow in groups) {
      final groupMap = Map<String, dynamic>.from(groupRow);
      if (groupMap['table_names'] != null && groupMap['table_names'] is String) {
        try {
          groupMap['table_names'] = jsonDecode(groupMap['table_names']);
        } catch (_) {}
      }
      if (groupMap['tax_snapshot'] != null &&
          groupMap['tax_snapshot'] is String) {
        try {
          groupMap['tax_snapshot'] = jsonDecode(groupMap['tax_snapshot']);
        } catch (_) {}
      }

      final items = await db.query(
        'pending_order_items',
        where: 'order_group_id = ?',
        whereArgs: [groupMap['id']],
      );

      final decodedItems = items.map((itemRow) {
        final itemMap = Map<String, dynamic>.from(itemRow);
        if (itemMap['modifiers'] != null && itemMap['modifiers'] is String) {
          try {
            itemMap['modifiers'] = jsonDecode(itemMap['modifiers']);
          } catch (_) {}
        }
        if (itemMap['target_print_category_ids'] != null &&
            itemMap['target_print_category_ids'] is String) {
          try {
            itemMap['target_print_category_ids'] =
                jsonDecode(itemMap['target_print_category_ids']);
          } catch (_) {}
        }
        return itemMap;
      }).toList();

      final checkoutRows = await db.query(
        'pending_checkouts',
        where: 'order_group_id = ? AND is_synced = 0',
        whereArgs: [groupMap['id']],
      );

      result.add({
        'group': groupMap,
        'items': decodedItems,
        'checkout': checkoutRows.isEmpty ? null : checkoutRows.first,
      });
    }
    return result;
  }

  /// 清桌取消：標記訂單為已取消（is_synced=1 讓 sync 跳過）
  Future<void> cancelPendingOrderGroup(String id) async {
    final db = await database;
    await db.update(
        'pending_order_groups', {'status': 'cancelled', 'is_synced': 1},
        where: 'id = ?', whereArgs: [id]);
    await db.update('pending_order_items', {'is_synced': 1},
        where: 'order_group_id = ?', whereArgs: [id]);
  }

  Future<void> updatePendingOrderGroupStatus(String id, String status) async {
    final db = await database;
    await db.update('pending_order_groups', {'status': status},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Hub 同步用：標記訂單（含明細與結帳）為已同步
  Future<void> markOrderGroupAndCheckoutSynced(String orderGroupId) async {
    final db = await database;
    await db.update('pending_order_groups', {'is_synced': 1, 'status': 'completed'},
        where: 'id = ?', whereArgs: [orderGroupId]);
    await db.update('pending_order_items', {'is_synced': 1},
        where: 'order_group_id = ?', whereArgs: [orderGroupId]);
    await db.update('pending_checkouts', {'is_synced': 1},
        where: 'order_group_id = ?', whereArgs: [orderGroupId]);
  }

  /// P3 sync：取得孤立 items（group 已在 Supabase，items 是離線存的加點）
  Future<List<Map<String, dynamic>>> getUnsyncedOrphanItems() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT * FROM pending_order_items
      WHERE is_synced = 0
        AND order_group_id NOT IN (
          SELECT id FROM pending_order_groups WHERE is_synced = 0
        )
    ''');
  }

  /// 單筆 item 標記為已同步
  Future<void> markSingleItemSynced(String id) async {
    final db = await database;
    await db.update('pending_order_items', {'is_synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  /// 加點：只新增 items，不動 order_group
  Future<void> addItemsToOrder(
      String orderGroupId, List<Map<String, dynamic>> items) async {
    final db = await database;
    for (final item in items) {
      await db.insert('pending_order_items', item,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 待上傳結帳記錄（v2）
  // ─────────────────────────────────────────────────────────────

  Future<void> insertPendingCheckout(Map<String, dynamic> checkout) async {
    final db = await database;
    await db.insert('pending_checkouts', checkout,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getPendingCheckout(
      String orderGroupId) async {
    final db = await database;
    final rows = await db.query(
      'pending_checkouts',
      where: 'order_group_id = ? AND is_synced = 0',
      whereArgs: [orderGroupId],
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getUnsyncedCheckouts() async {
    final db = await database;
    return await db.query(
      'pending_checkouts',
      where: 'is_synced = ?',
      whereArgs: [0],
      orderBy: 'checkout_time ASC',
    );
  }

  Future<void> markCheckoutSynced(String orderGroupId) async {
    final db = await database;
    await db.update(
      'pending_checkouts',
      {'is_synced': 1},
      where: 'order_group_id = ?',
      whereArgs: [orderGroupId],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 單項更新 (Hub v2 testing)
  // ─────────────────────────────────────────────────────────────

  Future<void> updatePendingOrderItemStatus(String id, String status) async {
    final db = await database;
    await db.update('pending_order_items', {'status': status, 'updated_at': DateTime.now().toUtc().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updatePendingOrderItemPrice(String id, {required double price, double? originalPrice}) async {
    final db = await database;
    final updates = <String, dynamic>{
      'price': price,
      'is_synced': 0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (originalPrice != null) updates['original_price'] = originalPrice;
    await db.update('pending_order_items', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updatePendingOrderGroupBilling(String id, {double? serviceFeeRate, double? discountAmount, double? finalAmount}) async {
    final db = await database;
    final Map<String, dynamic> updates = {};
    if (serviceFeeRate != null) updates['service_fee_rate'] = serviceFeeRate;
    if (discountAmount != null) updates['discount_amount'] = discountAmount;
    if (finalAmount != null) updates['final_amount'] = finalAmount;
    
    if (updates.isNotEmpty) {
      updates['updated_at'] = DateTime.now().toUtc().toIso8601String();
      await db.update('pending_order_groups', updates, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> updatePendingOrderGroupNote(String id, String note) async {
    final db = await database;
    await db.update(
      'pending_order_groups',
      {'note': note, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Session Operations (Move / Merge)
  // ─────────────────────────────────────────────────────────────

  Future<void> moveTableLocal({
    required String hostGroupId,
    required List<String> oldTables,
    required List<String> newTables,
    int? colorIndex,
  }) async {
    final db = await database;
    final String updatedAt = DateTime.now().toUtc().toIso8601String();

    final removedSet = oldTables.toSet().difference(newTables.toSet());
    final addedSet = newTables.toSet().difference(oldTables.toSet());
    
    String? targetForTransfer;
    if (addedSet.isNotEmpty) {
      targetForTransfer = addedSet.first;
    } else if (newTables.isNotEmpty) {
      targetForTransfer = newTables.first;
    }

    await db.transaction((txn) async {
      // 0a. Guard: prevent moving host to a merged child's original table
      // (would cause table_names collision and ghost order on unmerge)
      final mergedChildGuardRows = await txn.query(
        'pending_order_groups',
        columns: ['table_names'],
        where: 'merged_target_id = ?',
        whereArgs: [hostGroupId],
      );
      final mergedChildTableSet = <String>{};
      for (final row in mergedChildGuardRows) {
        final tables = jsonDecode(row['table_names'] as String? ?? '[]') as List;
        mergedChildTableSet.addAll(tables.cast<String>());
      }
      final conflicting = newTables.toSet().intersection(mergedChildTableSet);
      if (conflicting.isNotEmpty) {
        throw Exception('無法移動至 ${conflicting.join("、")}，該桌號為已併入子桌。請先拆桌再移動。');
      }

      // 0b. Determine color_index: prefer caller-supplied value, fallback to existing
      int? groupColorIndex = colorIndex;
      if (groupColorIndex == null && oldTables.isNotEmpty) {
        final colorRows = await txn.query(
          'cached_tables',
          columns: ['color_index'],
          where: 'table_name = ?',
          whereArgs: [oldTables.first],
        );
        groupColorIndex = colorRows.isNotEmpty ? colorRows.first['color_index'] as int? : null;
      }

      // 1. Update order group table names
      await txn.update(
        'pending_order_groups',
        {
          'table_names': jsonEncode(newTables),
          'updated_at': updatedAt,
        },
        where: 'id = ?',
        whereArgs: [hostGroupId],
      );

      // 2. Transfer item original_table_name
      // Collect merged child group tables to preserve their original_table_name
      // (prevents merge history from being lost when host moves tables)
      if (targetForTransfer != null) {
        final mergedChildRows = await txn.query(
          'pending_order_groups',
          columns: ['table_names'],
          where: 'merged_target_id = ?',
          whereArgs: [hostGroupId],
        );
        final mergedChildTables = <String>{};
        for (final row in mergedChildRows) {
          final tables = jsonDecode(row['table_names'] as String? ?? '[]') as List;
          mergedChildTables.addAll(tables.cast<String>());
        }

        for (final removedTable in removedSet) {
          // Skip tables belonging to merged child groups — preserve their original_table_name
          if (mergedChildTables.contains(removedTable)) continue;

          await txn.update(
            'pending_order_items',
            {'original_table_name': targetForTransfer},
            where: 'order_group_id = ? AND original_table_name = ?',
            whereArgs: [hostGroupId, removedTable],
          );
        }

        // Handle NULL original_table_name (host's own items from first table)
        await txn.update(
          'pending_order_items',
          {'original_table_name': targetForTransfer},
          where: 'order_group_id = ? AND original_table_name IS NULL',
          whereArgs: [hostGroupId],
        );
      }

      // 3. Update cached_tables (for UI consistency on Hub)
      // Clear old tables that are no longer in newTables,
      // but only if no OTHER active group still references that table.
      for (final table in removedSet) {
        final others = await txn.query(
          'pending_order_groups',
          columns: ['id'],
          where: "id != ? AND status NOT IN ('cancelled','merged','completed') AND table_names LIKE ?",
          whereArgs: [hostGroupId, '%"$table"%'],
        );
        if (others.isEmpty) {
          await txn.update(
            'cached_tables',
            {'current_order_group_id': null, 'status': 'empty', 'pax_adult': 0, 'color_index': null},
            where: 'table_name = ?',
            whereArgs: [table],
          );
        }
      }
      // Set ALL new tables as occupied (upsert: update if exists, insert if not)
      // Carry over the group's color_index so all tables in the group stay the same color
      for (final table in newTables.toSet()) {
        final count = await txn.update(
          'cached_tables',
          {
            'current_order_group_id': hostGroupId,
            'status': 'occupied',
            if (groupColorIndex != null) 'color_index': groupColorIndex,
            'updated_at': updatedAt,
          },
          where: 'table_name = ?',
          whereArgs: [table],
        );
        if (count == 0) {
          await txn.insert('cached_tables', {
            'table_name': table,
            'status': 'occupied',
            'current_order_group_id': hostGroupId,
            if (groupColorIndex != null) 'color_index': groupColorIndex,
            'updated_at': updatedAt,
          });
        }
      }
    });

    _printTaskUpdateController.add(null);
  }

  Future<void> mergeOrderGroupsLocal({
    required String hostGroupId,
    required List<String> targetGroupIds,
    int? colorIndex,
  }) async {
    final db = await database;
    final String updatedAt = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      // 1. Get host's current tables
      final hostRows = await txn.query('pending_order_groups', columns: ['table_names'], where: 'id = ?', whereArgs: [hostGroupId]);
      List<String> currentHostTables = hostRows.isNotEmpty ? List<String>.from(jsonDecode(hostRows.first['table_names'] as String? ?? '[]')) : [];
      final Set<String> newHostTables = currentHostTables.toSet();

      // Determine final color: use provided colorIndex, else fallback to host's existing color
      int? finalColor = colorIndex;
      if (finalColor == null && currentHostTables.isNotEmpty) {
        final colorRows = await txn.query('cached_tables', columns: ['color_index'], where: 'table_name = ?', whereArgs: [currentHostTables.first]);
        finalColor = colorRows.isNotEmpty ? colorRows.first['color_index'] as int? : null;
      }

      for (final targetId in targetGroupIds) {
        // 2. Get target tables
        final targetRows = await txn.query('pending_order_groups', columns: ['table_names'], where: 'id = ?', whereArgs: [targetId]);
        List<String> targetTables = targetRows.isNotEmpty ? List<String>.from(jsonDecode(targetRows.first['table_names'] as String? ?? '[]')) : [];
        String targetPrimaryTable = targetTables.isNotEmpty ? targetTables.first : 'Unknown';

        newHostTables.addAll(targetTables);

        // 3. Update target items
        // Set original_table_name for those that are NULL
        await txn.update(
          'pending_order_items',
          {'original_table_name': targetPrimaryTable},
          where: 'order_group_id = ? AND original_table_name IS NULL',
          whereArgs: [targetId],
        );
        // Move to host
        await txn.update(
          'pending_order_items',
          {'order_group_id': hostGroupId, 'updated_at': updatedAt},
          where: 'order_group_id = ?',
          whereArgs: [targetId],
        );

        // 4. Set target status to merged
        await txn.update(
          'pending_order_groups',
          {
            'status': 'merged',
            'note': '已併入主單',
            'merged_target_id': hostGroupId,
            'updated_at': updatedAt,
          },
          where: 'id = ?',
          whereArgs: [targetId],
        );

        // 5. Update cached_tables for target tables (same group + same color)
        for (final table in targetTables) {
          await txn.update(
            'cached_tables',
            {
              'current_order_group_id': hostGroupId,
              if (finalColor != null) 'color_index': finalColor,
            },
            where: 'table_name = ?',
            whereArgs: [table],
          );
        }
      }

      // 6. Final Update Main Host Group (tables + color)
      await txn.update(
        'pending_order_groups',
        {
          'table_names': jsonEncode(newHostTables.toList()),
          if (finalColor != null) 'color_index': finalColor,
          'updated_at': updatedAt,
        },
        where: 'id = ?',
        whereArgs: [hostGroupId],
      );

      // 7. Also update host's cached_tables entry color
      if (finalColor != null) {
        for (final table in currentHostTables) {
          await txn.update(
            'cached_tables',
            {'color_index': finalColor},
            where: 'table_name = ?',
            whereArgs: [table],
          );
        }
      }
    });

    _printTaskUpdateController.add(null);
  }

  Future<void> unmergeOrderGroupsLocal({
    required String hostGroupId,
    required List<String> targetGroupIds,
    Map<String, String>? tableOverrides, // childGroupId → new table name (when original is occupied)
  }) async {
    final db = await database;
    final String updatedAt = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
       // 1. Get host's current tables
      final hostRows = await txn.query('pending_order_groups', columns: ['table_names'], where: 'id = ?', whereArgs: [hostGroupId]);
      List<String> currentHostTables = hostRows.isNotEmpty ? List<String>.from(jsonDecode(hostRows.first['table_names'] as String? ?? '[]')) : [];
      final Set<String> newHostTables = currentHostTables.toSet();

      for (final childId in targetGroupIds) {
        // 2. Restore child status
        await txn.update(
          'pending_order_groups',
          {
            'status': 'dining',
            'note': null,
            'merged_target_id': null,
            'updated_at': updatedAt,
          },
          where: 'id = ?',
          whereArgs: [childId],
        );

        // 3. Get child tables + original color
        final childRows = await txn.query('pending_order_groups', columns: ['table_names', 'color_index'], where: 'id = ?', whereArgs: [childId]);
        final List<String> childTables = childRows.isNotEmpty ? List<String>.from(jsonDecode(childRows.first['table_names'] as String? ?? '[]')) : [];
        final int? childOriginalColor = childRows.isNotEmpty ? childRows.first['color_index'] as int? : null;
        newHostTables.removeAll(childTables);

        // If a table override is provided, assign child to the new table
        final overrideTable = tableOverrides?[childId];
        final List<String> effectiveTables = overrideTable != null ? [overrideTable] : childTables;
        if (overrideTable != null) {
          await txn.update(
            'pending_order_groups',
            {'table_names': jsonEncode(effectiveTables), 'updated_at': updatedAt},
            where: 'id = ?',
            whereArgs: [childId],
          );
        }

        // 4. Return items (always based on original table names)
        if (childTables.isNotEmpty) {
          await txn.update(
            'pending_order_items',
            {'order_group_id': childId, 'updated_at': updatedAt},
            where: 'order_group_id = ? AND original_table_name IN (${childTables.map((_) => '?').join(',')})',
            whereArgs: [hostGroupId, ...childTables],
          );
        }

        // 5. Update cached_tables — use effective (possibly overridden) tables
        // Use upsert: the override table may never have been occupied before
        // and might not have a row in cached_tables yet.
        for (final table in effectiveTables) {
          final count = await txn.update(
            'cached_tables',
            {
              'current_order_group_id': childId,
              'status': 'occupied',
              if (childOriginalColor != null) 'color_index': childOriginalColor,
              'updated_at': updatedAt,
            },
            where: 'table_name = ?',
            whereArgs: [table],
          );
          if (count == 0) {
            await txn.insert('cached_tables', {
              'table_name': table,
              'status': 'occupied',
              'current_order_group_id': childId,
              if (childOriginalColor != null) 'color_index': childOriginalColor,
              'updated_at': updatedAt,
            });
          }
        }
      }

       // 6. Update Host
      await txn.update(
        'pending_order_groups',
        {
          'table_names': jsonEncode(newHostTables.toList()),
          'updated_at': updatedAt,
        },
        where: 'id = ?',
        whereArgs: [hostGroupId],
      );
    });

    _printTaskUpdateController.add(null);
  }

  /// 測試用：清空所有訂單資料及桌位快取
  Future<void> clearAllOrderData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('pending_order_items');
      await txn.delete('pending_order_groups');
      await txn.update('cached_tables', {
        'status': 'empty',
        'current_order_group_id': null,
        'pax_adult': 0,
        'color_index': null,
      });
    });
    _printTaskUpdateController.add(null);
  }

  Future<List<String>> getMergedChildGroupIds(String hostGroupId) async {
    final db = await database;
    final rows = await db.query(
      'pending_order_groups',
      columns: ['id'],
      where: 'merged_target_id = ? AND status = ?',
      whereArgs: [hostGroupId, 'merged'],
    );
    return rows.map((r) => r['id'] as String).toList();
  }

  /// Returns a map of childGroupId → list of table names for all merged children.
  Future<Map<String, List<String>>> getMergedChildGroups(String hostGroupId) async {
    final db = await database;
    final rows = await db.query(
      'pending_order_groups',
      columns: ['id', 'table_names'],
      where: 'merged_target_id = ? AND status = ?',
      whereArgs: [hostGroupId, 'merged'],
    );
    return {
      for (final r in rows)
        r['id'] as String:
            List<String>.from(jsonDecode(r['table_names'] as String? ?? '[]')),
    };
  }

  Future<void> splitOrderGroupLocal({
    required String sourceGroupId,
    required Map<String, int> itemQuantitiesToMove,
    required List<String> targetTables,
    String? targetGroupId,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      // 1. Determine target group ID
      String finalTargetId;
      if (targetGroupId != null && targetGroupId.isNotEmpty) {
        finalTargetId = targetGroupId;
      } else {
        // Create a new group if target not provided
        finalTargetId = const Uuid().v4();
        final sourceGroup = await txn.query(
          'pending_order_groups',
          where: 'id = ?',
          whereArgs: [sourceGroupId],
        );
        if (sourceGroup.isEmpty) throw Exception('Source group not found');

        final newGroup = Map<String, dynamic>.from(sourceGroup.first);
        newGroup['id'] = finalTargetId;
        newGroup['table_names'] = jsonEncode(targetTables);
        newGroup['is_synced'] = 0;
        newGroup['created_at'] = DateTime.now().toUtc().toIso8601String();

        await txn.insert('pending_order_groups', newGroup);
      }

      // 2. Move items (supports partial qty splits)
      for (final entry in itemQuantitiesToMove.entries) {
        final rawId = entry.key;
        final qtyToMove = entry.value;

        final rows = await txn.query(
          'pending_order_items',
          where: 'id = ?',
          whereArgs: [rawId],
        );
        if (rows.isEmpty) continue;
        final existingQty = (rows.first['quantity'] as num).toInt();

        if (qtyToMove >= existingQty) {
          // Move whole row
          await txn.update(
            'pending_order_items',
            {'order_group_id': finalTargetId, 'is_synced': 0},
            where: 'id = ?',
            whereArgs: [rawId],
          );
        } else {
          // Partial split: reduce original qty, insert new row with moved qty
          await txn.update(
            'pending_order_items',
            {'quantity': existingQty - qtyToMove, 'is_synced': 0},
            where: 'id = ?',
            whereArgs: [rawId],
          );
          final newRow = Map<String, dynamic>.from(rows.first);
          newRow['id'] = const Uuid().v4();
          newRow['quantity'] = qtyToMove;
          newRow['order_group_id'] = finalTargetId;
          newRow['is_synced'] = 0;
          await txn.insert('pending_order_items', newRow);
        }
      }

      // 3. Update cached_tables for target tables
      for (final tableName in targetTables) {
        await txn.update(
          'cached_tables',
          {
            'status': 'occupied',
            'current_order_group_id': finalTargetId,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'table_name = ?',
          whereArgs: [tableName],
        );
      }
    });

    _printTaskUpdateController.add(null);
  }

  /// 按人數均分：在 SQLite 建立 N-1 個新訂單並加入「分攤餐費」品項，對源訂單加入扣除品項。
  Future<void> splitByPaxLocal({
    required String sourceGroupId,
    required int pax,
    required double totalAmount,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final sourceRows = await txn.query(
        'pending_order_groups',
        where: 'id = ?',
        whereArgs: [sourceGroupId],
      );
      if (sourceRows.isEmpty) throw Exception('Source group not found');
      final sourceGroup = sourceRows.first;
      final tableNames = List<String>.from(
          jsonDecode(sourceGroup['table_names'] as String? ?? '[]'));
      final double perPerson = totalAmount / pax;
      final now = DateTime.now().toUtc().toIso8601String();

      // 建立 N-1 張新訂單
      for (int i = 2; i <= pax; i++) {
        final newGroupId = const Uuid().v4();
        await txn.insert('pending_order_groups', {
          'id': newGroupId,
          'shop_id': sourceGroup['shop_id'],
          'table_names': jsonEncode(tableNames),
          'pax_adult': 1,
          'staff_name': sourceGroup['staff_name'],
          'tax_snapshot': sourceGroup['tax_snapshot'],
          'color_index': (DateTime.now().millisecondsSinceEpoch + i) % 20,
          'status': 'dining',
          'note': '均分 ($i/$pax)',
          'open_id': sourceGroup['open_id'],
          'created_at': now,
          'updated_at': now,
          'is_synced': 0,
        });
        await txn.insert('pending_order_items', {
          'id': const Uuid().v4(),
          'order_group_id': newGroupId,
          'item_name': '分攤餐費 (Split Share)',
          'price': perPerson,
          'quantity': 1,
          'status': 'served',
          'print_status': 'pending',
          'created_at': now,
          'updated_at': now,
          'is_synced': 0,
        });
      }

      // 源訂單加入扣除品項
      final double deduction = -(totalAmount - perPerson);
      await txn.insert('pending_order_items', {
        'id': const Uuid().v4(),
        'order_group_id': sourceGroupId,
        'item_name': '拆單扣除 (Split Deduction)',
        'price': deduction,
        'quantity': 1,
        'status': 'served',
        'print_status': 'pending',
        'created_at': now,
        'updated_at': now,
        'is_synced': 0,
      });

      // 更新源訂單備注
      final oldNote = (sourceGroup['note'] as String? ?? '');
      final newNote =
          oldNote.isEmpty ? '均分 (1/$pax)' : '$oldNote | 均分 (1/$pax)';
      await txn.update(
        'pending_order_groups',
        {'note': newNote, 'updated_at': now, 'is_synced': 0},
        where: 'id = ?',
        whereArgs: [sourceGroupId],
      );
    });
    _printTaskUpdateController.add(null);
  }

  /// 還原拆單：把 sourceGroupId（子單）的品項移回 targetGroupId（主單），刪除子單。
  /// 語義與 Supabase revertSplit 一致：source = 子單（被刪除），target = 主單（接收品項）。
  Future<void> revertSplitLocal({
    required String sourceGroupId, // 子單，品項從這裡搬走，最後被刪除
    required String targetGroupId, // 主單，品項移往這裡，保留
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      // 1. 取得子單（source）的 table_names
      final sourceRows = await txn.query(
        'pending_order_groups',
        columns: ['table_names'],
        where: 'id = ?',
        whereArgs: [sourceGroupId],
      );
      final sourceTables = sourceRows.isNotEmpty
          ? List<String>.from(
              jsonDecode(sourceRows.first['table_names'] as String? ?? '[]'))
          : <String>[];

      // 2. 取得主單（target）的 table_names，用於判斷哪些桌位要清空
      final targetRows = await txn.query(
        'pending_order_groups',
        columns: ['table_names'],
        where: 'id = ?',
        whereArgs: [targetGroupId],
      );
      final targetTables = targetRows.isNotEmpty
          ? List<String>.from(
              jsonDecode(targetRows.first['table_names'] as String? ?? '[]'))
          : <String>[];

      // 3. 把子單的非 cancelled 品項移回主單
      await txn.update(
        'pending_order_items',
        {
          'order_group_id': targetGroupId,
          'is_synced': 0,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: "order_group_id = ? AND status != ?",
        whereArgs: [sourceGroupId, 'cancelled'],
      );

      // 4. 刪除子單剩餘（cancelled）品項
      await txn.delete(
        'pending_order_items',
        where: 'order_group_id = ?',
        whereArgs: [sourceGroupId],
      );

      // 5. 刪除子單
      await txn.delete(
        'pending_order_groups',
        where: 'id = ?',
        whereArgs: [sourceGroupId],
      );

      // 6. 清空子單獨有（不與主單共用）的桌位快照
      final uniqueSourceTables =
          sourceTables.where((t) => !targetTables.contains(t)).toList();
      for (final table in uniqueSourceTables) {
        await txn.update(
          'cached_tables',
          {'status': 'empty', 'current_order_group_id': null, 'pax_adult': 0},
          where: 'table_name = ?',
          whereArgs: [table],
        );
      }
    });
    _printTaskUpdateController.add(null);
  }
}

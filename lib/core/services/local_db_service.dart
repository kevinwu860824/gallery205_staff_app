import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'dart:async';

class LocalDbService {
  static Database? _database;
  
  // Singleton pattern
  static final LocalDbService _instance = LocalDbService._internal();
  factory LocalDbService() => _instance;
  LocalDbService._internal();

  // Stream for notify changes
  final _printTaskUpdateController = StreamController<void>.broadcast();
  Stream<void> get onPrintTaskUpdate => _printTaskUpdateController.stream;

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
      version: 1,
      onCreate: _createDB,
    );
  }

  // 建立本地表結構
  Future<void> _createDB(Database db, int version) async {
    // 1. 本地訂單暫存表 (斷網時使用)
    await db.execute('''
      CREATE TABLE local_orders (
        id TEXT PRIMARY KEY,
        shop_id TEXT,
        table_names TEXT,
        people_count INTEGER,
        items_json TEXT,       -- 儲存 OrderItem 列表的 JSON
        status TEXT,
        created_at TEXT,
        is_synced INTEGER DEFAULT 0 -- 0: 未同步, 1: 已同步到 Supabase
      )
    ''');

    // 2. 本地列印任務隊列 (處理失敗補印的核心)
    await db.execute('''
      CREATE TABLE local_print_tasks (
        id TEXT PRIMARY KEY,
        order_group_id TEXT,
        content_json TEXT,    -- 儲存要印的文字/品項內容
        printer_ip TEXT,
        status TEXT,          -- pending, success, failed
        error_message TEXT,
        created_at TEXT
      )
    ''');
  }

  // --- 列印任務相關操作 ---

  // 新增列印任務
  Future<void> insertPrintTask(Map<String, dynamic> task) async {
    final db = await database;
    await db.insert('local_print_tasks', task, conflictAlgorithm: ConflictAlgorithm.replace);
    _printTaskUpdateController.add(null);
  }

  // 更新列印任務狀態 (例如改為 failed 或 success)
  Future<void> updatePrintTaskStatus(String id, String status, {String? error}) async {
    final db = await database;
    await db.update(
      'local_print_tasks',
      {
        'status': status,
        'error_message': error,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _printTaskUpdateController.add(null);
  }

  // 取得所有失敗的列印任務 (用於你說的「點擊驚嘆號」顯示補印清單)
  Future<List<Map<String, dynamic>>> getFailedPrintTasks() async {
    final db = await database;
    return await db.query(
      'local_print_tasks',
      where: 'status = ?',
      whereArgs: ['failed'],
      orderBy: 'created_at DESC',
    );
  }

  // 清除已成功的任務 (選用)
  Future<void> clearSuccessfulTasks() async {
    final db = await database;
    await db.delete('local_print_tasks', where: 'status = ?', whereArgs: ['success']);
  }

  // --- 離線訂單相關操作 ---

  Future<void> insertOfflineOrder(Map<String, dynamic> order) async {
    final db = await database;
    await db.insert('local_orders', order, conflictAlgorithm: ConflictAlgorithm.replace);
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
}
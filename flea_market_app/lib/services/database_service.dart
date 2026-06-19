import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'flea_market.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        category TEXT NOT NULL,
        condition TEXT NOT NULL,
        purchasePrice INTEGER DEFAULT 0,
        imagePaths TEXT,
        mercariPrice INTEGER,
        mercariUrl TEXT,
        mercariListedAt INTEGER,
        mercariSold INTEGER DEFAULT 0,
        rakumaPrice INTEGER,
        rakumaUrl TEXT,
        rakumaListedAt INTEGER,
        rakumaSold INTEGER DEFAULT 0,
        status TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        memo TEXT,
        tags TEXT
      )
    ''');
  }

  Future<String> insertProduct(Product product) async {
    final db = await database;
    await db.insert(
      'products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return product.id;
  }

  Future<void> updateProduct(Product product) async {
    final db = await database;
    await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<void> deleteProduct(String id) async {
    final db = await database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final maps = await db.query('products', orderBy: 'updatedAt DESC');
    return maps.map(Product.fromMap).toList();
  }

  Future<List<Product>> getProductsByStatus(ListingStatus status) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'status = ?',
      whereArgs: [status.name],
      orderBy: 'updatedAt DESC',
    );
    return maps.map(Product.fromMap).toList();
  }

  Future<Product?> getProduct(String id) async {
    final db = await database;
    final maps =
        await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<Map<String, dynamic>> getStats() async {
    final db = await database;
    final total = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM products'));
    final listed = Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(*) FROM products WHERE status = 'listed'"));
    final sold = Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(*) FROM products WHERE status = 'sold'"));
    final totalPurchase = Sqflite.firstIntValue(await db.rawQuery(
        "SELECT SUM(purchasePrice) FROM products"));
    final soldRevenue = Sqflite.firstIntValue(await db.rawQuery(
        "SELECT SUM(CASE WHEN mercariSold=1 THEN mercariPrice WHEN rakumaSold=1 THEN rakumaPrice ELSE 0 END) FROM products WHERE status='sold'"));

    return {
      'total': total ?? 0,
      'listed': listed ?? 0,
      'sold': sold ?? 0,
      'totalPurchase': totalPurchase ?? 0,
      'soldRevenue': soldRevenue ?? 0,
    };
  }
}

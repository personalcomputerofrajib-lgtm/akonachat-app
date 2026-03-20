import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import 'security_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), 'akonachat_secure.db');
    final String? dbKey = await SecurityService().getDatabaseKey();
    
    if (dbKey == null) throw Exception('Database encryption key not initialized');

    return await openDatabase(
      path,
      password: dbKey, // SQLCipher encryption triggered here
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages(
            id TEXT PRIMARY KEY,
            chatId TEXT,
            senderId TEXT,
            ciphertext TEXT,
            mediaUrl TEXT,
            type TEXT,
            clientMsgId TEXT,
            createdAt TEXT,
            status TEXT,
            sequence INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE chats(
            id TEXT PRIMARY KEY,
            name TEXT,
            lastMessage TEXT,
            unreadCount INTEGER,
            updatedAt TEXT
          )
        ''');
      },
    );
  }

  // Helper methods to save/retrieve messages
  Future<void> saveMessage(Map<String, dynamic> msg) async {
    final db = await database;
    await db.insert('messages', {
      'id': msg['_id'] ?? msg['clientMsgId'],
      'chatId': msg['chatId'],
      'senderId': msg['senderId'] is Map ? msg['senderId']['_id'] : msg['senderId'].toString(),
      'ciphertext': msg['ciphertext'],
      'mediaUrl': msg['mediaUrl'],
      'type': msg['type'] ?? 'text',
      'clientMsgId': msg['clientMsgId'],
      'createdAt': msg['createdAt'],
      'status': msg['status'],
      'sequence': msg['sequence'] ?? 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getMessages(String chatId) async {
    final db = await database;
    return await db.query('messages', where: 'chatId = ?', whereArgs: [chatId], orderBy: 'sequence DESC');
  }
}

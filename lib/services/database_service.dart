import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'dart:async'; // Import for Completer
import 'security_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  static Completer<Database>? _dbCompleter;
  
  factory DatabaseService() => _instance;
  DatabaseService._internal();
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    
    // Use a completer to prevent multiple initialization calls
    if (_dbCompleter != null) return _dbCompleter!.future;
    
    _dbCompleter = Completer<Database>();
    try {
      _database = await _initDatabase();
      _dbCompleter!.complete(_database);
      return _database!;
    } catch (e) {
      _dbCompleter!.completeError(e);
      _dbCompleter = null; // Allow retry on error
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), 'akonachat_secure.db');
    final String? dbKey = await SecurityService().getDatabaseKey();
    
    if (dbKey == null) throw Exception('Database encryption key not initialized');

    return await openDatabase(
      path,
      password: dbKey,
      version: 2, // Upgraded version to add missing fields
      onCreate: (db, version) async {
        await _createTablesV2(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Simplest upgrade: drop and recreate if needed, or add columns
          // Here we'll drop to ensure schema matches the new V2 exactly
          await db.execute('DROP TABLE IF EXISTS messages');
          await db.execute('DROP TABLE IF EXISTS chats');
          await _createTablesV2(db);
        }
      },
    );
  }

  Future<void> _createTablesV2(Database db) async {
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
        sequence INTEGER,
        localMediaOrdinal TEXT,
        isEdited INTEGER,
        isDeletedEveryone INTEGER,
        reactions TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE chats(
        id TEXT PRIMARY KEY,
        name TEXT,
        participants TEXT,
        lastMessageAt TEXT,
        lastMessageText TEXT,
        unreadCount INTEGER,
        lastSequence INTEGER,
        updatedAt TEXT
      )
    ''');
  }

  // --- Message Methods ---

  Future<void> saveMessage(Map<String, dynamic> msg, {String? localMediaPath}) async {
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
      'localMediaOrdinal': localMediaPath, // Save local path for offline access
      'isEdited': (msg['isEdited'] == true) ? 1 : 0,
      'isDeletedEveryone': (msg['isDeletedEveryone'] == true) ? 1 : 0,
      'reactions': msg['reactions'] != null ? jsonEncode(msg['reactions']) : null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getMessages(String chatId) async {
    final db = await database;
    final results = await db.query('messages', where: 'chatId = ?', whereArgs: [chatId], orderBy: 'createdAt DESC');
    
    // Convert status/boolean/json back for UI consumption
    return results.map((m) {
      final msg = Map<String, dynamic>.from(m);
      if (msg['reactions'] != null) {
        msg['reactions'] = jsonDecode(msg['reactions']);
      }
      msg['isEdited'] = msg['isEdited'] == 1;
      msg['isDeletedEveryone'] = msg['isDeletedEveryone'] == 1;
      if (msg['localMediaOrdinal'] != null) {
        // Map back to mediaUrl if offline and we have a local path
        // OR provide it as a separate field the UI checks
      }
      return msg;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getPendingMessages() async {
    final db = await database;
    return await db.query('messages', where: 'status = ?', whereArgs: ['pending']);
  }

  Future<void> updateMessageStatus(String? clientMsgId, String status) async {
    if (clientMsgId == null) return;
    final db = await database;
    await db.update('messages', {'status': status}, where: 'clientMsgId = ?', whereArgs: [clientMsgId]);
  }

  // --- Chat Methods ---

  Future<void> saveChat(Map<String, dynamic> chat) async {
    final db = await database;
    await db.insert('chats', {
      'id': chat['_id'],
      'name': chat['name'],
      'participants': jsonEncode(chat['participants']),
      'lastMessageAt': chat['lastMessageAt'],
      'lastMessageText': chat['lastMessage'] != null ? chat['lastMessage']['ciphertext'] : null,
      'unreadCount': 0, // Calculated in UI but can be cached here
      'lastSequence': chat['lastSequence'] ?? 0,
      'updatedAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getChats() async {
    final db = await database;
    final results = await db.query('chats', orderBy: 'lastMessageAt DESC');
    
    return results.map((c) {
      final chat = Map<String, dynamic>.from(c);
      if (chat['participants'] != null) {
        chat['participants'] = jsonDecode(chat['participants']);
      }
      // Reconstruct lastMessage object if text exists
      if (chat['lastMessageText'] != null) {
        chat['lastMessage'] = {
          'ciphertext': chat['lastMessageText'],
        };
      }
      return chat;
    }).toList();
  }

  Future<void> updateChatUnread(String chatId, int unreadCount) async {
    final db = await database;
    await db.update('chats', {'unreadCount': unreadCount}, where: 'id = ?', whereArgs: [chatId]);
  }
}

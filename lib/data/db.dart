import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

/// 本地 SQLite。表结构沿用云端那套列名，方便以后接同步时两端对齐。
class AppDatabase {
  static const _name = 'fitness_desk.db';
  static const _version = 1;

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _name);
    _db = await openDatabase(
      path,
      version: _version,
      onCreate: _create,
      onUpgrade: (db, oldV, newV) async {
        // 目前只有 v1；后续加列时在这里按版本迁移，不要删库重建。
      },
    );
    return _db!;
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        weeks INTEGER NOT NULL DEFAULT 4,
        start_date TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        plan_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE workout_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER,
        day_id TEXT,
        day_title TEXT,
        version TEXT NOT NULL DEFAULT 'full',
        status TEXT NOT NULL DEFAULT 'in_progress',
        performed_on TEXT NOT NULL,
        duration_min INTEGER,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE set_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        exercise_key TEXT,
        exercise_name TEXT NOT NULL,
        set_index INTEGER NOT NULL,
        weight REAL,
        reps INTEGER,
        rpe REAL,
        is_warmup INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE body_metrics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recorded_on TEXT NOT NULL,
        weight_kg REAL,
        body_fat_pct REAL,
        chest_cm REAL,
        waist_cm REAL,
        hip_cm REAL,
        arm_cm REAL,
        thigh_cm REAL,
        note TEXT,
        created_at TEXT NOT NULL,
        UNIQUE(recorded_on)
      )
    ''');
    await db.execute('''
      CREATE TABLE nutrition_targets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        day_type TEXT NOT NULL,
        kcal INTEGER,
        protein_g INTEGER,
        carb_g INTEGER,
        fat_g INTEGER,
        created_at TEXT NOT NULL,
        UNIQUE(day_type)
      )
    ''');
    await db.execute('''
      CREATE TABLE meals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eaten_on TEXT NOT NULL,
        slot TEXT NOT NULL,
        name TEXT,
        kcal INTEGER NOT NULL DEFAULT 0,
        protein_g INTEGER NOT NULL DEFAULT 0,
        carb_g INTEGER NOT NULL DEFAULT 0,
        fat_g INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE weekly_reviews (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        week_start TEXT NOT NULL,
        completion_pct REAL,
        avg_rpe REAL,
        sleep_quality INTEGER,
        soreness INTEGER,
        note TEXT,
        created_at TEXT NOT NULL,
        UNIQUE(week_start)
      )
    ''');
    // 同步用的脏标记表：本地写入时记一笔，将来接远端只需要读这张表
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        op TEXT NOT NULL,
        queued_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_set_logs_session ON set_logs(session_id)');
    await db.execute('CREATE INDEX idx_set_logs_key ON set_logs(exercise_key)');
    await db.execute('CREATE INDEX idx_sessions_date ON workout_sessions(performed_on)');
  }
}

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/report.dart';

/// Capa de persistencia offline (SQLite via sqflite).
///
/// Tabla `reports`:
///  - id            INTEGER PK AUTOINCREMENT
///  - no_reporte    TEXT   (metadato para listar/buscar)
///  - fecha         TEXT   (dia/mes/anio concatenado, para mostrar en la lista)
///  - cliente       TEXT   (metadato para listar)
///  - updated_at    TEXT   (ISO8601, orden de la lista)
///  - data          TEXT   (blob JSON con el Report completo)
///
/// El blob JSON es la fuente de verdad; las columnas de metadatos son copias
/// desnormalizadas para la pantalla de lista sin tener que parsear cada blob.
class ReportDatabase {
  ReportDatabase._();
  static final ReportDatabase instance = ReportDatabase._();

  static const _dbName = 'reportes_jh.db';
  static const _dbVersion = 2;
  static const _table = 'reports';
  static const _counters = 'counters';

  /// Prefijo del consecutivo automatico. Formato final: MTNE-0001.
  static const String consecutivoPrefix = 'MTNE-';

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            no_reporte TEXT NOT NULL DEFAULT '',
            fecha TEXT NOT NULL DEFAULT '',
            cliente TEXT NOT NULL DEFAULT '',
            updated_at TEXT NOT NULL DEFAULT '',
            data TEXT NOT NULL
          )
        ''');
        await _createCounters(db);
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await _createCounters(db);
        }
      },
    );
  }

  Future<void> _createCounters(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_counters (
        name TEXT PRIMARY KEY,
        value INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.insert(
      _counters,
      {'name': 'reporte', 'value': 0},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Genera y RESERVA el siguiente consecutivo (atomico). Formato MTNE-0001.
  /// Lo llama el editor solo al crear un reporte nuevo.
  Future<String> nextConsecutivo() async {
    final db = await database;
    return db.transaction<String>((txn) async {
      final rows = await txn.query(_counters,
          where: 'name = ?', whereArgs: ['reporte'], limit: 1);
      final current = rows.isEmpty ? 0 : (rows.first['value'] as int? ?? 0);
      final next = current + 1;
      await txn.update(_counters, {'value': next},
          where: 'name = ?', whereArgs: ['reporte']);
      return '$consecutivoPrefix${next.toString().padLeft(4, '0')}';
    });
  }

  /// Valores distintos ya usados en un campo del modelo, para autocompletar.
  /// `field` es la clave JSON (ej 'clienteNombre', 'marca', 'equipo').
  Future<List<String>> distinctValues(String field) async {
    final db = await database;
    final rows = await db.query(_table, columns: ['data']);
    final set = <String>{};
    for (final row in rows) {
      try {
        final r = Report.fromJsonString(row['data'] as String);
        final v = _fieldValue(r, field);
        if (v != null && v.trim().isNotEmpty) set.add(v.trim());
      } catch (_) {}
    }
    final list = set.toList()..sort();
    return list;
  }

  String? _fieldValue(Report r, String field) {
    switch (field) {
      case 'clienteNombre':
        return r.clienteNombre;
      case 'clienteCiudad':
        return r.clienteCiudad;
      case 'clienteSede':
        return r.clienteSede;
      case 'equipo':
        return r.equipo;
      case 'marca':
        return r.marca;
      case 'modelo':
        return r.modelo;
      default:
        return null;
    }
  }

  String _fecha(Report r) {
    final parts = [r.fechaDia, r.fechaMes, r.fechaAnio]
        .where((e) => e.trim().isNotEmpty)
        .toList();
    return parts.join('/');
  }

  Map<String, Object?> _metaRow(Report r) => {
        'no_reporte': r.noReporte,
        'fecha': _fecha(r),
        'cliente': r.clienteNombre,
        'updated_at': r.updatedAt.toIso8601String(),
        'data': r.toJsonString(),
      };

  /// Inserta un reporte nuevo y devuelve su id asignado.
  Future<int> insert(Report r) async {
    final db = await database;
    r.updatedAt = DateTime.now();
    final id = await db.insert(_table, _metaRow(r));
    r.id = id;
    return id;
  }

  /// Actualiza un reporte existente (debe traer id).
  Future<void> update(Report r) async {
    final db = await database;
    if (r.id == null) {
      throw ArgumentError('update requiere un Report con id');
    }
    r.updatedAt = DateTime.now();
    await db.update(
      _table,
      _metaRow(r),
      where: 'id = ?',
      whereArgs: [r.id],
    );
  }

  /// Inserta o actualiza segun tenga id.
  Future<int> save(Report r) async {
    if (r.id == null) {
      return insert(r);
    }
    await update(r);
    return r.id!;
  }

  /// Lista todos los reportes, mas recientes primero. Hidrata el modelo completo.
  Future<List<Report>> getAll() async {
    final db = await database;
    final rows = await db.query(_table, orderBy: 'updated_at DESC');
    return rows
        .map((row) => Report.fromJsonString(
              row['data'] as String,
              id: row['id'] as int,
            ))
        .toList();
  }

  /// Devuelve un reporte por id, o null.
  Future<Report?> getById(int id) async {
    final db = await database;
    final rows =
        await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return Report.fromJsonString(
      row['data'] as String,
      id: row['id'] as int,
    );
  }

  /// Elimina un reporte por id.
  Future<void> delete(int id) async {
    final db = await database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// Duplica un reporte (para usar uno previo como plantilla).
  Future<int> duplicate(int id) async {
    final original = await getById(id);
    if (original == null) {
      throw StateError('No existe el reporte $id');
    }
    original.id = null;
    original.createdAt = DateTime.now();
    original.updatedAt = DateTime.now();
    original.noReporte = await nextConsecutivo();
    return insert(original);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

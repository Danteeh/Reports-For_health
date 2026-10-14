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
  static const _dbVersion = 1;
  static const _table = 'reports';

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
      },
    );
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
    original.noReporte = '${original.noReporte} (copia)';
    return insert(original);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

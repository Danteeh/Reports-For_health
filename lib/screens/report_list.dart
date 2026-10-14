import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database.dart';
import '../models/report.dart';
import '../widgets/logo_widget.dart';
import 'report_editor.dart';

/// Pantalla principal: lista de reportes guardados localmente.
class ReportListScreen extends StatefulWidget {
  const ReportListScreen({super.key});

  @override
  State<ReportListScreen> createState() => _ReportListScreenState();
}

class _ReportListScreenState extends State<ReportListScreen> {
  final _db = ReportDatabase.instance;
  late Future<List<Report>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _db.getAll();
  }

  Future<void> _openEditor([Report? report]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReportEditorScreen(report: report),
      ),
    );
    if (changed == true && mounted) {
      setState(_reload);
    }
  }

  Future<void> _confirmDelete(Report r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar reporte'),
        content: Text(
            'Se eliminara el reporte "${r.noReporte.isEmpty ? '(sin numero)' : r.noReporte}". Esta accion no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true && r.id != null) {
      await _db.delete(r.id!);
      if (mounted) setState(_reload);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: const Row(
          children: [
            LogoWidget(width: 150),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: FutureBuilder<List<Report>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = items[i];
              final fecha = [r.fechaDia, r.fechaMes, r.fechaAnio]
                  .where((e) => e.trim().isNotEmpty)
                  .join('/');
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: kAccent,
                    child: Icon(Icons.description, color: Colors.black),
                  ),
                  title: Text(
                    r.noReporte.isEmpty ? '(sin numero)' : r.noReporte,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text([
                    if (r.clienteNombre.isNotEmpty) r.clienteNombre,
                    if (r.equipo.isNotEmpty) r.equipo,
                    if (fecha.isNotEmpty) 'Fecha: $fecha',
                    'Mod.: ${DateFormat('yyyy-MM-dd HH:mm').format(r.updatedAt)}',
                  ].join('  -  ')),
                  isThreeLine: true,
                  onTap: () => _openEditor(r),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'edit') {
                        _openEditor(r);
                      } else if (v == 'duplicate' && r.id != null) {
                        await _db.duplicate(r.id!);
                        if (mounted) setState(_reload);
                      } else if (v == 'delete') {
                        _confirmDelete(r);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(
                          value: 'duplicate', child: Text('Duplicar')),
                      PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: kAccent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo reporte'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('No hay reportes guardados',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text('Toca "Nuevo reporte" para crear el primero.',
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

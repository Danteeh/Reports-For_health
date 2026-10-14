import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/report.dart';
import '../pdf/report_pdf.dart';
import '../widgets/logo_widget.dart';

/// Vista previa del PDF generado + compartir por correo.
class PreviewScreen extends StatefulWidget {
  final Report report;

  const PreviewScreen({super.key, required this.report});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  Uint8List? _bytes;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    try {
      final bytes = await ReportPdf.build(widget.report);
      if (mounted) setState(() => _bytes = bytes);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  String get _fileName {
    final no = widget.report.noReporte.trim().isEmpty
        ? 'reporte'
        : widget.report.noReporte.trim().replaceAll(RegExp(r'[^\w\-]'), '_');
    return 'Reporte_$no.pdf';
  }

  Future<File> _writeTempFile(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, _fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _shareByEmail() async {
    final bytes = _bytes;
    if (bytes == null) return;
    final file = await _writeTempFile(bytes);
    final subject =
        'Reporte de mantenimiento ${widget.report.noReporte}'.trim();
    final body =
        'Adjunto el reporte de mantenimiento preventivo${widget.report.clienteNombre.isNotEmpty ? ' para ${widget.report.clienteNombre}' : ''}.';
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf', name: _fileName)],
      subject: subject,
      text: body,
    );
  }

  Future<void> _print() async {
    final bytes = _bytes;
    if (bytes == null) return;
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vista previa PDF'),
        backgroundColor: kAccent,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            tooltip: 'Imprimir / Guardar PDF',
            icon: const Icon(Icons.print),
            onPressed: _bytes == null ? null : _print,
          ),
          IconButton(
            tooltip: 'Enviar por correo',
            icon: const Icon(Icons.email),
            onPressed: _bytes == null ? null : _shareByEmail,
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error generando el PDF:\n$_error',
                    textAlign: TextAlign.center),
              ),
            )
          : _bytes == null
              ? const Center(child: CircularProgressIndicator())
              : PdfPreview(
                  build: (_) async => _bytes!,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  allowPrinting: true,
                  allowSharing: true,
                  pdfFileName: _fileName,
                ),
      floatingActionButton: _bytes == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _shareByEmail,
              backgroundColor: kAccent,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.email),
              label: const Text('Enviar por correo'),
            ),
    );
  }
}

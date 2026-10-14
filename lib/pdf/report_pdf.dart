import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/report.dart';

/// Generador del PDF de ALTA FIDELIDAD (2 paginas) que replica la plantilla
/// MTNE-RG-01 a tamano Carta (612x792 pt).
///
/// Decisiones de fidelidad:
///  - Banda de seccion: color EXACTO #FFC000, ancho completo, texto negro, bold.
///  - Bordes finos (0.5 pt) negros en todas las celdas/filas.
///  - Logo reconstruido VECTORIALMENTE (onda ECG + dos lineas de texto), nunca
///    el PNG de baja resolucion.
///  - El checklist se dibuja recorriendo [kChecklistSections], no hardcode.
class ReportPdf {
  // Paleta
  static final PdfColor accent = PdfColor.fromHex('#FFC000');
  static final PdfColor black = PdfColors.black;
  static final PdfColor white = PdfColors.white;
  static final PdfColor red = PdfColor.fromHex('#C00000');

  // Geometria (margenes de la plantilla: ~19.6 pt izq, borde der ~585.4).
  static const double pageMargin = 18.0;
  static const double borderW = 0.5;

  static pw.BorderSide get _side =>
      pw.BorderSide(color: black, width: borderW);
  static pw.Border get _box => pw.Border.all(color: black, width: borderW);

  /// Construye el documento. [repFirma] es el PNG (bytes) de la firma del
  /// representante si existe; puede ser null.
  static Future<Uint8List> build(Report r) async {
    final doc = pw.Document();

    final repFirma = await _loadRepresentanteSignature();
    final clientFirma = _decodeBase64Png(r.firmaClienteBase64);

    final baseFont = await _tryLoadFont();
    final theme = baseFont == null
        ? null
        : pw.ThemeData.withFont(base: baseFont.$1, bold: baseFont.$2);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        theme: theme,
        margin: const pw.EdgeInsets.all(pageMargin),
        build: (context) => _page1(r),
      ),
    );
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        theme: theme,
        margin: const pw.EdgeInsets.all(pageMargin),
        build: (context) => _page2(r, repFirma, clientFirma),
      ),
    );

    return doc.save();
  }

  // ------------------------------------------------------------------ PAGE 1

  static pw.Widget _page1(Report r) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _headerBlock(),
        _procesoRow(),
        pw.SizedBox(height: 6),
        _reporteRow(r),
        pw.SizedBox(height: 6),
        _band('INFORMACION DEL CLIENTE'),
        _clienteBlock(r),
        pw.SizedBox(height: 4),
        _band('INFORMACION DEL EQUIPO'),
        _equipoBlock(r),
        pw.SizedBox(height: 4),
        _band('INFORMACION DEL CASO'),
        _casoBlock(r),
        pw.SizedBox(height: 4),
        // Secciones de checklist (bandas + filas)
        ..._checklistSections(r),
      ],
    );
  }

  /// Encabezado de 3 columnas: logo vectorial | titulo | mini-tabla.
  static pw.Widget _headerBlock() {
    return pw.Container(
      decoration: pw.BoxDecoration(border: _box),
      child: pw.IntrinsicHeight(
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // col 1: logo
            pw.Container(
              width: 160,
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                border: pw.Border(right: _side),
              ),
              child: pw.Center(child: _vectorLogo()),
            ),
            // col 2: titulo
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                decoration: pw.BoxDecoration(border: pw.Border(right: _side)),
                child: pw.Center(
                  child: pw.Text(
                    EmpresaConfig.titulo,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
            // col 3: mini tabla Codigo/Version/Pagina
            pw.Container(
              width: 190,
              child: pw.Column(
                children: [
                  _miniRow('Codigo', EmpresaConfig.codigo),
                  pw.Divider(height: borderW, thickness: borderW, color: black),
                  _miniRow('Version', EmpresaConfig.version),
                  pw.Divider(height: borderW, thickness: borderW, color: black),
                  _miniRow('Pagina', EmpresaConfig.pagina),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _miniRow(String label, String value) {
    return pw.Expanded(
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: pw.BoxDecoration(border: pw.Border(right: _side)),
              child: pw.Text(label,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
            ),
          ),
          pw.Expanded(
            child: pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: pw.Text(value,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _procesoRow() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: _side,
          right: _side,
          bottom: _side,
        ),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
                text: 'Proceso: ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
            pw.TextSpan(
                text: EmpresaConfig.proceso,
                style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      ),
    );
  }

  /// Fila No REPORTE + Fecha [dia][mes][anio] + Hora.
  static pw.Widget _reporteRow(Report r) {
    pw.Widget cell(String v, {double w = 34}) => pw.Container(
          width: w,
          height: 20,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(border: _box),
          child: pw.Text(v,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('No REPORTE:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        pw.SizedBox(width: 6),
        pw.Container(
          width: 130,
          height: 24,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(border: _box),
          child: pw.Text(r.noReporte,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        ),
        pw.Spacer(),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                pw.SizedBox(
                  width: 92,
                  child: pw.Text('Fecha de reporte :',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ),
                cell(r.fechaDia),
                pw.SizedBox(width: 2),
                cell(r.fechaMes),
                pw.SizedBox(width: 2),
                cell(r.fechaAnio, w: 44),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              children: [
                pw.SizedBox(
                  width: 92,
                  child: pw.Text('Hora de Reporte :',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ),
                pw.Container(
                  width: 118,
                  height: 20,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(border: _box),
                  child: pw.Text(r.hora.isEmpty ? ':' : r.hora,
                      style: const pw.TextStyle(fontSize: 9)),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// Banda amarilla de seccion a ancho completo.
  static pw.Widget _band(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      decoration: pw.BoxDecoration(color: accent, border: _box),
      alignment: pw.Alignment.center,
      child: pw.Text(
        title,
        style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold, fontSize: 10, color: black),
      ),
    );
  }

  /// Celda etiqueta + celda valor enmarcada (patron del cuerpo de datos).
  static pw.Widget _labeledField(
    String label,
    String value, {
    double labelW = 95,
    double? valueW,
  }) {
    final valueBox = pw.Container(
      height: 20,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(border: _box),
      padding: const pw.EdgeInsets.symmetric(horizontal: 4),
      child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
    );
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.SizedBox(
          width: labelW,
          child: pw.Text(label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        ),
        if (valueW != null)
          pw.SizedBox(width: valueW, child: valueBox)
        else
          pw.Expanded(child: valueBox),
      ],
    );
  }

  static pw.Widget _clienteBlock(Report r) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: pw.Column(
        children: [
          pw.Row(children: [
            pw.Expanded(
                child: _labeledField('Nombre del Cliente:', r.clienteNombre)),
            pw.SizedBox(width: 10),
            pw.Expanded(child: _labeledField('Ciudad:', r.clienteCiudad)),
          ]),
          pw.SizedBox(height: 6),
          pw.Row(children: [
            pw.Expanded(child: _labeledField('SEDE:', r.clienteSede)),
            pw.SizedBox(width: 10),
            pw.Expanded(child: _labeledField('Telefono:', r.clienteTelefono)),
          ]),
        ],
      ),
    );
  }

  static pw.Widget _equipoBlock(Report r) {
    pw.Widget checkbox(String label, bool checked) => pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(label,
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
            pw.SizedBox(width: 3),
            _checkbox(checked),
            pw.SizedBox(width: 8),
          ],
        );

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: pw.Column(
        children: [
          pw.Row(children: [
            pw.Expanded(child: _labeledField('EQUIPO:', r.equipo)),
            pw.SizedBox(width: 10),
            pw.Expanded(child: _labeledField('Marca:', r.marca)),
          ]),
          pw.SizedBox(height: 6),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              _labeledField('MODELO:', r.modelo, labelW: 55, valueW: 110),
              pw.SizedBox(width: 10),
              checkbox('Serie', r.idEquipo == IdEquipo.serie),
              checkbox('Lote', r.idEquipo == IdEquipo.lote),
              checkbox('Cod. Interno', r.idEquipo == IdEquipo.codInterno),
              pw.SizedBox(width: 6),
              pw.Text('No.:',
                  style:
                      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.SizedBox(width: 4),
              pw.Expanded(
                child: pw.Container(
                  height: 20,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(border: _box),
                  child: pw.Text(r.equipoNo,
                      style: const pw.TextStyle(fontSize: 9)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _casoBlock(Report r) {
    pw.Widget opt(String label, bool checked) => pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(width: 4),
            _checkbox(checked),
            pw.SizedBox(width: 18),
          ],
        );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: pw.Row(
        children: [
          pw.Text('Modalidad de Servicio:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          pw.SizedBox(width: 20),
          opt('Garantia', r.modalidad == Modalidad.garantia),
          opt('Contrato', r.modalidad == Modalidad.contrato),
          opt('Orden de trabajo', r.modalidad == Modalidad.ordenTrabajo),
        ],
      ),
    );
  }

  /// Recorre la estructura configurable y pinta banda + filas de cada seccion.
  static List<pw.Widget> _checklistSections(Report r) {
    final out = <pw.Widget>[];
    for (final section in kChecklistSections) {
      out.add(_band(section.title));
      final rows = <pw.Widget>[];
      for (var i = 0; i < section.items.length; i++) {
        rows.add(_checklistRow(section.items[i], r.stateFor(section.items[i].key)));
      }
      out.add(pw.Container(
        decoration: pw.BoxDecoration(
            border: pw.Border(left: _side, right: _side, bottom: _side)),
        child: pw.Column(children: rows),
      ));
    }
    return out;
  }

  /// Una fila del checklist: [texto + subcampos] | [N/A PASS FAIL].
  static pw.Widget _checklistRow(ChecklistItemDef def, ChecklistItemState st) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border(top: _side)),
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      constraints: const pw.BoxConstraints(minHeight: 15),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Flexible(
                  child: pw.Text(def.text,
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                ),
                if (def.subFields.isNotEmpty) ...[
                  pw.SizedBox(width: 10),
                  ..._subFields(def, st),
                ],
              ],
            ),
          ),
          pw.SizedBox(width: 8),
          _marks(st.result),
        ],
      ),
    );
  }

  static List<pw.Widget> _subFields(ChecklistItemDef def, ChecklistItemState st) {
    final out = <pw.Widget>[];
    for (final f in def.subFields) {
      final v = st.values[f.key] ?? '';
      out.add(pw.Padding(
        padding: const pw.EdgeInsets.only(right: 10),
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            if (f.label.isNotEmpty)
              pw.Text('${f.label} ',
                  style: const pw.TextStyle(fontSize: 8.5)),
            _underlineValue(v, minW: 22),
          ],
        ),
      ));
    }
    return out;
  }

  /// Valor subrayado estilo "_____".
  static pw.Widget _underlineValue(String value, {double minW = 30}) {
    return pw.Container(
      constraints: pw.BoxConstraints(minWidth: minW),
      decoration: pw.BoxDecoration(border: pw.Border(bottom: _side)),
      padding: const pw.EdgeInsets.symmetric(horizontal: 3),
      child: pw.Text(value.isEmpty ? '    ' : value,
          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
    );
  }

  /// Marcas "N/A__ PASS__ FAIL__" con X en la opcion elegida.
  static pw.Widget _marks(CheckResult result) {
    pw.Widget mark(String label, bool on) => pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(label,
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
            pw.Container(
              width: 14,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(border: pw.Border(bottom: _side)),
              child: pw.Text(on ? 'X' : ' ',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
            ),
            pw.SizedBox(width: 4),
          ],
        );

    return pw.SizedBox(
      width: 150,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          mark('N/A', result == CheckResult.na),
          mark('PASS', result == CheckResult.pass),
          mark('FAIL', result == CheckResult.fail),
        ],
      ),
    );
  }

  static pw.Widget _checkbox(bool checked) {
    return pw.Container(
      width: 9,
      height: 9,
      decoration: pw.BoxDecoration(border: _box),
      alignment: pw.Alignment.center,
      child: pw.Text(checked ? 'X' : '',
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
    );
  }

  // ------------------------------------------------------------------ PAGE 2

  static pw.Widget _page2(
    Report r,
    Uint8List? repFirma,
    Uint8List? clientFirma,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _band('REPUESTOS CAMBIADOS'),
        _repuestosTable(r),
        pw.SizedBox(height: 16),
        _band('OBSERVACIONES GENERALES'),
        pw.SizedBox(height: 10),
        _observaciones(r),
        pw.SizedBox(height: 20),
        _signatureBlock(r, repFirma, clientFirma),
        pw.SizedBox(height: 8),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: red, width: 1.2)),
          ),
          padding: const pw.EdgeInsets.only(top: 4),
          width: double.infinity,
          child: pw.Center(
            child: pw.Text(EmpresaConfig.footer,
                style: const pw.TextStyle(fontSize: 8.5)),
          ),
        ),
      ],
    );
  }

  static pw.Widget _repuestosTable(Report r) {
    pw.Widget hCell(String t, int flex) => pw.Expanded(
          flex: flex,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            decoration: pw.BoxDecoration(border: pw.Border(right: _side)),
            alignment: pw.Alignment.center,
            child: pw.Text(t,
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          ),
        );
    pw.Widget dCell(String t, int flex, {bool last = false}) => pw.Expanded(
          flex: flex,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            decoration: pw.BoxDecoration(
                border: last ? null : pw.Border(right: _side)),
            child: pw.Text(t, style: const pw.TextStyle(fontSize: 9)),
          ),
        );

    final rows = <pw.Widget>[
      pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border(bottom: _side)),
        child: pw.Row(children: [
          hCell('Cantidad', 2),
          hCell('Descripcion', 5),
          hCell('Referencia', 2),
          pw.Expanded(
            flex: 4,
            child: pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              alignment: pw.Alignment.center,
              child: pw.Text('Observaciones',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 9)),
            ),
          ),
        ]),
      ),
    ];
    for (var i = 0; i < r.repuestos.length; i++) {
      final rep = r.repuestos[i];
      rows.add(pw.Container(
        constraints: const pw.BoxConstraints(minHeight: 22),
        decoration: pw.BoxDecoration(
            border: i == r.repuestos.length - 1
                ? null
                : pw.Border(bottom: _side)),
        child: pw.Row(children: [
          dCell(rep.cantidad, 2),
          dCell(rep.descripcion, 5),
          dCell(rep.referencia, 2),
          dCell(rep.observaciones, 4, last: true),
        ]),
      ));
    }

    return pw.Container(
      decoration: pw.BoxDecoration(border: _box),
      child: pw.Column(children: rows),
    );
  }

  static pw.Widget _observaciones(Report r) {
    final lines =
        r.observaciones.where((e) => e.trim().isNotEmpty).toList();
    final rows = <pw.Widget>[];
    // Al menos 4 lineas para preservar el aspecto.
    final count = lines.length < 4 ? 4 : lines.length;
    for (var i = 0; i < count; i++) {
      final text = i < lines.length ? lines[i] : '';
      final bold = i < lines.length &&
          text.toUpperCase() == text &&
          text.trim().isNotEmpty;
      rows.add(pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.only(bottom: 10, top: 2),
        decoration: pw.BoxDecoration(border: pw.Border(bottom: _side)),
        child: pw.Center(
          child: pw.Text(text,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ),
      ));
    }
    return pw.Column(children: rows);
  }

  static pw.Widget _signatureBlock(
    Report r,
    Uint8List? repFirma,
    Uint8List? clientFirma,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Izquierda: representante (precarga fija)
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('REPRESENTANTE MS MAINTENANCE SERVICE:',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.SizedBox(height: 6),
              pw.Container(
                height: 42,
                width: 150,
                alignment: pw.Alignment.bottomLeft,
                child: repFirma != null
                    ? pw.Image(pw.MemoryImage(repFirma),
                        height: 42, fit: pw.BoxFit.contain)
                    : pw.SizedBox(),
              ),
              pw.Text(RepresentanteConfig.nombre,
                  style: const pw.TextStyle(fontSize: 9)),
              pw.Text(RepresentanteConfig.celular,
                  style: const pw.TextStyle(fontSize: 9)),
              pw.Text(RepresentanteConfig.ip,
                  style: const pw.TextStyle(fontSize: 9)),
              pw.Text(RepresentanteConfig.regInvima,
                  style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ),
        pw.SizedBox(width: 16),
        // Derecha: aprobado por el cliente
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('APROBADO POR EL CLIENTE:',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.SizedBox(height: 6),
              _aprobadoRow('Nombre:', r.aprobadoNombre),
              pw.SizedBox(height: 8),
              _aprobadoRow('Cargo:', r.aprobadoCargo),
              pw.SizedBox(height: 8),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Firma:',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.SizedBox(width: 6),
                  pw.Expanded(
                    child: pw.Container(
                      height: 40,
                      decoration: pw.BoxDecoration(
                          border: pw.Border(bottom: _side)),
                      alignment: pw.Alignment.bottomCenter,
                      child: clientFirma != null
                          ? pw.Image(pw.MemoryImage(clientFirma),
                              height: 38, fit: pw.BoxFit.contain)
                          : pw.SizedBox(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _aprobadoRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.SizedBox(
          width: 46,
          child: pw.Text(label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        ),
        pw.Expanded(
          child: pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border(bottom: _side)),
            padding: const pw.EdgeInsets.symmetric(horizontal: 3),
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ LOGO

  /// Logo vectorial para el PDF: onda ECG ambar + dos lineas de texto.
  static pw.Widget _vectorLogo() {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.SizedBox(
          width: 140,
          height: 26,
          child: pw.CustomPaint(
            size: const PdfPoint(140, 26),
            painter: (PdfGraphics canvas, PdfPoint size) {
              final w = size.x;
              final h = size.y;
              final midY = h * 0.45; // PDF: y crece hacia arriba
              canvas
                ..setStrokeColor(accent)
                ..setLineWidth(1.0)
                ..moveTo(0, midY)
                ..lineTo(w, midY)
                ..strokePath();

              // Perfil ECG (x frac, altura frac desde la base).
              final pts = <List<double>>[
                [0.00, 0.45],
                [0.18, 0.45],
                [0.26, 0.60],
                [0.33, 0.30],
                [0.40, 0.95], // pico R
                [0.47, 0.05],
                [0.54, 0.55],
                [0.62, 0.45],
                [0.70, 0.60],
                [0.77, 0.30],
                [0.84, 0.70],
                [0.91, 0.45],
                [1.00, 0.45],
              ];
              canvas
                ..setStrokeColor(accent)
                ..setLineWidth(1.8);
              for (var i = 0; i < pts.length; i++) {
                final x = pts[i][0] * w;
                final y = pts[i][1] * h;
                if (i == 0) {
                  canvas.moveTo(x, y);
                } else {
                  canvas.lineTo(x, y);
                }
              }
              canvas.strokePath();
            },
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text('J&H EQUIPOS MEDICOS SAS',
            style: pw.TextStyle(
                color: accent, fontWeight: pw.FontWeight.bold, fontSize: 11)),
        pw.Text('NIT. 901.933.809-3',
            style: pw.TextStyle(
                color: accent, fontWeight: pw.FontWeight.bold, fontSize: 7)),
      ],
    );
  }

  // ------------------------------------------------------------------ ASSETS

  /// Carga la firma del representante desde assets si existe; null si no.
  static Future<Uint8List?> _loadRepresentanteSignature() async {
    try {
      final data =
          await rootBundle.load(RepresentanteConfig.signaturePngAssetPath);
      return data.buffer.asUint8List();
    } catch (_) {
      // Fallback: intentar como archivo en disco.
      try {
        final f = File(RepresentanteConfig.signaturePngAssetPath);
        if (await f.exists()) {
          return await f.readAsBytes();
        }
      } catch (_) {}
      return null;
    }
  }

  static Uint8List? _decodeBase64Png(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  /// Intenta cargar una fuente que soporte acentos; si no, usa Helvetica.
  static Future<(pw.Font, pw.Font)?> _tryLoadFont() async {
    // Helvetica (default de package:pdf) ya cubre Latin-1 con acentos; no
    // forzamos carga de assets para evitar dependencias de archivos.
    return null;
  }
}

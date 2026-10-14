import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../db/database.dart';
import '../models/report.dart';
import '../widgets/logo_widget.dart';
import 'preview.dart';

/// Editor del formulario completo. Un unico [Report] mutable se va llenando
/// con los controladores; al guardar se persiste en SQLite.
class ReportEditorScreen extends StatefulWidget {
  final Report? report;

  const ReportEditorScreen({super.key, this.report});

  @override
  State<ReportEditorScreen> createState() => _ReportEditorScreenState();
}

class _ReportEditorScreenState extends State<ReportEditorScreen> {
  final _db = ReportDatabase.instance;
  late Report _r;
  bool _dirty = false;

  // Controladores de los campos de texto principales.
  final _controllers = <String, TextEditingController>{};

  // Firma del cliente.
  late final SignatureController _sigController;

  @override
  void initState() {
    super.initState();
    _r = widget.report ?? Report();
    _sigController = SignatureController(
      penStrokeWidth: 2.5,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  TextEditingController _ctrl(String key, String initial) {
    return _controllers.putIfAbsent(
      key,
      () => TextEditingController(text: initial),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _sigController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _captureSignatureIntoModel() async {
    if (_sigController.isNotEmpty) {
      final Uint8List? png = await _sigController.toPngBytes();
      if (png != null) {
        _r.firmaClienteBase64 = base64Encode(png);
      }
    }
  }

  Future<bool> _save() async {
    await _captureSignatureIntoModel();
    await _db.save(_r);
    return true;
  }

  Future<void> _onSavePressed() async {
    await _save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reporte guardado')),
    );
    setState(() => _dirty = false);
  }

  Future<void> _onPreviewPressed() async {
    await _save();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PreviewScreen(report: _r)),
    );
    setState(() => _dirty = false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _save();
        if (mounted) Navigator.pop(context, true);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_r.id == null ? 'Nuevo reporte' : 'Editar reporte'),
          backgroundColor: kAccent,
          foregroundColor: Colors.black,
          actions: [
            IconButton(
              tooltip: 'Guardar',
              icon: const Icon(Icons.save),
              onPressed: _onSavePressed,
            ),
            IconButton(
              tooltip: 'Vista previa / PDF',
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _onPreviewPressed,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _sectionCard('Identificacion del reporte', [
              _text('noReporte', 'No REPORTE', _r.noReporte,
                  (v) => _r.noReporte = v),
              Row(children: [
                Expanded(
                    child: _text('fechaDia', 'Dia', _r.fechaDia,
                        (v) => _r.fechaDia = v,
                        keyboard: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(
                    child: _text('fechaMes', 'Mes', _r.fechaMes,
                        (v) => _r.fechaMes = v,
                        keyboard: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(
                    child: _text('fechaAnio', 'Anio', _r.fechaAnio,
                        (v) => _r.fechaAnio = v,
                        keyboard: TextInputType.number)),
              ]),
              _text('hora', 'Hora de reporte', _r.hora, (v) => _r.hora = v),
            ]),
            _bandCard('INFORMACION DEL CLIENTE', [
              _text('cNombre', 'Nombre del Cliente', _r.clienteNombre,
                  (v) => _r.clienteNombre = v),
              _text('cCiudad', 'Ciudad', _r.clienteCiudad,
                  (v) => _r.clienteCiudad = v),
              _text('cSede', 'SEDE', _r.clienteSede,
                  (v) => _r.clienteSede = v),
              _text('cTel', 'Telefono', _r.clienteTelefono,
                  (v) => _r.clienteTelefono = v,
                  keyboard: TextInputType.phone),
            ]),
            _bandCard('INFORMACION DEL EQUIPO', [
              _text('equipo', 'EQUIPO', _r.equipo, (v) => _r.equipo = v),
              _text('marca', 'Marca', _r.marca, (v) => _r.marca = v),
              _text('modelo', 'MODELO', _r.modelo, (v) => _r.modelo = v),
              const SizedBox(height: 4),
              const Text('Identificador:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 12,
                children: [
                  _radioChip('Serie', _r.idEquipo == IdEquipo.serie,
                      () => setState(() {
                            _r.idEquipo = IdEquipo.serie;
                            _markDirty();
                          })),
                  _radioChip('Lote', _r.idEquipo == IdEquipo.lote,
                      () => setState(() {
                            _r.idEquipo = IdEquipo.lote;
                            _markDirty();
                          })),
                  _radioChip('Cod. Interno',
                      _r.idEquipo == IdEquipo.codInterno, () => setState(() {
                            _r.idEquipo = IdEquipo.codInterno;
                            _markDirty();
                          })),
                ],
              ),
              _text('equipoNo', 'No.', _r.equipoNo, (v) => _r.equipoNo = v),
            ]),
            _bandCard('INFORMACION DEL CASO', [
              const Text('Modalidad de Servicio:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 12,
                children: [
                  _radioChip('Garantia', _r.modalidad == Modalidad.garantia,
                      () => setState(() {
                            _r.modalidad = Modalidad.garantia;
                            _markDirty();
                          })),
                  _radioChip('Contrato', _r.modalidad == Modalidad.contrato,
                      () => setState(() {
                            _r.modalidad = Modalidad.contrato;
                            _markDirty();
                          })),
                  _radioChip('Orden de trabajo',
                      _r.modalidad == Modalidad.ordenTrabajo, () => setState(() {
                            _r.modalidad = Modalidad.ordenTrabajo;
                            _markDirty();
                          })),
                ],
              ),
            ]),
            // Secciones de checklist generadas desde la estructura configurable.
            ...kChecklistSections.map(_checklistSectionCard),
            _bandCard('REPUESTOS CAMBIADOS', [_repuestosEditor()]),
            _bandCard('OBSERVACIONES GENERALES', [_observacionesEditor()]),
            _bandCard('APROBADO POR EL CLIENTE', [
              _text('aprNombre', 'Nombre', _r.aprobadoNombre,
                  (v) => _r.aprobadoNombre = v),
              _text('aprCargo', 'Cargo', _r.aprobadoCargo,
                  (v) => _r.aprobadoCargo = v),
              const SizedBox(height: 8),
              const Text('Firma del cliente:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              _signatureCanvas(),
            ]),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _onSavePressed,
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _onPreviewPressed,
                    style: FilledButton.styleFrom(
                        backgroundColor: kAccent,
                        foregroundColor: Colors.black),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Generar PDF'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------- helpers UI

  Widget _sectionCard(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _bandCard(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: kAccent,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.black)),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _text(
    String key,
    String label,
    String initial,
    ValueChanged<String> onChanged, {
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: _ctrl(key, initial),
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (v) {
          onChanged(v);
          _markDirty();
        },
      ),
    );
  }

  Widget _radioChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: kAccent,
    );
  }

  Widget _checklistSectionCard(ChecklistSectionDef section) {
    return _bandCard(
      section.title,
      section.items.map(_checklistItemTile).toList(),
    );
  }

  Widget _checklistItemTile(ChecklistItemDef def) {
    final st = _r.stateFor(def.key);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(def.text, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (def.subFields.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: def.subFields.map((f) {
                final k = '${def.key}.${f.key}';
                return SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _ctrl(k, st.values[f.key] ?? ''),
                    decoration: InputDecoration(
                      labelText: f.label.isEmpty ? 'Valor' : f.label,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      st.values[f.key] = v;
                      _markDirty();
                    },
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 6),
          _marksSelector(st),
        ],
      ),
    );
  }

  Widget _marksSelector(ChecklistItemState st) {
    Widget seg(String label, CheckResult value, Color on) {
      final selected = st.result == value;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: selected ? on : null,
              foregroundColor: selected ? Colors.black : null,
              padding: const EdgeInsets.symmetric(vertical: 4),
            ),
            onPressed: () => setState(() {
              st.result = selected ? CheckResult.none : value;
              _markDirty();
            }),
            child: Text(label),
          ),
        ),
      );
    }

    return Row(
      children: [
        seg('N/A', CheckResult.na, Colors.grey.shade400),
        seg('PASS', CheckResult.pass, Colors.green.shade300),
        seg('FAIL', CheckResult.fail, Colors.red.shade300),
      ],
    );
  }

  Widget _repuestosEditor() {
    return Column(
      children: [
        for (var i = 0; i < _r.repuestos.length; i++) _repuestoRow(i),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() {
              _r.repuestos.add(RepuestoRow());
              _markDirty();
            }),
            icon: const Icon(Icons.add),
            label: const Text('Agregar fila'),
          ),
        ),
      ],
    );
  }

  Widget _repuestoRow(int i) {
    final rep = _r.repuestos[i];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _ctrl('rep_${i}_cant', rep.cantidad),
                  decoration: const InputDecoration(
                      labelText: 'Cantidad',
                      border: OutlineInputBorder(),
                      isDense: true),
                  onChanged: (v) {
                    rep.cantidad = v;
                    _markDirty();
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 5,
                child: TextField(
                  controller: _ctrl('rep_${i}_desc', rep.descripcion),
                  decoration: const InputDecoration(
                      labelText: 'Descripcion',
                      border: OutlineInputBorder(),
                      isDense: true),
                  onChanged: (v) {
                    rep.descripcion = v;
                    _markDirty();
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _r.repuestos.length <= 1
                    ? null
                    : () => setState(() {
                          _r.repuestos.removeAt(i);
                          _controllers.clear(); // reindex
                          _markDirty();
                        }),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _ctrl('rep_${i}_ref', rep.referencia),
                  decoration: const InputDecoration(
                      labelText: 'Referencia',
                      border: OutlineInputBorder(),
                      isDense: true),
                  onChanged: (v) {
                    rep.referencia = v;
                    _markDirty();
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 5,
                child: TextField(
                  controller: _ctrl('rep_${i}_obs', rep.observaciones),
                  decoration: const InputDecoration(
                      labelText: 'Observaciones',
                      border: OutlineInputBorder(),
                      isDense: true),
                  onChanged: (v) {
                    rep.observaciones = v;
                    _markDirty();
                  },
                ),
              ),
            ],
          ),
          const Divider(),
        ],
      ),
    );
  }

  Widget _observacionesEditor() {
    return Column(
      children: [
        for (var i = 0; i < _r.observaciones.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl('obs_$i', _r.observaciones[i]),
                    maxLines: null,
                    decoration: InputDecoration(
                      labelText: 'Observacion ${i + 1}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      _r.observaciones[i] = v;
                      _markDirty();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _r.observaciones.length <= 1
                      ? null
                      : () => setState(() {
                            _r.observaciones.removeAt(i);
                            _controllers.clear();
                            _markDirty();
                          }),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() {
              _r.observaciones.add('');
              _markDirty();
            }),
            icon: const Icon(Icons.add),
            label: const Text('Agregar observacion'),
          ),
        ),
      ],
    );
  }

  Widget _signatureCanvas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            color: Colors.white,
          ),
          height: 180,
          child: Signature(
            controller: _sigController,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        if (_r.firmaClienteBase64 != null && _r.firmaClienteBase64!.isNotEmpty)
          const Text('Hay una firma guardada. Dibujar de nuevo la reemplaza.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                _sigController.clear();
                setState(() {
                  _r.firmaClienteBase64 = null;
                  _markDirty();
                });
              },
              icon: const Icon(Icons.clear),
              label: const Text('Limpiar firma'),
            ),
          ],
        ),
      ],
    );
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  /// Sugerencias de autocompletado por campo (valores ya usados + semillas).
  final Map<String, List<String>> _suggestions = {};

  /// Semillas iniciales: valores comunes para arrancar aunque no haya historial.
  static const Map<String, List<String>> _seeds = {
    'equipo': [
      'Equipo de Onda de Choque',
      'BTL-6000 Onda de Choque',
      'Equipo de Terapia',
    ],
    'marca': ['BTL', 'Chattanooga', 'Enraf-Nonius'],
    'clienteCiudad': [
      'Bogota',
      'Medellin',
      'Cali',
      'Barranquilla',
      'Cartagena',
      'Bucaramanga',
    ],
  };

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
    _init();
  }

  Future<void> _init() async {
    // Reporte nuevo: consecutivo automatico + fecha/hora de hoy.
    if (widget.report == null) {
      final consec = await _db.nextConsecutivo();
      final now = DateTime.now();
      if (!mounted) return;
      setState(() {
        _r.noReporte = consec;
        _r.fecha = now;
        _r.hora = DateFormat('HH:mm').format(now);
      });
    }
    await _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    final fields = [
      'clienteNombre',
      'clienteCiudad',
      'clienteSede',
      'equipo',
      'marca',
      'modelo',
    ];
    final map = <String, List<String>>{};
    for (final f in fields) {
      final used = await _db.distinctValues(f);
      final merged = <String>{...(_seeds[f] ?? const []), ...used}.toList()
        ..sort();
      map[f] = merged;
    }
    if (!mounted) return;
    setState(() {
      _suggestions
        ..clear()
        ..addAll(map);
    });
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
              _consecutivoField(),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _datePickerField()),
                const SizedBox(width: 8),
                Expanded(child: _timePickerField()),
              ]),
            ]),
            _bandCard('INFORMACION DEL CLIENTE', [
              _autocompleteText('cNombre', 'Nombre del Cliente',
                  _r.clienteNombre, (v) => _r.clienteNombre = v,
                  field: 'clienteNombre'),
              _autocompleteText('cCiudad', 'Ciudad', _r.clienteCiudad,
                  (v) => _r.clienteCiudad = v,
                  field: 'clienteCiudad'),
              _autocompleteText(
                  'cSede', 'SEDE', _r.clienteSede, (v) => _r.clienteSede = v,
                  field: 'clienteSede'),
              _text('cTel', 'Telefono', _r.clienteTelefono,
                  (v) => _r.clienteTelefono = v,
                  keyboard: TextInputType.phone),
            ]),
            _bandCard('INFORMACION DEL EQUIPO', [
              _autocompleteText(
                  'equipo', 'EQUIPO', _r.equipo, (v) => _r.equipo = v,
                  field: 'equipo'),
              _autocompleteText(
                  'marca', 'Marca', _r.marca, (v) => _r.marca = v,
                  field: 'marca'),
              _autocompleteText(
                  'modelo', 'MODELO', _r.modelo, (v) => _r.modelo = v,
                  field: 'modelo'),
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

  // --- Consecutivo (solo lectura, lo mantiene la app) ---
  Widget _consecutivoField() {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'No REPORTE (automatico)',
        border: OutlineInputBorder(),
        isDense: true,
        prefixIcon: Icon(Icons.tag),
      ),
      child: Text(
        _r.noReporte.isEmpty ? 'Asignando...' : _r.noReporte,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }

  // --- Fecha con DatePicker nativo ---
  Widget _datePickerField() {
    final label =
        _r.fecha == null ? 'Seleccionar fecha' : DateFormat('dd/MM/yyyy').format(_r.fecha!);
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: _r.fecha ?? now,
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 5),
        );
        if (picked != null) {
          setState(() {
            _r.fecha = picked;
            _markDirty();
          });
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Fecha de reporte',
          border: OutlineInputBorder(),
          isDense: true,
          prefixIcon: Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(label),
      ),
    );
  }

  // --- Hora con TimePicker nativo ---
  Widget _timePickerField() {
    return InkWell(
      onTap: () async {
        final parts = _r.hora.split(':');
        final initial = TimeOfDay(
          hour: int.tryParse(parts.isNotEmpty ? parts[0] : '') ??
              TimeOfDay.now().hour,
          minute: int.tryParse(parts.length > 1 ? parts[1] : '') ??
              TimeOfDay.now().minute,
        );
        final picked =
            await showTimePicker(context: context, initialTime: initial);
        if (picked != null) {
          setState(() {
            _r.hora =
                '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
            _markDirty();
          });
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Hora',
          border: OutlineInputBorder(),
          isDense: true,
          prefixIcon: Icon(Icons.access_time, size: 18),
        ),
        child: Text(_r.hora.isEmpty ? 'Seleccionar hora' : _r.hora),
      ),
    );
  }

  // --- Campo de texto con autocompletado de valores ya usados + semillas ---
  Widget _autocompleteText(
    String key,
    String label,
    String initial,
    ValueChanged<String> onChanged, {
    required String field,
  }) {
    final options = _suggestions[field] ?? const <String>[];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Autocomplete<String>(
        initialValue: TextEditingValue(text: initial),
        optionsBuilder: (TextEditingValue value) {
          final q = value.text.trim().toLowerCase();
          if (q.isEmpty) return options;
          return options.where((o) => o.toLowerCase().contains(q));
        },
        onSelected: (sel) {
          onChanged(sel);
          _markDirty();
        },
        fieldViewBuilder: (context, controller, focusNode, onSubmit) {
          // Mantener el texto inicial la primera vez que se construye.
          if (controller.text.isEmpty && initial.isNotEmpty) {
            controller.text = initial;
          }
          return TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: options.isEmpty
                  ? null
                  : const Icon(Icons.arrow_drop_down, size: 20),
            ),
            onChanged: (v) {
              onChanged(v);
              _markDirty();
            },
          );
        },
        optionsViewBuilder: (context, onSelected, opts) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240, maxWidth: 320),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: opts.length,
                  itemBuilder: (context, i) {
                    final o = opts.elementAt(i);
                    return ListTile(
                      dense: true,
                      title: Text(o),
                      onTap: () => onSelected(o),
                    );
                  },
                ),
              ),
            ),
          );
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

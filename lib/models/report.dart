import 'dart:convert';

/// Resultado de un item del checklist. El template imprime "N/A___PASS___FAIL___"
/// y marca con una X la opcion elegida.
enum CheckResult { none, na, pass, fail }

extension CheckResultLabel on CheckResult {
  String get code {
    switch (this) {
      case CheckResult.na:
        return 'NA';
      case CheckResult.pass:
        return 'PASS';
      case CheckResult.fail:
        return 'FAIL';
      case CheckResult.none:
        return '';
    }
  }

  static CheckResult fromCode(String? code) {
    switch (code) {
      case 'NA':
        return CheckResult.na;
      case 'PASS':
        return CheckResult.pass;
      case 'FAIL':
        return CheckResult.fail;
      default:
        return CheckResult.none;
    }
  }
}

/// Definicion de un sub-campo con valor en linea dentro de la fila del checklist
/// (ej: "1.5Brs:__1.5_"). `label` es el texto fijo, `key` identifica el valor.
class SubField {
  final String key;
  final String label;

  const SubField({required this.key, required this.label});
}

/// Definicion ESTATICA de un item del checklist (texto + sub-campos).
/// NO guarda estado; el estado vive en [ChecklistItemState].
class ChecklistItemDef {
  final String key;
  final String text;
  final List<SubField> subFields;

  const ChecklistItemDef({
    required this.key,
    required this.text,
    this.subFields = const [],
  });
}

/// Un grupo (seccion) del checklist, con su banda amarilla.
class ChecklistSectionDef {
  final String key;
  final String title;
  final List<ChecklistItemDef> items;

  const ChecklistSectionDef({
    required this.key,
    required this.title,
    required this.items,
  });
}

/// ====================================================================
/// ESTRUCTURA DE DATOS CONFIGURABLE DEL CHECKLIST (unica fuente de verdad).
/// El editor, el PDF y el prototipo HTML derivan de aqui. Para cambiar textos,
/// agregar/quitar filas o sub-campos, editar SOLO esta lista.
/// Textos tomados verbatim de la plantilla MTNE-RG-01.
/// ====================================================================
const List<ChecklistSectionDef> kChecklistSections = [
  ChecklistSectionDef(
    key: 'inspeccion_visual',
    title: '1. Inspeccion Visual',
    items: [
      ChecklistItemDef(
        key: 'iv_integridad',
        text:
            'Integridad mecanica de la unidad y los accesorios para un uso seguro',
      ),
      ChecklistItemDef(
        key: 'iv_interruptor',
        text: 'Interruptor de voltaje funcional',
      ),
      ChecklistItemDef(
        key: 'iv_fusibles',
        text: 'Verificacion de los fusibles en la unidad',
      ),
      ChecklistItemDef(
        key: 'iv_serie_firmware',
        text: 'Chequeo de numeros de serie y versiones de firmware',
      ),
      ChecklistItemDef(
        key: 'iv_accesorios',
        text: 'Verificacion de estado de accesorios',
      ),
    ],
  ),
  ChecklistSectionDef(
    key: 'rutina',
    title: '2. RUTINA DE MANTENIMIENTO',
    items: [
      ChecklistItemDef(
        key: 'rt_lcd',
        text: 'Funcionalidad del LCD y luz de fondo',
      ),
      ChecklistItemDef(
        key: 'rt_botones',
        text: 'Funcionalidad de los botones',
      ),
      ChecklistItemDef(
        key: 'rt_alarmas',
        text: 'Funcionalidad de Alarmas audibles Visuales y Sonidos',
      ),
      ChecklistItemDef(
        key: 'rt_panel_tactil',
        text: 'Calibracion de panel tactil',
      ),
      ChecklistItemDef(
        key: 'rt_logs',
        text: 'Test de funcionamiento programacion verifiaccion de logs Error',
      ),
      ChecklistItemDef(
        key: 'rt_inicio_terapia',
        text: 'Chequeo inicio de terapia Onda de Choque',
      ),
      ChecklistItemDef(
        key: 'rt_compresion',
        text: 'Prueba de Compresion salida a aplicador',
        subFields: [
          SubField(key: 'brs_1_5', label: '1.5Brs:'),
          SubField(key: 'brs_3', label: '3Brs:'),
          SubField(key: 'brs_4', label: '4Brs:'),
          SubField(key: 'brs_5', label: '5Brs:'),
        ],
      ),
      ChecklistItemDef(
        key: 'rt_desarme_camaras',
        text: 'Desarme y limpieza de camaras de compresion',
      ),
      ChecklistItemDef(
        key: 'rt_lubricacion',
        text: 'Lubricacion de Rodamientos del Compresor',
      ),
      ChecklistItemDef(
        key: 'rt_mangueras',
        text: 'Verificacion estado mangueras',
      ),
      ChecklistItemDef(
        key: 'rt_drenaje',
        text: 'Drenaje de tanque de Reserva',
      ),
      ChecklistItemDef(
        key: 'rt_valvula_relief',
        text: 'Mantenimiento de Valvula Relief',
      ),
      ChecklistItemDef(
        key: 'rt_calib_relief',
        text: 'Calibracion valvula Relief',
      ),
      ChecklistItemDef(
        key: 'rt_refrigeracion',
        text: 'limpieza de sistema de refrigeracion y extraccion de calor',
      ),
      ChecklistItemDef(
        key: 'rt_tiempo_carga',
        text: 'Prueba Tiempo de Carga del Compresor a 5 Bar',
        subFields: [
          SubField(key: 'seg_m15', label: '- 15 seg.'),
          SubField(key: 'seg_m20', label: '- 20Seg.'),
          SubField(key: 'seg_p20', label: '+ 20 Seg'),
        ],
      ),
      ChecklistItemDef(
        key: 'rt_conteo_disparos',
        text: 'Conteo de Disparos de Trabajo Piston',
        subFields: [
          SubField(key: 'conteo', label: ''),
        ],
      ),
      ChecklistItemDef(
        key: 'rt_ajustes_carro',
        text: 'Ajustes de carro y limpieza de ruedas',
      ),
      ChecklistItemDef(
        key: 'rt_frenos',
        text: 'Verificacion de frenos carro',
      ),
      ChecklistItemDef(
        key: 'rt_adaptador',
        text: 'veriificacion de adaptador de voltaje y cable AC',
      ),
    ],
  ),
];

/// Estado por item: resultado (N/A/PASS/FAIL) + valores de sub-campos.
class ChecklistItemState {
  CheckResult result;
  Map<String, String> values;

  ChecklistItemState({
    this.result = CheckResult.none,
    Map<String, String>? values,
  }) : values = values ?? {};

  Map<String, dynamic> toJson() => {
        'result': result.code,
        'values': values,
      };

  factory ChecklistItemState.fromJson(Map<String, dynamic> json) {
    return ChecklistItemState(
      result: CheckResultLabel.fromCode(json['result'] as String?),
      values: (json['values'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
          {},
    );
  }
}

/// Fila de la tabla REPUESTOS CAMBIADOS.
class RepuestoRow {
  String cantidad;
  String descripcion;
  String referencia;
  String observaciones;

  RepuestoRow({
    this.cantidad = '',
    this.descripcion = '',
    this.referencia = '',
    this.observaciones = '',
  });

  Map<String, dynamic> toJson() => {
        'cantidad': cantidad,
        'descripcion': descripcion,
        'referencia': referencia,
        'observaciones': observaciones,
      };

  factory RepuestoRow.fromJson(Map<String, dynamic> json) => RepuestoRow(
        cantidad: (json['cantidad'] ?? '').toString(),
        descripcion: (json['descripcion'] ?? '').toString(),
        referencia: (json['referencia'] ?? '').toString(),
        observaciones: (json['observaciones'] ?? '').toString(),
      );
}

/// Modalidad de servicio (checkboxes exclusivos en la plantilla).
enum Modalidad { none, garantia, contrato, ordenTrabajo }

extension ModalidadCode on Modalidad {
  String get code {
    switch (this) {
      case Modalidad.garantia:
        return 'GARANTIA';
      case Modalidad.contrato:
        return 'CONTRATO';
      case Modalidad.ordenTrabajo:
        return 'ORDEN';
      case Modalidad.none:
        return '';
    }
  }

  static Modalidad fromCode(String? code) {
    switch (code) {
      case 'GARANTIA':
        return Modalidad.garantia;
      case 'CONTRATO':
        return Modalidad.contrato;
      case 'ORDEN':
        return Modalidad.ordenTrabajo;
      default:
        return Modalidad.none;
    }
  }
}

/// Identificacion del equipo: cual casilla (Serie/Lote/Cod.Interno) esta marcada.
enum IdEquipo { none, serie, lote, codInterno }

extension IdEquipoCode on IdEquipo {
  String get code {
    switch (this) {
      case IdEquipo.serie:
        return 'SERIE';
      case IdEquipo.lote:
        return 'LOTE';
      case IdEquipo.codInterno:
        return 'COD_INTERNO';
      case IdEquipo.none:
        return '';
    }
  }

  static IdEquipo fromCode(String? code) {
    switch (code) {
      case 'SERIE':
        return IdEquipo.serie;
      case 'LOTE':
        return IdEquipo.lote;
      case 'COD_INTERNO':
        return IdEquipo.codInterno;
      default:
        return IdEquipo.none;
    }
  }
}

/// Modelo completo del reporte. Se persiste como blob JSON en SQLite,
/// con metadatos (id, noReporte, fecha) en columnas aparte para listar/buscar.
class Report {
  int? id;

  // Seccion 2: identificacion del reporte
  String noReporte;

  /// Fecha unica del reporte. Fuente de verdad del dia/mes/anio.
  /// El PDF sigue leyendo fechaDia/Mes/Anio: esos getters se derivan de aqui.
  DateTime? fecha;

  String hora;

  // --- Compatibilidad con el PDF: dia/mes/anio como strings derivados ---
  String get fechaDia =>
      fecha == null ? '' : fecha!.day.toString().padLeft(2, '0');
  String get fechaMes =>
      fecha == null ? '' : fecha!.month.toString().padLeft(2, '0');
  String get fechaAnio => fecha == null ? '' : fecha!.year.toString();

  // Seccion 3: informacion del cliente
  String clienteNombre;
  String clienteCiudad;
  String clienteSede;
  String clienteTelefono;

  // Seccion 4: informacion del equipo
  String equipo;
  String marca;
  String modelo;
  IdEquipo idEquipo;
  String equipoNo;

  // Seccion 5: informacion del caso
  Modalidad modalidad;

  // Secciones 6 y 7: checklist
  Map<String, ChecklistItemState> checklist;

  // Pagina 2
  List<RepuestoRow> repuestos;
  List<String> observaciones;

  // Firma cliente (PNG en base64, dibujada en el canvas)
  String? firmaClienteBase64;
  String aprobadoNombre;
  String aprobadoCargo;

  // Metadatos
  DateTime createdAt;
  DateTime updatedAt;

  Report({
    this.id,
    this.noReporte = '',
    this.fecha,
    this.hora = '',
    this.clienteNombre = '',
    this.clienteCiudad = '',
    this.clienteSede = '',
    this.clienteTelefono = '',
    this.equipo = '',
    this.marca = '',
    this.modelo = '',
    this.idEquipo = IdEquipo.serie,
    this.equipoNo = '',
    this.modalidad = Modalidad.none,
    Map<String, ChecklistItemState>? checklist,
    List<RepuestoRow>? repuestos,
    List<String>? observaciones,
    this.firmaClienteBase64,
    this.aprobadoNombre = '',
    this.aprobadoCargo = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : checklist = checklist ?? _emptyChecklist(),
        repuestos = repuestos ?? List.generate(5, (_) => RepuestoRow()),
        observaciones = observaciones ?? ['', '', ''],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  static Map<String, ChecklistItemState> _emptyChecklist() {
    final map = <String, ChecklistItemState>{};
    for (final section in kChecklistSections) {
      for (final item in section.items) {
        map[item.key] = ChecklistItemState();
      }
    }
    return map;
  }

  ChecklistItemState stateFor(String key) =>
      checklist[key] ??= ChecklistItemState();

  Map<String, dynamic> toJson() => {
        'noReporte': noReporte,
        'fecha': fecha?.toIso8601String(),
        'fechaDia': fechaDia,
        'fechaMes': fechaMes,
        'fechaAnio': fechaAnio,
        'hora': hora,
        'clienteNombre': clienteNombre,
        'clienteCiudad': clienteCiudad,
        'clienteSede': clienteSede,
        'clienteTelefono': clienteTelefono,
        'equipo': equipo,
        'marca': marca,
        'modelo': modelo,
        'idEquipo': idEquipo.code,
        'equipoNo': equipoNo,
        'modalidad': modalidad.code,
        'checklist':
            checklist.map((k, v) => MapEntry(k, v.toJson())),
        'repuestos': repuestos.map((r) => r.toJson()).toList(),
        'observaciones': observaciones,
        'firmaClienteBase64': firmaClienteBase64,
        'aprobadoNombre': aprobadoNombre,
        'aprobadoCargo': aprobadoCargo,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  String toJsonString() => jsonEncode(toJson());

  /// Reconstruye la fecha: primero el campo ISO `fecha`, luego los strings
  /// legacy dia/mes/anio de reportes guardados antes de este cambio.
  static DateTime? _parseFecha(Map<String, dynamic> json) {
    final iso = json['fecha'];
    if (iso is String && iso.isNotEmpty) {
      final d = DateTime.tryParse(iso);
      if (d != null) return d;
    }
    final dia = int.tryParse((json['fechaDia'] ?? '').toString());
    final mes = int.tryParse((json['fechaMes'] ?? '').toString());
    final anio = int.tryParse((json['fechaAnio'] ?? '').toString());
    if (dia != null && mes != null && anio != null) {
      try {
        return DateTime(anio, mes, dia);
      } catch (_) {}
    }
    return null;
  }

  factory Report.fromJson(Map<String, dynamic> json, {int? id}) {
    final checklistJson = (json['checklist'] as Map?) ?? {};
    final checklist = <String, ChecklistItemState>{};
    // Partir de la plantilla para que items nuevos aparezcan vacios.
    for (final section in kChecklistSections) {
      for (final item in section.items) {
        final raw = checklistJson[item.key];
        checklist[item.key] = raw is Map
            ? ChecklistItemState.fromJson(Map<String, dynamic>.from(raw))
            : ChecklistItemState();
      }
    }

    final repsRaw = (json['repuestos'] as List?) ?? [];
    final reps = repsRaw
        .map((e) => RepuestoRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final obsRaw = (json['observaciones'] as List?) ?? ['', '', ''];
    final obs = obsRaw.map((e) => e.toString()).toList();

    return Report(
      id: id,
      noReporte: (json['noReporte'] ?? '').toString(),
      fecha: _parseFecha(json),
      hora: (json['hora'] ?? '').toString(),
      clienteNombre: (json['clienteNombre'] ?? '').toString(),
      clienteCiudad: (json['clienteCiudad'] ?? '').toString(),
      clienteSede: (json['clienteSede'] ?? '').toString(),
      clienteTelefono: (json['clienteTelefono'] ?? '').toString(),
      equipo: (json['equipo'] ?? '').toString(),
      marca: (json['marca'] ?? '').toString(),
      modelo: (json['modelo'] ?? '').toString(),
      idEquipo: IdEquipoCode.fromCode(json['idEquipo'] as String?),
      equipoNo: (json['equipoNo'] ?? '').toString(),
      modalidad: ModalidadCode.fromCode(json['modalidad'] as String?),
      checklist: checklist,
      repuestos: reps.isEmpty ? List.generate(5, (_) => RepuestoRow()) : reps,
      observaciones: obs.isEmpty ? ['', '', ''] : obs,
      firmaClienteBase64: json['firmaClienteBase64'] as String?,
      aprobadoNombre: (json['aprobadoNombre'] ?? '').toString(),
      aprobadoCargo: (json['aprobadoCargo'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  factory Report.fromJsonString(String s, {int? id}) =>
      Report.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map), id: id);
}

/// ====================================================================
/// Datos FIJOS del ingeniero del area (precarga).
/// Configurables en un solo lugar. `signaturePngAssetPath` es el path
/// (asset o archivo) de la firma escaneada que se puede soltar luego.
/// ====================================================================
class RepresentanteConfig {
  static const String nombre = 'ANDRES CHAVEZ';
  static const String celular = 'CEL. 3177663545';
  static const String ip = 'COPNIA. 091030-9585CND';
  static const String regInvima = 'REG. INVIMA RH-202007-00088';

  /// Ruta del PNG de la firma del representante. Si el archivo no existe,
  /// el PDF deja el espacio en blanco. Ver README para como reemplazarlo.
  static const String signaturePngAssetPath = 'assets/firma_representante.png';
}

/// Datos fijos de la empresa / encabezado.
class EmpresaConfig {
  static const String nombre = 'J&H EQUIPOS MEDICOS SAS';
  static const String nit = 'NIT. 901.933.809-3';
  static const String titulo = 'REPORTE DE MANTENIMIENTO PREVENTIVO';
  static const String codigo = 'MTNE-RG-01';
  static const String version = '1';
  static const String pagina = '1 de 1';
  static const String proceso = 'Gestion Comercial';
  static const String footer =
      'Se hace constar que el cliente acepta el servicio y es recibido a entera satisfaccion.';
}

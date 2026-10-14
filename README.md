# Reportes J&amp;H

App Android (Flutter) offline-first para elaborar, guardar, editar y enviar por
correo el **REPORTE DE MANTENIMIENTO PREVENTIVO** de J&amp;H Equipos Medicos SAS.
Reproduce la plantilla `MTNE-RG-01` en un PDF de alta fidelidad (2 paginas,
tamano Carta, banda de acento `#FFC000`, logo vectorial).

- Un solo usuario, sin backend. Los reportes se guardan localmente en **SQLite**.
- El PDF se genera en el dispositivo con `package:pdf` y se comparte por correo
  con `share_plus`.
- El APK se compila en **GitHub Actions** (no necesitas instalar Flutter/Android
  SDK en tu maquina).

---

## 1. Como se compila el APK (sin Flutter local)

El build corre en CI. Flujo:

1. Crea un repositorio en GitHub (ver seccion 5) y sube este proyecto.
2. Cada `git push` dispara el workflow `.github/workflows/build-apk.yml`.
   Tambien puedes lanzarlo manualmente: pestana **Actions** -> **Build APK** ->
   **Run workflow** (`workflow_dispatch`).
3. El workflow (ubuntu-latest):
   - instala JDK 17 y Flutter stable (`subosito/flutter-action@v2`),
   - ejecuta `flutter create --platforms=android --org com.jh .` para rellenar
     SOLO los archivos de plataforma que no estan versionados (iconos
     `mipmap/ic_launcher`, wrapper de Gradle, etc.). **No** sobreescribe los
     archivos escritos a mano (`android/app/build.gradle`, `AndroidManifest.xml`,
     `MainActivity.kt`),
   - `flutter pub get`,
   - `flutter analyze` (no bloqueante: informa pero no detiene el build),
   - `flutter build apk --release`,
   - sube el artefacto **`reportes-apk`**.
4. Abre la ejecucion terminada en **Actions**, baja el artefacto `reportes-apk`,
   descomprime y obtienes `app-release.apk`.

> El APK release se firma con la clave **debug** (ver
> `android/app/build.gradle`), asi el CI produce un APK **instalable** sin
> keystore. Para publicar en Play Store, reemplaza por tu propia firma.

## 2. Instalar el APK en el telefono

1. Transfiere `app-release.apk` al dispositivo (cable, correo, nube).
2. En Android, habilita **Instalar apps de origen desconocido** para el gestor
   de archivos o navegador que uses.
3. Abre el `.apk` y confirma la instalacion. La app aparece como **Reportes J&amp;H**.

## 3. Estructura del proyecto

```
E:\Andres_Korea\
  pubspec.yaml                      Dependencias (sqflite, pdf, printing, share_plus, signature, intl...)
  analysis_options.yaml             Reglas de lint
  .github\workflows\build-apk.yml   CI: compila el APK release y lo sube como artefacto
  lib\
    main.dart                       Punto de entrada (tema Material3, color #FFC000)
    models\report.dart              Modelo Report + ESTRUCTURA CONFIGURABLE del checklist
                                    (kChecklistSections) + config fija empresa/representante
    db\database.dart                SQLite: tabla reports (blob JSON + metadatos) + CRUD
    widgets\logo_widget.dart        Logo vectorial (onda ECG + texto) reutilizable en la app
    screens\
      report_list.dart              Lista de reportes guardados (abrir/nuevo/duplicar/eliminar)
      report_editor.dart            Formulario completo (checkboxes, N/A/PASS/FAIL,
                                    sub-campos, repuestos, observaciones, firma del cliente)
      preview.dart                  Genera + previsualiza el PDF, comparte por correo
    pdf\report_pdf.dart             PDF de ALTA FIDELIDAD (2 paginas, logo vectorial,
                                    bandas #FFC000, tablas/bordes finos)
  android\                          Scaffold minimo para compilar en CI
    build.gradle, settings.gradle, gradle.properties
    gradle\wrapper\gradle-wrapper.properties
    app\build.gradle                applicationId com.jh.reportes, minSdk 21, compile/target 34
    app\src\main\AndroidManifest.xml  label "Reportes J&amp;H"
    app\src\main\kotlin\com\jh\reportes\MainActivity.kt
    app\src\main\res\...            styles (LaunchTheme/NormalTheme) + launch_background
  _tooling\
    prototype\index.html            Prototipo de fidelidad HTML/CSS (proporcion Carta)
    ref\page1.png, page2.png        Referencia visual de la plantilla original
    extract_pdf.py, render_ref.py   Scripts usados para extraer texto/rects (referencia)
```

## 4. Checklist configurable (una sola fuente de verdad)

Los items del checklist **no** estan hardcodeados en el bucle de dibujo. Viven
en una sola estructura: `kChecklistSections` en
`lib/models/report.dart`. El editor, el PDF y el prototipo HTML derivan de ella.

Para cambiar textos, agregar/quitar filas o sub-campos (ej. las presiones
`1.5/3/4/5 Brs`, los tiempos `-15/-20/+20 seg`, el `Conteo de Disparos`):
edita **solo** esa lista y los tres lugares quedan consistentes (recuerda
reflejar el cambio en el array `SECTIONS` del prototipo `index.html` si lo usas
para eyeballear).

## 5. Crear el repo y subir (proximos pasos)

Desde `E:\Andres_Korea` (tienes git, Node 24, Python 3.12):

```powershell
cd E:\Andres_Korea
git init
git add .
git commit -m "App Flutter reportes de mantenimiento J&H"
git branch -M main
git remote add origin https://github.com/<tu-usuario>/<tu-repo>.git
git push -u origin main
```

Tras el push, ve a **Actions**, espera a que **Build APK** termine en verde y
descarga el artefacto `reportes-apk`.

## 6. Reemplazar la firma del representante y el logo de alta resolucion

### Firma del representante (Hugo Acosta R.)

El PDF busca la firma en `assets/firma_representante.png`
(`RepresentanteConfig.signaturePngAssetPath` en `lib/models/report.dart`). Si el
archivo no existe, el espacio queda en blanco (el resto de los datos del
representante siempre se precargan).

Para incluir la firma escaneada:

1. Guarda el PNG (fondo transparente, recomendado ~600x200 px) en
   `E:\Andres_Korea\assets\firma_representante.png`.
2. Declara el asset en `pubspec.yaml`:
   ```yaml
   flutter:
     uses-material-design: true
     assets:
       - assets/firma_representante.png
   ```
3. `git add`, commit y push. El siguiente build lo embebe automaticamente.

Si prefieres otra ruta/nombre, cambia la constante
`RepresentanteConfig.signaturePngAssetPath`.

### Logo de alta resolucion

El logo se dibuja **vectorialmente** (onda ECG + texto) tanto en la app como en
el PDF, asi que es nitido a cualquier escala y no requiere imagen. Si en el
futuro quieres usar un logo oficial en alta resolucion:

1. Agrega el PNG/SVG a `assets/` y declaralo en `pubspec.yaml` (igual que la
   firma).
2. En `lib/pdf/report_pdf.dart`, metodo `_vectorLogo()`, reemplaza el
   `pw.CustomPaint` por `pw.Image(pw.MemoryImage(bytes))`.
3. En `lib/widgets/logo_widget.dart` reemplaza el `CustomPaint` por un
   `Image.asset(...)`.

## 7. Notas / verificacion

- **No se pudo ejecutar Flutter/Dart en el equipo de desarrollo** (no hay SDK
  instalado, por diseno). Todos los archivos se escribieron a mano y la
  consistencia de imports/`pubspec` se reviso por inspeccion. La compilacion
  real ocurre en CI; si `flutter analyze` reporta algo, aparece en el log del
  workflow sin bloquear el build.
- `applicationId` y `namespace` son `com.jh.reportes`. El `--org com.jh` del
  comando `flutter create` solo afecta a archivos que no existen; como el
  `build.gradle` y el `MainActivity.kt` ya estan versionados con el paquete
  correcto, no se alteran.
- Permisos: la app no requiere INTERNET en release (todo es offline). `share_plus`
  abre el selector de apps de correo del sistema para adjuntar el PDF.

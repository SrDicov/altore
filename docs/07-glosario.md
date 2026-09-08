# 07 — Glosario

Definiciones cortas, sin jerga asumida. Si usas un término de esta lista en
código o docs, úsalo con este significado.

- **glibc / musl** — Dos implementaciones de la biblioteca base de C en Linux.
  glibc = la de Arch/Debian/Fedora (casi todo el software binario se compila
  contra ella). musl = la de Void-musl/Alpine/Gentoo-musl (ligera, simple).
  Son incompatibles entre sí dentro del mismo proceso.
- **Syscall** — Petición directa de un programa al kernel (abrir archivo, red,
  GPU…). Idénticas en musl y glibc: por eso un programa glibc corre en kernel
  musl si le das su glibc.
- **Cargador / linker dinámico (`ld-linux`, `ld-musl`)** — Programa que el
  kernel arranca primero al ejecutar un binario dinámico; carga sus
  librerías. Cada binario lleva escrito el suyo en `INTERP`.
- **INTERP** — Campo del ejecutable con la ruta de su cargador.
- **`--library-path`** — Flag del cargador glibc: lista de directorios donde
  buscar librerías, con máxima prioridad y sin heredarse a procesos hijos
  (a diferencia de `LD_LIBRARY_PATH`).
- **rpath / `$ORIGIN`** — Ruta de búsqueda de librerías grabada en el binario;
  `$ORIGIN` = "donde estoy yo", permite bundles reubicables.
- **CAS (content-addressed storage)** — Guardar archivos por el hash de su
  contenido: dos archivos iguales ocupan un solo slot. Base del store de
  Altore (y de nix-store).
- **Hardlink** — Dos nombres para el mismo contenido en disco. Ocupan espacio
  una vez; borrar un nombre no borra el contenido mientras quede otro.
- **AppDir** — Carpeta con app + dependencias + `AppRun`, lista para ejecutar
  o empaquetar. La produce `quick-sharun`.
- **AppRun** — Script/binario de entrada del AppDir: ejecuta el cargador
  bundlado con sus rutas y luego la app.
- **AppImage** — Un archivo ejecutable que contiene un AppDir comprimido
  (aquí: DwarFS) + runtime que lo monta al arrancar.
- **DwarFS / SquashFS** — Sistemas de archivos comprimidos de solo lectura.
  DwarFS: mejor ratio y mucho más rápido (el usado aquí).
- **sharun** — Herramienta que empaqueta apps con su glibc + cargador y
  corrige `/proc/self/exe`. Base del método AnyLinux.
- **uruntime** — Runtime de AppImage con fallbacks (FUSE → namespaces →
  extraer y correr): "0 requisitos".
- **Overlay / unionfs** — Ver varias carpetas como una sola (lectura) con
  capa de escritura aparte. Conty lo usa para persistir instalaciones.
- **bwrap (bubblewrap)** — Ejecutor de contenedores ligeros con namespaces.
  Lo usan Flatpak y Conty (y cpak en espíritu con namespaces directos).
- **User-namespace** — Permite a un usuario sin root crear entornos aislados
  (montajes, red…). Requisito de Conty/Flatpak; Altore no lo necesita.
- **OCI (imagen/capa)** — Formato estándar de contenedores (Docker): imagen =
  pila de capas por hash. cpak lo usa como transporte.
- **Flatpak-hell** — Runtimes duplicados por versiones que se acumulan
  (término de la comparativa de pkgforge).
- **Sandbox / portal** — Aislamiento de apps (Flatpak) y APIs para pedir
  acceso puntual (ficheros, cámara…). Altore no tiene: decisión explícita.
- **Closure** — En nix: un paquete más todo su grafo de dependencias.
- **Manifiesto** — Descripción de un paquete (nombre, versión, origen,
  binarios, permisos, hash). En Altore: catálogo; en cpak: `cpak.json`.
- **Shim** — Pequeño lanzador en `~/.local/bin/<app>` que delega en
  `altore run <app>`.
- **FHS** — Jerarquía estándar (`/usr`, `/etc`…). Los bundles la evitan a
  propósito.
- **dlopen** — Cargar una librería en caliente desde el programa (plugins,
  drivers, temas). Las libs "opcionales" se detectan trazándolo.
- **Mesa / ANV / RADV / Iris** — Drivers gráficos open source (Mesa los
  agrupa): ANV = Vulkan Intel, RADV = Vulkan AMD, Iris = OpenGL Intel moderno.
- **ICD (Vulkan)** — "Installable Client Driver": cada driver Vulkan se
  registra con un JSON en `/usr/share/vulkan/icd.d`.

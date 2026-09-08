# 02 — Por qué se hace Altore

## 1. El problema, sin jerga

Linux no tiene "un" sistema: tiene familias incompatibles de bibliotecas base.
Las dos grandes son **glibc** (Arch, Debian, Fedora…) y **musl** (Void-musl,
Alpine, Gentoo-musl). Casi todo el software distribuido como binario (sobre
todo el privativo: navegadores, Discord, Spotify, Steam, juegos) se compila
contra glibc.

En un PC con musl, ese software **no arranca**. Y no es un detalle menor: al
kernel le dan igual musl o glibc (un programa solo hace *syscalls*, idénticas
en ambos), pero cada programa lleva escrito qué *cargador* usar (`INTERP`) y
espera unas librerías con las que fue compilado. Sin su glibc, muere al nacer.

## 2. Por qué "solo cambiar glibc" no funciona

La idea obvia ("deja las libs del sistema y mapea solo glibc") es imposible
por física del enlazado dinámico: **en un proceso solo puede vivir UNA libc**.
Todo comparte la misma memoria: el asignador (`malloc`), los hilos
(`pthread_mutex_t` y amigos), `errno`, los datos de locale… tienen layouts
**incompatibles** entre musl y glibc. Mezclar una lib musl en un proceso glibc
(o al revés) es corrupción garantizada, no "casi funciona".

La prueba viviente es `gcompat` (shim de glibc sobre musl en Alpine): sirve
para binarios simples y se rompe con programas serios. Ni siquiera
glibc-con-glibc es seguro (símbolos versionados `GLIBC_X.XX` distintos entre
distros: el clásico infierno que mataba a los AppImage viejos).

**Conclusión forzosa, sin punto medio a nivel de cargador:** o traes el grafo
completo de dependencias consistente (una libc, un allocator, un threading) o
remapeas APIs una por una como Wine/gcompat (trabajo infinito y frágil). Todo
el diseño de Altore sale de esta frase.

## 3. Qué probamos antes y qué impuesto paga cada uno

Análisis honesto tras usar cada tecnología en un Void-musl real:

- **nix** — Ejecución con 0 delay (es un subsistema: `exec` directo) y todo el
  software funciona porque trae su propio userland con glibc. Impuestos: el
  store crece sin control (un Firefox se va a ~1GB+ con su closure), duplica
  muchísimo y compila desde fuente. Pesa demasiado para el objetivo.
- **flatpak** — Lo más simple para el usuario (tienda → instalar → play).
  Impuestos: delay notable al abrir apps (bwrap + ostree + portales) y
  runtimes monumentales que se acumulan (medido por terceros: 6.27GB para
  20 apps, 14.86GB en ext4 sin compresión; el "flatpak-hell" de runtimes
  duplicados por versiones).
- **cpak** (`cpak.it`, Containerpak) — Espectacular en concepto: simplicidad
  tipo flatpak, manifiesto Git + capas OCI deduplicadas, binarios Go
  estáticos, `cpak doctor`, rollback. Impuestos: hay que empaquetar 1-a-1 cada
  software, y monta capas OCI en cada lanzamiento (overhead frente a exec
  directo). Temprano en desarrollo.
- **AnyLinux-AppImages** (pkgforge/sharun) — Espectacular también: descargar y
  jugar, arranque rapidísimo (DwarFS, ±300ms del nativo), cientos de apps ya
  empaquetadas, funciona hasta en NixOS y BSD. Impuestos: hay que empaquetar
  1-a-1 (para maintainers) y, el grave para este proyecto, **cada AppImage
  duplica su base** (medido: 2.0GB para 21 apps): no comparte dependencias
  entre imágenes y al acumularse pesan muchísimo.
- **Conty** (construido y probado en este mismo PC: `conty-minimal.sh`, 580MB)
  — Abre *en teoría* todo lo glibc, incluyendo binarios sueltos arbitrarios
  (probado: Hytale, LibreWolf) y mezcla 32/64-bit. Impuestos: delay de FUSE
  (squashfuse) + bwrap en cada arranque, base monolítica, y problemas de
  dependencias si no va todo empaquetado al 100% como el Conty original.
- **chroot** — Descartado con datos: pide root (mata el requisito "sin root"),
  no aísla nada útil (solo cambia `/`) y no acelera nada. Ya se usa donde toca
  (construcción con root), jamás en ejecución.

## 4. El hueco que nadie ocupa

Puesto en fila, falta exactamente esto:

> **Velocidad de nix** (exec directo, 0 delay) **+ simplicidad de flatpak**
> (`get` + abrir) **+ arranque de AnyLinux** (bundles con su glibc, DwarFS,
> catálogo ya existente) **+ deduplicación real entre apps** (lo que a
> AnyLinux le falta) **+ fallback universal tipo Conty** para lo raro
> (binarios sueltos, 32/64-bit, wine) — **sin** sandbox obligatorio, sin root,
> sin daemon, sin compilar.

Ese hueco se llama Altore. El cómo está en `04-como-funciona.md`.

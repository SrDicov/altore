# 05 — Arquitectura técnica

Decisiones de diseño con sus motivos. Si algo aquí cambia, actualizar este
documento es parte del cambio.

## 1. Layout en disco (todo bajo `$HOME`, nada fuera)

```
~/.local/share/altore/
  store/<sha256[:2]>/<sha256>   # archivos por contenido (el "mar de bits")
  apps/<nombre>/
    AppRun                      # lanzador generado (loader trick)
    <árbol de la app>           # hardlinks al store
    manifest.json               # copia del manifiesto instalado + digest
  db.json                       # app -> [hashes], versiones, pins
  cache/                        # descargas en curso (reanudables)
  overlays/                     # estado del fallback Conty (raro; ver §7)
~/.local/bin/<app>              # shims -> `altore run <app>`
~/.local/share/applications/<app>-altore.desktop
```

Reglas:
- **Nada fuera de `$HOME`.** Ni `/opt`, ni `/usr/local`, ni systemd units.
- `store/` es solo-lectura por convención (permisos `a-w` tras verificar;
  el GC es el único escritor además del instalador).
- Los dos primeros caracteres del hash como subdirectorio evitan directorios
  con cientos de miles de entradas (como git/objects y nix/store).
- Borrar `~/.local/share/altore` = desinstalación total sin rastro.

## 2. Formato de paquete (lo que viaja por red)

Se reutiliza el AppDir sharun tal cual sale de `quick-sharun` + paquetes
debloated (`get-debloated-pkgs.sh`): binarios, `*.so*`, `ld-linux`,
`AppRun`, `.desktop`, iconos. Transporte comprimido con DwarFS/zstd (mejor
ratio y arranque que squashfs; medido por pkgforge).

Por qué no inventar formato propio: el catálogo pkgforge (cientos de apps,
CI con plantillas) ya existe y funciona; reinventarlo violaría el
no-objetivo nº 5. La Fase 2 convierte esos artefactos, no los reconstruye.

## 3. Componentes y responsabilidades

| Componente | Qué hace | Qué NO hace |
|---|---|---|
| `altore` (binario Zig, estático musl) | CLI: `get/run/ls/rm/gc/update/doctor`; hashing (sha256), hardlinks, `exec`; pinta shims y `.desktop` | No monta nada, no daemoniza, no pide root, no toca red salvo `get/update` (vía `curl` externo en v1) |
| Catálogo | nombre → manifiesto + URL + hash + dependencias declaradas | No es tienda cerrada: cualquier origen con manifiesto válido vale |
| `AppRun` generado | `ld-linux --library-path <rutas del store> <bin> "$@"` + limpieza de entorno heredado | No decide nada: rutas ya resueltas por el instalador |
| Fallback Conty-minimal | `run --universal`: binarios sueltos, 32/64-bit, wine | No es el path feliz; solo cuando sharun no cubre |
| `doctor` | chequea kernel, `/dev/dri`, sesión gráfica, espacio, red, FUSE/ns (informativo) | No "arregla" nada solo |

## 4. Decisiones técnicas (y sus porqués)

1. **Zig para el CLI** (fallback: Rust). Criterio: binario estático-musl
   diminuto (~100-300KB) sin toolchain extra, sin GC, arranque instantáneo.
   El path caliente es `exec` (overhead cero en cualquier lenguaje); el CLI
   solo orquesta. TLS/descompresión se delegan a `curl`/`tar` del sistema en
   v1 (ya exigidos como host-deps) en vez de reinventarlos.
2. **Extraer al instalar, ejecutar directo siempre.** Elimina el impuesto de
   montaje por lanzamiento (el delay de flatpak/AppImage). Coste: disco en la
   primera instalación; se paga una vez y el CAS lo minimiza.
3. **Deduplicación por hash de archivo + hardlink.** Simple, portable (ext4,
   btrfs, xfs…), sin daemon ni FS especial. Alternativas descartadas:
   reflink (solo btrfs/xfs, no portable), OverlayFS por app (montaje por
   lanzamiento: vuelve el delay), squashfs por app (duplica: el problema
   original).
4. **DwarFS para transporte, no para ejecución.** Mejor compresión que
   squashfs; al extraerse, su velocidad de montaje deja de importar.
5. **Binarios glibc debloated de Arch como entrada.** Evita compilar desde
   fuente (no-objetivo nº 4) con paquetes ya optimizados en tamaño
   (ej: `libicudata` <1MB vs 30MB stock).
6. **Sin sandbox por diseño.** Menos código, más velocidad, requisito
   explícito. Quien necesite aislar usará Flatpak/cpak.
7. **Conty como fallback externo, no integrado.** Separación de
   responsabilidades: el path rápido no sabe que Conty existe; solo
   `--universal` lo invoca. Si Conty no está presente, ese flag da error
   claro en vez de fallar raro.

## 5. Seguridad del diseño (mínima pero explícita)

Sin sandbox, la superficie es: hashes verificados antes de extraer (obligatorio),
orígenes con digest inmutable (lockfiles en Fase 2), y nada que se ejecute con
más privilegios que el usuario. No hay daemon que explotar porque no hay
daemon. Esto es una decisión documentada, no un descuido (ver no-objetivo nº 1
en `03-objetivos.md`).

## 6. Límites conocidos desde el día uno

- En host glibc el store duplica lo que el sistema ya trae (target = musl).
- Apps que necesitan 32-bit + 64-bit mezclados → fallback Conty.
- Drivers propietarios (Nvidia): la app trae Mesa bundlada; Nvidia oficial
  funciona por enlazar glibc vieja (documentado por pkgforge), pero validar
  por GPU en Fase 1.
- Nombres de shims pueden chocar con binarios del host (`~/.local/bin`
  primero en `$PATH` o no, según la distro: documentarlo en el instalador).

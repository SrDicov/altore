# 08 — Spec CLI `alt`/`altore` (v1, congelada)

Gramática, semántica y códigos de salida. Cambiar este archivo = cambiar el
contrato con el usuario; requiere actualizar `src/alt`, `alt -h` y tests.

## 0. Invocación

```
alt [-s TXT] | [-i PKG] | [-R PKG] | [-r PKG [ARGS...]]
    | [-I PKG] | [-l] | [-lg [REPO]] | [-u [PKG]]
    | [-h] | [-v] | doctor | gc
alt PALABRA ...   (alias: search install remove run info information
                   list listg update help version doctor gc)
alt PKG [ARGS...] (atajo de run)
```

- `alt` y `altore` son el mismo programa (dos nombres en el `.xbps`).
- Opciones largas equivalentes: `--search --install --remove --run --info
  --information --list --listg --update --help --version --doctor --gc`.
- No hay flags cortos combinados (`-si` no existe; error de uso, código 2).
- Todo prompt interactivo acepta `1..N` o `n` (ninguno). `n`/vacío = cancelar.
- ListadosMachine? No: salida humana a stdout, prompts a stderr, avisos a
  stderr. Códigos: `0` ok · `1` error operativo · `2` uso incorrecto ·
  `3` sin resultados · `4` red/hash/verificación.

## 1. Comandos

### `-s TXT` / `search TXT` — buscar
Busca TXT en el índice local unificado (todos los repos; no toca red, ver §3).
Motor (case-insensitive, `-`/`_`/` ` equivalentes): exacto (100) > prefijo de
nombre (80) > subcadena en nombre (60) > subcadena en descripción (30).
Muestra hasta 20: `N) nombre  versión  [repo]  — descripción`.
Sin resultados → código 3 + sugerencia de `update` (índices viejos).

### `-i PKG` / `install PKG` — instalar
1. Si índice ausente/vacío → sincroniza solo (como `update` de índices).
2. Nombre exacto → instala directo. Si no → candidatos con el motor de `-s`;
   lista numerada + `Elige número (n=ninguno):`; `n` = aborta (código 0,
   "cancelado", sin error).
3. Descarga a `cache/` con resume y hasta 5 intentos (aborta conexiones
   paradas y reintenta; los errores de red se muestran), mostrando el tamaño
   antes (`descargando X (141.0 MiB)...`). Verifica sha256 (filas de
   catálogo remoto sin sha: verifica por tamaño y lo dice), extrae en
   staging dentro de `$ALTORE_HOME` (mismo FS que el store; `/tmp` suele ser
   tmpfs pequeño) tras comprobar espacio libre (×3 tarball, ×4 AppImage),
   `apps/<nombre>/` con hardlinks, escribe `manifest`, crea shim en
   `~/.local/bin` + `.desktop`, imprime
   `instalado <nombre> <versión> (<tamaño nuevo en disco>)`. Los bins no
   declarados (catálogo remoto) se descubren del `.desktop` al instalar.
4. Si ya instalado en igual versión → "ya instalado", código 0. Si hay
   versión mayor → propone actualizar (mismo prompt; `n` cancela).

### `-R PKG` / `remove PKG` — desinstalar
Resuelve **contra lo instalado** (mismo motor; ambiguo → numerada + `n`).
Borra `apps/<nombre>/`, shim y `.desktop`. No toca el store (`gc` lo hace).
Config del usuario (`~/.config`, `~/.cache` de la app) **no se toca nunca**.
Sugiere `gc` si quedan blobs huérfanos.

### `-r PKG [ARGS...]` / `run PKG` / `alt PKG` — ejecutar
Instalado → `exec` de su `AppRun` con entorno saneado (se borran
`LD_LIBRARY_PATH`, `GCONV_PATH`, `GDK_PIXBUF_MODULE_FILE` heredados) + `ARGS`.
No instalado → flujo `-i` (búsqueda + prompt) y, si instala, ejecuta en la
misma invocación. Fallo de lanzamiento → mensaje + `doctor` sugerido.

### `-I PKG` / `info PKG` — ficha del paquete
Resuelve contra **todo el índice** (no necesita estar instalado). Muestra:
nombre, descripción (larga si existe), versión disponible, repo, tamaño,
sha256 (recortado), binarios que exporta, estado: `instalado <v>` o
`no instalado` (+ `instalable con: alt -i <nombre>`). Único comando de
información por paquete: **`-v` nunca acepta paquete**.

### `-l` / `list` — instalados
`nombre  versión  [repo]  tamaño-en-disco` por línea + total al final.

### `-lg [REPO]` / `listg [REPO]` — disponibles
Sin arg: todo el índice agrupado por repo (cabecera `== repo ==`). Con arg:
solo ese repo; repo inexistente → lista repos conocidos (código 3).

### `-u [PKG]` / `update [PKG]` — actualizar
Sin args: sincroniza índices y actualiza **todo** lo instalado con versión
mayor disponible, uno por uno; conserva la vieja hasta verificar la nueva;
resume por paquete al final (`actualizados N, al día M, fallidos K`).
Con `PKG`: resuelve **contra lo instalado** (motor `-s`; ambiguo → numerada);
no instalado → error accionable (`usa alt -i`, código 3); al día → lo dice
(código 0).
Índices: `update` siempre los refresca primero (único comando que toca red
además de `-i`).

### `-h` / `help` — ayuda
Uso compacto + tabla de comandos + ejemplos + rutas (`$ALTORE_HOME`,
repos.conf). Cabe en una pantalla (~40 líneas).

### `-v` / `version` — versión
`altore <versión> (<arch>, <libc del build>)`. Sin argumentos, siempre.

### `doctor` — diagnóstico
Chequeos con `ok`/`FALTA`/`aviso`: kernel/arquitectura, `/dev/dri` (GPU),
sesión gráfica (`DISPLAY`/`WAYLAND_DISPLAY`), espacio en `$HOME`, red hacia
repos configurados, herramientas (`curl tar gzip sha256sum awk ln df`).
Código 0 si nada crítico falta; 1 si falta algo crítico. Pensado para pegar
su salida en un reporte de fallo.

### `gc` — limpieza
Borra blobs del store sin referente en ningún `apps/*/manifest`, rmdirs
vacíos. Informa `borrados N archivos, liberados X`. Nunca toca apps
instaladas. Código 0 siempre (con `nada que limpiar` si aplica).

## 2. Variables de entorno

- `ALTORE_HOME` (defecto `~/.local/share/altore`): store, apps, índices, caché.
- `ALTORE_BIN` (defecto `~/.local/bin`): dónde se crean los shims.
- `ALTORE_REPOS` (defecto `$ALTORE_HOME/repos.conf`): fichero de repos.
- `ALTORE_NONINTERACTIVE=1`: ningún prompt; ambigüedad = error (código 3).
  Para scripts/CI.

## 3. Red e índices

`-s/-I/-l/-lg` **nunca tocan red**: usan el índice local. `update` refresca;
`-i` refresca solo si no hay índice. TTL sugerido: aviso `índices de hace >7
días, ejecuta alt -u` en `-s` sin resultados.

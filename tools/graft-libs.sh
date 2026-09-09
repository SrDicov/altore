#!/bin/sh
# graft-libs.sh — injerta la glibc que le falta a un AppDir clásico.
# Uso: sh tools/graft-libs.sh <appdir> --from <base-appdir>
# Ejemplo: sh tools/graft-libs.sh ./mi.AppDir --from ~/.local/share/altore/apps/yt-dlp
#
# Hace:
#   1. Enumera los NEEDED de cada ELF del AppDir (readelf).
#   2. Copia a <appdir>/lib lo que falte y esté en la base (cierre transitivo;
#      los ficheros byte-idénticos los deduplica el CAS al instalar: ~0 disco).
#   3. Copia el loader (ld-linux) de la base.
#   4. Sustituye AppRun por un stub que invoca el loader injertado con
#      --library-path (el original queda en AppRun.orig). Sin patchelf.
# Requiere en la máquina que empaqueta: readelf, readlink.
set -u

[ $# -eq 3 ] && [ "$2" = "--from" ] || \
    { echo "uso: $0 <appdir> --from <base-appdir>" >&2; exit 2; }
APP="$1"; BASE="$3"
[ -d "$APP" ] || { echo "no existe $APP" >&2; exit 1; }
[ -d "$BASE" ] || { echo "no existe base $BASE" >&2; exit 1; }
command -v readelf >/dev/null 2>&1 || { echo "falta readelf" >&2; exit 1; }

# Loader de la base.
LOADER_SRC=$(find "$BASE" -name 'ld-linux-*.so*' -type f 2>/dev/null | head -1)
[ -n "$LOADER_SRC" ] || { echo "la base no trae loader (ld-linux)" >&2; exit 1; }
LOADER_NAME=$(basename "$LOADER_SRC")
[ -f "$APP/lib/$LOADER_NAME" ] || { mkdir -p "$APP/lib"; cp -p "$LOADER_SRC" "$APP/lib/"; }

# Directorios donde buscar/copiar libs.
app_libdirs() {
    for d in lib usr/lib lib64 usr/lib64 lib/x86_64-linux-gnu usr/lib/x86_64-linux-gnu; do
        [ -d "$APP/$d" ] && printf '%s\n' "$APP/$d"
    done
}
base_libdirs() {
    for d in lib usr/lib lib64 usr/lib64 lib/x86_64-linux-gnu usr/lib/x86_64-linux-gnu; do
        [ -d "$BASE/$d" ] && printf '%s\n' "$BASE/$d"
    done
}
BASEDIRS=$(base_libdirs)

have_lib() {
    # have_lib <soname> → 0 si ya está en el AppDir
    _s="$1"
    for _d in $(app_libdirs); do
        [ -e "$_d/$_s" ] && return 0
    done
    return 1
}

find_base() {
    # find_base <soname> → ruta del fichero real en la base (o vacío)
    _s="$1"
    for _d in $BASEDIRS; do
        if [ -e "$_d/$_s" ]; then
            ( cd "$_d" && readlink -f "$_s" 2>/dev/null ) || printf '%s/%s' "$_d" "$_s"
            return 0
        fi
    done
    return 1
}

# Cierre transitivo de NEEDED (punto fijo: se repite hasta no copiar nada).
NEEDED_LIST=$(mktemp "${TMPDIR:-/tmp}/graft.XXXXXX")
trap 'rm -f "$NEEDED_LIST"' EXIT INT TERM
collect_needed() {
    find "$APP" "$APP/lib" -type f 2>/dev/null | while IFS= read -r _f; do
        readelf -d "$_f" 2>/dev/null | awk '/NEEDED/ {gsub(/[\[\]]/, "", $NF); print $NF}'
    done | grep -v -e '^linux-vdso' -e '^ld-linux' | sort -u
}
COPIED=0; PASS=0
while [ "$PASS" -lt 20 ]; do
    PASS=$((PASS+1)); NEW=0
    collect_needed >"$NEEDED_LIST"
    while read -r _need; do
        [ -n "$_need" ] || continue
        if have_lib "$_need"; then continue; fi
        _src=$(find_base "$_need" || true)
        if [ -z "$_src" ] || [ ! -f "$_src" ]; then continue; fi
        cp -p "$_src" "$APP/lib/$_need"
        COPIED=$((COPIED+1)); NEW=$((NEW+1))
    done <"$NEEDED_LIST"
    [ "$NEW" -eq 0 ] && break
done
# Aviso final de lo que sigue sin resolver.
collect_needed >"$NEEDED_LIST"
while read -r _need; do
    [ -n "$_need" ] || continue
    have_lib "$_need" || echo "aviso: $_need no está en el AppDir ni en la base (puede fallar en ejecución)" >&2
done <"$NEEDED_LIST"

# Aviso sobre RPATH absolutos reales ($ORIGIN es relativo y vale).
find "$APP" -type f ! -path '*/share/*' 2>/dev/null | while IFS= read -r _f; do
    _rp=$(readelf -d "$_f" 2>/dev/null | grep -E 'RPATH|RUNPATH' | sed 's/\$ORIGIN//g' | \
          grep -o '/[^] :]*' | grep -v '^/\(\.\./\)*' | head -1)
    if [ -n "$_rp" ]; then echo "aviso: $_f tiene rpath absoluto ($_rp)" >&2; fi
done

# Stub AppRun con el loader injertado.
DESK=$(ls "$APP"/*.desktop 2>/dev/null | head -1)
[ -n "$DESK" ] || { echo "sin .desktop" >&2; exit 1; }
_BIN=$(grep -m1 '^Exec=' "$DESK" | cut -d= -f2 | awk '{print $1}')
[ -n "$_BIN" ] || { echo ".desktop sin Exec" >&2; exit 1; }
_RELBIN=""
for _c in "usr/bin/$_BIN" "bin/$_BIN" "usr/sbin/$_BIN" "$_BIN"; do
    if [ -x "$APP/$_c" ]; then _RELBIN="$_c"; break; fi
done
[ -n "$_RELBIN" ] || { echo "no se halla ejecutable $_BIN en el AppDir" >&2; exit 1; }

[ -f "$APP/AppRun.orig" ] || mv "$APP/AppRun" "$APP/AppRun.orig"
# altore.env: overrides de entorno del paquete (una línea VAR=valor; admite
# $here = dir del AppDir en ejecución). Cubre apps que localizan recursos
# vía /proc/self/exe (con loader explícito apunta al loader, no al binario).
if [ -d "$APP/usr/share/nvim/runtime" ]; then
    printf 'VIMRUNTIME=$here/usr/share/nvim/runtime\n' >"$APP/altore.env"
    echo "nota: altore.env con VIMRUNTIME (neovim localiza su runtime por exe)" >&2
fi
# Libdirs reales del árbol (nada hardcodeado: solo las que existen).
_LPDIRS=""
for _ld in lib usr/lib lib64 usr/lib64; do
    [ -d "$APP/$_ld" ] && _LPDIRS="$_LPDIRS:\$here/$_ld"
done
_LPDIRS=$(printf '%s' "$_LPDIRS" | sed 's/^://')
cat >"$APP/AppRun" <<EOF
#!/bin/sh
# Generado por alt graft-libs: usa la glibc injertada en ./lib, no la del host.
here=\$(dirname "\$(readlink -f "\$0" 2>/dev/null || echo "\$0")")
if [ -f "\$here/altore.env" ]; then set -a; . "\$here/altore.env"; set +a; fi
unset LD_LIBRARY_PATH GCONV_PATH GDK_PIXBUF_MODULE_FILE
exec "\$here/lib/$LOADER_NAME" --library-path "$_LPDIRS" "\$here/$_RELBIN" "\$@"
EOF
chmod +x "$APP/AppRun"

echo "injertadas $COPIED libs en $APP/lib (+ loader $LOADER_NAME)"
echo "binario: $_RELBIN | prueba: $APP/AppRun --version"

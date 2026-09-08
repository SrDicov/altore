#!/bin/sh
# anylinux2repo.sh — convierte un AppImage sharun/AnyLinux en paquete altore.
# Uso:
#   sh tools/anylinux2repo.sh <AppImage> <dir-repo> <nombre> <versión> "<descripción>" [bins] [--graft-from <base>]
# Ejemplo:
#   sh tools/anylinux2repo.sh ./yt-dlp.AppImage /srv/altore-repo yt-dlp 2026.08.19 \
#     "Descargador de videos de cientos de sitios"
#   sh tools/anylinux2repo.sh ./nvim.AppImage /srv/altore-repo neovim 0.12.5 \
#     "Editor modal" nvim --graft-from ~/.local/share/altore/apps/yt-dlp
#
# --graft-from injerta la glibc que le falte a un AppImage clásico (ver
# tools/graft-libs.sh): las libs copiadas byte-idénticas las deduplica el
# CAS al instalar (~0 disco extra).
#
# Hace: extrae (--appimage-extract, sin FUSE) → [injerto] → normaliza
# Hidden, AppRun ejecutable, Exec relativo) → empaqueta pool/ →
# añade/sustituye la fila en index.tsv. Ver docs/09-repos.md §5.
set -u

[ $# -ge 5 ] || { echo "uso: $0 <AppImage> <dir-repo> <nombre> <versión> \"<desc>\" [bins]" >&2; exit 2; }
IMG="$1"; REPO="$2"; NAME="$3"; VER="$4"; DESC="$5"
BINS="$3"; GRAFT_BASE=""
if [ "${6:-}" = "--graft-from" ]; then
    GRAFT_BASE="${7:-}"
elif [ "${7:-}" = "--graft-from" ]; then
    BINS="${6:-$3}"; GRAFT_BASE="${8:-}"
else
    BINS="${6:-$3}"
fi

[ -f "$IMG" ] || { echo "no existe $IMG" >&2; exit 1; }
case "$NAME" in *[!a-z0-9+._-]*|"" ) echo "nombre inválido: $NAME" >&2; exit 2;; esac
case "$DESC" in *"$(
printf '\t')"* ) echo "la descripción no puede llevar tabuladores" >&2; exit 2;; esac

T=$(mktemp -d "${TMPDIR:-/tmp}/any2repo.XXXXXX")
trap 'rm -rf "$T"' EXIT INT TERM

chmod +x "$IMG"
( cd "$T" && "$IMG" --appimage-extract >/dev/null 2>&1 ) || \
    { echo "falló --appimage-extract de $IMG" >&2; exit 1; }
# Ojo: uruntime extrae como symlink squashfs-root -> ./AppDir; find(1) no
# desciende en symlinks, así que se resuelve la ruta física primero.
APP=$(cd "$T/squashfs-root" && pwd -P) || exit 1

if [ -n "$GRAFT_BASE" ]; then
    HERE_GRAFT=$(dirname "$0")
    sh "$HERE_GRAFT/graft-libs.sh" "$APP" --from "$GRAFT_BASE" || exit 1
fi
[ -x "$APP/AppRun" ] || { echo "sin AppRun ejecutable: ¿es sharun?" >&2; exit 1; }

DESK=$(ls "$APP/$NAME.desktop" 2>/dev/null || ls "$APP"/*.desktop 2>/dev/null | head -1)
[ -n "$DESK" ] || { echo "sin .desktop en el AppDir" >&2; exit 1; }
sed -i '/^Hidden=true$/d' "$DESK"
_EXEC=$(grep -m1 '^Exec=' "$DESK" | cut -d= -f2 | awk '{print $1}')
case "$_EXEC" in /*) echo "aviso: Exec absoluto ($_EXEC), puede fallar fuera del AppImage" >&2;; esac
_icon_found=0
for _e in png svg; do
    ls "$APP"/*."$_e" >/dev/null 2>&1 && _icon_found=1
done
[ "$_icon_found" -eq 1 ] || \
    echo "aviso: sin icono png/svg (el .desktop quedará sin Icon)" >&2

mkdir -p "$REPO/pool"
PKG="$NAME-$VER.tar.gz"
# Higiene: si el AppDir se ejecutó antes de empaquetar, arrastra
# __pycache__/.pyc generados (varios MB). Fuera.
find "$APP" -type d -name '__pycache__' -prune -exec rm -rf {} + 2>/dev/null || true
tar -czf "$REPO/pool/$PKG" -C "$APP" . || exit 1
SHA=$(sha256sum "$REPO/pool/$PKG" | awk '{print $1}')
SIZE=$(wc -c <"$REPO/pool/$PKG" | tr -d ' ')
touch "$REPO/index.tsv"
TAB=$(printf '\t')
grep -v "^${NAME}${TAB}" "$REPO/index.tsv" >"$T/index" 2>/dev/null || : >"$T/index"
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$NAME" "$VER" "$DESC" "$SIZE" "$SHA" "pool/$PKG" "$BINS" >>"$T/index"
mv "$T/index" "$REPO/index.tsv"
trap - EXIT INT TERM
rm -rf "$T"

echo "paquete: $REPO/pool/$PKG ($SIZE B)"
echo "fila: $(grep "^${NAME}${TAB}" "$REPO/index.tsv")"
echo "publícalo y en el cliente: alt -u && alt -i $NAME"

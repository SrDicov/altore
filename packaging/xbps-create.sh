#!/bin/sh
# xbps-create.sh — construye altore-<ver>_<rev>.<arch>.xbps directamente
# desde este repo (sin checkout de void-packages). Uso:
#   sh packaging/xbps-create.sh [--outdir DIR]
# En CI descarga xbps estático si el host no trae xbps-create.
set -u

HERE=$(dirname "$0")
ROOT=$(readlink -f "$HERE/.." 2>/dev/null || (cd "$HERE/.." && pwd))
OUTDIR="$ROOT"
[ "${1:-}" = "--outdir" ] && { OUTDIR="$2"; mkdir -p "$OUTDIR"; }

VER=$(grep '^ALTORE_VERSION=' "$ROOT/src/alt" | cut -d'"' -f2)
[ -n "$VER" ] || { echo "no se pudo leer versión" >&2; exit 1; }
REV=1
ARCH=$(xbps-uhelper arch 2>/dev/null || uname -m)
PKG="altore-${VER}_${REV}.${ARCH}.xbps"

XBPS_CREATE="xbps-create"
if ! command -v xbps-create >/dev/null 2>&1; then
    echo "xbps-create no encontrado, descargando xbps estático..."
    need() { command -v "$1" >/dev/null 2>&1 || { echo "falta $1" >&2; exit 1; }; }
    need curl; need tar; need xz
    ST="$ROOT/packaging/work/xbps-static"
    mkdir -p "$ST"
    curl -fSL -o "$ST/xbps.tar.xz" \
        "https://repo-default.voidlinux.org/static/xbps-static-latest.${ARCH}-musl.tar.xz" || \
    curl -fSL -o "$ST/xbps.tar.xz" \
        "https://repo-default.voidlinux.org/static/xbps-static-latest.${ARCH}.tar.xz"
    tar -xf "$ST/xbps.tar.xz" -C "$ST"
    XBPS_CREATE="$ST/usr/bin/xbps-create"
fi

WORK="$ROOT/packaging/work/destdir"
rm -rf "$WORK"
mkdir -p "$WORK/usr/bin" "$WORK/usr/share/doc/altore" \
         "$WORK/usr/share/examples/altore"
install -m755 "$ROOT/src/alt" "$WORK/usr/bin/alt"
ln -s alt "$WORK/usr/bin/altore"
cp "$ROOT/README.md" "$ROOT/docs/08-cli.md" "$WORK/usr/share/doc/altore/"
printf '# Repos de Altore: "<nombre> <url-raíz>" (un repo por línea).\n# La raíz contiene index.tsv + pool/. Acepta https:// y file://.\n' \
    >"$WORK/usr/share/examples/altore/repos.conf.example"
cp "$ROOT/LICENSE" "$WORK/usr/share/doc/altore/"

( cd "$OUTDIR" && "$XBPS_CREATE" \
    -A "$ARCH" \
    -n "altore-${VER}_${REV}" \
    -s "Software glibc en PCs musl: ligero, instantáneo, simple" \
    -D "curl>=0 tar>=0 gzip>=0 coreutils>=0 findutils>=0 gawk>=0 grep>=0 sed>=0" \
    -l "MIT" \
    -m "SrDicov <SrDicov@users.noreply.github.com>" \
    -H "https://github.com/SrDicov/altore" \
    "$WORK" ) || exit 1

echo "paquete: $OUTDIR/$PKG"
ls -la "$OUTDIR/$PKG"

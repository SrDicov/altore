#!/bin/sh
# mkanylinux-catalog.sh — genera un repo alt (solo índice) con TODO AnyLinux.
# Uso: sh tools/mkanylinux-catalog.sh <dir-salida>
# Requiere: gh (autenticado), jq.
#
# Las filas apuntan DIRECTO a los assets de GitHub (URL absoluta, sin sha:
# pkgforge no publica sha256; alt verifica por tamaño e informa). Los bins
# se descubren al instalar desde el .desktop. Ver docs/09-repos.md §4.
#
# Paralelo (xargs -P8): ~500 repos en ~10 min. Requiere gh+jq.
set -u

[ $# -eq 1 ] || { echo "uso: $0 <dir-salida>" >&2; exit 2; }
OUT="$1"
command -v gh >/dev/null 2>&1 || { echo "falta gh" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "falta jq" >&2; exit 1; }
command -v xargs >/dev/null 2>&1 || { echo "falta xargs" >&2; exit 1; }

HERE=$(dirname "$0")
mkdir -p "$OUT"
TMPJ=$(mktemp -d "${TMPDIR:-/tmp}/anycat.XXXXXX")
trap 'rm -rf "$TMPJ"' EXIT INT TERM
mkdir -p "$TMPJ/rows"

echo "listando repos pkgforge-dev..." >&2
gh api "orgs/pkgforge-dev/repos?per_page=100&type=all" --paginate \
    -q '.[] | select(.name | test("^[^-].*-AppImage([-.]|$)"; "i")) | "\(.name)\t\(.description // "")"' \
    >"$TMPJ/repos.tsv" 2>/dev/null || { echo "falló listado de repos" >&2; exit 1; }
TOTAL=$(wc -l <"$TMPJ/repos.tsv" | tr -d ' ')
echo "$TOTAL repos candidatos, procesando de 8 en 8..." >&2

xargs -P8 -d'\n' -I{} sh "$HERE/catalog-one.sh" "$TMPJ/rows" "{}" <"$TMPJ/repos.tsv" 2>"$TMPJ/warn.log" || true
grep -v '^aviso' "$TMPJ/warn.log" 2>/dev/null | head -5 >&2 || true
grep -c '^aviso' "$TMPJ/warn.log" 2>/dev/null | xargs -I{} echo "{} avisos (omitidos con motivo)" >&2 || true

# Ensambla: una fila por fichero no vacío; colisiones → primera alfabética.
cat "$TMPJ"/rows/*.tsv 2>/dev/null | grep . | sort -u -t'	' -k1,1 >"$TMPJ/all.tsv" || : >"$TMPJ/all.tsv"
cut -f1 "$TMPJ/all.tsv" | sort | uniq -d >"$TMPJ/dupes" || true
if [ -s "$TMPJ/dupes" ]; then
    echo "colisiones resueltas (primera): $(tr '\n' ' ' <"$TMPJ/dupes")" >&2
    grep -v -F -f "$TMPJ/dupes" "$TMPJ/all.tsv" >"$TMPJ/rest.tsv" || true
    while read -r _d; do grep -m1 "^$_d	" "$TMPJ/all.tsv"; done <"$TMPJ/dupes" >>"$TMPJ/rest.tsv"
    sort -t'	' -k1,1 "$TMPJ/rest.tsv" -o "$TMPJ/all.tsv"
fi
cp "$TMPJ/all.tsv" "$OUT/index.tsv"
OK=$(wc -l <"$OUT/index.tsv" | tr -d ' ')
echo "catálogo: $OK paquetes en $OUT/index.tsv" >&2

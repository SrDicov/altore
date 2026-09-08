#!/bin/sh
# catalog-one.sh — procesa UN repo pkgforge → fila TSV (para xargs paralelo).
# Uso: sh tools/catalog-one.sh <dir-filas> "repo<TAB>desc"
# Escribe <dir-filas>/<repo>.tsv (una fila, o vacío si se omite). Avisos a stderr.
set -u
ROWD="$1"
TAB=$(printf '\t')
REPO=${2%%"$TAB"*}; DESC=${2#*"$TAB"}
[ "$DESC" = "$2" ] && DESC=""

norm_name() {
    printf '%s' "$1" | sed -e 's/-[Aa][Pp][Pp][Ii][Mm][Aa][Gg][Ee]\(-[Ee][Nn][Hh][Aa][Nn][Cc][Ee][Dd]\)\?$//' \
        -e 's/-[Ee][Nn][Hh][Aa][Nn][Cc][Ee][Dd]$//' | tr '[:upper:]_ ' '[:lower:]--'
}

NAME=$(norm_name "$REPO")
case "$NAME" in ""|*[!a-z0-9+._-]*)
    echo "aviso: nombre no válido: $REPO → $NAME (omitido)" >&2
    : >"$ROWD/$REPO.tsv"; exit 0;;
esac

REL=$(gh api "repos/pkgforge-dev/$REPO/releases/latest" 2>/dev/null)
[ -n "$REL" ] || { echo "aviso: $REPO sin releases (omitido)" >&2; : >"$ROWD/$REPO.tsv"; exit 0; }
ASSET=$(printf '%s' "$REL" | jq -r '
    (.assets // []) |
    [ .[] | select(.name | test("\\.AppImage$"; "i")) ] |
    ((map(select(.name | test("x86_64|amd64"; "i"))) | .[0]) // .[0] // empty) |
    "\(.size)\t\(.browser_download_url)"' 2>/dev/null)
[ -n "$ASSET" ] || { echo "aviso: $REPO sin AppImage x86_64 (omitido)" >&2; : >"$ROWD/$REPO.tsv"; exit 0; }
SIZE=$(printf '%s' "$ASSET" | cut -f1)
URL=$(printf '%s' "$ASSET" | cut -f2-)
TAG=$(printf '%s' "$REL" | jq -r '.tag_name // ""')
VER=$(printf '%s' "$TAG" | cut -d@ -f1 | sed 's/^[vV]//')
[ -n "$VER" ] || VER="$TAG"
D=$(printf '%s' "$DESC" | tr '\t\n' '  ' | cut -c1-120)
[ -n "$D" ] || D="AppImage AnyLinux: $NAME"
printf '%s\t%s\t%s\t%s\t\t%s\t\n' "$NAME" "$VER" "$D" "$SIZE" "$URL" >"$ROWD/$REPO.tsv"

#!/bin/sh
# mkdemo.sh — construye el repo demo (fixtures) para tests.
# Uso: sh tests/mkdemo.sh
# Lee tests/demo-src/<pkg>/{VERSION,DESC,BINS,app/...} y genera
# tests/fixture/repo/{index.tsv,pool/<pkg>-<ver>.tar.gz}.
set -u
HERE=$(dirname "$0")
SRC="$HERE/demo-src"
OUT="$HERE/fixture/repo"
POOL="$OUT/pool"

mkdir -p "$POOL"
: >"$OUT/index.tsv"

for d in "$SRC"/*; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    ver=$(cat "$d/VERSION" | tr -d ' \n')
    desc=$(cat "$d/DESC")
    bins=$(cat "$d/BINS" | tr -d ' \n')
    main=$(printf '%s' "$bins" | cut -d, -f1)
    st=$(mktemp -d)
    cp -a "$d/app/." "$st/"
    # AppRun con versión inyectada
    sed "s/__VER__/$ver/g; s/__NAME__/$name/g" "$d/app/AppRun" >"$st/AppRun"
    chmod +x "$st/AppRun"
    cat >"$st/$name.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$name
Comment=$desc
Exec=$main
Icon=icon.png
Categories=Utility;
EOF
    printf 'fake-icon-%s' "$name" >"$st/icon.png"
    # tar portable (funciona con GNU, bsdtar y busybox tar)
    tar -czf "$POOL/$name-$ver.tar.gz" -C "$st" .
    rm -rf "$st"
    sha=$(sha256sum "$POOL/$name-$ver.tar.gz" | awk '{print $1}')
    size=$(stat -c%s "$POOL/$name-$ver.tar.gz")
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$name" "$ver" "$desc" "$size" "$sha" \
        "pool/$name-$ver.tar.gz" "$bins" >>"$OUT/index.tsv"
    echo "demo: $name $ver ($size B)"
done
echo "demo: índice en $OUT/index.tsv"

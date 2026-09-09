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
    term=$(cat "$d/TERMINAL" 2>/dev/null || printf 'false')
    cat >"$st/$name.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$name
Comment=$desc
Exec=$main
Icon=icon.png
Terminal=$term
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

# Repo "remoto" (filas de catálogo: URL absoluta, sin sha256, sin bins).
# Prueba el flujo de catálogo: verificación por tamaño + bins descubiertos.
ROUT="$HERE/fixture/remote"
RPOOL="$ROUT/pool"
mkdir -p "$RPOOL"
st2=$(mktemp -d)
mkdir -p "$st2/usr/bin"
printf '#!/bin/sh\necho "HELLO remoteprobe 0.9 args:$*"\n' >"$st2/AppRun"
chmod +x "$st2/AppRun"
printf '#!/bin/sh\necho "BIN remoteprobe running"\n' >"$st2/usr/bin/remoteprobe"
chmod +x "$st2/usr/bin/remoteprobe"
cat >"$st2/remoteprobe.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=remoteprobe
Comment=Sonda de catalogo remoto
Exec=remoteprobe
Icon=icon.png
Categories=Utility;
EOF
printf 'fake-icon-remote' >"$st2/icon.png"
tar -czf "$RPOOL/remoteprobe-0.9.tar.gz" -C "$st2" .
rm -rf "$st2"
size=$(stat -c%s "$RPOOL/remoteprobe-0.9.tar.gz")
printf 'remoteprobe\t0.9\tSonda de catalogo remoto\t%s\t\tfile://%s/remoteprobe-0.9.tar.gz\t\n' \
    "$size" "$RPOOL" >"$ROUT/index.tsv"
echo "demo: repo remoto en $ROUT/index.tsv"

# AppImage falso (script auto-extraíble): prueba la rama de instalación
# directa desde .AppImage (catálogo remoto real).
st3=$(mktemp -d)
mkdir -p "$st3/usr/bin"
printf '#!/bin/sh\necho "HELLO directapp 1.0 args:$*"\n' >"$st3/AppRun"
chmod +x "$st3/AppRun"
printf '#!/bin/sh\necho "BIN directapp running"\n' >"$st3/usr/bin/directapp"
chmod +x "$st3/usr/bin/directapp"
cat >"$st3/directapp.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=directapp
Comment=AppImage falso para tests
Exec=directapp
Icon=icon.png
Categories=Utility;
EOF
printf 'fake-icon-direct' >"$st3/icon.png"
PAYLOAD=$(tar -czf - -C "$st3" . | base64 | tr -d '\n')
rm -rf "$st3"
{
printf '#!/bin/sh\n# Fake AppImage para tests de alt (solo --appimage-extract).\n'
printf 'if [ "${1:-}" = "--appimage-extract" ]; then\n'
printf '  mkdir -p squashfs-root\n'
printf '  awk "/^__PAYLOAD__$/{f=1;next} f" "$0" | base64 -d | tar -xzf - -C squashfs-root\n'
printf '  exit $?\nfi\necho "fake-appimage sin instalar"\nexit 0\n__PAYLOAD__\n'
printf '%s\n' "$PAYLOAD"
} >"$RPOOL/directapp-1.0.AppImage"
chmod +x "$RPOOL/directapp-1.0.AppImage"
size=$(stat -c%s "$RPOOL/directapp-1.0.AppImage")
printf 'directapp\t1.0\tAppImage falso para tests\t%s\t\tfile://%s/directapp-1.0.AppImage\t\n' \
    "$size" "$RPOOL" >>"$ROUT/index.tsv"
echo "demo: AppImage falso en $RPOOL/directapp-1.0.AppImage"

# Paquete con Exec absoluto (/opt/...): los bins se reducen a basename.
st4=$(mktemp -d)
mkdir -p "$st4/opt/abspath/bin"
printf '#!/bin/sh\necho "HELLO abspath 1.0 args:$*"\n' >"$st4/opt/abspath/bin/abspath"
chmod +x "$st4/opt/abspath/bin/abspath"
printf '#!/bin/sh\nexec "$(dirname "$0")/opt/abspath/bin/abspath" "$@"\n' >"$st4/AppRun"
chmod +x "$st4/AppRun"
cat >"$st4/abspath.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=abspath
Comment=Exec absoluto para tests
Exec=/opt/abspath/bin/abspath %U
Icon=icon.png
Categories=Utility;
EOF
printf 'fake-icon-abs' >"$st4/icon.png"
tar -czf "$RPOOL/abspath-1.0.tar.gz" -C "$st4" .
rm -rf "$st4"
size=$(stat -c%s "$RPOOL/abspath-1.0.tar.gz")
sha=$(sha256sum "$RPOOL/abspath-1.0.tar.gz" | awk '{print $1}')
printf 'abspath\t1.0\tExec absoluto para tests\t%s\t%s\tpool/abspath-1.0.tar.gz\t\n' \
    "$size" "$sha" >>"$ROUT/index.tsv"
echo "demo: paquete abspath en repo remoto"

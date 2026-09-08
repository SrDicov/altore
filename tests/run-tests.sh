#!/bin/sh
# run-tests.sh — suite funcional de altore contra el repo demo.
# Uso: sh tests/run-tests.sh
# Todo ocurre en un HOME temporal; no toca el sistema.
set -u

HERE=$(dirname "$0")
ROOT=$(readlink -f "$HERE/.." 2>/dev/null || (cd "$HERE/.." && pwd))
ALT="$ROOT/src/altore"
PASS=0; FAIL=0

T=$(mktemp -d "${TMPDIR:-/tmp}/altore-test.XXXXXX")
export ALTORE_HOME="$T/home" ALTORE_BIN="$T/bin"
export XDG_DATA_HOME="$T/xdg" HOME="$T/fakehome"
mkdir -p "$ALTORE_HOME" "$ALTORE_BIN" "$XDG_DATA_HOME" "$HOME"
printf 'demo  file://%s/tests/fixture/repo\n' "$ROOT" >"$ALTORE_HOME/repos.conf"

ok()   { PASS=$((PASS+1)); printf 'ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf 'FAIL %s\n%s\n' "$1" "${2:-}"; }
is_eq() { # is_eq <desc> <esperado> <obtenido>
    if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "  esperado: [$2]  obtenido: [$3]"; fi
}
contains() { # contains <desc> <aguja> <pajar>
    case "$3" in *"$2"*) ok "$1";; *) bad "$1" "  no contiene [$2] en: $3";; esac
}

A() { sh "$ALT" "$@"; }  # invoca altore con dash (igual que /bin/sh)

# 1. sync + search
out=$(A -u 2>&1); contains "sync inicial" "4 paquetes conocidos" "$out"
out=$(A -s brave 2>&1); rc=$?
is_eq "search brave rc" "0" "$rc"
contains "search brave halla brave-bin" "brave-bin" "$out"
contains "search brave halla brave-nightly" "brave-nightly" "$out"
A -s zzzzzz >/dev/null 2>&1; is_eq "search sin resultados rc=3" "3" "$?"

# 2. install exacto + run + list + info
A -i brave-bin >/dev/null 2>&1; is_eq "install brave-bin rc" "0" "$?"
[ -x "$ALTORE_HOME/apps/brave-bin/AppRun" ] && ok "AppRun instalado" || bad "AppRun instalado"
[ -x "$ALTORE_BIN/brave" ] && [ -x "$ALTORE_BIN/brave-browser" ] && ok "shims brave" || bad "shims brave"
out=$("$ALTORE_BIN/brave" hola 2>&1); is_eq "shim ejecuta y pasa args" "HELLO brave-bin 1.0 args:hola" "$out"
out=$(A brave mundo 2>&1); is_eq "atl PKG atajo run" "HELLO brave-bin 1.0 args:mundo" "$out"
out=$(A -l 2>&1); contains "list muestra brave-bin" "brave-bin  1.0" "$out"
out=$(A -I freetube 2>&1); contains "info freetube no instalado" "no instalado" "$out"
contains "info freetube sugiere -i" "atl -i freetube" "$out"

# 3. install con picker (un candidato inexacto) + cancelación con n
out=$(printf '1\n' | A -i tube 2>&1); is_eq "install tube eligiendo 1" "0" "$?"
[ -x "$ALTORE_HOME/apps/freetube/AppRun" ] && ok "freetube instalado vía picker" || bad "freetube instalado vía picker"
printf 'n\n' | A -i studio >/dev/null 2>&1; is_eq "install studio con n cancela" "0" "$?"
[ -e "$ALTORE_HOME/apps/obs-studio" ] && bad "studio cancelado no instala" || ok "studio cancelado no instala"

# 4. remove de no-instalado + remove real + gc conserva lo compartido
A -R obs >/dev/null 2>&1; is_eq "remove no-instalado rc=3" "3" "$?"
A -i obs-studio >/dev/null 2>&1
i1=$(stat -c %i "$ALTORE_HOME/apps/brave-bin/usr/lib/common/libcommon.so")
i2=$(stat -c %i "$ALTORE_HOME/apps/obs-studio/usr/lib/common/libcommon.so")
is_eq "dedup: libcommon mismo inodo" "$i1" "$i2"
nblob=$(find "$ALTORE_HOME/store" -type f | wc -l | tr -d ' ')
[ "$nblob" -lt 20 ] && ok "store deduplica ($nblob blobs)" || bad "store deduplica" "$nblob blobs"
A -R obs-studio >/dev/null 2>&1; is_eq "remove obs-studio rc" "0" "$?"
[ -e "$ALTORE_HOME/apps/obs-studio" ] && bad "obs-studio borrado" || ok "obs-studio borrado"
[ -e "$ALTORE_BIN/obs" ] && bad "shim obs borrado" || ok "shim obs borrado"
[ -f "$ALTORE_HOME/apps/brave-bin/usr/lib/common/libcommon.so" ] && ok "lib común sigue para brave" || bad "lib común sigue para brave"
out=$(A gc 2>&1); contains "gc libera" "liberados" "$out"
[ -f "$ALTORE_HOME/apps/freetube/usr/lib/common/libcommon.so" ] && ok "gc no rompe freetube" || bad "gc no rompe freetube"

# 5. update de un paquete (bump de versión en el repo demo)
printf '1.1' >"$ROOT/tests/demo-src/brave-bin/VERSION"
sh "$ROOT/tests/mkdemo.sh" >/dev/null 2>&1
out=$(A -u brave-bin 2>&1); contains "update brave-bin" "instalado brave-bin 1.1" "$out"
out=$("$ALTORE_BIN/brave" 2>&1); is_eq "tras update corre 1.1" "HELLO brave-bin 1.1 args:" "$out"
out=$(A -u brave-bin 2>&1); contains "update al día" "al día" "$out"
A -u noexiste >/dev/null 2>&1; is_eq "update no-instalado rc=3" "3" "$?"
printf '1.0' >"$ROOT/tests/demo-src/brave-bin/VERSION"  # restaura fixture
sh "$ROOT/tests/mkdemo.sh" >/dev/null 2>&1
A -u >/dev/null 2>&1  # re-sincroniza tras regenerar fixtures

# 6. listg / -I ambiguo / flags varios
out=$(A -lg 2>&1); contains "listg agrupa por repo" "== demo ==" "$out"
out=$(A -lg demo 2>&1); contains "listg demo filtra" "freetube" "$out"
A -lg norepo >/dev/null 2>&1; is_eq "listg repo malo rc=3" "3" "$?"
out=$(A -v 2>&1); contains "version" "altore 0.1.0" "$out"
A -h >/dev/null 2>&1; is_eq "help rc" "0" "$?"
A --bogus >/dev/null 2>&1; is_eq "flag desconocido rc=2" "2" "$?"
out=$(printf 'n\n' | A -I brave 2>&1); contains "info ambiguo cancelable" "Se encontraron" "$out"
out=$(ALTORE_NONINTERACTIVE=1 sh "$ALT" -i brave 2>&1); contains "noninteractive cancela" "cancelado" "$out"
out=$(A doctor 2>&1); is_eq "doctor rc" "0" "$?"

# 7. run instala-y-ejecuta si falta (vía picker)
[ -e "$ALTORE_HOME/apps/obs-studio" ] && rm -rf "$ALTORE_HOME/apps/obs-studio"
out=$(printf '1\n' | A obs-studio under test 2>&1 | tail -1)
is_eq "run instala y ejecuta" "HELLO obs-studio 2.0 args:under test" "$out"

rm -rf "$T"
printf '\n=== %d ok, %d fallos ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]

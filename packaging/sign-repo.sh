#!/bin/sh
# sign-repo.sh — firma un repo xbps de Altore y emite la clave pública.
# Uso: sh packaging/sign-repo.sh <dir-del-repo>
#
# Hace:
#   1. Genera packaging/keys/altore-priv.pem si no existe
#      (RSA tradicional 4096; la PRIVADA no se sube a git jamás).
#   2. Firma cada .xbps (-S), reindexa (-a) y firma repodata (-s).
#   3. Genera packaging/keys/<fingerprint>.plist (pública, SÍ se publica)
#      e imprime el fingerprint y cómo instalarlo en clientes.
#
# Fondo: xbps >=0.60 descarta repos sin firmar en silencio; la clave del
# cliente debe llamarse <fingerprint-md5-ssh>.plist (ver SIGNING.md).
set -u

[ $# -eq 1 ] || { echo "uso: $0 <dir-del-repo>" >&2; exit 2; }
REPODIR="$1"
[ -d "$REPODIR" ] || { echo "no existe $REPODIR" >&2; exit 1; }

HERE=$(dirname "$0")
ROOT=$(readlink -f "$HERE/.." 2>/dev/null || (cd "$HERE/.." && pwd))
KEYD="$ROOT/packaging/keys"
PRIV="$KEYD/altore-priv.pem"
PUB="$KEYD/altore-pub.pem"
SIGNEDBY="Altore Repo"

command -v xbps-rindex >/dev/null 2>&1 || { echo "falta xbps-rindex" >&2; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "falta openssl" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "falta python3" >&2; exit 1; }

mkdir -p "$KEYD"
if [ ! -f "$PRIV" ]; then
    # Tradicional ("RSA PRIVATE KEY"): xbps usa PEM_read_RSAPrivateKey.
    openssl genrsa -traditional -out "$PRIV" 4096 2>/dev/null || \
        openssl rsa -in "$(openssl genrsa -out "$KEYD/tmp.pem" 4096 2>/dev/null; printf '%s' "$KEYD/tmp.pem")" \
            -out "$PRIV" 2>/dev/null
    rm -f "$KEYD/tmp.pem"
    chmod 600 "$PRIV"
    echo "generada $PRIV (NO commitear; ver .gitignore)"
fi
openssl rsa -in "$PRIV" -pubout -out "$PUB" 2>/dev/null || exit 1

for p in "$REPODIR"/*.xbps; do
    [ -f "$p" ] || continue
    xbps-rindex --privkey "$PRIV" --signedby "$SIGNEDBY" -S "$p" || exit 1
done
xbps-rindex --privkey "$PRIV" --signedby "$SIGNEDBY" -a "$REPODIR"/*.xbps || exit 1
xbps-rindex --privkey "$PRIV" --signedby "$SIGNEDBY" -s "$REPODIR" || exit 1

# Fingerprint = MD5 del blob SSH (mismo algoritmo que xbps_pubkey2fp).
FP=$(python3 - "$PUB" <<'EOF'
import sys, hashlib, subprocess, re
pub = sys.argv[1]
out = subprocess.run(['openssl', 'rsa', '-pubin', '-in', pub, '-text', '-noout'],
                     capture_output=True, text=True).stdout
mod = re.search(r'modulus:\s+((?:[0-9a-f]{2}:?\s*)+)', out, re.I).group(1)
n = bytes(int(b, 16) for b in re.findall(r'[0-9a-f]{2}', mod, re.I))
e = int(re.search(r'xponent:\s*(\d+)', out).group(1))
eb = e.to_bytes((e.bit_length() + 7) // 8, 'big') or b'\x00'
def enc(b):
    return (b'\x00' + b if b[0] & 0x80 else b)
blob = b'\x00\x00\x00\x07ssh-rsa'
for b in (enc(eb), enc(n)):
    blob += len(b).to_bytes(4, 'big') + b
print(':'.join('%02x' % x for x in hashlib.md5(blob).digest()))
EOF
) || exit 1

python3 - "$PUB" "$KEYD/$FP.plist" <<'EOF'
import plistlib, sys
pub = open(sys.argv[1], 'rb').read()
d = {'public-key': pub, 'public-key-size': 4096, 'signature-by': 'Altore Repo'}
open(sys.argv[2], 'wb').write(plistlib.dumps(d))
EOF

echo "fingerprint: $FP"
echo "clave pública: packaging/keys/$FP.plist"
echo "En cada cliente (una vez):"
echo "  sudo install -m644 packaging/keys/$FP.plist /var/db/xbps/keys/"
echo "  echo 'repository=<url-del-repo>' | sudo tee /etc/xbps.d/90-altore.conf"
echo "  sudo xbps-install -Sy altore"

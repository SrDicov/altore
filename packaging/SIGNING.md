# Firmar repos xbps de Altore

## Por qué

xbps (≥0.60) **descarta en silencio** los repos sin firmar: el paquete no
aparece y no hay error útil (solo se ve con `xbps-install -d`: `[repo]
'<url>' removed`). Todo repo Altore que se distribuya debe ir firmado.

## Procedimiento

```bash
sh packaging/xbps-create.sh --outdir repo/   # construye el .xbps
sh packaging/sign-repo.sh repo/              # firma + genera clave pública
```

`sign-repo.sh` genera `packaging/keys/altore-priv.pem` (RSA 4096
tradicional) la primera vez. **Esa clave privada no se commitea**
(`.gitignore` la excluye): quien la posea puede publicar paquetes como
"Altore". Guardarla fuera del repo; en releases la custodia CI (secreto).

## Lado cliente (una vez por PC)

```bash
sudo install -m644 packaging/keys/<fingerprint>.plist /var/db/xbps/keys/
echo 'repository=https://repo.ejemplo.com/altore' | sudo tee /etc/xbps.d/90-altore.conf
sudo xbps-install -Sy altore
```

Notas duras, verificadas contra la fuente de xbps (`lib/repo.c`,
`lib/pubkey2fp.c`, `bin/xbps-rindex/sign.c`):

- El fichero de clave debe llamarse `<fingerprint>.plist`, donde fingerprint
  es el MD5 del blob SSH de la clave (`xbps_pubkey2fp`), con formato
  `aa:bb:...` (16 pares). Con otro nombre, xbps no la encuentra y descarta
  el repo sin decir por qué.
- El `<data>` del plist es el PEM `PUBLIC KEY` en crudo (plistlib lo codifica
  a base64 al escribir; no pre-codificar).
- La privada debe ser RSA **tradicional** (`-----BEGIN RSA PRIVATE KEY-----`;
  `openssl genrsa -traditional`). xbps la lee con `PEM_read_RSAPrivateKey` y
  rechaza el formato PKCS#8 (`BEGIN PRIVATE KEY`).
- `signature-by` del plist debe coincidir con el `--signedby` del firmado.
- En roots de test: `XBPS_ARCH=x86_64-musl xbps-install -r <root> ...` (sin
  la variable, el arch cae a `x86_64` y el repo "no existe").

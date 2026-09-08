# 09 — Formato de repos y paquetes (v1)

Cómo se publica un paquete Altore (origen AnyLinux convertido o paquete
propio del equipo) y cómo lo consume el cliente sin dependencias extra.

## 1. Decisión base: índice TSV, cero dependencias en cliente

El cliente (`src/alt`, shell POSIX) **no usa `jq` ni `python`**: el índice
que viaja y se cachea es `index.tsv` (tabuladores, UTF-8, una línea por
paquete). Se parsea con `awk`. Quien prefiera mantener catálogo en JSON usa
la herramienta `tools/json2tsv.sh` (requiere `jq`, solo en el lado
publicación, jamás en el PC del usuario).

## 2. Layout de un repo

```
https://ejemplo.com/altore-repo/   (o file:///ruta, o cualquier http dir)
  index.tsv
  pool/<paquete>-<versión>.tar.zst   (zst preferido; .tar.gz/.tar.xz válidos)
```

`repos.conf` del cliente (una línea por repo, `#` comentarios):

```
# nombre  url-raíz
demo    file:///home/dicov/Altore/tests/fixture/repo
propio  https://repo.ejemplo.com/altore
```

## 3. `index.tsv` — columnas (TODAS obligatorias, en este orden)

```
nombre  versión  descripción-corta  tamaño-bytes  sha256  url-relativa  binarios
```

- `nombre`: `[a-z0-9][a-z0-9+._-]*` (minúsculas, sin espacios).
- `versión`:comparable con `sort -V` (ej `1.40.4`, `2.1.r3`).
- `descripción-corta`: 1 línea, sin tabuladores, ≤120 car., español.
- `tamaño-bytes`: entero del tarball (informativo).
- `sha256`: hex del tarball. Verificación **obligatoria** antes de extraer.
- `url-relativa`: `pool/...` relativo a la raíz del repo.
- `binarios`: coma-separado, sin espacios (`brave,brave-browser`); el primero
  es el principal (shim + `.desktop` lo usan).

Ejemplo:

```
brave-bin	1.40.4	Navegador Brave, binario oficial con su glibc	48211320	9f2c…a41	pool/brave-bin-1.40.4.tar.zst	brave,brave-browser
```

## 4. Contenido del tarball (AppDir mínimo válido)

```
<AppDir>/
  AppRun            # ejecutable: lanza la app (loader trick en real; script en demo)
  <nombre>.desktop  # .desktop válido (Name, Exec=<bin-principal>, Icon, Categories)
  <icono>.*         # png o svg referenciado por Icon=
  <árbol de la app> # usr/bin/..., usr/lib/...
```

`AppRun` real (sharun): `ld-linux --library-path ... <bin> "$@"` + saneo de
entorno + fix `/proc/self/exe` (ver `docs/04-como-funciona.md`). El instalador
no exige estructura interna concreta: enlaza **todo** el árbol tal cual.

## 5. Conversión AnyLinux → repo Altore (procedimiento, no magia)

1. Tomar el AppImage sharun de pkgforge + su digest publicado.
2. Verificar digest. Extraer AppDir (`--appimage-extract`).
3. Normalizar: `AppRun` ejecutable, `.desktop` con `Exec` = binario principal
   sin rutas absolutas y sin `Hidden=true`, icono presente. **No ejecutar el
   AppDir antes de empaquetar** (o podar `__pycache__`: Python genera `.pyc`
   en la primera ejecución y engordan el paquete varios MB; la herramienta
   `tools/anylinux2repo.sh` ya lo hace).
4. Empaquetar `tar --zstd -cf pool/<n>-<v>.tar.zst -C <AppDir> .`
   (reproducible: `--sort-name --mtime=@0 --owner=0 --group=0`).
5. Añadir fila a `index.tsv` con sha256 real. Firmar el commit que lo añade
   (trazabilidad; firma de artefactos v2).

## 6. Caché e índice unificado en cliente

```
$ALTORE_HOME/
  repos/<nombre>.index.tsv   # última sincronización por repo
  index.tsv                  # unificado: <repo>\t + fila original
  store/<hh>/<sha256>        # blobs por contenido, a-w
  apps/<nombre>/             # árbol por hardlinks + manifest + blobs.tsv
  cache/<nombre>-<versión>.tar.*  # descargas (reanudables con curl -C -)
```

`apps/<nombre>/manifest` (parseable por shell, valores con comilla simple):

```
name='brave-bin'
version='1.40.4'
repo='propio'
desc='...'
size='48211320'
bins='brave,brave-browser'
```

`apps/<nombre>/blobs.tsv`: `<sha256>\t<ruta-relativa>` por cada fichero
regular (fuente de verdad para `gc`).

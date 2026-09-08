# 04 — Cómo funciona Altore

Explicación completa del mecanismo, de principio a fin, sin asumir
conocimientos previos más allá de "he usado Linux".

## 0. La idea física en 3 frases

Al kernel de Linux le dan igual musl y glibc: un programa solo hace *syscalls*
(abrir archivos, red, GPU…), idénticas en ambos. `musl` y `glibc` son solo
bibliotecas que traducen a esos syscalls. Si le das al programa **su glibc
propia**, corre en cualquier kernel, incluido el de tu Void-musl.

## 1. Cómo un programa encuentra (o no) su glibc

Todo ejecutable Linux lleva escrita dentro una ruta `INTERP`: el *cargador*
que el kernel arranca primero, y que a su vez carga el resto de librerías.
Ejemplo: `/lib64/ld-linux-x86-64.so.2` (glibc) o `/lib/ld-musl-x86-64.so.1`
(musl). En tu musl no hay cargador glibc → un binario glibc muere al nacer
("No such file or directory" aunque el archivo exista: lo que falta es su
intérprete).

Altore no deja que el kernel elija: **invoca el cargador bundlado a mano**:

```bash
~/.local/share/altore/store/<hash>/ld-linux-x86-64.so.2 \
  --library-path ~/.local/share/altore/store/<hashes...>/lib \
  ~/.local/share/altore/apps/brave/bin/brave "$@"
```

Desde ese instante, para ese programa musl no existe: `libc.so.6`, Mesa, GTK…
todo sale del store.

## 2. Por qué `--library-path` y no `LD_LIBRARY_PATH`

`LD_LIBRARY_PATH` es una variable de entorno: **se hereda** a cada proceso
hijo que el programa lance, contaminándolo con librerías ajenas (crashes
legendarios y dificilísimos de depurar). `--library-path` es un flag del
cargador: tiene la misma prioridad de búsqueda pero **muere con esa
ejecución**. Además un shim limpia variables heredadas (`LD_LIBRARY_PATH`,
`GCONV_PATH`…). Detalle fino heredado de sharun: `/proc/self/exe` debe apuntar al
binario real y no al cargador; el wrapper lo corrige.

Orden de búsqueda resultante para cada librería: rutas bundladas
(`--library-path`) → `rpath $ORIGIN` → caché del host → `/usr/lib` del host.
Lo bundlado siempre gana; el host solo aparece como último recurso para
librerías opcionales (p. ej. el tema GTK del sistema).

## 3. Por qué no basta con "mapear solo glibc" (la pregunta del millón)

Porque **en un proceso solo cabe UNA libc**: todo comparte memoria y las
estructuras internas (`malloc`, hilos, `errno`, locales) son incompatibles
entre musl y glibc. Una lib musl dentro de un proceso glibc (o al revés) es
corrupción garantizada. La prueba viviente es `gcompat`: sirve para binarios
simples, se rompe con programas serios. Ni glibc-con-glibc es seguro
(símbolos versionados distintos por distro). Conclusión: hay que traer el
**grafo completo consistente** (una libc, un allocator, un threading). Eso es
exactamente lo que guarda el store, ni más ni menos.

## 4. Instalación: extraer una vez, deducir siempre

`altore get brave` hace esto, en orden:

1. **Resuelve** el paquete en el catálogo (nombre → manifiesto + URL del
   AppDir/AppImage + hash esperado).
2. **Descarga** el artefacto (comprimido con DwarFS/zstd para transporte;
   resumo: poco peso en red).
3. **Verifica** el hash. Si no cuadra, se descarta. Sin excepciones.
4. **Extrae** el AppDir a un temporal.
5. **Parte por contenido**: cada archivo se guarda en
   `store/<sha256-de-su-contenido>` **solo si ese hash no existe ya**. Si
   existe, no se copia nada: se reutiliza.
6. **Enlaza** el árbol de la app (`apps/brave/...`) con *hardlinks* a esos
   hashes. Resultado: 50 apps comparten una sola copia de cada archivo común.
   Primera app con base nueva ≈ 150-250MB; las siguientes, solo su delta.
7. **Registra** en `db.json` qué hashes usa cada app (imprescindible para el
   `gc` posterior) y **exporta** `~/.local/bin/brave` (shim) + `.desktop` al
   menú.

## 5. Ejecución: el camino más corto posible

`brave` (shim) → `altore run brave` → `exec` directo del cargador bundlado
con sus rutas. **Nada en medio**: sin montar FUSE, sin namespaces, sin root,
sin daemon, sin sandbox. Por eso el arranque es clase nix (milisegundos):
ejecutar es literalmente ejecutar.

Casos especiales, en orden:
- **Binario suelto del usuario** (`altore run --universal ~/apps/juego):
  delega a **Conty-minimal + auto-deps** (detecta libs faltantes con `ldd`,
  las instala en overlay, ejecuta). Es el fallback universal ya probado.
- **Mezcla 32/64-bit, wine/steam**: siempre vía Conty (sharun no cubre bien
  ese terreno; documentado por los propios autores de sharun).
- **Binario musl del host**: se rechaza con mensaje claro ("recompila dentro
  o en estático"); jamás correría sobre glibc.
- **AppImage crudo**: se sugiere extraerlo primero.

## 6. Actualizar, listar, borrar

- `altore ls`: qué hay instalado y cuánto ocupa cada cosa (árbol + parte
  proporcional del store).
- `altore update [app]`: descarga la versión nueva, repite el proceso; la
  vieja sigue intacta hasta que la nueva verifica (rollback = no borrar la
  vieja hasta confirmar; v2: pins).
- `altore rm <app>`: borra árbol + shims + desktop; los hashes siguen hasta…
- `altore gc`: borra del store los hashes que ninguna app referencia.
- `altore doctor`: preflight (kernel, GPU/DRI, sesión gráfica, espacio,
  red) que diagnostica el PC *antes* de culpar a la app (idea tomada de
  cpak; habría ahorrado horas en casos reales como Hytale).

## 7. Qué pasa si algo falla (filosofía de errores)

- Hash que no cuadra → abortar, nunca instalar a medias.
- Descarga interrumpida → reanudar/continuar donde quedó (capas/archivos por
  hash lo permiten gratis).
- App que no arranca → `doctor` primero, log del shim después; mensajes que
  dicen *qué falta* (lib, driver, GPU), nunca traces pelados.

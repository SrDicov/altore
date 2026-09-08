# AGENTS.md — Altore

Instrucciones para agentes IA que trabajen en este repositorio. Leer este
archivo antes de tocar nada; la fuente de verdad del proyecto son `docs/`.

## Qué es (resumen operativo)

Altore = instalador/ejecutor de software glibc en PCs musl. Formato: AppDir
sharun extraído a un **store deduplicado por hash** (`~/.local/share/altore/`),
ejecución **directa** vía cargador bundlado (`ld-linux --library-path`, cero
montajes/daemons/root/sandbox). Repos relacionados (solo lectura salvo
indicación): `/home/dicov/Conty` (fallback universal),
`/home/dicov/Anylinux-AppImages` (origen de paquetes y técnica sharun).

## Decisiones cerradas (no reabrir sin orden explícita)

- Repo nuevo e independiente; Conty solo como fallback (`run --universal`).
- Lenguaje del CLI: **Zig** (estático musl diminuto), fallback Rust.
- Sin sandbox, sin root, sin daemon, sin compilar en cliente, sin empaquetar
  1-a-1 a mano (convertir catálogo pkgforge automáticamente).
- Docs en español, en `docs/NN-tema.md`. Si cambia el diseño, actualizar el
  doc correspondiente **en el mismo cambio**.

## Reglas de trabajo

- **Evidencia antes que síntesis**: verificar afirmaciones técnicas en los
  repos/fuentes antes de escribirlas. Nada especulativo en docs.
- **Documentación**: cada línea debe responder "¿lo perdería un agente sin
  este archivo?". Nada genérico, nada de relleno. Español claro; código y
  rutas en `monoespaciado`; tablas para comparativas.
- **Commits/PRs**: solo cuando se pidan explícitamente. Nunca pushear sin
  permiso. Nunca tocar `~/.local/share/altore` del usuario salvo orden.
- **Tests/verificación**: todo cambio de runtime trae su prueba (hyperfine
  para tiempos, `du` para disco, matriz Void-musl + Alpine). Sin benchmarks,
  no hay merge de facto.
- **Tono con el usuario**: directo, técnico, honesto (incluidos límites y
  fracasos). Sin superlativos ni validación emocional. Respuestas cortas
  salvo que pida detalle.
- **Preguntar** (herramienta `question`, un lote corto) solo ante decisiones
  reales no respondidas por los docs: alcance, catálogo, diseño. Jamás por lo
  ya escrito.

## Mapa rápido

- `README.md` índice; `docs/01..09` el proyecto por capas (qué → por qué →
  objetivos → mecanismo → arquitectura → roadmap → glosario → **spec CLI** →
  **formato repos**). `08-cli.md` es contrato congelado: cambiarlo exige
  actualizar `src/alt`, `alt -h` y `tests/`.
- `src/alt` (shell POSIX, ejecutable): único artefacto runtime. Sin
  bashismos (`/bin/sh` aquí es `dash`), sin `jq`/`python` en cliente (índice
  TSV + `awk`). Probar siempre con `sh -n`, `bash -n` y `tests/run-tests.sh`
  (40 pruebas; todo cambio trae su prueba).
- `tests/`: `mkdemo.sh` genera `fixture/` (gitignored) desde `demo-src/`;
  `run-tests.sh` usa HOME temporal, nunca toca el sistema.
- `tools/`: `anylinux2repo.sh` (AppImage→repo), `graft-libs.sh` (injerto
  glibc), `mkanylinux-catalog.sh` + `catalog-one.sh` (generan
  `catalog/anylinux/index.tsv`, solo-índice con URLs absolutas; refresco
  semanal en `.github/workflows/catalog.yml`).
- `packaging/`: `xbps-create.sh` (build directo del `.xbps`),
  `void-packages/srcpkgs/altore/template` (para xbps-src),
  `sign-repo.sh` + `SIGNING.md` (firmado obligatorio; la privada jamás se
  commitea). Arch del paquete vía `xbps-uhelper arch` (x86_64-musl, no
  x86_64); en roots de test fijar `XBPS_ARCH`.
- Criterios de corte Fase 0 en `docs/03-objetivos.md` (tabla) y
  `docs/06-hoja-de-ruta.md`. Si los números no salen, se rediseña: no
  construir sobre un piloto fallido.

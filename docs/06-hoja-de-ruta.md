# 06 — Hoja de ruta

## Regla de oro

Ninguna fase empieza sin que la anterior cumpla sus criterios medidos. El
prototipo barato (Fase 0) existe para poder **abortar o rediseñar antes de
invertir trabajo real**.

## Fase 0 — Prototipo y números (barato, decisivo)

**Hacer:** toolchain Zig funcionando (`-target x86_64-linux-musl`), prototipo
del store (partir por hash + hardlink) y del `exec` directo, con 3 apps reales
del catálogo pkgforge (una GTK, una Qt/SDL, una CLI).

**Medir (hyperfine + du, en Void-musl y Alpine):**
- ms de arranque: nativo vs AppImage vs prototipo vs conty-minimal.
- MB con CAS vs mismos AppImages sueltos (criterio de corte: **≥40% menos**).
- Frío vs caliente (debe ser igual: no hay montajes).
- Validar ecosistema Zig para lo necesario (sha256, hardlink, exec, https vía
  `curl` externo).

**Sale:** números + decisión Zig/Rust definitiva. Si CAS no ahorra o Zig roza,
se rediseña aquí, no en Fase 2.

## Fase 1 — CLI mínimo usable

**Hacer:** `get/run/ls/rm/gc/doctor`, shims en `~/.local/bin`, export
`.desktop`, base de datos `db.json`, `update` simple por app, manejo de
errores con mensajes que dicen qué falta.

**Probar:** matriz Void-musl + Alpine × Intel/AMD GPU; `shellcheck`-equivalente
para scripts auxiliares si los hay; cada comando con `--help` útil.

**Sale:** un usuario real instala y usa 5 apps diarias solo con el CLI.

## Fase 2 — Catálogo masivo (conversión, no empaquetado manual)

**Hacer:** CI que toma AppImages pkgforge y los convierte al formato del
store automáticamente (descargar → verificar → partir → publicar manifiesto).
Oleada 1: privativo diario + gaming (navegadores, Discord, Spotify,
VSCode/Cursor, Steam, PrismLauncher, Lutris, OBS, VLC/mpv). Oleada 2:
ofimática, diseño, trabajo, emuladores.

**Sale:** `altore get X` funciona para todo lo diario sin tocar un empaquetado
a mano.

## Fase 3 — Integración y refinamiento

**Hacer:** `run --universal` vía Conty-minimal auto-deps; base v3 opcional
(perfiles CachyOS reciclados de Conty); `self-update` del binario con
verificación de hash; pins y rollback básico (`update` conserva la versión
anterior hasta confirmar); `gc` agresivo con informe de ahorro.

## Verificación permanente (todas las fases)

- Benchmarks de arranque y disco versionados (regresión = fallo).
- Matriz musl (Void + Alpine) en cada cambio de runtime.
- `doctor` debe diagnosticar antes que el usuario abra un issue: si un fallo
  real no lo cubre, se amplía `doctor` en el mismo cambio que lo arregla.

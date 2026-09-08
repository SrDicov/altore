# Altore

Ejecuta software glibc en PCs con musl. Ligero, instantáneo, simple.

```bash
sudo xbps-install -Sy altore   # una vez (añade repo + clave según SIGNING.md)
atl -s brave                   # buscar en todos los repos
atl -i brave-bin               # instalar (con sugerencias si no es exacto)
brave                          # abrir, al instante, siempre
```

Sin contenedores, sin sandbox, sin root para usar, sin compilar, sin tiendas
pesadas. Todo vive bajo tu `$HOME`; `atl -R` desinstala y `atl gc` libera.

## Comandos

```
atl -s TEXTO        buscar paquetes en todos los repos
atl -i PAQUETE      instalar (lista numerada si hay dudas, n=cancela)
atl -R PAQUETE      desinstalar (tu config intacta)
atl -r PAQUETE [ARGS...] / atl PAQUETE ...   ejecutar (si falta, lo busca e instala)
atl -I PAQUETE      ficha del paquete (versión, repo, tamaño, estado)
atl -l              listar instalados
atl -lg [REPO]      listar disponibles (todos o de un repo)
atl -u [PAQUETE]    actualizar todo (o solo uno)
atl -h / atl -v     ayuda / versión
atl doctor / atl gc diagnosticar el PC / limpiar disco huérfano
```

`atl` y `altore` son lo mismo. Detalle congelado en `docs/08-cli.md`.

## Documentación

1. [`docs/01-que-es.md`](docs/01-que-es.md) — Qué es, a quién sirve, ejemplo.
2. [`docs/02-por-que.md`](docs/02-por-que.md) — El problema musl/glibc y análisis de nix, flatpak, cpak, AnyLinux, Conty, chroot.
3. [`docs/03-objetivos.md`](docs/03-objetivos.md) — Objetivos, no-objetivos, criterios de éxito medibles.
4. [`docs/04-como-funciona.md`](docs/04-como-funciona.md) — Mecanismo: cargador, store, instalación, ejecución, fallback.
5. [`docs/05-arquitectura.md`](docs/05-arquitectura.md) — Layout, formato, componentes, decisiones.
6. [`docs/06-hoja-de-ruta.md`](docs/06-hoja-de-ruta.md) — Fases y criterios de corte.
7. [`docs/07-glosario.md`](docs/07-glosario.md) — Términos sin jerga.
8. [`docs/08-cli.md`](docs/08-cli.md) — Spec CLI v1 (contrato congelado).
9. [`docs/09-repos.md`](docs/09-repos.md) — Formato de repos y paquetes.
10. [`packaging/SIGNING.md`](packaging/SIGNING.md) — Firmar repos xbps (obligatorio).

Para agentes IA: [`AGENTS.md`](AGENTS.md).

## Desarrollo

```bash
sh tests/mkdemo.sh     # construye repo demo local (4 paquetes ficticios)
sh tests/run-tests.sh  # 40 pruebas funcionales (40 ok, 0 fallos en v0.1.0)
sh packaging/xbps-create.sh --outdir repo/  # altore-V_R.arch.xbps
sh packaging/sign-repo.sh repo/             # firma + clave pública
```

Estructura: `src/altore` (el CLI, shell POSIX, sin dependencias raras) ·
`tests/` (fixtures + suite) · `packaging/` (template void-packages en
`packaging/void-packages/`, build directo, firmado) ·
`.github/workflows/` (CI: lint + tests + build `.xbps`).

## Estado

v0.1.0: CLI completo según spec, store CAS con deduplicación, firmado xbps
verificado con instalación real en root Void-musl limpio. Orígenes previstos:
AppImages AnyLinux/pkgforge convertidos + repos propios del equipo.

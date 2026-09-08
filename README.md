# Altore

Ejecuta software glibc en PCs con musl. Ligero, instantáneo, simple.

```bash
sudo xbps-install -Sy altore   # una vez (añade repo + clave según SIGNING.md)
alt -s brave                   # buscar en todos los repos
alt -i brave-bin               # instalar (con sugerencias si no es exacto)
brave                          # abrir, al instante, siempre
```

Sin contenedores, sin sandbox, sin root para usar, sin compilar, sin tiendas
pesadas. Todo vive bajo tu `$HOME`; `alt -R` desinstala y `alt gc` libera.

## Comandos

```
alt -s TEXTO        buscar paquetes en todos los repos
alt -i PAQUETE      instalar (lista numerada si hay dudas, n=cancela)
alt -R PAQUETE      desinstalar (tu config intacta)
alt -r PAQUETE [ARGS...] / alt PAQUETE ...   ejecutar (si falta, lo busca e instala)
alt -I PAQUETE      ficha del paquete (versión, repo, tamaño, estado)
  alt -l              listar instalados
  alt -lg [REPO]      listar disponibles: el repo `anylinux` trae TODO el
                      catálogo AnyLinux (~465 apps, URLs directas a GitHub)
alt -u [PAQUETE]    actualizar todo (o solo uno)
alt -h / alt -v     ayuda / versión
alt doctor / alt gc diagnosticar el PC / limpiar disco huérfano
```

`alt` y `altore` son lo mismo. Detalle congelado en `docs/08-cli.md`.

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
sh tests/mkdemo.sh     # construye repo demo local (5 paquetes ficticios)
sh tests/run-tests.sh  # 45 pruebas funcionales (45 ok, 0 fallos en v0.1.0)
sh tools/anylinux2repo.sh <AppImage> <dir-repo> <nombre> <versión> "<desc>"
                       # convierte un AppImage AnyLinux en paquete del repo
sh packaging/xbps-create.sh --outdir repo/  # altore-V_R.arch.xbps
sh packaging/sign-repo.sh repo/             # firma + clave pública
```

Estructura: `src/alt` (el CLI, shell POSIX, sin dependencias raras) ·
`tests/` (fixtures + suite) · `packaging/` (template void-packages en
`packaging/void-packages/`, build directo, firmado) ·
`.github/workflows/` (CI: lint + tests + build `.xbps`).

## Estado

v0.1.0: CLI completo según spec, store CAS con deduplicación, firmado xbps
verificado con instalación real en root Void-musl limpio. Orígenes previstos:
AppImages AnyLinux/pkgforge convertidos + repos propios del equipo.

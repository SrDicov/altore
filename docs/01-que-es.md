# 01 — Qué es Altore

## Definición en una frase

Altore es un **instalador y ejecutor de programas compilados para glibc en PCs con musl** (Void-musl, Alpine, Gentoo-musl…), que abre los programas **al instante** y ocupa el **mínimo disco posible**.

## A quién sirve

A quien usa una distro musl como sistema diario y choca con la realidad del
software Linux: casi todo el software privativo y gran parte del open source
compilado (navegadores, Discord, Spotify, Steam, juegos, herramientas de
trabajo) se distribuye compilado contra **glibc** y no arranca en musl.

El usuario típico de Altore no quiere cambiar de distro, no quiere compilar
nada, no quiere contenedores ni tiendas pesadas. Quiere escribir el nombre del
programa y que se abra. Ya.

## Ejemplo completo, de cero a programa abierto

```bash
# 1. Instalar Altore (dos binarios estáticos a ~/.local/bin, sin root)
#    (instrucciones exactas en la release; es copiar dos archivos)

# 2. Instalar un programa (una sola vez; descarga lo que no tengas ya)
altore get brave

# 3. Usarlo (instantáneo, siempre)
brave

# 4. Más programas después: solo descargan lo que no compartan con lo instalado
altore get obs-studio
obs

# 5. Ver qué hay, cuánto ocupa, limpiar restos
altore ls
altore gc
```

Qué pasa por dentro en ese ejemplo (resumen; el detalle está en
`04-como-funciona.md`):

1. `altore get brave` descarga el paquete Brave ya empaquetado, lo desarma **una
   sola vez** en una carpeta oculta (`~/.local/share/altore/`) y crea los
   accesos (`~/.local/bin/brave` + entrada de menú).
2. Los archivos que Brave comparte con lo ya instalado (glibc, Mesa, fuentes…)
   **no se duplican**: se guardan una sola vez y ambos programas los comparten.
3. `brave` ejecuta el binario **directamente**, con su propia glibc incluida.
   No hay montaje, ni contenedor, ni daemon, ni sandbox en el camino: el delay
   es ~0, como un programa nativo (como hace nix al ejecutar, pero sin nix).

## Qué NO es Altore (límites deliberados)

- **No es una distro** ni cambia tu sistema. Todo vive bajo tu `$HOME`. Borrar
  `~/.local/share/altore` lo desinstala por completo, sin dejar rastro.
- **No es un contenedor ni un sandbox.** No aísla nada a propósito: el programa
  ve tu home, tu red, tu GPU y tus dispositivos como cualquier programa nativo.
  Si buscas aislar apps de terceros, usa Flatpak; no es este proyecto.
- **No es una tienda con cuentas.** No hay registro, ni demonio, ni procesos en
  segundo plano. Los comandos corren y terminan.
- **No pide root nunca.** Ni para instalar Altore, ni para instalar programas,
  ni para ejecutarlos.
- **No compila nada en tu PC.** Los paquetes llegan ya compilados (binarios
  glibc + dependencias), igual que un AppImage. Tu CPU no calienta.
- **No empaqueta programas desde cero.** Reutiliza el catálogo existente de
  AppImages sharun (pkgforge: cientos de apps) mediante conversión automática.
  Empaquetar 1-a-1 a mano queda prohibido como flujo de trabajo.

## En qué se diferencia, en una tabla

| Sistema | Lo que Altore toma de él | Lo que Altore rechaza de él |
|---|---|---|
| nix | Ejecución instantánea; store por contenido | Compilar desde fuente; store gigante sin control |
| flatpak | `instalar + abrir` simple; una base compartida | Delay de arranque; runtimes monumentales; sandbox obligatorio |
| cpak | Comandos simples; manifiesto+origen; `doctor` | Montar capas OCI en cada lanzamiento; empaquetar 1-a-1 sin compartir |
| AnyLinux-AppImages | Bundles con su glibc; DwarFS; paquetes debloated; catálogo existente | Duplicar la base en cada AppImage |
| Conty | Fallback universal (binarios sueltos, 32/64-bit, wine) | Base monolítica de 580MB + delay FUSE+bwrap para el caso común |
| chroot | Nada (descartado: pide root y no aísla ni acelera nada) | Todo lo demás |

## Estado actual del proyecto

Diseño aprobado a nivel de concepto. Pendiente Fase 0: prototipo mínimo que
demuestre los números (tiempo de arranque y disco con/sin deduplicación) antes
de construir nada más. Ver `06-hoja-de-ruta.md`.

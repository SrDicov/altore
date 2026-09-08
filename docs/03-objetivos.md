# 03 — Objetivos

## Objetivo principal (único, medible)

> Ejecutar software glibc en PCs con musl con el **mayor rendimiento y
> rapidez posibles**, ocupando el **menor espacio posible**, de la forma
> **más simple posible**.

## Objetivos derivados (todos obligatorios)

1. **Arranque instantáneo.** Abrir un programa instalado debe costar lo mismo
   que un binario nativo (milisegundos, sin montajes ni daemons en el camino).
   Referencia a batir: nix; a no repetir: delay de flatpak.
2. **Disco mínimo.** Las dependencias comunes (glibc, Mesa, GTK…) existen **una
   sola vez** aunque las usen 50 programas (deduplicación por contenido).
   Referencia a batir: 2.0GB/21 apps de AnyLinux *con* duplicación.
3. **Simplicidad total para el usuario.** Instalar = un comando (`altore get
   X`); usar = escribir el nombre; desinstalar = otro comando. Cero
   configuración. Cero root. Referencia: simplicidad de flatpak/cpak.
4. **Cobertura total del catálogo.** Todo el software diario y privativo
   (navegadores, Discord, Spotify, ofimática, multimedia, herramientas de
   trabajo) + gaming (Steam, PrismLauncher, Lutris, wine). Nada de "para esta
   app no hay paquete": lo raro lo cubre el fallback Conty.
5. **Cero fricción con musl.** Funciona en Void-musl y Alpine con solo
   `fuse3 tar gzip coreutils curl` (idealmente ni FUSE en ejecución, al ser
   todo extraído). Sin user-namespaces obligatorios, sin systemd, sin FHS.
6. **Portabilidad del formato.** Los paquetes se construyen una vez (binarios
   glibc + DwarFS para transporte) y corren en cualquier kernel Linux x86_64
   (y aarch64 cuando el catálogo lo cubra).

## No-objetivos (tan importantes como los objetivos)

1. **Sin sandbox ni seguridad.** Decisión explícita del proyecto, no deuda
   técnica: no hay aislamiento, ni permisos por app, ni portals, ni seccomp.
   Los programas ven home/red/GPU como nativos. Quien quiera aislar, que use
   Flatpak o cpak.
2. **Sin root jamás.** Ni instalar Altore, ni programas, ni ejecutarlos.
3. **Sin daemon ni segundo plano.** Cada comando arranca, hace su trabajo y
   termina. Sin servicios, sin timers, sin notificaciones (la comprobación de
   updates, si existe, será manual: `altore update`).
4. **Sin compilar en el PC del usuario.** Todo llega precompilado. Nada de
   builds desde fuente en instalación.
5. **Sin empaquetar 1-a-1 a mano.** Se reutiliza y convierte automáticamente el
   catálogo sharun/pkgforge existente. Empaquetar manualmente queda prohibido
   como flujo (solo excepciones documentadas).
6. **Sin tienda central obligatoria.** Cualquier origen válido sirve; el
   catálogo es descubrimiento, no peaje (filosofía cpak: manifiesto + origen).

## Criterios de éxito (números que deciden si seguimos)

Medidos en la Fase 0 antes de construir nada más; si no se cumplen, se
rediseña barato:

| Métrica | Umbral mínimo | Referencia |
|---|---|---|
| Tiempo de arranque app instalada | ≤ 1.2× binario nativo (hyperfine) | nix ≈ 1.0×, AppImage ≈ +300ms, flatpak peor |
| Disco, set de ~10 apps mixtas | ≥ 40% menos que los mismos AppImages sueltos | AnyLinux 2.0GB/21 apps (con duplicación) |
| Arranque en frío (caché limpia) | Sin montajes: igual que en caliente | flatpak/AppImage degradan en frío |
| Funciona en Void-musl y Alpine | Sí, con solo host-deps básicas | — |
| Binario `altore` | Estático musl, < 1MB | — |

## Anti-metas (fracasos con nombre)

- Convertirse en otro flatpak (daemon, sandbox, runtimes gigantes).
- Convertirse en otro nix (compilar, store incontrolado).
- Convertirse en otra tienda cerrada (cuentas, central obligatorio).
- Soportar 32-bit mixto en el path rápido (eso es territorio Conty-fallback).

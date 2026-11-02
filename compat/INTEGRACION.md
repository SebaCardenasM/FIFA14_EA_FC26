# Integracion de la capa en un port

Esta carpeta contiene primitivas, no un reemplazo automatico de cualquier lanzador. Consultar `../reports/migration-plan.json` para las cadenas actuales y sus SHA.

## Antes de modificar una cadena

1. Comprobar que la revision instalada coincide con el SHA auditado.
2. Respaldar partidas y los scripts que se vayan a sustituir.
3. Mantener los parametros medidos del juego: su resolucion, fuentes, controles, motor y parches. La adaptacion de plataforma no requiere reducirlos nuevamente.
4. Revisar lanzador principal, supervisor, ejecutor nativo y recuperador como una sola cadena. Una deteccion en el padre se pierde si systemd crea una sesion nueva sin pasar el contexto.

## Deteccion y mandos

Al comienzo del lanzador, antes de sobrescribir variables SDL, cargar `portcompat.sh`, llamar a `portcompat_detect` y preparar `portcompat_controls` con la base local y, si existe, el archivo de mapeo del usuario. Escribir el contexto con `portcompat_write_context` en la carpeta de informes del lanzamiento.

La funcion de controles conserva las variables existentes y usa un archivo cuando los mapeos son demasiado grandes para una variable de entorno. No carga los modulos upstream que cambian enlaces en /usr/lib.

En el proceso que ejecutara el juego, recuperar ese contexto y aplicar `portcompat_apply_backends` despues de los exports antiguos. Llamar a `portcompat_before_exec` con el ejecutable real. Si el llamador ya preparo `pm_platform_helper`, se usa ese hook una sola vez, incluido el traspaso de los dialogos de PortMaster; se propaga su error. Si no existe, se usan las APIs de dialogo disponibles y los hooks acotados de ROCKNIX/muOS. La capa no carga modulos por su cuenta. Mantener al llamador esperando al juego; no volver inmediatamente al frontend mientras el motor sigue usando la pantalla.

NextUI/MinUI puede entregar PortMaster en `EMU_DIR`; esa ruta tambien se reconoce. La carpeta real del juego debe resolverse desde el lanzador o el contrato del Pak, incluyendo `.ports`, sin confundir la raiz temporal del Pak con la carpeta persistente de los datos.

## Graficos y ABI

Para un perfil con userspace del sistema, `driver_resolver.py --architecture aarch64` o `armhf` propone EGL, GLES y GBM separados. Inspecciona ELF sin crear contexto ni cargar las bibliotecas. Sus resultados son candidatos, no una validacion de las extensiones graficas.

La opcion `--aliases-in-empty-dir` acepta solo un directorio temporal nuevo y vacio. No crea enlaces en la microSD ni sustituye bibliotecas del firmware.

Un driver del sistema no debe mezclarse directamente con otra glibc privada. Elegir la pareja userspace/driver completa y comprobar dependencias. Conservar una pareja privada ya validada solo para su perfil exacto de dispositivo/kernel. No crear todos los aliases EGL/GLES/GBM apuntando a libMali por conveniencia.

Si el kernel no ejecuta ARM32, o faltan las bibliotecas graficas ARM32, no se arregla cambiando el nombre del ejecutable: hace falta preparar el motor en otra arquitectura. Lo mismo ocurre si el juego requiere GLES3 o texturas ASTC ausentes en la GPU.

## Auxiliares y validacion

- Frecuencias y reserva de memoria son opcionales y especificas del SoC. No deben impedir abrir el juego por faltar una ruta RK3326 en otro dispositivo.
- systemd, sudo, nombres de servicios, Python y rutas de ALSA requieren sus propias alternativas. La deteccion por si sola no las implementa en los scripts antiguos.
- No extraer los datos en la primera apertura: mantener la entrega completa y comprobarla antes de instalar.
- Validar apertura manual desde Ports, carga de partida, controles, audio, FPS medidos y transiciones. Separar los resultados de cada equipo y firmware.
- Solo despues actualizar el ZIP completo correspondiente y su manifiesto. Los ZIP historicos de dist se conservan.

FIFA 14 / EA FC MOD 26 BY ZEOL — Port Linux ARM32 sobre base 1.3.6

INSTALACIÓN
Copiar FIFA 14.sh y fifa14/ juntos a la carpeta ports de la tarjeta de ROMs.
Todos los datos y bibliotecas del perfil R36 están incluidos y extraídos al
nivel requerido por el motor; el OBB es el contenedor nativo del juego.
No se extraen datos del APK en la primera apertura.
Partidas dentro de fifa14/userdata/. Conservar esa carpeta al actualizar.
El lanzador resuelve su ubicación, incluida la tarjeta de ROMs SD2.
El ZIP no incluye partidas personales ni los perfiles del donante.

CONTROLES
L3: alternar cursor de menús / mando de partido.
Menús: cruceta o joystick mueve el cursor; A pulsa; B vuelve.
Partido: cruceta o joystick mueve al jugador.
A: pase / cambio de jugador. B: tiro / entrada deslizante.
X o L1: pase al hueco / llamar a segundo defensa.
Y o R1: sprint / presión y entrada. START: pausa.
SELECT + START: salida inmediata. R3: mostrar u ocultar FPS reales.
Se conserva el cursor para gestos de faltas, penaltis y otras acciones táctiles.
No se han validado todavía todos esos gestos ni todas las filigranas.

CONTENIDO Y VOCES
Plantillas, gráficos y banco Speech del mod incluidos y verificados en SD.
Se registran los archivos locales presentes sin volver a descargarlos.
Voces e interruptor en Personalizar > Sonido. Se observó la opción Español
y el motor abrió el banco completo durante un partido; ese nombre no verifica
por sí solo el idioma grabado del banco suministrado.
Se conserva el español real del OBB; el archivo SPA_ES suelto era portugués.
Carrera en Jugar > Modo Mánager; controles, imagen y sonido en Personalizar.
Presentación 640x480 centrada en 4:3, con botones táctiles a elección al iniciar.
No crea respaldos automáticos al iniciar. Los respaldos de desarrollo
existentes se conservan fuera de la entrega.

PRUEBAS Y LÍMITES CONOCIDOS
R36 Max dArkOS4Clone: partidos normalmente alrededor de 30 FPS medidos;
hubo bajadas en cargas y transiciones. No son 30 FPS garantizados.
Controles de partido y conmutación R3 del contador observados en ejecución.
Se probó crear carrera, selección de equipo, patrocinio y simulación inicial.
Reanudar la carrera de la revisión anterior produjo un cierre con las bases
nuevas; el respaldo anterior se conserva en la tarjeta.
También se observó un cierre pasando por Imagen durante un partido.
No se han validado todas las temporadas, modos ni la apertura manual desde
Ports de esta revisión. Otros firmwares y equipos requieren prueba propia
y soporte ARM32; no se anuncia compatibilidad universal.

CÓDIGO Y CRÉDITOS
Host EA: EapRules/masseffect-native-arm v1.0.7, GPL-3.0.
https://github.com/EapRules/masseffect-native-arm
Fuentes del host y adaptador en source/; licencias en license/.
Los datos del juego suministrados por el usuario conservan su propia licencia.

ACTUALIZACION DE INTERFAZ Y SALIDA — 28/10/2026
Pantalla inicial: PORT HECHO POR DANI / FIFA 14 / MOD FC 26.
Cruceta o joystick elige con/sin botones táctiles; A, B o START confirma.
SELECT cancela y devuelve al apartado Ports.
La pantalla usa GLES, repinta de forma regular y libera su mando y contexto
antes de cargar el motor del juego. Se mantiene 640x480 centrado en 4:3.
Los FPS reales empiezan ocultos en cada apertura; R3 los muestra/oculta solo
para esa sesion. L3 conserva la funcion de cursor/mando. R3 ya no escribe
preferencias en la microSD al cambiar el contador.
SELECT + START solicita la salida nativa inmediata; el lanzador espera al
proceso y limpia sus auxiliares antes de devolver el control a Ports.
La apertura normal conserva EmulationStation y no reinicia su servicio.
No incluye ni crea backups automaticos ni sobrescribe partidas al actualizar.
No se cambia la velocidad de simulacion ni se quita el ritmo del motor EA.
Pruebas de esta actualizacion y de otros firmwares se registran por separado;
no se promete compatibilidad universal por tener PortMaster.

SELECTOR DE BOTONES TACTILES — 30/10/2026

Al abrir se elige CON BOTONES TACTILES o SIN BOTONES TACTILES.
La primera opción aparece seleccionada por defecto en cada apertura.
El modo sin botones incluye el aviso PUEDE PRESENTAR ERRORES.
La elección controla los gráficos del joystick y los botones de partido;
los contactos que traducen el mando físico se mantienen en ambos modos.
L3 sigue alternando cursor/mando y R3 sigue alternando el contador FPS.
La selección solo se aplica a esa apertura y no reemplaza las partidas.

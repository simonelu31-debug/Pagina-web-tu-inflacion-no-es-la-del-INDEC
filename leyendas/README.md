# Leyendas del fútbol argentino

Los 20 clubes con más puntos de la tabla histórica de Primera División, cada uno con
22 leyendas (titular y suplente por puesto) y 3 camisetas.

| Carpeta | Qué hay |
| --- | --- |
| `godot/` | El juego en 3D, hecho con [Godot 4.4](https://godotengine.org) (gratis y libre). |
| `jugar/` | La versión web exportada desde Godot: se abre en el navegador, sin instalar nada. |
| `clasico.html` | La versión original en un solo HTML (canvas 2D). Es también la fuente de los planteles. |
| `exportar_planteles.js` | Copia planteles y camisetas de `clasico.html` a `godot/data/equipos.json`. |

## Jugar

- **En el navegador:** abrir `jugar/index.html` desde GitHub Pages (en la carpeta `leyendas/jugar/` del sitio).
  Hace falta servirlo por http, no funciona abriendo el archivo con doble clic.
- **En la compu, con Godot:** bajar Godot 4.4, *Importar* → elegir `leyendas/godot/project.godot` → F5.

### Controles

| | Teclado | Joystick |
| --- | --- | --- |
| Mover | Flechas | Stick izquierdo / cruz |
| Correr (gasta resistencia) | Shift | RB / RT |
| Pase | S | A |
| Pase al hueco | Q | X |
| Pase largo / centro | W | Y |
| Remate (mantener para cargar) | D | B |
| Gambeta | E | LT |
| Cambiar de jugador | A | LB |
| Cámara (Transmisión, Cerca, Aérea) | V | Back |
| Pausa | P / Esc | Start |

- **Remate:** con Shift sale fuerte; sin Shift sale colocado con rosca. Si además apretás W, es vaselina.
  Arriba/abajo elige el palo.
- **Sin la pelota:** S mantenido cerca del rival es quite; D es barrida (de atrás puede ser falta y tarjeta);
  Q mantenido manda a un compañero a presionar con vos.
- **Tiro libre:** mantené D y apuntá (arriba/abajo: palo; izquierda/derecha: comba).
- **Penal:** mantené D y apuntá. Si atajás, elegí el lado con las flechas.
- En celular o tablet aparecen un joystick y botones en pantalla.

## Qué cambió respecto de la versión HTML

- **Gráficos 3D en Godot:** estadio con tribunas e hinchada que salta en los goles, red que se mueve,
  césped con franjas de corte, sombras, tres cámaras y repetición de cada gol.
- **Pelota con física de verdad:** resistencia del aire, efecto (las roscas y los tiros libres doblan),
  pique con efecto, palos y travesaño que la devuelven.
- **Correr con resistencia:** cada jugador tiene una barra que baja al correr y se recupera caminando;
  cansado corre menos. Al correr con la pelota se la adelanta más y es más fácil perderla.
- **Jugadores más completos:** ocho cualidades (velocidad, resistencia, gambeta, pase, tiro, cabezazo,
  marca, físico) y especialidades por leyenda (tiro libre, gambeta, cabezazo, remate potente, visión,
  velocidad, marca, atajador) que cambian cómo juegan. Se ven en la ficha de cada jugador.
- **Juego más rico:** pase al hueco, centros y cabezazos, voleas, gambeta, barridas, faltas, tarjetas,
  penales, tiros libres con barrera, córners, y una IA que se ordena por puesto (laterales que pasan,
  delanteros que tiran diagonales, volantes que contienen).

## Para quien quiera modificarlo

- Planteles y camisetas se editan en `clasico.html` y después se corre `node leyendas/exportar_planteles.js`.
- El motor del partido (`godot/scripts/sim.gd`) no depende de los gráficos. Hay pruebas que juegan
  partidos completos sin pantalla:

  ```
  godot --headless --path leyendas/godot --script res://tests/prueba_sim.gd   # 20 partidos máquina vs. máquina
  godot --headless --path leyendas/godot --script res://tests/humano.gd       # alguien apretando botones al azar
  godot --headless --path leyendas/godot --script res://tests/diag.gd         # estadísticas de juego
  ```

- Para regenerar la versión web: en Godot, *Proyecto → Exportar → Web* (hay que tener instaladas las
  plantillas de exportación), o `godot --headless --path leyendas/godot --export-release "Web" ../jugar/index.html`.

Fuentes tipográficas: Big Shoulders Display y VT323 (licencia SIL OFL, ver `godot/fonts/`).

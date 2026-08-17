# **Master Planner**
Una aplicación de Flutter para organización personal, desde tareas pequeñas y diarias hasta proyectos grandes y complejos de software con muchas partes.
Se compone de varias vistas para visualizar las tareas de distintas formas, todas sobre el mismo modelo de datos.
## **Vistas**
- **Vista de árbol (principal):** las tareas y subtareas se visualizan como un árbol, donde el eje Y representa el tiempo. Esto permite ver dependencias entre tareas, deadlines, y tener una overview de cómo va el proyecto completo.
- **Today view:** una lista simple de lo que se tiene que terminar hoy o lo que se planea hacer hoy.
- **Texto tabulado:** las tareas se pueden ver como texto tabulado, donde las tabulaciones marcan jerarquía (similar a Python).
- En el futuro se planea añadir más vistas, posiblemente kanban o SCRUM.
## **Estado actual**
Corre actualmente en desktop. Se está añadiendo la funcionalidad de trabajar en equipo con otras personas, usando un backend en Cloudflare. Posiblemente funcione en Android más adelante.
## **Dependencias**
```yaml
uuid: ^4.5.3            # para dar ids únicos a los elementos (especialmente nodos del grafo)
sqflite: ^2.4.3          # para guardar los datos del grafo
sqflite_common_ffi: any
path: ^1.9.1             # para obtener el path a la base de datos de sqflite
```
## **Instalación**
Funciona como un proyecto de Flutter normal:
```bash
flutter pub get
flutter run
```
## **Licencia**
MIT

[Español](README.es.md)

# **Master Planner**
A Flutter app for personal organization, from small daily tasks to large, complex software projects with many moving parts.
It's built around several views for visualizing tasks in different ways, all on top of the same underlying data model.

## **Views**
- **Tree view (main):** tasks and subtasks are visualized as a tree, where the Y axis represents time. This makes it possible to see dependencies between tasks, deadlines, and get an overview of how the whole project is progressing.
- **Today view:** a simple list of what needs to get done today, or what's planned for today.
- **Tabbed text:** tasks can also be viewed as tabbed text, where indentation marks hierarchy (similar to Python).
- More views are planned for the future, possibly kanban or SCRUM.

## **Current status**
Currently runs on desktop. Collaborative, multi-person functionality is being added, using a Cloudflare-based backend. It may support Android further down the line.

## **Dependencies**
```yaml
uuid: ^4.5.3            # gives unique ids to elements (especially graph nodes)
sqflite: ^2.4.3          # stores the graph's data
sqflite_common_ffi: any
path: ^1.9.1             # gets the path to the sqflite database
```

## **Installation**
Works like a normal Flutter project:
```bash
flutter pub get
flutter run
```

## **License**
MIT

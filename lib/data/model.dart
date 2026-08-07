import 'dart:developer';

import 'package:master_planner/utils.dart';
import 'package:uuid/uuid.dart';

enum TaskLoad{NONE, SMALL, MEDIUM, BIG, MASSIVE}
enum TaskState{OPEN, INDISPENSABLE, PLANEO, IN_PROGRESS, IN_SLOW_PROGRESS ,DONE}

//THIS MODEL DOES NOT STORE ANYTHING RELATED TO VISUALIZATION SUCH AS "Position", THAT SHOULD BE STORED BY SAVEABLE VISUALIZATIONS
class TaskModel {
  late final uuid;
  String title = "task title";
  String? description;
  DateTime? dueDate; 
  TaskLoad load = .NONE;
  TaskState state = .OPEN;
  List<TaskModel> subtasks = List.empty(growable: true); //claude: reverted to plain List<TaskModel>, no longer using WeakReference

  //constructor
  TaskModel (this.title, {String? uuid, this.description, this.dueDate, this.load = .NONE, this.state = .OPEN,  List<TaskModel>? subtasks}) : subtasks = subtasks ?? [], uuid = uuid ?? genUniqueID(); //claude: reverted constructor param type to List<TaskModel>?

  //serialization funcs
  Map<String,dynamic> toJson() {
    return {
      'uuid':uuid,
      'title':title,
      'description':description,
      'dueDate':dueDate.toString(),
      'load':load,
      'state':state,
      'subtasks':subtasks.map((task) => task.uuid).toList()
    };
  }
  
  static TaskModel fromJson(Map<String,dynamic> json){
    return TaskModel(json['title'], description:  json['description'], dueDate:  json['dueDate'] == 'null' ? null :  DateTime.parse(json['dueDate']));
  }

  void updateFrom(TaskModel other) {
    assert(uuid == other.uuid, 'Cannot updateFrom a task with a different uuid');
    title = other.title;
    description = other.description;
    dueDate = other.dueDate;
    load = other.load;
    state = other.state;
    subtasks = other.subtasks;
  }
}
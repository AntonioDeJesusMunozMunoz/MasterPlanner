import 'dart:developer';

import 'package:master_planner/utils.dart';
import 'package:uuid/uuid.dart';

//THIS MODEL DOES NOT STORE ANYTHING RELATED TO VISUALIZATION SUCH AS "Position", THAT SHOULD BE STORED BY SAVEABLE VISUALIZATIONS
class TaskModel {
  late final uuid = genUniqueID();
  String title = "task title";
  String? description;
  DateTime? dueDate; 
  List<TaskModel> subtasks = List.empty(growable: true); //claude: reverted to plain List<TaskModel>, no longer using WeakReference

  //constructor
  TaskModel (this.title, [this.description, this.dueDate,  List<TaskModel>? subtasks]) : subtasks = subtasks ?? []; //claude: reverted constructor param type to List<TaskModel>?

  //serialization funcs
  Map<String,dynamic> toJson() {
    return {
      'title':title,
      'description':description,
      'dueDate':dueDate.toString(),
    };
  }

  static TaskModel fromJson(Map<String,dynamic> json){
    log(json['dueDate']);
    return TaskModel(json['title'], json['description'],json['dueDate'] == 'null' ? null :  DateTime.parse(json['dueDate']));
  }
}
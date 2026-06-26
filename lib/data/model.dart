import 'dart:convert';
import 'dart:developer';

class TaskModel {
  String title = "task title";
  String? description;
  DateTime? dueDate; 

  //constructor
  TaskModel (String title, String? description, DateTime? dueDate){
    this.title = title;
    this.description = description;
    this.dueDate = dueDate;
  }

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
/* 
Connects the overview panel to the SOT
*/

import 'package:flutter/material.dart';
import 'package:master_planner/data/model.dart';
import 'package:master_planner/overviewPanel.dart';
import 'package:master_planner/viewModel/tasksSOT.dart';
import 'package:uuid/uuid.dart';

class OverViewViewModel{
  late final TasksSOT sot;
  late final OverviewController overviewController;
  String? _taskUuid;

  String? get taskUuid =>  _taskUuid;
  set taskUuid(String? newUuid) {
    _taskUuid = newUuid;
    updateOverviewPanel();
  } 

  OverViewViewModel({required this.sot, required this.overviewController}){
    overviewController.onTitleChangeCallback = _updateTaskTitleInSot;
    overviewController.onDescriptionChangeCallback = _updateTaskDescriptionInSot; //claude
    overviewController.onDueDateChangeCallback = _updateTaskDueDateInSot; //claude
    overviewController.onLoadChangeCallback = _updateTaskLoadInSot; //claude
    overviewController.onStateChangeCallback = _updateTaskStateInSot; //claude
    sot.addListener(updateOverviewPanel);
  }

  //================================ PRIVATE METHODS ===============================
  //TODO: this creates an entirely new task per field, horribly inneficient, could find a better way
  void _updateTaskTitleInSot(String newValue){
   assert(taskUuid != null);

   TaskModel oldTask = sot.tasks.firstWhere((task) => task.uuid == _taskUuid);

   //just change the title
   sot.setTask(TaskModel(newValue, uuid: _taskUuid, description: oldTask.description, dueDate: oldTask.dueDate, load: oldTask.load, state: oldTask.state, subtasks: oldTask.subtasks));
  } 

  void _updateTaskDescriptionInSot(String newValue){
    assert(taskUuid != null);
    TaskModel oldTask = sot.tasks.firstWhere((task) => task.uuid == _taskUuid);
    sot.setTask(TaskModel(oldTask.title, uuid: _taskUuid, description: newValue, dueDate: oldTask.dueDate, load: oldTask.load, state: oldTask.state, subtasks: oldTask.subtasks));
  }

  void _updateTaskDueDateInSot(DateTime? newValue){
    assert(taskUuid != null);
    TaskModel oldTask = sot.tasks.firstWhere((task) => task.uuid == _taskUuid);
    sot.setTask(TaskModel(oldTask.title, uuid: _taskUuid, description: oldTask.description, dueDate: newValue, load: oldTask.load, state: oldTask.state, subtasks: oldTask.subtasks));
  }

  void _updateTaskLoadInSot(TaskLoad? newValue){
    assert(taskUuid != null);
    if (newValue == null) return;
    TaskModel oldTask = sot.tasks.firstWhere((task) => task.uuid == _taskUuid);
    sot.setTask(TaskModel(oldTask.title, uuid: _taskUuid, description: oldTask.description, dueDate: oldTask.dueDate, load: newValue, state: oldTask.state, subtasks: oldTask.subtasks));
  }

  void _updateTaskStateInSot(TaskState? newValue){
    assert(taskUuid != null);
    if (newValue == null) return;
    TaskModel oldTask = sot.tasks.firstWhere((task) => task.uuid == _taskUuid);
    sot.setTask(TaskModel(oldTask.title, uuid: _taskUuid, description: oldTask.description, dueDate: oldTask.dueDate, load: oldTask.load, state: newValue, subtasks: oldTask.subtasks));
  }
  //=============================== PUBLIC METHODS =================================
  /*
  when the uuid is changed or the data in the sot is changed, the values are sent to the overview once
  */
  void updateOverviewPanel(){
    if (taskUuid != null){
      TaskModel theTask = sot.tasks.firstWhere((task) => task.uuid == taskUuid);
      overviewController.titleController.text = theTask.title;
      overviewController.descriptionController.text = theTask.description == null ? "" : theTask.description!;
      overviewController.loadController.selectedValue = theTask.load;
      overviewController.stateController.selectedValue = theTask.state;
      overviewController.datePickerController.selectedDate = theTask.dueDate;
    }
  }
}

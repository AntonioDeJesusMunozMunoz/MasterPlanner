import 'dart:collection';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:master_planner/data/model.dart';

/* 
how does the view model reconcile the sot and the view
-it can see the truth
-it has access to the controller

3 TYPES OF CHANGES
-truth to view@
	-delete task
	-add task
	-modify task
-view to truth
	-delete node@
	-add node@
	-add connection@
  -delete connection
-view to visualization
	-affects data specific to the visualization 
  ex:
		-node position@
		-zoom
		-pan


SOLUTION
-the vm stores the visualization data, this helps also to allow the user to store it (which is neccesary)
-on change, the vm updates its content using the visualization data and the truth
*/

/*
* CLASS THAT STORES THE TRUTH OF THE TASKS
* this class manages the actual data of the tasks
* all view models are mere representations of facets of the data in here
* of course, since this is the source of truth, here is also the method to save and load from the database
*/
class TasksSOT extends ChangeNotifier {
  //list of all tasks
  final List<TaskModel> _tasks = List.empty(growable: true);//TODO make it cear you shouldnt touch this directly

  List<TaskModel> get tasks{
    return _tasks;
  }

  //create a task
  void createTask(){
    tasks.add(TaskModel("newTask"));
    notifyListeners();
  }

  //delete task, deletes a task by instance
  void deleteTask(String uuid){
    log("tasks before: ${tasks.length}");
    tasks.removeWhere((currTask) {return currTask.uuid == uuid;});
    log("tasks after: ${tasks.length}");
    pruneDeadSubtasks();
    notifyListeners();
  }

  //add an externally created task
  void addTask(TaskModel task){
    this.tasks.add(task);
    log("tasks after adding new one: ${tasks.length}");
    notifyListeners();
  }  

  //update the value of a tasks associated with a uuid
  void setTask(TaskModel newData){
    int idx = _tasks.indexWhere((task) => task.uuid == newData.uuid);
    assert(idx != -1);
    
    _tasks[idx].updateFrom(newData);
    notifyListeners();
  }

  //checks whether a given TaskModel instance is still present in tasks, so other view models (that can't see this list directly) can verify a task still exists //claude: new method, replaces the old WeakReference.target == null check
  bool containsTask(TaskModel task){
    return tasks.any((currTask) => identical(currTask, task));
  }

  //load data from memory

  //save data to memory


  // ================================ HELPERS =========================
  void pruneDeadSubtasks(){
    log("PRUNNING DEADA SUBTasks");
    //por cada task
    for (var currTask in tasks){
      //remove any subtask reference that no longer exists in tasks //claude: reverted from WeakReference null-check to a containsTask lookup
      currTask.subtasks.removeWhere((subtask) => !containsTask(subtask));
    }
  }
}
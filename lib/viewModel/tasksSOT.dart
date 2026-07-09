import 'package:flutter/material.dart';
import 'package:master_planner/data/model.dart';

/* 
how does the view model reconcile the sot and the view
-it can see the truth
-it has access to the controller

3 TYPES OF CHANGES
-truth to view
	-delete task
	-add task
	-modify task
-view to truth
	-delete node
	-add node
	-add connection
-view to visualization
	-affects data specific to the visualization 
  ex:
		-node position
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
  //list of all tasksa
  final List<TaskModel> tasks = List.empty(growable: true);//TODO make it cear you shouldnt touch this directly


  //create a task
  void createTask(){
    tasks.add(TaskModel("newTask"));
    notifyListeners();
  }

  //delete task, deletes a task by instance
  void deleteTask(TaskModel instance){
    tasks.remove(instance);
    notifyListeners();
  }

  //add an externally created task
  void addTask(TaskModel task){
    this.tasks.add(task);
    notifyListeners();
  }

  //load data from memory

  //save data to memory

}

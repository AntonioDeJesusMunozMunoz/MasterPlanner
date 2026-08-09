/*
TODAY VIEW MODEL
-right now its just to connect the callback from the todayView on clicked to main (same as graphVM)
-also to connect the sot
*/

import 'package:master_planner/data/model.dart';
import 'package:master_planner/todayView.dart';
import 'package:master_planner/viewModel/tasksSOT.dart';

class TodayViewModel {
  late final TasksSOT sot;
  late final TodayViewController todayViewController;

  TodayViewModel({required this.sot, required this.todayViewController}){
    sot.addListener(updateTodayView);
  }

  //==================================== METHODS ====================================
  void updateTodayView(){
    todayViewController.tasksToShow = sot.tasks.where((task) => task.state == .INDISPENSABLE || task.state == .PLANEO || task.dueDate?.day == DateTime.now().day).toList();
  }
}
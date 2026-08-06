/*
TODAY VIEW
-shows only the tasks due today or marked as PLANEO or INDISPENSABLE
-just a list of tasks that show title and state

-taskList widget
  -fuck it, custom made, just a colum with taskListItem widgets
-taskListItem widget
  -a row with the data
  -reads the data straight from the SOT
  -has a clicked callback
*/

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:master_planner/data/model.dart';
import 'package:master_planner/viewModel/tasksSOT.dart';

class TodayView extends StatefulWidget {
  TodayViewController controller;
  void Function(TaskModel taskClicked)? onTaskClickedCallback;
  TodayView({super.key, TodayViewController? controller, this.onTaskClickedCallback}) : controller = controller ?? TodayViewController();

  @override
  State<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends State<TodayView> {

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
             child: Column(
              children: [
              ...widget.controller.tasksToShow.map((task) => TodayViewListItem(task: task, onClickedCallback: widget.onTaskClickedCallback))
              ],
            ),
    );
  }
}

class TodayViewController extends ChangeNotifier {
  List<TaskModel> _tasksToShow = List.empty(growable: true);
  List<TaskModel> get tasksToShow => _tasksToShow;
  set tasksToShow(List<TaskModel> newTasks) {
    _tasksToShow = newTasks;
    notifyListeners();
  }
} 

class TodayViewListItem extends StatelessWidget {
  final TaskModel task;
  void Function(TaskModel taskClicked)? onClickedCallback;
  TodayViewListItem({super.key, required this.task, this.onClickedCallback});

  Color _stateColor(TaskState state) {
  switch (state) {
    case TaskState.OPEN:
      return Colors.grey;
    case TaskState.INDISPENSABLE:
      return Colors.red;
    case TaskState.PLANEO:
      return Colors.blue;
    case TaskState.IN_PROGRESS:
      return Colors.purple;
    case TaskState.IN_SLOW_PROGRESS:
      return Colors.orange;
    case TaskState.DONE:
      return Colors.green;
  }
}

String _stateLabel(TaskState state) {
  //claude: turns IN_SLOW_PROGRESS into "In slow progress" instead of raw enum name
  final words = state.name.split('_');
  return words.first[0] + words.first.substring(1).toLowerCase() +
      (words.length > 1 ? ' ${words.sublist(1).join(' ').toLowerCase()}' : '');
}

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:() {log("SI CORRE EL INKWELL RAAAA");onClickedCallback?.call(task);},
      child: Container(
        width: 600,
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: .spaceBetween,
          children: [
            Text(
              task.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _stateColor(task.state).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _stateColor(task.state), width: 1),
              ),
              child: Text(
                _stateLabel(task.state),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _stateColor(task.state),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
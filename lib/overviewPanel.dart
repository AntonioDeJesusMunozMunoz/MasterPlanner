/*
Panel that shows an editable form of the all the fields of the current task selected
*/

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:master_planner/data/model.dart';


TextStyle titleStyle = TextStyle(fontSize: 30);
TextStyle subtitleStyle = TextStyle(fontSize: 15, color: Colors.grey.shade400);


//===================================== THE OVERVIEW PANEL ================================
//the class
class OverviewPanel extends StatefulWidget {
  OverviewController controller;
  OverviewPanel({super.key, required this.controller});

  @override
  State<OverviewPanel> createState() => _OverviewPanelState();
}


//the state
class _OverviewPanelState extends State<OverviewPanel> {
  @override
  Widget build(BuildContext context) {  
    //setup the controllers


    return Container(
      width: 400,
      height: 500,
      color: Colors.white70,
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text("Overview", style: titleStyle,),
          NamedTextField(title: "Title: ", controller: widget.controller.titleController,),
          NamedTextField(title: "Description: ", controller: widget.controller.descriptionController,),
          FullDatePicker(controller: widget.controller.datePickerController),
          EnumDropdownButton<TaskLoad>(title: "Load: ", values: TaskLoad.values, controller: widget.controller.loadController,),
          EnumDropdownButton<TaskState>(title: "State: ", values: TaskState.values, controller: widget.controller.stateController,),
          //Text("Subtasks: ", style: subtitleStyle),
        ],
      ),
      );
  }
}



//the controller
class OverviewController extends ChangeNotifier{
  //title vars
  TextEditingController titleController = TextEditingController();
  late String lastTitle = titleController.text;
  Function(String newValue)? _onTitleChangeCallback; 

  //description vars
  TextEditingController descriptionController = TextEditingController();
  late String lastDescription = descriptionController.text;
  Function(String newValue)? _onDescriptionChangeCallback;

  //due date vars
  FullDatePickerController datePickerController = FullDatePickerController();
  DateTime? lastDueDate; //claude: tracks last value, same purpose as lastTitle/lastDescription
  Function(DateTime? newValue)? _onDueDateChangeCallback;

  //load and state vars
  EnumController<TaskLoad> loadController = EnumController<TaskLoad>(); //claude
  EnumController<TaskState> stateController = EnumController<TaskState>(); //claude
  TaskLoad? lastLoad; //claude
  TaskState? lastState; //claude
  Function(TaskLoad? newValue)? _onLoadChangeCallback; //claude
  Function(TaskState? newValue)? _onStateChangeCallback; //claude

  set onTitleChangeCallback(Function(String newValue)? callback) {
    _onTitleChangeCallback = callback;
    titleController.addListener(() {
      //only callback when the title actually changes
      if (titleController.text == lastTitle) return;
      lastTitle = titleController.text;
      _onTitleChangeCallback!.call(titleController.text);
      });
  }

   set onDescriptionChangeCallback(Function(String newValue)? callback) {
    _onDescriptionChangeCallback = callback;
    descriptionController.addListener(() {
      //only callback when the description actually changes
      if (descriptionController.text == lastDescription) return;
      lastDescription = descriptionController.text;
      _onDescriptionChangeCallback!.call(descriptionController.text);
    });
  }

  set onDueDateChangeCallback(Function(DateTime? newValue)? callback) {
    _onDueDateChangeCallback = callback;
    datePickerController.addListener(() {
      //claude: only callback when the due date actually changes
      if (datePickerController.selectedDate == lastDueDate) return;
      lastDueDate = datePickerController.selectedDate; //claude
      _onDueDateChangeCallback!.call(datePickerController.selectedDate);
    });
  }

  set onLoadChangeCallback(Function(TaskLoad? newValue)? callback) {
    _onLoadChangeCallback = callback;
    loadController.addListener(() {
      //claude: only callback when the load actually changes
      if (loadController.selectedValue == lastLoad) return;
      lastLoad = loadController.selectedValue; //claude
      _onLoadChangeCallback!.call(loadController.selectedValue);
    });
  }

  set onStateChangeCallback(Function(TaskState? newValue)? callback) {
    _onStateChangeCallback = callback;
    stateController.addListener(() {
      //claude: only callback when the state actually changes
      if (stateController.selectedValue == lastState) return;
      lastState = stateController.selectedValue; //claude
      _onStateChangeCallback!.call(stateController.selectedValue);
    });
  }
  
}

//================================ ENUM DROPDOWN BUTTON ===========================================
class EnumDropdownButton<T extends Enum> extends StatefulWidget {
  final String title;
  final List<T> values;
  final EnumController<T> controller; //claude: replaces initialValue + onChanged

  const EnumDropdownButton({
    super.key,
    required this.values,
    required this.controller, //claude
    this.title = "",
  });

  @override
  State<EnumDropdownButton<T>> createState() => _EnumDropdownButtonState<T>();
}

class _EnumDropdownButtonState<T extends Enum> extends State<EnumDropdownButton<T>> {

  //claude: no more local _selectedItem — value now lives in widget.controller, rebuild when it changes
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged); //claude
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged); //claude
    super.dispose();
  }

  void _onControllerChanged() => setState(() {}); //claude

  void _dropdownButtonOnChanged(T? newItem) {
    widget.controller.selectedValue = newItem; //claude: write straight to controller instead of local state + callback
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: .start,
      children: [
        Text(widget.title),Container(width: 50,),
        DropdownButton<T>(
          items: widget.values.map((value) {
            return DropdownMenuItem<T>(
              value: value,
              child: Text(value.name),
            );
          }).toList(),
          value: widget.controller.selectedValue, //claude: read from controller
          onChanged: _dropdownButtonOnChanged,
        ),
      ],
    );
  }
}
//claude: new controller, holds the currently selected enum value, mirrors FullDatePickerController's shape
class EnumController<T extends Enum> extends ChangeNotifier {
  T? _selectedValue;
  T? get selectedValue => _selectedValue;
  set selectedValue(T? newVal) {
    _selectedValue = newVal;
    notifyListeners();
  }
}
//================================ NAMED TEXTFIELD ===========================================

class NamedTextField extends StatelessWidget {
  String title;
  TextEditingController controller;
  NamedTextField({
    super.key, required this.title, required this.controller
  });

  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: .start,
        children: [
          Text(title, style: subtitleStyle, textAlign: .left,),
          TextField(
            controller: controller, 
            decoration: 
              InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.zero, isCollapsed: true, isDense: true), 
              minLines: 1 ,maxLines: 5, 
              cursorHeight: 15,
            ),
        ],
    );
  }
}


//================================ DATE PICKER ===========================================
class FullDatePicker extends StatefulWidget{
  FullDatePickerController? controller;
  FullDatePicker({super.key, this.controller}){
    if (controller == null){
      this.controller = FullDatePickerController();
    }
  }
  
  @override
  State<FullDatePicker> createState() => _FullDatePickerState();
}

class _FullDatePickerState extends State<FullDatePicker> {

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text("Due Date: ", style: subtitleStyle),
        ElevatedButton(
          onPressed:  () async {
              DateTime? potentialSelectedDate = await showDatePicker(context: context, firstDate: DateTime(1900), lastDate: DateTime(2200));
              if (potentialSelectedDate != null){
                setState(() {
                  widget.controller!.selectedDate = potentialSelectedDate;
                });
              }
            }, 
          child: Text(widget.controller!.selectedDate == null ? "Elegir fecha" :   "${widget.controller!.selectedDate!.day}/${widget.controller!.selectedDate!.month}/${widget.controller!.selectedDate!.year}"),),
      ],
    );
  }
}

class FullDatePickerController extends ChangeNotifier {
  DateTime? _selectedDate;
  DateTime? get selectedDate{
    return _selectedDate;
  }
  set selectedDate(DateTime? newVal) {
    _selectedDate = newVal;
    notifyListeners();
  }
}
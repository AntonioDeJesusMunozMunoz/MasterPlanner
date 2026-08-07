import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:master_planner/data/db.dart';
import 'package:master_planner/data/model.dart';
import 'package:master_planner/overviewPanel.dart';
import 'package:master_planner/timelineAndGraph.dart';
import 'package:master_planner/todayView.dart';
import 'package:master_planner/viewModel/graphViewModel.dart';
import 'package:master_planner/viewModel/overviewViewModel.dart';
import 'package:master_planner/viewModel/tasksSOT.dart';
import 'package:master_planner/viewModel/todayViewModel.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

//constants
var uuid = Uuid();
enum Views {graph,tabbedText,stratifiedGraph, today}

//===================== view variables =================================
TasksSOT tasksSot = TasksSOT();

//graphView
late GraphViewModel graphVM;
late OverViewViewModel overviewVM;
late TodayViewModel todayVM;
GraphController stratifiedGraphController = GraphController();
OverviewController overviewController = OverviewController();
TodayViewController todayViewController = TodayViewController();


//==================== INTENTS FOR KEYBOARD ASSIGNMENTS =====================
class DeleteIntent extends Intent {

}

//==================== MAIN, AS IN THE FUNC AND THE WIDGET ==================
//Main func
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  graphVM =  GraphViewModel(sot: tasksSot, graphController: stratifiedGraphController);
  overviewVM = OverViewViewModel(sot: tasksSot, overviewController: overviewController);
  todayVM = TodayViewModel(sot: tasksSot, todayViewController: todayViewController);

  runApp(const MainApp());
}

//Main app
class MainApp extends StatefulWidget {
  const MainApp({super.key});


  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  //VARS
  var currView = Views.stratifiedGraph;
  var shouldShowOverview = false;
  var overViewOOBPos = 1000000.0;

  @override
  void initState() {
    super.initState();
    graphVM.onNodeSelectedChanged = _onGraphControllerNodeSelectedChangedDecideIfShowOverview;
  }

  //FUNCS 
  void _changeView(Views newView) {
    setState(() {
      currView = newView;
    });
  }

  void _onGraphControllerNodeSelectedChangedDecideIfShowOverview(GraphNode? node){
    setState(() {
      if (node != null){
        shouldShowOverview = true;
        overviewVM.taskUuid = node.uuid;
      }else{
        shouldShowOverview = false;
      }
    });
  }
  void showOverview(TaskModel task){
    setState(() {
      log("OHHHH MA GAAD");
      shouldShowOverview = !shouldShowOverview || overviewVM.taskUuid != task.uuid; //toggle show overview
      overviewVM.taskUuid = task.uuid;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {LogicalKeySet(LogicalKeyboardKey.delete) : DeleteIntent()},
      child: Actions(
        actions: {
          DeleteIntent : CallbackAction<DeleteIntent>(
            onInvoke: (intent) {
              graphVM.deleteSelectedTaskNode();
            },
          )
        },
        child: MaterialApp(
          home:  Scaffold(
            appBar: AppBar(backgroundColor: Colors.lightGreen,),
            drawer: Drawer(
              child: ListView(
                children: [
                  DrawerHeader(child: Icon(Icons.line_axis)),
                  ListTile(leading: Icon(Icons.account_tree), title: Text('Graph'), onTap: () => _changeView(Views.graph)),
                  ListTile(leading: Icon(Icons.text_fields), title: Text('Tabbed text'), onTap: () => _changeView(Views.tabbedText)),
                  ListTile(leading: Icon(Icons.calendar_month), title: Text('Calendar'), onTap: () => _changeView(Views.graph)),
                  ListTile(leading: Icon(Icons.account_tree_outlined), title: Text('Stratified tree'), onTap: () => _changeView(Views.stratifiedGraph)),
                  ListTile(leading: Icon(Icons.date_range), title: Text('Today'), onTap: () => _changeView(Views.today)),
                ],
              ),
            ),
            body: Stack(
              children: [
                //the main views
                switch (currView) {
                  Views.graph => GraphTaskView(),
                  Views.tabbedText => TabbedTextTaskView(),
                  Views.today => TodayView(controller: todayViewController, onTaskClickedCallback: showOverview,),
                  _ => OverviewPanel(controller: overviewController,)
                },

                //The overview always on top, can be shown on demand
                Positioned(left: MediaQuery.of(context).size.width - 400, top: shouldShowOverview ?  50 : overViewOOBPos, child: OverviewPanel(controller: overviewController,)), //TODO: currently the way the overview is hidden is by actually just moving it out of thw way, kinda janky
                ],
              )
          ),
        ),
      ),
    );
  }
}


//======================================= VIEWS ===============================

//graph view
class GraphTaskView extends StatefulWidget {
  const GraphTaskView({
    super.key,
  });

  @override
  State<GraphTaskView> createState() => _GraphTaskViewState();
}

class _GraphTaskViewState extends State<GraphTaskView> {
  //============================================= nav bar actions ==========================================
  void _addNode(){
    graphVM.addTaskNode();
  }

  void _saveGraph() async{

  }

  void _loadGraph() async{

  }

  void test(){
    log("testies");
    graphVM.addTaskNode();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
        children: [
          Row(
              mainAxisAlignment: .center,children: [ 
                IconButton(
                  onPressed: _addNode
                  ,icon: Icon(Icons.add)),
                IconButton(onPressed: _saveGraph, icon: Icon(Icons.save)),
                IconButton(onPressed: _loadGraph, icon: Icon(Icons.save_alt)),
                IconButton(onPressed: () {}, icon: Icon(Icons.timer)),
                IconButton(onPressed: test, icon: Icon(Icons.telegram))
            
              ],
            ),
      
          Expanded(
            child: Row(
              children: [ 
                Expanded(
                  child: timelineAndGraphWidget(graphController: stratifiedGraphController),
                )    
              ]
            ),
          ),
        ],
    );
  }

  @override
  void dispose(){
    super.dispose();
  }
}

//tabbed text view, this turned out to be way harder to make so its read only for now
class TabbedTextTaskView extends StatefulWidget {
  const TabbedTextTaskView({super.key});

  @override
  State<TabbedTextTaskView> createState() => _TabbedTextTaskViewState();
}

class _TabbedTextTaskViewState extends State<TabbedTextTaskView> {
  @override
  void initState(){
    super.initState();

    getTabbedText();
  }

  void test(){
    log("RAAAA");
  }

  String? tabbedText;

  //Turns the json into the tabbed text for displaying 
  //the convertion process was made with ai, so its a blackbox basically
  Future<void> getTabbedText() async {
    //loads the text
    var graphJson = await TaskRepository.loadGraph();

    //converts it 
    final json = jsonDecode(graphJson);

    final List nodes = json['nodes'];
    final List connections = json['connections'];

    // id -> node
    final Map<String, Map<String, dynamic>> nodeMap = {
      for (final n in nodes) n['id']: Map<String, dynamic>.from(n),
    };

    // parent -> children
    final Map<String, List<String>> children = {};

    // child -> parent count
    final Map<String, int> incoming = {
      for (final n in nodes) n['id']: 0,
    };

    for (final c in connections) {
      final parent = c['sourceNodeId'];
      final child = c['targetNodeId'];

      children.putIfAbsent(parent, () => []).add(child);
      incoming[child] = incoming[child]! + 1;
    }

    final buffer = StringBuffer();

    void dfs(String nodeId, int depth) {
      final node = nodeMap[nodeId]!;
      final title = node['data']['title'] ?? '';

      buffer.writeln('${'    ' * depth}$title');

      for (final child in children[nodeId] ?? []) {
        dfs(child, depth + 1);
      }
    }

    // Start from roots
    for (final id in incoming.keys.where((id) => incoming[id] == 0)) {
      dfs(id, 0);
    }

    //sets it
    setState(() {
      tabbedText = buffer.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.black38),
      child: Column(
        children: [
          Row(mainAxisAlignment: .center,children: [ 
                IconButton(
                  onPressed: () {}
                  ,icon: Icon(Icons.add)),
                IconButton(onPressed: () {}, icon: Icon(Icons.save)),
                IconButton(onPressed: () {}, icon: Icon(Icons.save_alt)),
                IconButton(onPressed: test, icon: Icon(Icons.telegram))
            
              ],),
          Expanded(child: tabbedText == null ? CircularProgressIndicator() : TextField(readOnly: true, maxLines: null, decoration: InputDecoration(fillColor: Colors.black38), controller: TextEditingController(text: tabbedText),))
        ],
      ),  
    );
  }
}
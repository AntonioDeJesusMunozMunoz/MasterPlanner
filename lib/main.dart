import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:master_planner/TimelineRuler.dart';
import 'package:master_planner/data/db.dart';
import 'package:master_planner/data/model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:vyuh_node_flow/vyuh_node_flow.dart';

var uuid = Uuid();
enum Views {graph,tabbedText,stratifiedGraph}

//===================================================HELPERS==============================
String genUniqueID() {return uuid.v4();}

//Main func
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  runApp(const MainApp());
}

//Main app
class MainApp extends StatefulWidget {
  const MainApp({super.key});


  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {

  //======================================= VARS ==============================
  var currView = Views.stratifiedGraph;


  //========================================= FUNCS ==========================================
  void _changeView(Views newView) {
    //taskStorageDBHelper.saveGraph(nodeFlowCon.exportGraph().toJsonString());//TODO i dont know how to save it now since nodeFlowCon now lives in that widget
    setState(() {
      currView = newView;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
            ],
          ),
        ),
        body: switch (currView) {
          Views.graph => GraphTaskView(),
          Views.tabbedText => TabbedTextTaskView(),
          _ => Column()
        }
      ),
    );
  }
}


//======================================= VIEWS ===============================

//graph view
class GraphTaskView extends StatefulWidget {
  GraphTaskView({
    super.key,
  });

  @override
  State<GraphTaskView> createState() => _GraphTaskViewState();
}

class _GraphTaskViewState extends State<GraphTaskView> {

  //the controller necesary for the tree view
  //it manages all state for it (nodes, connections, selections and viewport)
  // Create controller with initial nodes and connections
  var nodeFlowCon = NodeFlowController<TaskModel, dynamic>(
    config: NodeFlowConfig(
      plugins: [
        SnapPlugin([
          GridSnapDelegate(gridSize: 50.0)
        ],
        enabled: false
        )
      ]
    )
  );

  //============================================= nav bar actions ==========================================
  void _addNode(){
    var nodeSize = Size(200,100);
    nodeFlowCon.addNode(
                  Node<TaskModel>(
                    id: genUniqueID(), 
                    type: 'default', position: Offset(100, 100), 
                    data: TaskModel("taskTitle", null, null),
                    size: nodeSize,
                    ports: [
                      Port(id: genUniqueID(), name: 'asf', type: PortType.input,position: PortPosition.top, offset: Offset(nodeSize.width/2,0), multiConnections: true),
                      Port(id: genUniqueID(), name: 'asf2', type: PortType.output, position: PortPosition.top, offset: Offset(nodeSize.width/2,0), multiConnections: true),
                      Port(id: genUniqueID(), name: 'asf3', type: PortType.input,position: PortPosition.bottom, offset: Offset(nodeSize.width/2,0), multiConnections: true),
                      Port(id: genUniqueID(), name: 'asf4', type: PortType.output, position: PortPosition.bottom, offset: Offset(nodeSize.width/2,0), multiConnections: true)
                      ]
                  )
                  );
  }

  void _saveGraph() async{
    taskStorageDBHelper.saveGraph(nodeFlowCon.exportGraph().toJsonString());
  }

  void _loadGraph() async{
    log(await taskStorageDBHelper.loadGraph());
    nodeFlowCon.loadGraph(
      NodeGraph.fromJson(
        jsonDecode(await taskStorageDBHelper.loadGraph()),
        (data) => TaskModel.fromJson(data as Map<String,dynamic>),
        (data) => data
      )
    );
  }

  void test(){
    log(nodeFlowCon.exportGraph().toJsonString());
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
                IconButton(onPressed: () {(nodeFlowCon.plugins[0] as SnapPlugin).toggle();}, icon: Icon(Icons.timer)),//TODO this way of toggling stratos is SUPER hacky and will braek if another plugin ends up being the first one
                IconButton(onPressed: test, icon: Icon(Icons.telegram))
            
              ],
            ),
      
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: NodeFlowEditor<TaskModel, dynamic>(
                       controller: nodeFlowCon,
                       theme: NodeFlowTheme.light, 
                       nodeBuilder: (context,node) => Center(
                          child: TextField(
                            onChanged: (newData) =>{ node.data.title = newData}, 
                            controller: TextEditingController(text: node.data.title),
                            textAlign: .center,),
                          ),
                       events: NodeFlowEvents(
                        viewport: ViewportEvents(
                          onMove: (viewPortState) {
                            log("message");
                          },
                        )
                       ),
                     ),
                ),
                   //TimeRuler(canvasOffsetY: 0, zoom: 1, epoch: DateTime(2026,6,27), pxPerHour: 10),
                      
                ]
            ),

                   
          ),
      
        ],
    );
  }

  @override
  void dispose(){
    nodeFlowCon.dispose();
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
    var graphJson = await taskStorageDBHelper.loadGraph();

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
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:master_planner/data/db.dart';
import 'package:master_planner/data/model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:vyuh_node_flow/vyuh_node_flow.dart';

var uuid = Uuid();

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
 const  MainApp({super.key});


  @override
  State<MainApp> createState() => _MainAppState();


}

class _MainAppState extends State<MainApp> {

  //the controller necesary for the tree view
  //it manages all state for it (nodes, connections, selections and viewport)
  // Create controller with initial nodes and connections
  late final nodeFlowCon = NodeFlowController<TaskModel, dynamic>();

  //====================== nav bar actions ================================
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
    return MaterialApp(
      home:  Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: .center,children: [ 
              IconButton(
                onPressed: _addNode
                ,icon: Icon(Icons.add)),
              IconButton(onPressed: _saveGraph, icon: Icon(Icons.save)),
              IconButton(onPressed: _loadGraph, icon: Icon(Icons.save_alt)),
              IconButton(onPressed: test, icon: Icon(Icons.telegram))
            ],
          )
        ),
        body: NodeFlowEditor<TaskModel, dynamic>(
                 controller: nodeFlowCon,
                 theme: NodeFlowTheme.light, 
                 nodeBuilder: (context,node) => Center(
                    child: TextField(onChanged: (newData) =>{ nodeFlowCon.getNode(node.id)!.data.title = newData}, controller: TextEditingController(text: node.data.title))
                    )
                  ),
      ),
    )
        ;
  }

  @override
  void dispose(){
    nodeFlowCon.dispose();
    super.dispose();
  }
}

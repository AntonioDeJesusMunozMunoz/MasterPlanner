import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:master_planner/data/db.dart';
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
  late final controller = NodeFlowController<dynamic, dynamic>(
    nodes: []
    //   Node<String>(
    //     id: 'start',
    //     type: 'input',
    //     position: const Offset(100, 100),
    //     size: const Size(140, 70),
    //     data: 'Start',
    //     ports: [Port(id: 'id', name: 'name')]
    //   ),
    //   Node<String>(
    //     id: 'process',
    //     type: 'default',
    //     position: const Offset(320, 100),
    //     size: const Size(140, 70),
    //     data: 'Process',
    //   ),
    //   Node<String>(
    //     id: 'end',
    //     type: 'output',
    //     position: const Offset(540, 100),
    //     size: const Size(140, 70),
    //     data: 'End',
    //   ),
    // ],
    // connections: [
    //   Connection(
    //     id: 'conn-1',
    //     sourceNodeId: 'start',
    //     sourcePortId: 'out',
    //     targetNodeId: 'process',
    //     targetPortId: 'in',
    //   ),
    //   Connection(
    //     id: 'conn-2',
    //     sourceNodeId: 'process',
    //     sourcePortId: 'out',
    //     targetNodeId: 'end',
    //     targetPortId: 'in',
    //   ),
    // ],
  );

  //====================== nav bar actions ================================
  void _addNode(){
    var nodeSize = Size(200,100);
    controller.addNode(
                  Node<dynamic>(
                    id: genUniqueID(), 
                    type: 'default', position: Offset(100, 100), 
                    data: 'testies',//TextField( decoration: null, textAlign: .center,),//TODO change to a serializable custom class
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
    taskStorageDBHelper.saveGraph(controller.exportGraph().toJsonString());
  }

  void _loadGraph() async{
    log(await taskStorageDBHelper.loadGraph());
    controller.loadGraph(
      NodeGraph.fromJson(
        jsonDecode(await taskStorageDBHelper.loadGraph()),
        (data) => data,
        (data) => data
      )
    );
  }

  void test(){
    log(controller.exportGraph().toJsonString());
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
        body: NodeFlowEditor<dynamic, dynamic>(
                 controller: controller,
                 theme: NodeFlowTheme.light, 
                 nodeBuilder: (context,node) => Center(
                    child: node.data is String? Text(node.data) : node.data
                    )
                  ),
      ),
    )
        ;
  }

  @override
  void dispose(){
    controller.dispose();
    super.dispose();
  }
}

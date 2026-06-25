import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:vyuh_node_flow/vyuh_node_flow.dart';

var uuid = Uuid();

//===================================================HELPERS==============================
String genUniqueID() {return uuid.v4();}

//Main func
void main() {
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
  late final controller = NodeFlowController<String, dynamic>(
    nodes: [
      Node<String>(
        id: 'start',
        type: 'input',
        position: const Offset(100, 100),
        size: const Size(140, 70),
        data: 'Start',
        ports: [Port(id: 'id', name: 'name')]
      ),
      Node<String>(
        id: 'process',
        type: 'default',
        position: const Offset(320, 100),
        size: const Size(140, 70),
        data: 'Process',
      ),
      Node<String>(
        id: 'end',
        type: 'output',
        position: const Offset(540, 100),
        size: const Size(140, 70),
        data: 'End',
      ),
    ],
    connections: [
      Connection(
        id: 'conn-1',
        sourceNodeId: 'start',
        sourcePortId: 'out',
        targetNodeId: 'process',
        targetPortId: 'in',
      ),
      Connection(
        id: 'conn-2',
        sourceNodeId: 'process',
        sourcePortId: 'out',
        targetNodeId: 'end',
        targetPortId: 'in',
      ),
    ],
  );

  void _addNode(){
    controller.addNode(
                  Node(id: genUniqueID(), 
                    type: 'default', position: Offset(100, 100), 
                    data: 'RAAA',
                    ports: [
                      Port(id: genUniqueID(), name: 'asf', type: PortType.input,position: PortPosition.top, offset: Offset(100, 0)),
                      Port(id: genUniqueID(), name: 'asf2', type: PortType.output, position: PortPosition.top),
                      Port(id: genUniqueID(), name: 'asf3', type: PortType.input,position: PortPosition.bottom),
                      Port(id: genUniqueID(), name: 'asf4', type: PortType.output, position: PortPosition.bottom)
                      ]
                  )
                  );
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
                ,icon: Icon(Icons.add))
            ],
          )
        ),
        body: NodeFlowEditor<String, dynamic>(
                 controller: controller,
                 theme: NodeFlowTheme.light, 
                 nodeBuilder: (context,node) => Center(child: Text(node.data))),
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

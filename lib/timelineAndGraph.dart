import 'dart:developer';

import 'package:flutter/material.dart';



//===================================== HELPER CLASSES =========================================
// single node from the timeline idget,has pos x,y and ofset long and tall
class GraphNode{
  late Offset pos;//position is the id as to not allow 2 nodes to be in the same place
  late Size size;
  String uuid = ""; 

  GraphNode(double x,double y,double long, double tall, {this.uuid = ""}){
    pos = Offset(x, y);
    size = Size(long, tall);
  }

  Offset get topPort => Offset(pos.dx + size.width/2, pos.dy-5);
  Offset get bottomPort => Offset(pos.dx + size.width/2, pos.dy + size.height+5);
} 

class GraphConnections{
  late GraphNode startNode;
  late GraphNode endNode;

  GraphConnections(this.startNode, this.endNode);
}

//==================================== HELPER functions ========================================
bool between(double pos, double side1, double side2){
  return (pos < side1 && pos > side2) || (pos < side2 && pos > side1);
}

bool aabb(GraphNode node,Offset pos){
  return between(pos.dx, node.pos.dx, node.pos.dx + node.size.width) && between(pos.dy, node.pos.dy, node.pos.dy + node.size.height);
}

bool circleCollision(Offset center, double radius, Offset pos){
  return (center - pos).distance <= radius;
}

//==================================== MAIN CLASS ==============================================
class timelineAndGraphWidget extends StatefulWidget{
  late final GraphController graphController;

  timelineAndGraphWidget({required  this.graphController});

  @override
  State<timelineAndGraphWidget> createState() => _timelineAndGraphWidgetState();
}

class _timelineAndGraphWidgetState extends State<timelineAndGraphWidget> {
  late timelineAndGraphPainter painter = timelineAndGraphPainter(widget.graphController);

  int? draggedNodeInd;
  bool makingConnection = false;
  bool newConnStartOrEndPort = true;//true == start, false == end
  GraphNode? newConnGrabbedNode;

  GraphNode? getTouchedNode(Offset pos){
    //go over every node and return only the one touched
    for (var node in widget.graphController.nodes) {
      if( aabb(node, pos)){
        return node;
      }
    }

    //return null if it didnt touch any
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
        minScale: 0.1,
        maxScale: 4,
        boundaryMargin: EdgeInsets.zero,
        constrained: false,
        child: SizedBox(
            width: 20000,
            height: 10000,
            child: Container(//keep this for debug
              decoration: BoxDecoration(color: const Color.fromARGB(255, 64, 203, 238)),
              child: GestureDetector(
                onTapUp:(onTapUpDetails) {
                  bool touchedNothing = true;

                  //logic for selecting
                  for (var node in widget.graphController.nodes) {
                    if( aabb(node, onTapUpDetails.localPosition)){
                      log("touched");
                      widget.graphController.selectedNode = node;
                      touchedNothing = false;
                      widget.graphController.moveNode(0, Offset.zero);//TODO this is so the canvas repaints, there must be a better way
                      break;
                    }
                    
                    if (circleCollision(node.topPort, widget.graphController.portRadius, onTapUpDetails.localPosition)){
                      log("touched top port");
                    }
                    
                    if (circleCollision(node.bottomPort, widget.graphController.portRadius, onTapUpDetails.localPosition)){
                      log("touched bottom port");
                    }
                  }

                  //logic for deselecting
                  if (touchedNothing){
                    widget.graphController.selectedNode = null;
                  }
                },
                
                onPanStart: (onPanDetails) {
                  GraphNode? touchedNode = getTouchedNode(onPanDetails.localPosition);
                  widget.graphController.selectedNode = touchedNode;
                  //if it touched a node, start moving the node
                  if (touchedNode != null){
                    draggedNodeInd = widget.graphController.nodes.indexWhere((node) => node.pos == touchedNode!.pos);
                  } 
                  //otherwise, check if it touched a port
                  else {
                    for (var node in widget.graphController.nodes) {
                    
                      //check if it collided with any port and save it 
                    
                      //if it collided with the top port, set the flag to false to signal its going to be the end port
                      if (circleCollision(node.topPort, widget.graphController.portRadius, onPanDetails.localPosition)){
                        newConnGrabbedNode = node;
                        newConnStartOrEndPort = false;
                        makingConnection = true;
                    
                      //else, do the oposite with the bottom port
                      } else if (circleCollision(node.bottomPort, widget.graphController.portRadius, onPanDetails.localPosition)){
                        newConnGrabbedNode = node;
                        newConnStartOrEndPort = true;
                        makingConnection = true;
                      }
                    }
                  }
                },
                    
                onPanUpdate: (details) {
                  if (draggedNodeInd != null){
                      //update pos
                      widget.graphController.moveNode(draggedNodeInd!, details.delta);
                    
                  } else if (makingConnection) {
                    log("${details.localPosition}");
                    if (newConnStartOrEndPort){
                      widget.graphController.setNewConnection(GraphConnections(newConnGrabbedNode!, GraphNode(details.localPosition.dx,details.localPosition.dy,1,1)));
                    } else {
                      widget.graphController.setNewConnection(GraphConnections(GraphNode(details.localPosition.dx,details.localPosition.dy,1,1), newConnGrabbedNode!));
                    }
                  }
                },
                    
                onPanEnd: (details) {
                  //si se estaba haciendo una conexion
                  if (makingConnection){
                    GraphNode? selectedNode;
                    
                    //checo si el final esta lo suficientemente cerca de algun nodo opuesto
                    if (newConnStartOrEndPort) {
                      for (var node in widget.graphController.nodes) {
                        //if the top port is close enough, it marks it as the selected one
                        if (circleCollision(node.topPort, widget.graphController.portRadius + 5, details.localPosition)) {
                          selectedNode = node;
                          break;
                        }
                      }
                    } else {
                      for (var node in widget.graphController.nodes) {
                        //if the top port is close enough, it marks it as the selected one
                        if (circleCollision(node.bottomPort, widget.graphController.portRadius + 5, details.localPosition)) {
                          selectedNode = node;
                          break;
                        }
                      }
                    }
                    
                    //si si esta lo suficientemente cerca de un puerto, crea la conexion
                    if (selectedNode != null) {
                      if (newConnStartOrEndPort) {
                        widget.graphController.addConnection(GraphConnections(newConnGrabbedNode!, selectedNode));
                      } else {
                        widget.graphController.addConnection(GraphConnections(selectedNode, newConnGrabbedNode!));
                      }
                    }
                  }
                    
                  makingConnection = false;
                  newConnGrabbedNode = null;
                  widget.graphController.destroyNewConnection();
                  draggedNodeInd = null;
                },
                
                child: CustomPaint(
                  painter: painter,
                ),
              ),
            ),
          ),
    );
  }
}

class timelineAndGraphPainter extends CustomPainter{
  Paint nodePaint = Paint();
  Paint portPaint = Paint();
  Paint connectionPaint = Paint();
  Paint newConnectionPaint = Paint();
  Paint nodeHighlightPaint = Paint();
  final GraphController controller;

  timelineAndGraphPainter(this.controller) : super(repaint: controller) {
    nodePaint.style = PaintingStyle.fill;
    nodePaint.color = Colors.black45;
    portPaint.style = PaintingStyle.fill;
    portPaint.color = Colors.greenAccent;
    connectionPaint.color = Colors.blueGrey;
    connectionPaint.strokeWidth = 7;
    newConnectionPaint.color = Colors.blueGrey;
    newConnectionPaint.strokeWidth = 7;
    nodeHighlightPaint.style = PaintingStyle.stroke;
    nodeHighlightPaint.color = Colors.red;
    nodeHighlightPaint.strokeWidth = 10;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // NEW: draw dot grid background first, so everything else draws on top
    final dotPaint = Paint()..color = Colors.black26;
    const spacing = 50.0;
    const dotRadius = 2.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
      }
    }


    //draw connections
    for (var connection in controller.conns) {
      canvas.drawLine(connection.startNode.bottomPort, connection.endNode.topPort, connectionPaint);
    }

    //draw every node
    for (var node in controller.nodes) {
      //draw body
      canvas.drawRect(Rect.fromLTWH(node.pos.dx, node.pos.dy, node.size.width, node.size.height), nodePaint);

      //highlight selected
      if (identical(node, controller.selectedNode)){
        canvas.drawRect(Rect.fromLTWH(node.pos.dx, node.pos.dy, node.size.width, node.size.height),nodeHighlightPaint);
      }

      //draw ports
      canvas.drawCircle(node.topPort, controller.portRadius, portPaint);
      canvas.drawCircle(node.bottomPort, controller.portRadius, portPaint);
    }

    //draw the newConnection if it exists

    if (controller.newConnection != null) {
      canvas.drawLine(controller.newConnection!.startNode.bottomPort, controller.newConnection!.endNode.topPort, newConnectionPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // TODO: implement shouldRepaint
    return true;
  }
}

class GraphController extends ChangeNotifier {
  List<GraphNode> nodes = List<GraphNode>.empty(growable: true); //TODO make it clear you shouldnt touch this directly
  List<GraphConnections> conns = List<GraphConnections>.empty(growable: true);
  double portRadius = 6;
  GraphConnections? newConnection;
  GraphNode? selectedNode;

  //callbacks
  void Function(GraphNode nodeAdded)? onNodeAddedCallback;
  void Function(GraphNode nodeDeleted)? onNodeDeletedCallback;
  void Function(GraphNode nodeMoved)? onNodeMovedCallback;
  void Function(GraphConnections connAdded)? onConnectionAddedCallback;
  void Function(GraphConnections connRemoved)? onConnectionRemovedCallback;
  void Function()? onGraphReplacedCallback;

  void addNode(GraphNode newNode) {
    nodes.add(newNode); //add node
    notifyListeners();

    onNodeAddedCallback?.call(newNode);
  }

  void deleteSelectedNode(){
    //first safeguard for deleting non existing node
    if (selectedNode == null){
      log("tried to delete without a node selected");
      return;
    }

    //then delete it
    deleteNode(selectedNode!);

    //then deselect it 
    selectedNode = null;
  }

  void deleteNode(GraphNode removedNode) {
    nodes.remove(removedNode);

    // also drop any connections that referenced this node, so you don't
    // end up with dangling GraphConnections pointing at a removed node
    conns.removeWhere((conn) =>
        identical(conn.startNode, removedNode) || identical(conn.endNode, removedNode));

    notifyListeners();

    onNodeDeletedCallback?.call(removedNode);
  }

  void moveNode(int nodeInd, Offset delta) {
    nodes[nodeInd].pos += delta;
    notifyListeners();

    onNodeMovedCallback?.call(nodes[nodeInd]);
  }

  void setNewConnection(GraphConnections newConData) {
    newConnection = newConData;
    notifyListeners();
  }

  void destroyNewConnection() {
    newConnection = null;
    notifyListeners();
  }

  void addConnection(GraphConnections conn) {
    conns.add(conn);
    notifyListeners();

    onConnectionAddedCallback?.call(conn);
  }

  void removeConnection(GraphConnections conn) {
    conns.remove(conn);
    notifyListeners();

    onConnectionRemovedCallback?.call(conn);
  }

  void replaceNodes(List<GraphNode> newNodes, List<GraphConnections> newConns) {
    nodes = newNodes;
    conns = newConns;
    notifyListeners();

    onGraphReplacedCallback?.call();
  }
}
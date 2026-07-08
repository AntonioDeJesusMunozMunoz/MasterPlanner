import 'dart:developer';

import 'package:flutter/material.dart';



//===================================== HELPER CLASSES =========================================
// single node from the timeline widget,has pos x,y and ofset long and tall
class GraphNode{
  late Offset pos;//position is the id as to not allow 2 nodes to be in the same place
  late Size size;

  GraphNode(double x,double y,double long, double tall){
    pos = Offset(x, y);
    size = Size(long, tall);
  }

  Offset get topPort => Offset(this.pos.dx + this.size.width/2, this.pos.dy-5);
  Offset get bottomPort => Offset(this.pos.dx + this.size.width/2, this.pos.dy + this.size.height+5);
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
    return SizedBox.expand(
      child: GestureDetector(
        onTapUp:(onTapUpDetails) {
          for (var node in widget.graphController.nodes) {
            if( aabb(node, onTapUpDetails.localPosition)){
              log("touched");
            }

            if (circleCollision(node.topPort, widget.graphController.portRadius, onTapUpDetails.localPosition)){
              log("touched top port");
            }

            if (circleCollision(node.bottomPort, widget.graphController.portRadius, onTapUpDetails.localPosition)){
              log("touched bottom port");
            }
          }
        },
        
        onPanStart: (onPanDetails) {
          GraphNode? touchedNode = getTouchedNode(onPanDetails.localPosition);

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
    );
  }
}

class timelineAndGraphPainter extends CustomPainter{
  Paint nodePaint = Paint();
  Paint portPaint = Paint();
  Paint connectionPaint = Paint();
  Paint newConnectionPaint = Paint();
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
    
  }

  @override
  void paint(Canvas canvas, Size size) {
    //draw connections
    for (var connection in controller.conns) {
      canvas.drawLine(connection.startNode.bottomPort, connection.endNode.topPort, connectionPaint);
    }

    //draw every node
    for (var node in controller.nodes) {
      //draw body
      canvas.drawRect(Rect.fromLTWH(node.pos.dx, node.pos.dy, node.size.width, node.size.height), nodePaint);

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
  List<GraphNode> nodes = List<GraphNode>.empty(growable: true);
  List<GraphConnections> conns = List<GraphConnections>.empty(growable: true);
  double portRadius = 6;
  GraphConnections? newConnection;

  void addNode(GraphNode newNode){
    nodes.add(newNode);//add node
    notifyListeners();
  }

  void moveNode(int nodeInd, Offset delta) {
    nodes[nodeInd].pos += delta;
    notifyListeners();
  }

  void setNewConnection(GraphConnections newConData){
   newConnection = newConData;
   notifyListeners();
  }

  void destroyNewConnection(){
    newConnection = null;
    notifyListeners();
  }

  void addConnection(GraphConnections conn) {
    conns.add(conn);
    notifyListeners();
  }
}

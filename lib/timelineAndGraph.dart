import 'dart:developer';

import 'package:flutter/material.dart';



//===================================== HELPER CLASSES =========================================
// single node from the timeline widget,has pos x,y and ofset long and tall
class graphNode{
  late Offset pos;//position is the id as to not allow 2 nodes to be in the same place
  late Size size;

  graphNode(double x,double y,double long, double tall){
    pos = Offset(x, y);
    size = Size(long, tall);
  }
} 

//==================================== HEPER functions ========================================
bool between(double pos, double side1, double side2){
  return (pos < side1 && pos > side2) || (pos < side2 && pos > side1);
}

bool aabb(graphNode node,Offset pos){
  return between(pos.dx, node.pos.dx, node.pos.dx + node.size.width) && between(pos.dy, node.pos.dy, node.pos.dy + node.size.height);
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


  graphNode? getTouchedNode(Offset pos){
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
          }
        },
        onPanStart: (onPanDetails) {
          graphNode? touchedNode = getTouchedNode(onPanDetails.localPosition);
          if (touchedNode != null){
            draggedNodeInd = widget.graphController.nodes.indexWhere((node) => node.pos == touchedNode!.pos);
          }
        },

        onPanUpdate: (details) {
          if (draggedNodeInd != null){
              //identify node
              for (var node in widget.graphController.nodes) {
                log('${node.pos}');
              }

              graphNode draggedNode = widget.graphController.nodes[draggedNodeInd!];
              //update pos
              widget.graphController.changeNode(graphNode(draggedNode.pos.dx + details.delta.dx, draggedNode.pos.dy + details.delta.dy, draggedNode.size.width, draggedNode.size.height), draggedNodeInd!);
           }
        },

        onPanEnd: (details) {
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
  final GraphController controller;

  timelineAndGraphPainter(this.controller) : super(repaint: controller) {
    nodePaint.style = PaintingStyle.fill;
    nodePaint.color = Colors.black45;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (var node in controller.nodes) {
      canvas.drawRect(Rect.fromLTWH(node.pos.dx, node.pos.dy, node.size.width, node.size.height), nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // TODO: implement shouldRepaint
    return true;
  }
}

class GraphController extends ChangeNotifier {
  List<graphNode> nodes = List<graphNode>.empty(growable: true);

  void addNode(graphNode newNode){
    nodes.add(newNode);//add node
    notifyListeners();
  }

  void changeNode(graphNode newNodeValue, int nodeIndex){
    nodes[nodeIndex] = newNodeValue;
    notifyListeners();
  }
}

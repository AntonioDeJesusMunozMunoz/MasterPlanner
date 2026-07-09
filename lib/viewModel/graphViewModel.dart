import 'dart:developer';
import 'dart:core';

import 'package:flutter/material.dart';
import 'package:master_planner/data/model.dart';
import 'package:master_planner/main.dart';
import 'package:master_planner/timelineAndGraph.dart';
import 'package:master_planner/viewModel/tasksSOT.dart';

/*
* INTERFACE CLASS FOR COMUNICATING THE TASKS
* the view gets the data it needs for the visualization through here
*/

class GraphViewModel {
  late final TasksSOT sot;
  late final GraphController graphController;
  final Map<String, GraphNode> idToNode = Map.from({});

  //constructor
  GraphViewModel({required this.sot, required this.graphController}) {
    sot.addListener(_updateGraph);
  }

  //update graph
  void _updateGraph(){
    log("truth changed, billions must die");
    buildGraph();
  }

  //helper bfs
  void _createGraphDFS(TaskModel currTask ,Offset posOffset, GraphNode? parent,final List<GraphNode> newNodes, final List<GraphConnections> newConnections, final Set<String> visitedTasks){
    //create and add curr node
    GraphNode currNode = GraphNode(posOffset.dx, posOffset.dy, 200, 100);
    newNodes.add(currNode);

    idToNode[currTask.uuid] = currNode;

    //create connection if has a parent
    if (parent != null) {
      newConnections.add(GraphConnections(parent, currNode));
    } 

    //prepare offset
    posOffset += Offset(-150,150);  

    //repeat for children
    for (var child in currTask.subtasks) {
      //skip visited
      if (visitedTasks.contains(child.uuid)){
        continue;
      }

      //if not visited, visit and mark it
      _createGraphDFS(child, posOffset, currNode, newNodes, newConnections, visitedTasks);
      visitedTasks.add(child.uuid);

      //update offset
      posOffset += Offset(125, 0);
    }
  }

  //this function sets the graph controllers nodes and connections to a 
  void buildGraph(){
    List<GraphNode> newNodes = List.empty(growable: true);
    List<GraphConnections> newConnections  = List.empty(growable: true);

    Offset startPos = Offset(1000, 500);
    Set<String> visitedTasks = Set.of({});

    //bfs that creates task and assigns connections and position 
    for (var task in tasksSot.tasks) { 
      //skip visited
      if (visitedTasks.contains(task.uuid)){
        continue;
      }

      //if not visited, visit and mark it
      _createGraphDFS(task, startPos, null, newNodes, newConnections, visitedTasks);
      visitedTasks.add(task.uuid);

      //update startPos
      startPos += Offset(125, 0);
    }

    graphController.replaceNodes(newNodes, newConnections);
  }
}
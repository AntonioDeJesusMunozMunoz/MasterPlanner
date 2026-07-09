import 'dart:developer';
import 'dart:core';

import 'package:flutter/material.dart';
import 'package:master_planner/data/model.dart';
import 'package:master_planner/main.dart';
import 'package:master_planner/timelineAndGraph.dart';
import 'package:master_planner/viewModel/tasksSOT.dart';


class NodeVisualizationData {
  Offset nodePos;

  NodeVisualizationData(this.nodePos);
}

/*
* INTERFACE CLASS FOR COMUNICATING THE TASKS
* the view manages the graph through here as to keep graph and sot synched
*/

class GraphViewModel {
  late final TasksSOT sot;
  late final GraphController graphController;
  //final Map<String, GraphNode> idToNode = Map.from({});
  final Map<String, NodeVisualizationData> idToVisualizationData = Map.from({});


  //constructor
  GraphViewModel({required this.sot, required this.graphController}) {
    sot.addListener(_updateGraph);
    
    //set graph callbacks
    graphController.onConnectionAddedCallback = _addConnection;
    graphController.onNodeDeletedCallback = _deleteTaskNode; //TODO code for this guy was added BUT NEVER TESTED because you cant even delete nodes yet
    graphController.onNodeMovedCallback = _updateNodeVisualizationData;
  }

  //listeners
  void _updateGraph(){
    log("truth changed, billions must die");
    buildGraph();
  }

  void _addConnection(GraphConnections conn){
    TaskModel parentTask = sot.tasks.firstWhere((task) {log(task.uuid); return task.uuid == conn.startNode.uuid;});
    parentTask.subtasks.add(sot.tasks.firstWhere((task) => task.uuid == conn.endNode.uuid));
  }

  void _deleteTaskNode(GraphNode node){
    sot.tasks.removeWhere((task) => task.uuid == node.uuid);//TODO ahorita no eliminar hijos, eso esta bien, pero no se si sea lo que se quiera al final
  }

  void _updateNodeVisualizationData(GraphNode node){
    idToVisualizationData[node.uuid] = NodeVisualizationData(node.pos);
  }

  //helper bfs
  void _createGraphDFS(TaskModel currTask ,Offset posOffset, GraphNode? parent,final List<GraphNode> newNodes, final List<GraphConnections> newConnections, final Set<String> visitedTasks){
    //load visualization data if i have
    NodeVisualizationData? vizData = idToVisualizationData[currTask.uuid];

    log('antes del if');

    if (vizData != null){
      log("si corre el if");
      posOffset = vizData.nodePos;
    }

    //create and add curr node
    GraphNode currNode = GraphNode(posOffset.dx, posOffset.dy, 200, 100, uuid: currTask.uuid);
    newNodes.add(currNode);

    //create connection if has a parent
    if (parent != null) {
      newConnections.add(GraphConnections(parent, currNode));
    } 

    //prepare offset
    posOffset += Offset(-400,150);  

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
      posOffset += Offset(300, 0);
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
      startPos += Offset(300.0 * (1 + task.subtasks.length), 0);
    }

    graphController.replaceNodes(newNodes, newConnections);
  }

  //=================================== methods for the view ============================
  void addTaskNode(){
    sot.addTask(TaskModel("new task"));
  }
}
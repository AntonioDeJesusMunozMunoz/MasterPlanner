import 'dart:developer';
import 'dart:core';
import 'dart:math' show min, max;

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

const double MAX_RIGHT_OFFSET = 10000;
const double MAX_DOWN_OFFSET = 5000;
const double MIN_LEFT_OFFSET = 0;
const double MIN_UP_OFFSET = 0;

class GraphViewModel {
  late final TasksSOT sot;
  late final GraphController graphController;
  //final Map<String, GraphNode> idToNode = Map.from({});
  final Map<String, NodeVisualizationData> idToVisualizationData = Map.from({});

  void Function (GraphNode? node)? onNodeSelectedChanged;


  //constructor
  GraphViewModel({required this.sot, required this.graphController, this.onNodeSelectedChanged}) {
    sot.addListener(_updateGraph);
    
    //set graph callbacks
    graphController.onConnectionAddedCallback = _addConnection;
    graphController.onNodeDeletedCallback = _deleteTaskNode;
    graphController.onNodeMovedCallback = _updateNodeVisualizationData;
    graphController.onSelectedNodeChangedCallback =  _onNodeSelectedChangedCallback;
  }

  //listeners
  void _updateGraph(){
    buildGraph();
  }

  void _addConnection(GraphConnections conn){
    TaskModel parentTask = sot.taskMap[conn.startNode.uuid]!;
    parentTask.subtasks.add(conn.endNode.uuid);
  }

  void _deleteTaskNode(GraphNode node){
    sot.deleteTask(node.uuid);//TODO ahorita no eliminar hijos, eso esta bien, pero no se si sea lo que se quiera al final
    //sot.tasks.removeWhere((currTask) {return currTask.uuid == node.uuid;});
  }

  void _updateNodeVisualizationData(GraphNode node){
    idToVisualizationData[node.uuid] = NodeVisualizationData(node.pos);
  }

  void _onNodeSelectedChangedCallback(GraphNode? node){
    onNodeSelectedChanged?.call(node);
  }

  //helper bfs
  void _createGraphDFS(TaskModel currTask ,Offset posOffset, GraphNode? parent,final List<GraphNode> newNodes, final List<GraphConnections> newConnections, final Set<String> visitedTasks){
    //load visualization data if i have
    NodeVisualizationData? vizData = idToVisualizationData[currTask.uuid];

    if (vizData != null){
      posOffset = vizData.nodePos;
    }

    //create and add curr node
    posOffset = Offset(//clamp before accepting
      posOffset.dx.clamp(MIN_LEFT_OFFSET, MAX_RIGHT_OFFSET).toDouble(),
      posOffset.dy.clamp(MIN_UP_OFFSET, MAX_DOWN_OFFSET).toDouble(),
    );
    GraphNode currNode = GraphNode(posOffset.dx, posOffset.dy, 200, 100, uuid: currTask.uuid, text: currTask.title);
    log("task to be added: ${currNode.uuid}, parent: ${parent}");
    newNodes.add(currNode);

    //create connection if has a parent
    if (parent != null) {
      newConnections.add(GraphConnections(parent, currNode));
    } 

    //prepare offset starting more left and down in respect of me
    posOffset += Offset(-400,150);  
    posOffset = Offset(max(posOffset.dx, MIN_LEFT_OFFSET), min(posOffset.dy, MAX_DOWN_OFFSET));//cap bounds

    //repeat for children
    for (var childUuid in currTask.subtasks) {
      TaskModel child = sot.taskMap[childUuid]!;
      //skip subtasks that no longer exist in the sot //claude: reverted from a null .target check to a sot.containsTask lookup, since subtasks is now a plain List<TaskModel>
      if (!sot.containsTask(child)){
        log("THIS SHOULD NEVER RUN BECAUSE THE SOT PRUNES DEAD SUBTASKS UPON DELETION");
        continue;
      }

      //skip visited
      if (visitedTasks.contains(child.uuid)){ //claude: reverted, no longer unwrapping .target
        return;
      }

      //if not visited, visit and mark it
      visitedTasks.add(child.uuid); 
      //recurr setting child posOffset to the prepared one
      _createGraphDFS(child, posOffset, currNode, newNodes, newConnections, visitedTasks); 

      //move offset for next child
      posOffset += Offset(300, 0);
      posOffset = Offset(min(posOffset.dx, MAX_RIGHT_OFFSET), min(posOffset.dy, MAX_DOWN_OFFSET));//cap upper offset bounds
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
      visitedTasks.add(task.uuid);
      _createGraphDFS(task, startPos, null, newNodes, newConnections, visitedTasks);

      //update startPos
      startPos += Offset(300.0 * (1 + task.subtasks.length), 0);
    }

    graphController.replaceNodes(newNodes, newConnections);
  }

  //=================================== methods for the view ============================
  void addTaskNode(){
    sot.addTask(TaskModel("new task"));
  }

  void deleteSelectedTaskNode(){
    graphController.deleteSelectedNode();//absolutely crazy workflow, this calls graph controller which calls this._deleteTaskNode which calls the sot which notifies listeners which this is a listener of? why doesnt this loop?
  }
}
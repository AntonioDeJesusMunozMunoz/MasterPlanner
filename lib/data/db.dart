import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class TaskRepository {
  static final TaskRepository instance = TaskRepository._init();
  static Database? _db;

  TaskRepository._init();

   static Future<Database> getDB() async{
      //if it doesnt exist, initialize it
      if (_db == null){
        _db = await _initDB();
      }

      return _db!;
   }
   
   static Future<Database> _initDB() async{
    //get path
    final pathToDB = join(await getDatabasesPath(), 'taskStorageDB.db');

    //return the database in that path
    return await openDatabase(pathToDB, version: 1, onCreate: _onCreate);

   }

   //on create method for the openDatabase function, basically the querys to create the db
   static Future<void> _onCreate(Database db, int version) async {
      await db.transaction( ((txn) async {
        
        //table for storing the jsons of the graphs
        //im using the json format from the graph to json adding ny extra data i need to a node through the data field and a custom serializeable class
        await txn.execute(
          '''
          CREATE TABLE graphsAsJson(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            graph TEXT
          );
          '''
        );


      })
        
      );
   }

  //interface
   static Future<void> saveGraph(String graphJson, {int id = 1}) async {
      var db = await getDB();

     await db.transaction((txn) async {
        await txn.insert('graphsAsJson', {'graph':graphJson, 'id':id}, conflictAlgorithm: ConflictAlgorithm.replace);
      });
   }

   static Future<String> loadGraph({int id = 1}) async {
      //load data
      var db = await getDB();
      var resultList = await db.query('graphsAsJson', where: 'id == ?', whereArgs: [id]);
      
      //if empty, return empy dict
      if (resultList.isEmpty){
        return '{"nodes":[]}';
      }

      //else return the actual data
      return resultList[0]['graph'] as String;
   }
}

import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensorsiot/sensor_data_model.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io' as io;
import 'package:path/path.dart';

class DataHelper {
  static Database? _db;
  Future<Database> get db async {
    if (_db != null) {
      return _db!;
    }
    _db = await initDatabase();
    return _db!;
  }

  initDatabase() async {
    io.Directory documentDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentDirectory.path, 'sensordata.db');
    var db = await openDatabase(path, version: 1, onCreate: _onCreate);
    return db;
  }

  _onCreate(Database db, int version) async {
    await db.execute(
        'CREATE TABLE sensor (x TEXT, y TEXT, z TEXT, dateTime TEXT)');
  }

  Future<void> convertToCSV() async {
    io.Directory documentDirectory = await getApplicationDocumentsDirectory();
    final data = await _db?.rawQuery('SELECT * FROM sensor');
    final csvData = data?.map((row) => row.values.toList()).toList();
    final csvFile = File(join(documentDirectory.path, 'sensor_data.csv'));
    String csv = const ListToCsvConverter().convert(csvData);
    File file = await csvFile.writeAsString(csv);
    Share.shareFiles([file.path]);
  }

  delete() async {
    var dbClient = await db;
    dbClient.delete("sensor");
  }

  Future<SensorData> add(SensorData items) async {
    var dbClient = await db;
    try {
      await dbClient.insert('sensor', items.toMap());
    } catch (e) {
      print("the error is $e");
    }
    return items;
  }

  Future<List<SensorData>> getItems() async {
    var dbClient = await db;
    List<Map<String,dynamic>> maps = await dbClient.query('sensor', columns: [
      'x',
      'y',
      'z',
      'dateTime',
    ]);
    // ignore: non_constant_identifier_names
    List<SensorData> Items = [];
    if (maps.length > 0) {
      for (int i = 0; i < maps.length; i++) {
        Items.add(SensorData.fromMap(maps[i]));
      }
    }
    return Items;
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:sensorsiot/my_db.dart';
import 'package:sensorsiot/sensor_data_model.dart';
import 'package:shared_preferences/shared_preferences.dart';





DataHelper dataHelper = DataHelper();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  await dataHelper.initDatabase();
  runApp(const MyApp());
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  debugPrint('Initializing service...');
  try {
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // this will be executed when app is in foreground or background in separated isolate
        onStart: onStart,
        // auto start service
        autoStart: true,
        isForegroundMode: true,
      ),
      iosConfiguration: IosConfiguration(
        // auto start service
        autoStart: true,

        // this will be executed when app is in foreground in separated isolate
        onForeground: onStart,

        // you have to enable background fetch capability on xcode project
        onBackground: onIosBackground,
      ),
    );
  } catch (e) {
    debugPrint('Error while configuring service: $e');
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  MagnetometerEvent? magnetometerEvent;
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  magnetometerEvents.listen((MagnetometerEvent event) {
    magnetometerEvent = event;
  });
  Timer.periodic(const Duration(seconds: 5), (timer) async {
    print('onIosBackground SERVICE: ${DateTime.now().toLocal().toString()}');
    callStoreData(magnetometerEvent);
  });
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Only available for flutter 3.0.0 and later
  MagnetometerEvent? magnetometerEvent;
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  debugPrint('Service started!');
  // For flutter prior to version 3.0.0
  // We have to register the plugin manually

  magnetometerEvents.listen((MagnetometerEvent event) {
    magnetometerEvent = event;
  });

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      debugPrint('setAsForeground event received!');
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      debugPrint('setAsBackground event received!');
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    debugPrint('stopService event received!');
    service.stopSelf();
  });
  Timer.periodic(const Duration(seconds: 5), (timer) async {
    callStoreData(magnetometerEvent);
  });
}

void callStoreData(magnetometerEvent) async{

    /// you can see this log in logcat
    print('FLUTTER BACKGROUND SERVICE: ${DateTime.now().toLocal().toString()}');
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    bool writeData = sharedPreferences.getBool('writeToCSV') ?? false;
    debugPrint('Writing data to excel: $writeData');
    if (writeData) {
      dataHelper.add(SensorData(
          x: magnetometerEvent?.x.toInt().toString(),
          y: magnetometerEvent?.y.toInt().toString(),
          z: magnetometerEvent?.z.toInt().toString(),
          dateTime: DateTime.now().toLocal().toString()));
      Fluttertoast.showToast(
        msg: "Storing data to DB",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.black,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }

}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NAVEEN SENSOR APP',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: const MyHomePage(title: 'NAVEEN SENSOR APP'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  ///UI Display
  AccelerometerEvent? magnetometerEventUI;
  final service = FlutterBackgroundService();
  bool serviceIsRunning = false;
  List<SensorData>? sensorData = [];
  @override
  void initState() {
    checkForService();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void checkForService() async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    bool writeData = sharedPreferences.getBool('writeToCSV') ?? false;
    if (writeData) {
      startListening();
      serviceIsRunning = true;
    } else {
      stopListening();
      serviceIsRunning = false;
    }
    Timer.periodic(const Duration(seconds: 3), (timer) async {
      getDbData();
    });
  }

  void stopListening() async {
    debugPrint('stopListening');
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setBool('writeToCSV', false);
    service.invoke('stopService');
    setState(() {
      serviceIsRunning = false;
    });
  }

  void startListening() async {
    service.startService();
    debugPrint('startListening');
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setBool('writeToCSV', true);
    setState(() {
      serviceIsRunning = true;
    });
  }

  void getDbData() async {
    sensorData = await dataHelper.getItems();
    debugPrint('sensorData: $sensorData');
    setState(() {

    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.title),
            const Text(
              'Magnetometer Sensor Data:',
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: ListView.builder(
                  itemCount: sensorData?.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(
                          "${index + 1}. x:${sensorData?[index].x}, y:${sensorData?[index].y}, z:${sensorData?[index].z}, dateTime:${sensorData?[index].dateTime}"),
                    );
                  },
                ),
              ),
              serviceIsRunning
                  ? ElevatedButton(
                      onPressed: () {
                        stopListening();
                      },
                      child: const Text('Stop Listening'))
                  : ElevatedButton(
                      onPressed: () {
                        startListening();
                      },
                      child: Text('Start Listening'))
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
         dataHelper.convertToCSV();
        },
        tooltip: 'Send Data',
        child: const Icon(Icons.send),
      )
    );
  }
}

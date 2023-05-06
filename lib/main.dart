import 'dart:async';
import 'dart:ui';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

StreamController<MagnetometerEvent> magnetometerStream =
StreamController<MagnetometerEvent>.broadcast();

StreamSubscription<MagnetometerEvent>? magnetometerEventData;

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
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
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.reload();
  final log = preferences.getStringList('log') ?? <String>[];
  log.add(DateTime.now().toIso8601String());
  await preferences.setStringList('log', log);

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
  SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
  int? excelCreated =  sharedPreferences.getInt('excelCreated');
  if(excelCreated != null && excelCreated == 1) {
    debugPrint('Excel already created');
    var excel = Excel.createExcel();
  }
  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.setString("hello", "world");

  magnetometerEvents.listen((MagnetometerEvent event) {
    magnetometerStream.add(event);
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

  // bring to foreground
  Timer.periodic(const Duration(seconds: 1), (timer) async {

    /// you can see this log in logcat
    print('FLUTTER BACKGROUND SERVICE: ${DateTime.now()}');
    print('MagnetometerEvent on start: X:${magnetometerEvent?.x}\nY:${magnetometerEvent?.y}\nZ:${magnetometerEvent?.z}');

    // test using external plugin


    service.invoke(
      'update',
      {
        "current_date": DateTime.now().toIso8601String(),
        "device": "device details",
      },
    );
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
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
  MagnetometerEvent? magnetometerEventUI;

  @override
  void initState() {
    final service = FlutterBackgroundService();
    service.isRunning().then((isRunning) {
      if (isRunning) {
        debugPrint('FlutterBackgroundService is running');
        startListening();
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void stopListening() {
    debugPrint('stopListening');
    magnetometerEventData?.pause();
    setState(() {});
  }

  void resumeListening() {
    debugPrint('resumeListening');
    magnetometerEventData?.resume();
    setState(() {});
  }

  void startListening() {
    debugPrint('startListening');
    final service = FlutterBackgroundService();
    service.startService();
    magnetometerEvents.listen((MagnetometerEvent event) {
      magnetometerStream.add(event);
      debugPrint('startListening data: ${event.x} ${event.y} ${event.z} ==== ${magnetometerStream.stream}');
    });
    magnetometerEventData = magnetometerStream.stream.listen((event) {
      debugPrint('magnetometerEvent stream listen: $event');
      setState(() {
        magnetometerEventUI = event;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Row(
              children: [
                const Text(
                  'Magnetometer Sensor Data:',
                ),
                magnetometerStream.isPaused || magnetometerStream.isClosed
                    ? const Text('start listening')
                    : Text(
                        'x:${magnetometerEventUI?.x.toInt()} y:${magnetometerEventUI?.y.toInt()} z:${magnetometerEventUI?.z.toInt()}',
                      ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          magnetometerStream.hasListener
              ? Container()
              : FloatingActionButton(
                  onPressed: startListening,
                  child: const Icon(Icons.play_arrow),
                ),
          const SizedBox(
            width: 10,
          ),
          magnetometerEventData != null
              ? (magnetometerEventData!.isPaused
                  ? FloatingActionButton(
                      onPressed: resumeListening,
                      child: const Icon(Icons.play_arrow),
                    )
                  : FloatingActionButton(
                      onPressed: stopListening,
                      child: const Icon(Icons.stop),
                    ))
              : Container(),
        ],
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

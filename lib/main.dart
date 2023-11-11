import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:get/get.dart';
import 'package:philips_robot/ble_controller.dart';

// global vars
double currentSliderValueLeft = 0;
double currentSliderValueRight = 0;

void main() {
  // WidgetsFlutterBinding.ensureInitialized();
  // SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft])
  //     .then((value) {
  runApp(const MainApp());
  // });
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: BlueToothScreen(),
    );
  }
}

class ControlSliders extends StatefulWidget {
  const ControlSliders({super.key});

  @override
  State<ControlSliders> createState() => _ControlSlidersState();
}

class _ControlSlidersState extends State<ControlSliders> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 200),
            child: RotatedBox(
              quarterTurns: 3,
              child: Slider(
                value: currentSliderValueLeft,
                min: -100,
                max: 100,
                activeColor: Colors.blue,
                inactiveColor: Colors.blue,
                divisions: 200,
                label: currentSliderValueLeft.round().toString(),
                onChanged: (double value) {
                  setState(() {
                    currentSliderValueLeft = value.roundToDouble();
                  });
                },
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("$currentSliderValueLeft, $currentSliderValueRight"),
              TextButton(
                  style: ButtonStyle(
                      foregroundColor:
                          MaterialStateProperty.all<Color>(Colors.black),
                      backgroundColor:
                          MaterialStateProperty.all<Color>(Colors.red)),
                  onPressed: () {
                    setState(() {
                      currentSliderValueLeft = 0;
                      currentSliderValueRight = 0;
                    });
                  },
                  child: const Text("Stop")),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(left: 200),
            child: RotatedBox(
              quarterTurns: 3,
              child: Slider(
                value: currentSliderValueRight,
                min: -100,
                max: 100,
                activeColor: Colors.blue,
                inactiveColor: Colors.blue,
                divisions: 200,
                label: currentSliderValueRight.toString(),
                onChanged: (double value) {
                  setState(() {
                    currentSliderValueRight = value.roundToDouble();
                  });
                },
              ),
            ),
          )
        ],
      ),
    );
  }
}

class BlueToothScreen extends StatefulWidget {
  const BlueToothScreen({super.key});

  @override
  State<BlueToothScreen> createState() => BlueToothScreenState();
}

class BlueToothScreenState extends State<BlueToothScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("connect to your bluetooth robot"),
      ),
      body: GetBuilder<BleController>(
        init: BleController(),
        builder: (BleController controller) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StreamBuilder<List<ScanResult>>(
                  stream: controller.scanResult,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      // return Expanded(
                        // child:
                         return SizedBox(
                          height: 200.0,
                          child: 
                           ListView.builder(
                            // itemCount: snapshot.data!.length,
                            itemBuilder: (context, index) {
                              // final data = snapshot.data![index];
                              return const Card(
                                elevation: 2,
                                child: ListTile(
                                  title: Text("hello"),
                                  // title: Text(data.device.name),
                                  // subtitle: Text(data.device.id.id),
                                  // trailing: Text(data.rssi.toString()),
                                ),
                              );
                            },
                          ),
                        // ),
                      );
                    } else {
                      return const Center(
                        child: Text("No Device Found"),
                      );
                    }
                  },
                ),
                ElevatedButton(
                  onPressed: () => controller.scanDevices(),
                  child: const Text("SCAN"),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}

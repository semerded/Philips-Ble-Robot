import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:get/get.dart';
import 'package:philips_robot/ble_controller.dart';

// global vars
double currentSliderValueLeft = 0;
double currentSliderValueRight = 0;
bool bleRobotFound = false;
String bleRobotInfo = "Search for the robot";
const String bluetoothRobotName = "ble-robot";

void main() {
  // WidgetsFlutterBinding.ensureInitialized();
  // SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft])
  //     .then((value) {
  // runApp(const MainApp());
  // });

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: BlueToothScreen(),
      // home: ControlSliders(),
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
                onChanged: (double value) {
                  setState(() {
                    currentSliderValueRight = value.roundToDouble();
                  });
                },
                onChangeEnd: (double value) {
                  setState(() {
                    currentSliderValueRight = 0;
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

highlightRobotConnection(String robotName) {
  if (robotName == bluetoothRobotName) {
    return Colors.green;
  }
  return Colors.white;
}

connectToBluetooth(device) async {
  print(device);
  try {
    await device.connect();
  } catch (e) {
    if (e != 'already_connected') {
      throw e;
    }
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
                Center(
                  child: Text(
                    bleRobotInfo,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                StreamBuilder<List<ScanResult>>(
                  stream: controller.scanResult,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Expanded(
                        child: SizedBox(
                          height: 200.0,
                          child: ListView.builder(
                            itemCount: snapshot.data!.length,
                            itemBuilder: (context, index) {
                              if (snapshot.data![index].device.name.toString() ==
                                  bluetoothRobotName) {
                                // switch ble-robot to position 0 in list
                                var tempDataStorage = snapshot.data![0];
                                snapshot.data![0] = snapshot.data![index];
                                snapshot.data![index] = tempDataStorage;
                                bleRobotFound = true;
                                Future.delayed(Duration.zero, () async {
                                  setState(() {
                                    bleRobotInfo =
                                        "Robot found! Click to connect";
                                  });
                                });
                              }
                              final data = snapshot.data![index];

                              return Card(
                                elevation: 3,
                                child: ListTile(
                                  onTap: () =>
                                      {connectToBluetooth(data.device)},
                                  tileColor: highlightRobotConnection(
                                      data.device.name.toString()),
                                  title: Text(data.device.name.toString()),
                                  subtitle: Text(data.device.id.id.toString()),
                                  trailing: Text(data.rssi.toString()),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    } else {
                      return const Center(
                        child: Text("No Device Found"),
                      );
                    }
                  },
                ),
                ElevatedButton(
                  onPressed: () {
                    controller.scanDevices();
                    setState(() {
                      bleRobotInfo = "Searching...";
                    });
                  },
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

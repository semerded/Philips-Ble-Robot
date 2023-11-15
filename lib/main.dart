import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:get/get.dart';
import 'package:philips_robot/ble_controller.dart';

// global vars {
double currentSliderValueLeft = 0;
double currentSliderValueRight = 0;
const String bluetoothRobotName = "ble-robot";
List robotList = [];
int counter = 0;
int selectedRobot = -1;
bool robotConnected = false;
var connectedRobotDevice;

const String speedMotorLeft = "c9261765-1076-41ac-82d7-a454e801bd9a";
const String speedMotorRight = "c9261765-1076-41ac-82d7-a454e801bd9b";
const String directionMotorLeft = "c9261765-1076-41ac-82d7-a454e801bd9c";
const String directionMotorRight = "c9261765-1076-41ac-82d7-a454e801bd9d";
const String motorStop = "c9261765-1076-41ac-82d7-a454e801bd9e";
const String inputSucceed = "c9261765-1076-41ac-82d7-a454e801bd9f";

var jsonString = File("BleCharacteristics.").readAsStringSync(); // open json file en lees als string
    final Map<String, dynamic> jsonmap =
        decoder.convert(jsonString);

// offset controll of main listview
ScrollController _scrollController = ScrollController();
double mainListViewScrollOffset = 0;
// }

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.portraitUp]).then((value) {
  //   runApp(const MaterialApp(
  //     title: 'Ble Robot',
  //     home: ControlSliders(),
  //   ));
  // });

  runApp(const MaterialApp(
    title: "Ble Robot Controller",
    home: ControlSliders(),
  ));
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
                 onChangeEnd: (double value) {
                  setState(() {
                    currentSliderValueLeft = 0;
                  });
                },
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) {
                      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                      return const BlueToothScreen();
                    }),
                  );
                },
                backgroundColor: Colors.blue,
                mini: true,
                child: const Icon(Icons.bluetooth),
              ),
              Text("$currentSliderValueLeft, $currentSliderValueRight"),
              TextButton(
                  style: ButtonStyle(foregroundColor: MaterialStateProperty.all<Color>(Colors.black), backgroundColor: MaterialStateProperty.all<Color>(Colors.red)),
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

int countRobotsFound(connections) {
  int robotsFound = 0;
  for (var connection in connections) {
    if (connection.device.name.toString() == bluetoothRobotName) {
      robotsFound++;
    }
  }
  return robotsFound;
}

connectTo(robot) async {
  // FlutterBlue ble = FlutterBlue.instance;
  // await BluetoothDevice.fromProto(robot).connect();
  await robot.connect(timeout: const Duration(seconds: 15), autoConnect: false);
  connectedRobotDevice = robot;
  robotConnected = true;
}

class BlueToothScreen extends StatefulWidget {
  const BlueToothScreen({super.key});

  @override
  State<BlueToothScreen> createState() => BlueToothScreenState();
}

class BlueToothScreenState extends State<BlueToothScreen> {
  String bleRobotInfo = "Search for the robot";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("connect to your bluetooth robot"),
          actions: [
            FloatingActionButton(
              onPressed: () {
                SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
                Navigator.pop(context);
              },
              backgroundColor: Colors.red,
              mini: true,
              child: const Icon(Icons.cancel_outlined),
            )
          ],
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

                  // listen to scroll updates
                  NotificationListener(
                    onNotification: (notification) {
                      if (notification is ScrollEndNotification) {
                        setState(() {
                          mainListViewScrollOffset = _scrollController.position.pixels;
                        });
                      }

                      return false;
                    },

                    // main list of robot connections and other connections
                    child: Expanded(
                      child: ListView(
                        controller: _scrollController,
                        shrinkWrap: true,
                        children: [
                          (() {
                            if (robotList.isNotEmpty) {
                              return Expanded(
                                child: ListView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  itemCount: robotList.length,
                                  itemBuilder: (context, index) {
                                    return ListTile(
                                      tileColor: selectedRobot == index ? Colors.green : Colors.blue,
                                      onTap: () {
                                        setState(
                                          () {
                                            if (selectedRobot == index) {
                                              selectedRobot = -1;
                                            } else {
                                              selectedRobot = index;
                                            }
                                          },
                                        );
                                      },
                                      title: Text(robotList[index].device.name.toString()),
                                      subtitle: Column(
                                        children: [
                                          Text(robotList[index].device.id.id.toString()),
                                          selectedRobot == index
                                              ? ElevatedButton(
                                                  onPressed: () {
                                                    connectTo(robotList[index].device);
                                                  },
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                                                  child: const Text("Connect to robot!"),
                                                )
                                              : Container(),
                                        ],
                                      ),
                                      trailing: Text(robotList[index].rssi.toString()),
                                    );
                                  },
                                ),
                              );
                            } else {
                              return Container();
                            }
                          }()),
                          Container(
                            height: 20,
                          ),
                          StreamBuilder<List<ScanResult>>(
                            stream: controller.scanResult,
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Expanded(
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: snapshot.data!.length,
                                    itemBuilder: (context, index) {
                                      // if (FlutterBlue.instance.isScanning.first) {
                                      if (counter >= 1) {
                                        for (var bleDevice in snapshot.data!) {
                                          if (bleDevice.device.name.toString() == bluetoothRobotName) {
                                            if (!robotList.contains(bleDevice)) {
                                              robotList.add(bleDevice);
                                            }
                                          }
                                          if (bleRobotInfo != "Robot found! Click to connect") {
                                            Future.delayed(
                                              Duration.zero,
                                              () async {
                                                bleRobotInfo = "Robot found! Click to connect";

                                                setState(() {});
                                              },
                                            );
                                          }
                                        }
                                        counter = 0;
                                      }
                                      counter++;

                                      final data = snapshot.data![index];
                                      if (data.device.name.toString() == bluetoothRobotName) {
                                        return Container();
                                      }

                                      return Card(
                                        elevation: 3,
                                        child: ListTile(
                                          // onLongPress: () {connectTo(data.device.);},
                                          title: Text(data.device.name.toString()),
                                          subtitle: Text(data.device.id.id.toString()),
                                          trailing: Text(data.rssi.toString()),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              } else {
                                return const Center(
                                  child: Text("No Device Found"),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          robotList = [];
                          selectedRobot = -1;
                          controller.scanDevices();
                          setState(() {
                            bleRobotInfo = "Searching for your robot...";
                          });
                        },
                        child: const Text("SCAN"),
                      ),
                      robotConnected == true
                          ? ElevatedButton(
                              onPressed: () {
                                connectedRobotDevice.disconnect();
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              child: const Text(
                                "Disconnect",
                              ))
                          : Container(),
                      ElevatedButton(
                          onPressed: () async {
                            var robotServices = await connectedRobotDevice.discoverServices();

                            for (var service in robotServices) {
                              if (service.uuid.toString() == "c9261765-1076-41ac-82d7-a454e801bd99") {
                                // print(service.characteristics);
                                var characteristics = service.characteristics;
                                for (BluetoothCharacteristic char in characteristics) {
                                  if (char.uuid.toString() == "c9261765-1076-41ac-82d7-a454e801bd9c") {
                                    await char.write([0x01], withoutResponse: true);
                                  }
                                  if (char.uuid.toString() == "c9261765-1076-41ac-82d7-a454e801bd9f") {
                                    await char.setNotifyValue(true);
                                    char.value.listen((value) {
                                      print(value);
                                    });
                                  if (char.uuid.toString() == "c9261765-1076-41ac-82d7-a454e801bd9a") {}
                                  }
                                }
                              }
                            }
                          },
                          child: const Text("data")),
                      ElevatedButton(
                          onPressed: () async {
                            var robotServices = await connectedRobotDevice.discoverServices();

                            for (var service in robotServices) {
                              if (service.uuid.toString() == "c9261765-1076-41ac-82d7-a454e801bd99") {
                                // print(service.characteristics);
                                var characteristics = service.characteristics;
                                for (BluetoothCharacteristic char in characteristics) {
                                  print(char);
                                  print("-----------------------");

                                  if (char.uuid.toString() == "c9261765-1076-41ac-82d7-a454e801bd9a") {
                                    await char.write([0x32], withoutResponse: true);
                                  }

                                  if (char.uuid.toString() == "c9261765-1076-41ac-82d7-a454e801bd9f") {
                                    await char.setNotifyValue(true);
                                    char.value.listen((value) {
                                      print(value);
                                    });
                                  }
                                }
                              }
                            }
                          },
                          child: const Text("data2"))
                    ],
                  )
                ],
              ),
            );
          },
        ),
        floatingActionButton: LayoutBuilder(builder: (context, constraints) {
          return _backToTopButton();
        }));
  }
}

Widget _backToTopButton() {
  return mainListViewScrollOffset > 20
      ? FloatingActionButton(
          onPressed: () {
            _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 500), curve: Curves.fastOutSlowIn);
          },
          child: const Icon(Icons.arrow_upward),
        )
      : Container();
}

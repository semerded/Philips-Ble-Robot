// ignore_for_file: prefer_final_fields

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:get/get.dart';
import 'package:philips_robot/ble_controller.dart';
import 'package:url_launcher/url_launcher.dart';

// global vars
double currentSliderValueLeft = 0;
double currentSliderValueRight = 0;
const String bluetoothRobotName = "ble-robot";
List robotList = [];
int counter = 0;
bool robotConnected = false;
dynamic connectedRobotDevice;
bool callReady = true;

bool sliderLeftUpdated = false;
bool sliderRightUpdated = false;

BluetoothCharacteristic? speedMotorLeft;
BluetoothCharacteristic? speedMotorRight;
BluetoothCharacteristic? directionMotorLeft;
BluetoothCharacteristic? directionMotorRight;
BluetoothCharacteristic? motorStop;
BluetoothCharacteristic? inputSucceed;

Map<String, BluetoothCharacteristic?> characteristics = {"a": speedMotorLeft, "b": speedMotorRight, "c": directionMotorLeft, "d": directionMotorRight, "e": motorStop, "f": inputSucceed};

MotorController? motorControlLeft;
MotorController? motorControlRight;

// offset controll of main listview
ScrollController _scrollController = ScrollController();
double mainListViewScrollOffset = 0;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);

  runApp(const MaterialApp(
    title: "Ble Robot Controller",
    home: ControlSliders(),
  ));
}

// Future<bool> waitFor(callReady) async {
//   if (await callReady) {
//     return true;
//   } else {
//     return false;
//   }
// }

Future waitFor(bool waitingFor, {int milliseconds = 10}) async {
  await Future.doWhile(() async {
    await Future.delayed(Duration(milliseconds: milliseconds));
    if (waitingFor) {
      return false;
    } else {
      return true;
    }
  });
  return true;
}

class MotorController {
  BluetoothCharacteristic? _speedMotor, _directionMotor;
  int _previousMotorSpeed = 0;
  int _previousMotorDirection = 0;
  bool _updateMotorPending = false;

  MotorController(BluetoothCharacteristic speedMotorChar, BluetoothCharacteristic directionMotorChar) {
    _speedMotor = speedMotorChar;
    _directionMotor = directionMotorChar;
  }

  int calculateNewValueOfInput(double speed) {
    int currentDirection;
    if (speed > 10) {
      currentDirection = 2;
    } else if (speed < -10) {
      currentDirection = 1;
    } else {
      currentDirection = 0;
    }
    return currentDirection;
  }

  Future<void> communicateToRobot(BluetoothCharacteristic? writeChar, int writeData) async {
    await waitFor(callReady);
    callReady = false;
    await writeChar?.write([writeData], withoutResponse: true);

    inputSucceed?.value.listen(
      (value) {
        try {
          if (value.first == 0) {
            callReady = true;
            return;
          }
        } catch (e) {
          //
        }
      },
    );
  }

  void callUpdate(double speed) async {
    if (callReady) {
      int currentDirection = calculateNewValueOfInput(speed);
      int motorSpeed = speed.abs().toInt();
      if (_previousMotorDirection != currentDirection) {
        _updateMotorPending = true;
      }
      if (_updateMotorPending) {
        await communicateToRobot(_directionMotor, currentDirection);
        _updateMotorPending = false;
        _previousMotorDirection = currentDirection;
      }

      if (_previousMotorSpeed + 10 < motorSpeed || _previousMotorSpeed - 10 > motorSpeed || motorSpeed > 90) {
        await communicateToRobot(_speedMotor, motorSpeed);
        _previousMotorSpeed = motorSpeed;
      }
    }
  }

  Future<void> stopMotor() async {
    await Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 20));
      if (callReady) {
        await communicateToRobot(_directionMotor, 0);
        return false;
      } else {
        return true;
      }
    });
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
                  sliderLeftUpdated = false;

                  setState(() {
                    currentSliderValueLeft = value.roundToDouble();
                  });
                  if (callReady && robotConnected) {
                    motorControlLeft!.callUpdate(currentSliderValueLeft);
                    if (sliderRightUpdated) {
                      motorControlRight!.callUpdate(currentSliderValueRight);
                    }
                  }
                  sliderLeftUpdated = true;
                },
                onChangeEnd: (double value) {
                  setState(() {
                    currentSliderValueLeft = 0;
                  });
                  if (robotConnected) {
                    motorControlLeft!.stopMotor();
                    if (currentSliderValueRight == 0) {
                      motorControlRight!.stopMotor();
                    }
                  }
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
                    Future(() async {
                      await motorControlLeft!.stopMotor();
                      await motorControlRight!.stopMotor();
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
                  sliderRightUpdated = false;

                  setState(() {
                    currentSliderValueRight = value.roundToDouble();
                  });
                  if (callReady && robotConnected) {
                    motorControlRight!.callUpdate(currentSliderValueRight);
                    if (sliderLeftUpdated) {
                      motorControlLeft!.callUpdate(currentSliderValueLeft);
                    }
                  }
                  sliderRightUpdated = true;
                },
                onChangeEnd: (double value) {
                  setState(() {
                    currentSliderValueRight = 0;
                  });
                  if (robotConnected) {
                    motorControlRight!.stopMotor();
                    if (currentSliderValueLeft == 0) {
                      motorControlLeft!.stopMotor();
                    }
                  }
                },
              ),
            ),
          ),
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

void connectTo(robot) async {
  await robot.connect(timeout: const Duration(seconds: 15), autoConnect: false);

  robot.mtu.elementAt(1).then((mtu) {
    mtu = mtu < 23 ? 20 : mtu - 3; // failsafe by always assuming an ATT MTU and not a DATA MTU
// do your service discovery
    robot.discoverServices();
  });
  await robot.requestMtu(512);
  var robotServices = await robot.discoverServices();
  for (var service in robotServices) {
    if (service.uuid.toString() == "c9261765-1076-41ac-82d7-a454e801bd99") {
      for (int index = 0; index < service.characteristics.length; index++) {
        BluetoothCharacteristic char = service.characteristics[index];
        for (var lastDigitOfUuid in characteristics.keys) {
          if (char.uuid.toString() == "c9261765-1076-41ac-82d7-a454e801bd9$lastDigitOfUuid") {
            characteristics[lastDigitOfUuid] = char;
          }
        }
      }
    }
  }

  speedMotorLeft = characteristics['a'];
  speedMotorRight = characteristics['b'];
  directionMotorLeft = characteristics['c'];
  directionMotorRight = characteristics['d'];
  motorStop = characteristics['e'];
  inputSucceed = characteristics['f'];
  await inputSucceed!.setNotifyValue(true);

  motorControlLeft = MotorController(speedMotorLeft!, directionMotorLeft!);
  motorControlRight = MotorController(speedMotorRight!, directionMotorRight!);

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
  int selectedRobot = -1;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DefaultTabController(
        length: 2,
        child: GetBuilder<BleController>(
          init: BleController(),
          builder: (BleController controller) {
            return Scaffold(
              appBar: AppBar(
                leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () {
                      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
                      Navigator.pop(context);
                    }),
                bottom: const TabBar(
                  tabs: [
                    Tab(icon: Text("robot")),
                    Tab(icon: Text("all")),
                  ],
                ),
                title: const Text("connect to your robot"),
              ),
              body: TabBarView(
                children: [
                  StreamBuilder<List<ScanResult>>(
                    stream: controller.scanResult,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Expanded(
                          child: ListView.builder(
                            itemCount: snapshot.data!.length,
                            itemBuilder: (context, index) {
                              if (snapshot.data![index].device.name.toString() == bluetoothRobotName) {
                                final data = snapshot.data![index];
                                return Card(
                                  elevation: 2,
                                  child: ListTile(
                                    tileColor: selectedRobot == index ? Colors.green : Colors.white,
                                    title: Text(data.device.name.toString()),
                                    subtitle: Text(data.device.id.id.toString()),
                                    trailing: selectedRobot == index ? ElevatedButton(onPressed: () => connectTo(data.device), child: const Text("Connect to robot")) : const Text(""),
                                    onTap: () {
                                      setState(() {
                                        if (selectedRobot == index) {
                                          selectedRobot = -1;
                                        } else {
                                          selectedRobot = index;
                                        }
                                      });
                                    },
                                  ),
                                );
                              } else {
                                return Container();
                              }
                            },
                          ),
                        );
                      } else {
                        return const Center(
                          child: Text("No Bluetooth Devices Found"),
                        );
                      }
                    },
                  ),
                  NotificationListener(
                    onNotification: (notification) {
                      if (notification is ScrollEndNotification) {
                        setState(() {
                          mainListViewScrollOffset = _scrollController.position.pixels;
                        });
                      }
                      return false;
                    },
                    child: StreamBuilder<List<ScanResult>>(
                      stream: controller.scanResult,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Expanded(
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: snapshot.data!.length,
                              itemBuilder: (context, index) {
                                final data = snapshot.data![index];
                                return Card(
                                  elevation: 2,
                                  child: ListTile(
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
                            child: Text("No Bluetooth Devices Found"),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(
                    flex: 7,
                  ),
                  ElevatedButton(
                    onPressed: () {
                      controller.scanDevices();
                      robotList = [];
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text("Search Robot"),
                  ),
                  const Spacer(
                    flex: 1,
                  ),
                  ElevatedButton(
                    onPressed: () => connectedRobotDevice.disconnect(),
                    style: ElevatedButton.styleFrom(backgroundColor: robotConnected ? Colors.red : Colors.grey),
                    child: const Text("Disconnect"),
                  ),
                  const Spacer(
                    flex: 3,
                  ),
                  FloatingActionButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const InfoScreen()),
                      );
                    },
                    mini: true,
                    tooltip: "why can't I find my robot?",
                    child: const Icon(Icons.info_outline),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    //   return Scaffold(
    //       appBar: AppBar(
    //       body: GetBuilder<BleController>(
    //         init: BleController(),
    //         builder: (BleController controller) {
    //           return Center(
    //             child: Column(
    //               mainAxisAlignment: MainAxisAlignment.center,
    //               children: [
    //                 Center(
    //                   child: Text(
    //                     bleRobotInfo,
    //                     style: const TextStyle(fontSize: 20),
    //                   ),
    //                 ),

    //                 // listen to scroll updates
    //

    //                   // main list of robot connections and other connections
    //                   child: Expanded(
    //                     child: ListView(
    //                       controller: _scrollController,
    //                       shrinkWrap: true,
    //                       children: [
    //                         (() {
    //                           if (robotList.isNotEmpty) {
    //                             return Expanded(
    //                               child: ListView.builder(
    //                                 physics: const NeverScrollableScrollPhysics(),
    //                                 shrinkWrap: true,
    //                                 itemCount: robotList.length,
    //                                 itemBuilder: (context, index) {
    //                                   return ListTile(
    //                                     tileColor: selectedRobot == index ? Colors.green : Colors.blue,
    //                                     onTap: () {
    //                                       setState(
    //                                         () {
    //                                           if (selectedRobot == index) {
    //                                             selectedRobot = -1;
    //                                           } else {
    //                                             selectedRobot = index;
    //                                           }
    //                                         },
    //                                       );
    //                                     },
    //                                     title: Text(robotList[index].device.name.toString()),
    //                                     subtitle: Column(
    //                                       children: [
    //                                         Text(robotList[index].device.id.id.toString()),
    //                                         selectedRobot == index
    //                                             ? ElevatedButton(
    //                                                 onPressed: () {
    //                                                   connectTo(robotList[index].device);
    //                                                 },
    //                                                 style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
    //                                                 child: const Text("Connect to robot!"),
    //                                               )
    //                                             : Container(),
    //                                       ],
    //                                     ),
    //                                     trailing: Text(robotList[index].rssi.toString()),
    //                                   );
    //                                 },
    //                               ),
    //                             );
    //                           } else {
    //                             return Container();
    //                           }
    //                         }()),
    //                         Container(
    //                           height: 20,
    //                         ),
    //                         StreamBuilder<List<ScanResult>>(
    //                           stream: controller.scanResult,
    //                           builder: (context, snapshot) {
    //                             if (snapshot.hasData) {
    //                               return Expanded(
    //                                 child: ListView.builder(
    //                                   shrinkWrap: true,
    //                                   physics: const NeverScrollableScrollPhysics(),
    //                                   itemCount: snapshot.data!.length,
    //                                   itemBuilder: (context, index) {
    //                                     // if (FlutterBlue.instance.isScanning.first) {
    //                                     if (counter >= 1) {
    //                                       for (var bleDevice in snapshot.data!) {
    //                                         if (bleDevice.device.name.toString() == bluetoothRobotName) {
    //                                           if (!robotList.contains(bleDevice)) {
    //                                             robotList.add(bleDevice);
    //                                           }
    //                                         }
    //                                         if (bleRobotInfo != "Robot found! Click to connect") {
    //                                           Future.delayed(
    //                                             Duration.zero,
    //                                             () async {
    //                                               setState(() {
    //                                                 bleRobotInfo = "Robot found! Click to connect";
    //                                               });
    //                                             },
    //                                           );
    //                                         }
    //                                       }
    //                                       counter = 0;
    //                                     }
    //                                     counter++;

    //                                     final data = snapshot.data![index];
    //                                     if (data.device.name.toString() == bluetoothRobotName) {
    //                                       return Container();
    //                                     }

    //                                     return Card(
    //                                       elevation: 3,
    //                                       child: ListTile(
    //                                         // onLongPress: () {connectTo(data.device.);},
    //                                         title: Text(data.device.name.toString()),
    //                                         subtitle: Text(data.device.id.id.toString()),
    //                                         trailing: Text(data.rssi.toString()),
    //                                       ),
    //                                     );
    //                                   },
    //                                 ),
    //                               );
    //                             } else {
    //                               return const Center(
    //                                 child: Text("No Device Found"),
    //                               );
    //                             }
    //                           },
    //                         ),
    //                       ],
    //                     ),
    //                   ),
    //                 ),
    //                 Row(
    //                   crossAxisAlignment: CrossAxisAlignment.center,
    //                   children: [
    //                     ElevatedButton(
    //                       onPressed: () {
    //                         robotList = [];
    //                         selectedRobot = -1;
    //                         controller.scanDevices();
    //                         setState(() {
    //                           bleRobotInfo = "Searching for your robot...";
    //                         });
    //                       },
    //                       child: const Text("SCAN"),
    //                     ),
    //                     robotConnected == true
    //                         ? ElevatedButton(
    //                             onPressed: () {
    //                               connectedRobotDevice.disconnect();
    //                             },
    //                             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
    //                             child: const Text(
    //                               "Disconnect",
    //                             ))
    //                         : Container(),
    //                   ],
    //                 )
    //               ],
    //             ),
    //           );
    //         },
    //       ),
    //       floatingActionButton: LayoutBuilder(builder: (context, constraints) {
    //         return _backToTopButton();
    //       }));
    // }
  }
}

class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  bool githubButtonPressed = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "why can't I find my robot?",
          overflow: TextOverflow.visible,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12.0),
        children: [
          _header("Check if your robot is advertising."),
          const Text(" This is indicated by the green blinking led."),
          const Text("If the led is red: press the most left button on the board -> the green led should start blinking."),
          const Text(
              "If the green led is solid green, it means that your robot is already connected to your/another device. You can reset it by pressing the middle button or the reset button on the board/motorshield. After this, press the left button to start advertising"),
          _dividingLine(),
          _header("Is your bluetooth on?"),
          const Text("Turn on your bluetooth in the settings and give this app permissions to connect to other devices"),
          _dividingLine(),
          _header("Is the switch for the batteries on?"),
          const Text("This robot has 2 different batteries: 1 for the board/motorshield and 1 for the motors. On the motorshield is a green led that turns on when the batteries for the motors is on."),
          _dividingLine(),
          _header("Is the battery empty?"),
          const Text(
              "Check if a blue led is blinking. If not, try to reset the robot by pressing the reset button on the board/motorshield. If it is still not blinking this may indicate that the battery is empty. You can test the battery with a multimeter or by licking it with your tongue :)"),
          const Text("Also check the batteries for the motor and test these"),
          _dividingLine(),
          _header("Have you pressed the scan button?"),
          const Text("This may seem obvious but everyone forgets things sometimes. If you can see other bluetooth connections then you've succesfully did a scan."),
          _dividingLine(),
          _header("Scan again"),
          const Text("Sometimes just scanning a second time does wonders. Maybe a third time if it doesn't work."),
          _dividingLine(),
          _header("Check the cables on the robot"),
          const Text("Check if all cables are connected. Sometimes a cable could go loose. Screw it back in or solder it back"),
          _dividingLine(),
          _header("Is the robot connected and is the robot giving a long beep signal?"),
          const Text(
              "This means that signals are send to the motor but the motor has not enough power to overcome friction to start. This may indicate that the motor batteries are empty. Try giving it a start by rotating the wheels by hand. After this try and replace the batteries."),
          _dividingLine(),
          _header("Nothing worked?"),
          const Text("Contact me via GitHub: semerded"),
          ElevatedButton(
            child: const Text("Go To GitHub"),
            onPressed: () {
              launchUrl(Uri(scheme: 'https', host: 'github.com', path: 'semerded/Philips-Ble-Robot'));
              setState(() => githubButtonPressed = true);
            },
          ),
          githubButtonPressed
              ? const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Button not working? link:",
                      style: TextStyle(color: Colors.green),
                    ),
                    Text(
                      " https://github.com/semerded/Philips-Ble-Robot",
                      style: TextStyle(color: Colors.green),
                    ),
                  ],
                )
              : Container()
        ],
      ),
    );
  }
}

Widget _dividingLine() {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 10),
    child: Container(height: 10, color: Colors.blue),
  );
}

Widget _header(String headerText) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      headerText,
      style: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

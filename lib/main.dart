// ignore_for_file: prefer_final_fields

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:get/get.dart';
import 'package:philips_robot/ble_controller.dart';

// global vars
double currentSliderValueLeft = 0;
double currentSliderValueRight = 0;
const String bluetoothRobotName = "ble-robot";
List robotList = [];
int counter = 0;
int selectedRobot = -1;
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

connectTo(robot) async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("connect to your bluetooth robot"),
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
                Navigator.pop(context);
              }),
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
                                                setState(() {
                                                  bleRobotInfo = "Robot found! Click to connect";
                                                });
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

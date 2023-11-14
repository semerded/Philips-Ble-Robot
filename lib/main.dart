import 'package:flutter/material.dart';
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

// offset controll of main listview
ScrollController _scrollController = ScrollController();
double mainListViewScrollOffset = 0;
// }

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

highlightRobotConnection(String robotName) {
  if (robotName == bluetoothRobotName) {
    return Colors.green;
  }
  return Colors.white;
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

connectToBluetooth(device) async {
  print(device);
  try {
    await device.connect();
  } catch (e) {
    if (e != 'already_connected') {
      rethrow;
    }
  }
}

connectTo() {
  print(true);
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
                      print(notification);
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
                                                    connectTo();
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
                                      if (counter >= 1000) {
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
                                          onTap: () => {connectToBluetooth(data.device)},
                                          tileColor: highlightRobotConnection(data.device.name.toString()),
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
                  ElevatedButton(
                    onPressed: () {
                      robotList = [];

                      controller.scanDevices();
                      setState(() {
                        bleRobotInfo = "Searching for your robot...";
                      });
                    },
                    child: const Text("SCAN"),
                  ),
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

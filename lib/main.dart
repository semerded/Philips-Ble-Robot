import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
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
dynamic connectedRobotDevice;
bool robotConnected = false;
bool callReady = true;
bool reverseRobot = false;
bool gyroControl = false;

List<int> previousData = [0, 0];

BluetoothCharacteristic? bluetoothMotorControl;
BluetoothCharacteristic? bluetoothAcknowledge;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  Timer.periodic(const Duration(milliseconds: 1), (timer) {
    if (gyroControl == false) {
      if (previousData[0] != currentSliderValueLeft || previousData[1] != currentSliderValueRight) {
        sendDataToRobot(currentSliderValueLeft, currentSliderValueRight);
      }
    }
  });

  runApp(const MaterialApp(
    title: "Ble Robot Controller",
    home: ControlSliders(),
  ));
}

void makeConnectionWithRobot(robot) async {
  // TODO try except
  await robot.connect(timeout: const Duration(seconds: 15), autoConnect: false);

  var robotServices = await robot.discoverServices();
  for (var service in robotServices) {
    if (service.uuid.toString() == "c9261765-1076-41ac-82d7-a454e801bd99") {
      for (BluetoothCharacteristic char in service.characteristics) {
        if (char.uuid.toString() == "c9261765-1076-41ac-82d7-a454e801bd9a") {
          bluetoothMotorControl = char;
        } else if (char.uuid.toString() == "c9261765-1076-41ac-82d7-a454e801bd9f") {
          bluetoothAcknowledge = char;
        }
      }
    }
  }

  await bluetoothAcknowledge!.setNotifyValue(true);
  connectedRobotDevice = robot;
  robotConnected = true;
}

void sendGyroDataToRobot(y) {
  double motorLeft = currentSliderValueLeft;
  double motorRight = currentSliderValueLeft;
  if (y < 0) {
    motorLeft = motorLeft.abs() - (y * (currentSliderValueLeft.abs() / 10)).abs();
    if (motorLeft < 0) {
      motorLeft = 0;
    }
    if (currentSliderValueLeft < 0) {
      motorLeft *= -1;
    }
  } else if (y > 0) {
    motorRight = motorRight.abs() - (y * (currentSliderValueLeft.abs() / 10));
    if (motorRight < 0) {
      motorRight = 0;
    }
    if (currentSliderValueLeft < 0) {
      motorRight *= -1;
    }
  }
  sendDataToRobot(motorLeft, motorRight);
}

int calculateDirection(double speed) {
  int currentDirection;
  if (speed > 10) {
    reverseRobot ? currentDirection = 1 : currentDirection = 2;
  } else if (speed < -10) {
    reverseRobot ? currentDirection = 2 : currentDirection = 1;
  } else {
    currentDirection = 0;
  }
  return currentDirection;
}

void sendDataToRobot(double sliderValueLeft, double sliderValueRight) async {
  if (robotConnected && callReady) {
    callReady = false;
    int directionLeft = calculateDirection(sliderValueLeft);
    int directionRight = calculateDirection(sliderValueRight);
    int speedLeft = sliderValueLeft.abs().toInt();
    int speedRight = sliderValueRight.abs().toInt();
    List<int> dataToWrite = [];
    reverseRobot ? dataToWrite = [directionRight, speedRight, directionLeft, speedLeft] : dataToWrite = [directionLeft, speedLeft, directionRight, speedRight];

    await bluetoothMotorControl?.write(dataToWrite, withoutResponse: true);

    bluetoothAcknowledge?.value.listen(
      (value) {
        try {
          if (value.first == 0) {
            callReady = true;
            previousData = [speedLeft, speedRight];
            return;
          }
        } catch (e) {
          //
        }
      },
    );
  }
}

class ControlSliders extends StatefulWidget {
  const ControlSliders({super.key});

  @override
  State<ControlSliders> createState() => _ControlSlidersState();
}

class _ControlSlidersState extends State<ControlSliders> {
  int divisions = 2;
  bool screenFlip = false;

  @override
  void initState() {
    super.initState();
    accelerometerEvents.listen(
      (AccelerometerEvent event) {
        if (gyroControl) {
          sendGyroDataToRobot(event.y);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 200, top: 10, bottom: 10),
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: const SliderThemeData(
                    trackHeight: 50,
                    activeTrackColor: Colors.red,
                    inactiveTickMarkColor: Colors.white,
                    inactiveTrackColor: Colors.blue,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 30, elevation: 5),
                    trackShape: RoundedRectSliderTrackShape(),
                    tickMarkShape: RoundSliderTickMarkShape(tickMarkRadius: 5)),
                child: Slider(
                  value: currentSliderValueLeft,
                  min: -100,
                  max: 100,
                  divisions: divisions,
                  onChanged: (double value) {
                    setState(() {
                      currentSliderValueLeft = value.roundToDouble();
                    });
                  },
                  onChangeEnd: (double value) async {
                    setState(() {
                      currentSliderValueLeft = 0;
                    });
                  },
                ),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                ///
                /// user manual
                ///
                children: [
                  FloatingActionButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) {
                          SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                          return const _UserManualPage();
                        },
                      ),
                    ),
                    child: const Icon(Icons.info_outline),
                  ),

                  ///
                  /// change device orientation
                  ///
                  FloatingActionButton(
                    onPressed: () {
                      screenFlip ? SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]) : SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight]);
                      screenFlip = !screenFlip;
                    },
                    backgroundColor: Colors.green,
                    child: const Icon(Icons.arrow_upward),
                  ),
                ],
              ),

              ///
              /// connect to bluetooth screen
              ///
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    fixedSize: const Size(112, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    )),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                      return const BlueToothScreen();
                    },
                  ),
                ),
                label: robotConnected ? const Icon(Icons.check) : const Icon(Icons.cancel),
                icon: robotConnected ? const Icon(Icons.bluetooth_connected) : const Icon(Icons.bluetooth),
              ),
              Row(
                children: [
                  ///
                  /// change robot drive direction
                  ///
                  FloatingActionButton(
                    onPressed: () {
                      setState(() {
                        reverseRobot = !reverseRobot;
                      });
                    },
                    backgroundColor: Colors.orange,
                    shape: reverseRobot ? RoundedRectangleBorder(side: const BorderSide(width: 3, color: Colors.green), borderRadius: BorderRadius.circular(100)) : null,
                    child: const Icon(Icons.flip_camera_android_outlined),
                  ),

                  ///
                  /// change slider speed behaviour
                  ///
                  FloatingActionButton(
                    onPressed: () {
                      setState(() {
                        divisions == 2 ? divisions = 20 : divisions = 2;
                        currentSliderValueLeft = 0;
                        currentSliderValueRight = 0;
                      });
                    },
                    shape: divisions == 20 ? RoundedRectangleBorder(side: const BorderSide(width: 3, color: Colors.green), borderRadius: BorderRadius.circular(100)) : null,
                    backgroundColor: Colors.yellow,
                    child: const Icon(Icons.speed),
                  ),
                ],
              ),
              Row(
                children: [
                  ///
                  /// switch gyro steering on/off
                  ///
                  FloatingActionButton(
                    onPressed: () {
                      setState(() {
                        gyroControl = !gyroControl;
                      });
                    },
                    backgroundColor: Colors.red,
                    shape: gyroControl ? RoundedRectangleBorder(side: const BorderSide(width: 3, color: Colors.green), borderRadius: BorderRadius.circular(100)) : null,
                    child: const Icon(Icons.control_camera),
                  )
                ],
              )
            ],
          ),
          Container(
            margin: const EdgeInsets.only(left: 200, top: 10, bottom: 10),
            child: RotatedBox(
                quarterTurns: 3,
                child: SliderTheme(
                  data: const SliderThemeData(
                      trackHeight: 50,
                      activeTrackColor: Colors.red,
                      inactiveTickMarkColor: Colors.white,
                      inactiveTrackColor: Colors.blue,
                      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 30, elevation: 5),
                      trackShape: RoundedRectSliderTrackShape(),
                      tickMarkShape: RoundSliderTickMarkShape(tickMarkRadius: 5)),
                  child: Slider(
                    value: gyroControl ? currentSliderValueLeft : currentSliderValueRight,
                    min: -100,
                    max: 100,
                    divisions: divisions,
                    onChanged: (double value) {
                      setState(() {
                        if (gyroControl) {
                          currentSliderValueLeft = value.roundToDouble();
                        } else {
                          currentSliderValueRight = value.roundToDouble();
                        }
                      });
                    },
                    onChangeEnd: (double value) async {
                      setState(() {
                        if (gyroControl) {
                          currentSliderValueLeft = 0;
                        }
                        currentSliderValueRight = 0;
                      });
                    },
                  ),
                )),
          ),
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
                                    trailing: selectedRobot == index
                                        ? ElevatedButton(
                                            // TODO test on phone
                                            onPressed: () {
                                              setState(() {
                                                makeConnectionWithRobot(data.device);
                                              });
                                            },
                                            child: const Text("Connect to robot"))
                                        : const Text(""),
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
                  StreamBuilder<List<ScanResult>>(
                    stream: controller.scanResult,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Expanded(
                          child: ListView.builder(
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
                    onPressed: () => connectedRobotDevice.disconnect(), // TODO
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
  }
}

class _UserManualPage extends StatefulWidget {
  const _UserManualPage();

  @override
  State<_UserManualPage> createState() => _UserManualPageState();
}

class _UserManualPageState extends State<_UserManualPage> {
  double dummySlider = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("User Manual"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
            Navigator.pop(context);
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12.0),
        children: [
          _header("Control UI", fontSize: 50),
          _dividingLine(),
          const Text("The UI is build out of 2 elements:\n\t\t\t\t\t\t- The sliders to control the robot\n\t\t\t\t\t\t- The buttons to adjust small things to the robot"),

          ///
          /// dummy slider
          ///
          _dividingLine(),
          _header("Slider"),
          const Text("The slider controls the robot, 1 slider for each motor (configurable*).\n <-- Move the slider to the red side to drive backwards.\n --> Move the slider to the blue side to drive forwards."),
          const Text("\nThe slider will jump back to 0 after you let your finger go of the slider\n"),

          SliderTheme(
            data: const SliderThemeData(
                trackHeight: 50,
                activeTrackColor: Colors.red,
                inactiveTickMarkColor: Colors.white,
                inactiveTrackColor: Colors.blue,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 30, elevation: 5),
                trackShape: RoundedRectSliderTrackShape(),
                tickMarkShape: RoundSliderTickMarkShape(tickMarkRadius: 5)),
            child: Slider(
              value: dummySlider,
              min: -100,
              max: 100,
              onChanged: (value) {
                setState(() {
                  dummySlider = value;
                });
              },
              onChangeEnd: (value) {
                setState(() {
                  dummySlider = 0;
                });
              },
            ),
          ),
          _header("*everything that is configurable means that it can be changed with the buttons in the middle of the screen", fontSize: 10), // not a header but a sidenote

          _dividingLine(),
          _header("Control buttons"),
          _header("Some buttons, when activated, have a green border\n", fontSize: 12), // side note
          _userManualButtonExplained(Icons.arrow_upward, Colors.green, "This button flips your screen, it wil also point at the top of your screen to orientate in which direction you have to hold your phone"),
          _userManualButtonExplained(Icons.flip_camera_android_outlined, Colors.orange, "This button changes the front of the robot (only software)."),
          _userManualButtonExplained(Icons.speed, Colors.yellow, "This button changes the slider input from a digital feel (0 or 100/on or off) to an analog feel (divided per 10%)"),
          _userManualButtonExplained(Icons.control_camera, Colors.red,
              "This button switches the gyrosteering on and off.\nThe gyrosteering enables you to control the robot with the orientation of your phone. In other words: you can use your phone as a steering wheel. When on, the sliders become unified as 1 throttle slider."),
          _userManualButtonExplained(
              Icons.bluetooth, Colors.blue, "The bigger button is the bluetooth button. It also shows the bluetooth status: a cross when not connected and a checkmark when connected.\nPress this button to open the bluetooth screen (read below ↓)"),
          _dividingLine(),
          _header("Bluetooth configuration screen", fontSize: 50),
          _dividingLine(),
          const Text("The main goal here is to connect your robot to the app. So you CAN only connect your robot here, nothing else\n"),
          const Text("You have 2 tabs, 1 where only the robots show up, the other one with all bluetooth connections in your area. You only have to be on the first tab.\n"),
          const Text("Press the most left button on the robot (button 1) to make the robot visible to other bluetooth devices. A green led will flicker."),
          const Text("Press the green connect button to start connecting. The app searches 15 seconds for your robot, if not found try again or press the i button to start troubleshooting."),
          const Text("When a robot is found it will show in the first tab. Press on the desired robot and click connect. A bright green led will light up on the robot.\n"),
          const Text("When the robot is connected you can go back to the home page, you can also disconnect your robot here.")
        ],
      ),
    );
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
          _header("Restart the app"),
          const Text("Sometimes it helps to just restart the app."),
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

Widget _header(String headerText, {double fontSize = 26}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      headerText,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

Widget _userManualButtonExplained(IconData icon, MaterialColor color, String text) {
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_userManualFloatingActionButton(icon, color), _userManualFlexText(text)],
    ),
  );
}

Widget _userManualFloatingActionButton(IconData icon, MaterialColor color) {
  return Padding(
    padding: const EdgeInsets.only(left: 12, right: 10, bottom: 30),
    child: FloatingActionButton(
      onPressed: null,
      backgroundColor: color,
      child: Icon(icon),
    ),
  );
}

Widget _userManualFlexText(String text) {
  return Flexible(
    child: Text(text),
  );
}

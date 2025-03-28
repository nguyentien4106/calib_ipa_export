// ignore_for_file: avoid_print, depend_on_referenced_packages

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:universal_ble_example/peripheral_details/widgets/result_widget.dart';
import 'package:universal_ble_example/peripheral_details/widgets/services_list_widget.dart';
import 'package:universal_ble_example/widgets/platform_button.dart';
import 'package:universal_ble_example/widgets/responsive_view.dart';

enum AppState { initial, setup, started }

class PeripheralDetailPage extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  const PeripheralDetailPage(this.deviceId, this.deviceName, {Key? key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _PeripheralDetailPageState();
  }
}

class _PeripheralDetailPageState extends State<PeripheralDetailPage> {
  bool isConnected = false;
  bool isSubscribe = false;
  AppState state = AppState.initial;
  List<String> notifications = [];
  Timer? _notificationTimer;

  String trueScore = '';
  String falseScore = '';
  GlobalKey<FormState> valueFormKey = GlobalKey<FormState>();
  List<BleService> discoveredServices = [];
  final List<String> _logs = [];
  final binaryCode = TextEditingController();
  String modeValue = 'RANDOM';
  String colorOnValue = 'RED';
  String colorOffValue = 'OFF';
  final TextEditingController timeOnController = TextEditingController();
  final TextEditingController timeOffController = TextEditingController();
  final TextEditingController timePlayController = TextEditingController();
  List<bool> activeNodes = List.generate(20, (index) => true);

  ({
    BleService service,
    BleCharacteristic characteristic
  })? selectedCharacteristic;

  @override
  void initState() {
    super.initState();
    UniversalBle.onConnectionChange = _handleConnectionChange;
    UniversalBle.onValueChange = _handleValueChange;
    UniversalBle.onPairingStateChange = _handlePairingStateChange;
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
    UniversalBle.onConnectionChange = null;
    UniversalBle.onValueChange = null;
    // Disconnect when leaving the page
    if (isConnected) UniversalBle.disconnect(widget.deviceId);
  }

  void _addLog(String type, dynamic data) {
    // setState(() {
    //   _logs.add('$type: ${data.toString()}');
    // });
  }

  void _handleConnectionChange(
    String deviceId,
    bool isConnected,
    String? error,
  ) async {
    print(
      '_handleConnectionChange $deviceId, $isConnected ${error != null ? 'Error: $error' : ''}',
    );
    setState(() {
      if (deviceId == widget.deviceId) {
        this.isConnected = isConnected;
      }
    });
    _addLog('Connection', isConnected ? "Connected" : "Disconnected");

    if (!isConnected) {
      // Unsubscribe when disconnected
      if (isSubscribe) {
        await _unsubscribe();
      }
      return;
    }

    // Auto Discover Services
    await _discoverServices();
    // Auto subscribe to notifications if we have services
    if (discoveredServices.isNotEmpty) {
      // Find the first service with notify/indicate characteristic
      for (var service in discoveredServices) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties
                  .contains(CharacteristicProperty.notify) ||
              characteristic.properties
                  .contains(CharacteristicProperty.indicate)) {
            setState(() {
              selectedCharacteristic =
                  (service: service, characteristic: characteristic);
            });
            await _subscribe();
            break;
          }
        }
        if (isSubscribe) break;
      }
    }
  }

  void _handleValueChange(
      String deviceId, String characteristicId, Uint8List value) {
    String s = String.fromCharCodes(value);
    String score = '';
    if (s.startsWith('true')) {
      score = s.split('~')[1];
      setState(() {
        trueScore = score;
      });
    } else if (s.startsWith('false')) {
      score = s.split('~')[1];
      setState(() {
        falseScore = score;
      });
    } else if (s.startsWith('act')) {
      // Handle node activation states
      try {
        List<String> values = s.split('~');
        if (values.length >= 21) {
          // "act" + 20 values
          setState(() {
            // Update all 20 nodes based on received values
            for (int i = 0; i < 20; i++) {
              activeNodes[i] =
                  values[i + 1] == "1"; // Convert "1" to true, "0" to false
            }
          });
        }
      } catch (e) {
        print('Error parsing node activation states: $e');
      }
    }
    print('_handleValueChange $deviceId, $characteristicId, $s');
    _addLog("Value", score);
  }

  void _handlePairingStateChange(String deviceId, bool isPaired) {
    print('isPaired $deviceId, $isPaired');
    _addLog("PairingStateChange - isPaired", isPaired);
  }

  Future<void> _discoverServices() async {
    const webWarning =
        "Note: Only services added in ScanFilter or WebOptions will be discovered";
    try {
      var services = await UniversalBle.discoverServices(widget.deviceId);
      print('${services.length} services discovered');
      print(services);
      discoveredServices.clear();
      setState(() {
        discoveredServices = services;
      });

      if (kIsWeb) {
        _addLog(
          "DiscoverServices",
          '${services.length} services discovered,\n$webWarning',
        );
      }
    } catch (e) {
      _addLog("DiscoverServicesError", '$e\n${kIsWeb ? webWarning : ""}');
    }
  }

  Uint8List _createRequest(text) {
    return Uint8List.fromList(text.codeUnits);
  }

  Future<bool> _write(value) async {
    if (selectedCharacteristic == null) {
      return false;
    }

    // Uint8List value;
    try {
      // value = Uint8List.fromList(hex.decode(binaryCode.text));
    } catch (e) {
      _addLog('WriteError', "Error parsing hex $e");
      return false;
    }

    try {
      await UniversalBle.writeValue(
        widget.deviceId,
        selectedCharacteristic!.service.uuid,
        selectedCharacteristic!.characteristic.uuid,
        value,
        _hasSelectedCharacteristicProperty(
                [CharacteristicProperty.writeWithoutResponse])
            ? BleOutputProperty.withoutResponse
            : BleOutputProperty.withResponse,
      );
      _addLog('Write', value);
      return true;
    } catch (e) {
      print(e);
      _addLog('WriteError', e);
      return false;
    }
  }

  Future<void> _setBleInputProperty(BleInputProperty inputProperty) async {
    if (selectedCharacteristic == null) return;
    try {
      if (inputProperty != BleInputProperty.disabled) {
        List<CharacteristicProperty> properties =
            selectedCharacteristic!.characteristic.properties;
        if (properties.contains(CharacteristicProperty.notify)) {
          inputProperty = BleInputProperty.notification;
        } else if (properties.contains(CharacteristicProperty.indicate)) {
          inputProperty = BleInputProperty.indication;
        } else {
          throw 'No notify or indicate property';
        }
      }
      await UniversalBle.setNotifiable(
        widget.deviceId,
        selectedCharacteristic!.service.uuid,
        selectedCharacteristic!.characteristic.uuid,
        inputProperty,
      );
      _addLog('BleInputProperty', inputProperty);
    } catch (e) {
      _addLog('NotifyError', e);
    }
  }

  void notify(String text) {
    setState(() {
      notifications.insert(0, text); // Add to the beginning of the list (LIFO)
    });

    // Remove the notification after 3 seconds
    _notificationTimer?.cancel();
    _notificationTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          if (notifications.isNotEmpty) {
            notifications.removeLast(); // Remove the oldest notification
          }
        });
      }
    });
  }

  Future<void> _stop() async {
    if (state != AppState.started) {
      notify('Need to Setup -> Start first!');
      return;
    }
    Uint8List command = _createRequest("~E");
    bool result = await _write(command);
    notify('Stop Successfully!');
    setState(() {
      state = AppState.initial;
    });
  }

  Future<void> _start() async {
    print(state.name);
    if (state != AppState.setup) {
      notify('Need to Setup first!');
      return;
    }
    Uint8List command = _createRequest("~B");
    bool result = await _write(command);
    setState(() {
      state = AppState.started;
    });
    notify('Start Successfully!');
  }

  Future<void> _setup() async {
    if (timeOnController.text.isEmpty) {
      notify('Please fill in fields: Time On');
      return;
    }

    if (timeOffController.text.isEmpty) {
      notify('Please fill in fields: Time Delay');
      return;
    }

    if (timePlayController.text.isEmpty) {
      notify('Please fill in fields: Time Play');
      return;
    }

    String value =
        '${modeValue[0]}~${timeOnController.text}~${timePlayController.text}~${timeOffController.text}~${colorOnValue == 'RANDOM' ? 'n' : colorOnValue[0]}~${colorOffValue == 'RANDOM' ? 'n' : colorOffValue[0]}';
    print(value);
    Uint8List command = _createRequest(value);
    bool result = await _write(command);
    setState(() {
      state = AppState.setup;
    });
    notify('Setup: ${result ? "Successfully" : "Failed"}');
  }

  Future<void> _subscribe() async {
    setState(() {
      isSubscribe = true;
    });
    _setBleInputProperty(BleInputProperty.notification);
    notify('Subscribe: Successfully');
  }

  Future<void> _unsubscribe() async {
    setState(() {
      isSubscribe = false;
    });
    _setBleInputProperty(BleInputProperty.disabled);
    notify('Unsubscribe: Successfully');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text("${widget.deviceName}"),
            elevation: 4,
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: isConnected ? Colors.greenAccent : Colors.red,
                  size: 24,
                ),
              )
            ],
          ),
          body: GestureDetector(
            onTap: () {
              FocusScope.of(context).requestFocus(new FocusNode());
            },
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Connection Status Card
                  Card(
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          ElevatedButton.icon(
                            icon: const Icon(Icons.bluetooth),
                            label: const Text('Connect'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            onPressed: !isConnected
                                ? () async {
                                    try {
                                      await UniversalBle.connect(
                                          widget.deviceId);
                                      _addLog("ConnectionResult", true);
                                    } catch (e) {
                                      _addLog(
                                          'ConnectError (${e.runtimeType})', e);
                                    }
                                  }
                                : null,
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.bluetooth_disabled),
                            label: const Text('Disconnect'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            onPressed: isConnected
                                ? () {
                                    UniversalBle.disconnect(widget.deviceId);
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Score Display Card
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'True Score',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  trueScore,
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 60,
                            color: Colors.grey[300],
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'False Score',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  falseScore,
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_hasSelectedCharacteristicProperty([
                    CharacteristicProperty.write,
                    CharacteristicProperty.writeWithoutResponse
                  ]))
                    // Control Panel Card
                    Card(
                      margin: const EdgeInsets.all(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Control Panel',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Mode and Colors Row
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Mode',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<String>(
                                        value: modeValue,
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                        ),
                                        items: ['RANDOM', 'SEQUENCE']
                                            .map((String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(value),
                                          );
                                        }).toList(),
                                        onChanged: (String? newValue) {
                                          if (newValue != null) {
                                            setState(() {
                                              modeValue = newValue;
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Color On',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<String>(
                                        value: colorOnValue,
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                        ),
                                        items: [
                                          'RED',
                                          'WHITE',
                                          'BLUE',
                                          'YELLOW',
                                          'RANDOM'
                                        ].map((String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(value),
                                          );
                                        }).toList(),
                                        onChanged: (String? newValue) {
                                          if (newValue != null) {
                                            setState(() {
                                              colorOnValue = newValue;
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Color Off',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<String>(
                                        value: colorOffValue,
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                        ),
                                        items: [
                                          'RED',
                                          'WHITE',
                                          'BLUE',
                                          'YELLOW',
                                          'OFF',
                                          'RANDOM'
                                        ].map((String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(value),
                                          );
                                        }).toList(),
                                        onChanged: (String? newValue) {
                                          if (newValue != null) {
                                            setState(() {
                                              colorOffValue = newValue;
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Time Inputs Row
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Time Play (s)',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: timePlayController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          hintText: 'seconds',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Time On (ms)',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: timeOnController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          hintText: 'milliseconds',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Time Delay (ms)',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: timeOffController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          hintText: 'milliseconds',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Control Buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.stop),
                                  label: const Text('Stop'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 12),
                                  ),
                                  onPressed: _stop,
                                ),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Start'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 12),
                                  ),
                                  onPressed: _start,
                                ),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.settings),
                                  label: const Text('Setup'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 12),
                                  ),
                                  onPressed: _setup,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Active Nodes Display
                  if (isConnected)
                    Card(
                      margin: const EdgeInsets.all(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Active Nodes',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(10, (index) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: activeNodes[index]
                                          ? Colors.green
                                          : Colors.white,
                                      border: Border.all(
                                        color: Colors.grey[400]!,
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.2),
                                          spreadRadius: 1,
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$index',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: activeNodes[index]
                                              ? Colors.white
                                              : Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(10, (index) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: activeNodes[index + 10]
                                          ? Colors.green
                                          : Colors.white,
                                      border: Border.all(
                                        color: Colors.grey[400]!,
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.2),
                                          spreadRadius: 1,
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 10}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: activeNodes[index + 10]
                                              ? Colors.white
                                              : Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        // Notification Overlay
        if (notifications.isNotEmpty)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.4,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  notifications.first,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }

  bool _hasSelectedCharacteristicProperty(
          List<CharacteristicProperty> properties) =>
      properties.any((property) =>
          selectedCharacteristic?.characteristic.properties
              .contains(property) ??
          false);
}

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
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
      ),
    );
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
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.deviceName}"),
        elevation: 4,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              isConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
              color: isConnected ? Colors.greenAccent : Colors.red,
              size: 20,
            ),
          )
        ],
      ),
      body: new GestureDetector(
        child: ResponsiveView(builder: (_, DeviceType deviceType) {
          return Row(
            children: [
              if (deviceType == DeviceType.desktop)
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Theme.of(context).secondaryHeaderColor,
                    child: discoveredServices.isEmpty
                        ? const Center(
                            child: Text('No Services Discovered'),
                          )
                        : ServicesListWidget(
                            discoveredServices: discoveredServices,
                            scrollable: true,
                            onTap: (BleService service,
                                BleCharacteristic characteristic) {
                              setState(() {
                                selectedCharacteristic = (
                                  service: service,
                                  characteristic: characteristic
                                );
                              });
                            },
                          ),
                  ),
                ),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Top buttons
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: <Widget>[
                              PlatformButton(
                                text: 'Connect',
                                enabled: !isConnected,
                                onPressed: () async {
                                  try {
                                    await UniversalBle.connect(
                                      widget.deviceId,
                                    );
                                    _addLog("ConnectionResult", true);
                                  } catch (e) {
                                    _addLog(
                                        'ConnectError (${e.runtimeType})', e);
                                  }
                                },
                              ),
                              PlatformButton(
                                text: 'Disconnect',
                                enabled: isConnected,
                                onPressed: () {
                                  UniversalBle.disconnect(widget.deviceId);
                                },
                              ),
                            ],
                          ),
                        ),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    'True Score',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    trueScore,
                                    style: TextStyle(fontSize: 50),
                                  )
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    'False Score',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    falseScore,
                                    style: TextStyle(fontSize: 50),
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_hasSelectedCharacteristicProperty([
                          CharacteristicProperty.write,
                          CharacteristicProperty.writeWithoutResponse
                        ]))
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                // Dropdown
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Select Mode:',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButton<String>(
                                      value: modeValue,
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          modeValue = newValue!;
                                        });
                                      },
                                      items: <String>['RANDOM', 'FREQUENTLY']
                                          .map<DropdownMenuItem<String>>(
                                              (String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          const Text(
                                            'Color On',
                                            style: TextStyle(fontSize: 16),
                                          ),
                                          const SizedBox(height: 8),
                                          DropdownButton<String>(
                                            value: colorOnValue,
                                            onChanged: (String? newValue) {
                                              setState(() {
                                                colorOnValue = newValue!;
                                              });
                                            },
                                            items: <String>[
                                              'RED',
                                              'WHITE',
                                              'YELLOW',
                                              'BLUE',
                                              'RANDOM'
                                            ].map<DropdownMenuItem<String>>(
                                                (String value) {
                                              return DropdownMenuItem<String>(
                                                value: value,
                                                child: Text(value),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(
                                        width: 16), // Space between two fields
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
                                          DropdownButton<String>(
                                            value: colorOffValue,
                                            onChanged: (String? newValue) {
                                              setState(() {
                                                colorOffValue = newValue!;
                                              });
                                            },
                                            items: <String>[
                                              'RED',
                                              'WHITE',
                                              'YELLOW',
                                              'BLUE',
                                              'OFF',
                                              'RANDOM'
                                            ].map<DropdownMenuItem<String>>(
                                                (String value) {
                                              return DropdownMenuItem<String>(
                                                value: value,
                                                child: Text(value),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                // Row with Two Text Fields
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
                                              hintText: 'giây',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(
                                        width: 16), // Space between two fields
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
                                              hintText: 'mili giây',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(
                                        width: 16), // Space between two fields
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
                                              hintText: 'mili giây',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    ElevatedButton(
                                      onPressed: _stop,
                                      child: const Text('Stop'),
                                    ),
                                    const SizedBox(
                                        width: 26), // Space between two fields
                                    ElevatedButton(
                                      onPressed: _start,
                                      child: const Text('Start'),
                                    ),
                                    const SizedBox(
                                        width: 26), // Space between two fields
                                    ElevatedButton(
                                      onPressed: _setup,
                                      child: const Text('Setup'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        const Divider(),
                        if (deviceType != DeviceType.desktop)
                          ServicesListWidget(
                            discoveredServices: discoveredServices,
                            onTap: (BleService service,
                                BleCharacteristic characteristic) {
                              setState(() {
                                selectedCharacteristic = (
                                  service: service,
                                  characteristic: characteristic
                                );
                              });
                            },
                          ),
                        const Divider(),
                        ResultWidget(
                            results: _logs,
                            onClearTap: (int? index) {
                              setState(() {
                                if (index != null) {
                                  _logs.removeAt(index);
                                } else {
                                  _logs.clear();
                                }
                              });
                            }),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
        onTap: () {
          FocusScope.of(context).requestFocus(new FocusNode());
        },
      ),
    );
  }

  bool _hasSelectedCharacteristicProperty(
          List<CharacteristicProperty> properties) =>
      properties.any((property) =>
          selectedCharacteristic?.characteristic.properties
              .contains(property) ??
          false);
}

import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:universal_ble_example/data/mock_universal_ble.dart';
import 'package:universal_ble_example/home/widgets/scan_filter_widget.dart';
import 'package:universal_ble_example/home/widgets/scanned_devices_placeholder_widget.dart';
import 'package:universal_ble_example/home/widgets/scanned_item_widget.dart';
import 'package:universal_ble_example/data/permission_handler.dart';
import 'package:universal_ble_example/peripheral_details/peripheral_detail_page.dart';
import 'package:universal_ble_example/widgets/platform_button.dart';
import 'package:universal_ble_example/widgets/responsive_buttons_grid.dart';

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _bleDevices = <BleDevice>[];
  bool _isScanning = false;
  QueueType _queueType = QueueType.global;
  TextEditingController servicesFilterController = TextEditingController();
  TextEditingController namePrefixController = TextEditingController();
  TextEditingController manufacturerDataController = TextEditingController();

  AvailabilityState? bleAvailabilityState;
  ScanFilter? scanFilter;

  @override
  void initState() {
    super.initState();

    /// Set mock instance for testing
    if (const bool.fromEnvironment('MOCK')) {
      UniversalBle.setInstance(MockUniversalBle());
    }

    /// Setup queue and timeout
    UniversalBle.queueType = _queueType;
    UniversalBle.timeout = const Duration(seconds: 10);

    UniversalBle.onAvailabilityChange = (state) {
      setState(() {
        bleAvailabilityState = state;
      });
    };

    UniversalBle.onScanResult = (result) {
      // Skip unknown devices
      if (result.name == null || result.name!.isEmpty) {
        return;
      }

      int index = _bleDevices.indexWhere((e) => e.deviceId == result.deviceId);
      if (index == -1) {
        _bleDevices.add(result);
      } else {
        if (result.name == null && _bleDevices[index].name != null) {
          result.name = _bleDevices[index].name;
        }
        _bleDevices[index] = result;
      }
      setState(() {});
    };

    // UniversalBle.onQueueUpdate = (String id, int remainingItems) {
    //   debugPrint("Queue: $id RemainingItems: $remainingItems");
    // };
  }

  Future<void> startScan() async {
    await UniversalBle.startScan(
      scanFilter: scanFilter,
    );
  }

  void _showScanFilterBottomSheet() {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (context) {
        return ScanFilterWidget(
          servicesFilterController: servicesFilterController,
          namePrefixController: namePrefixController,
          manufacturerDataController: manufacturerDataController,
          onScanFilter: (ScanFilter? filter) {
            setState(() {
              scanFilter = filter;
            });
          },
        );
      },
    );
  }

  void showSnackbar(message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.toString())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Device Scanner'),
        elevation: 4,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Bluetooth Status
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: bleAvailabilityState == AvailabilityState.poweredOn
                  ? Colors.green.shade100
                  : Colors.red.shade100,
              border: Border.all(
                color: bleAvailabilityState == AvailabilityState.poweredOn
                    ? Colors.green.shade300
                    : Colors.red.shade300,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  bleAvailabilityState == AvailabilityState.poweredOn
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: bleAvailabilityState == AvailabilityState.poweredOn
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  bleAvailabilityState == AvailabilityState.poweredOn
                      ? 'ON'
                      : 'OFF',
                  style: TextStyle(
                    color: bleAvailabilityState == AvailabilityState.poweredOn
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator.adaptive(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Scan Controls
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(_isScanning ? Icons.stop : Icons.search),
                    label: Text(_isScanning ? 'Stop Scan' : 'Start Scan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isScanning ? Colors.red : Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed:
                        bleAvailabilityState != AvailabilityState.poweredOn
                            ? null
                            : () async {
                                if (_isScanning) {
                                  await UniversalBle.stopScan();
                                  setState(() {
                                    _isScanning = false;
                                  });
                                } else {
                                  setState(() {
                                    _bleDevices.clear();
                                    _isScanning = true;
                                  });
                                  try {
                                    await startScan();
                                  } catch (e) {
                                    setState(() {
                                      _isScanning = false;
                                    });
                                    showSnackbar(e);
                                  }
                                }
                              },
                  ),
                ),
                if (_bleDevices.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      setState(() {
                        _bleDevices.clear();
                      });
                    },
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Device List
          Expanded(
            child: _isScanning && _bleDevices.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator.adaptive(),
                        SizedBox(height: 16),
                        Text(
                          'Scanning for devices...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : !_isScanning && _bleDevices.isEmpty
                    ? const ScannedDevicesPlaceholderWidget()
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _bleDevices.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          BleDevice device =
                              _bleDevices[_bleDevices.length - index - 1];
                          return ScannedItemWidget(
                            bleDevice: device,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PeripheralDetailPage(
                                    device.deviceId,
                                    device.name ?? "Unknown Device",
                                  ),
                                ),
                              );
                              UniversalBle.stopScan();
                              setState(() {
                                _isScanning = false;
                              });
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

class ScannedItemWidget extends StatelessWidget {
  final BleDevice bleDevice;
  final VoidCallback? onTap;
  const ScannedItemWidget({super.key, required this.bleDevice, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Skip rendering if device name is null or empty
    if (bleDevice.name == null || bleDevice.name!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Device Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bleDevice.isPaired == true
                      ? Colors.blue.shade50
                      : Colors.grey.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bluetooth,
                  color: bleDevice.isPaired == true
                      ? Colors.blue.shade700
                      : Colors.grey.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Device Name
              Expanded(
                child: Text(
                  bleDevice.name!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Paired Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bleDevice.isPaired == true
                      ? Colors.green.shade50
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      bleDevice.isPaired == true
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 16,
                      color: bleDevice.isPaired == true
                          ? Colors.green.shade700
                          : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      bleDevice.isPaired == true ? 'Paired' : 'Not Paired',
                      style: TextStyle(
                        fontSize: 12,
                        color: bleDevice.isPaired == true
                            ? Colors.green.shade700
                            : Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Forward Arrow
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

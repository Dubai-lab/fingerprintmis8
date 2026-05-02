import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'fingerprint_sdk.dart';

class FingerprintEnrollmentPage extends StatefulWidget {
  @override
  _FingerprintEnrollmentPageState createState() => _FingerprintEnrollmentPageState();
}

class _FingerprintEnrollmentPageState extends State<FingerprintEnrollmentPage> {
  final FingerprintSdk _fingerprintSdk = FingerprintSdk();

  String _status = 'Idle';
  bool _deviceOpened = false;
  bool _isEnrolling = false;
  Uint8List? _fingerprintTemplate;

  @override
  void initState() {
    super.initState();
    _fingerprintSdk.statusStream.listen((status) {
      setState(() {
        _status = status;
        if (status == 'Open Device OK') {
          _deviceOpened = true;
        } else if (status == 'Close Device' || status == 'Device Detached - Closed') {
          _deviceOpened = false;
          _fingerprintTemplate = null;
        }
      });
    });
    _fingerprintSdk.templateStream.listen((template) {
      setState(() {
        _fingerprintTemplate = template;
        _isEnrolling = false;
        _status = 'Fingerprint captured successfully';
        // Automatically pop and return the template base64 when captured
        if (_fingerprintTemplate != null) {
          String templateBase64 = base64Encode(_fingerprintTemplate!);
          Navigator.pop(context, templateBase64);
        }
      });
    });
  }

  Future<void> _openDevice() async {
    try {
      await _fingerprintSdk.openDevice();
    } catch (e) {
      setState(() {
        _status = 'Failed to open device: $e';
      });
    }
  }

  Future<void> _closeDevice() async {
    try {
      await _fingerprintSdk.closeDevice();
    } catch (e) {
      setState(() {
        _status = 'Failed to close device: $e';
      });
    }
  }

  Future<void> _enrollTemplate() async {
    if (!_deviceOpened) {
      setState(() {
        _status = 'Device not opened';
      });
      return;
    }
    setState(() {
      _isEnrolling = true;
      _status = 'Enrolling template...';
    });
    try {
      await _fingerprintSdk.enrollTemplate();
    } catch (e) {
      setState(() {
        _status = 'Failed to enroll fingerprint: $e';
        _isEnrolling = false;
      });
      _showErrorDialog('Enrollment Failed', 'Failed to enroll fingerprint: $e');
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fingerprintSdk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDeviceReady = _deviceOpened && !_isEnrolling;

    return WillPopScope(
      onWillPop: () async {
        if (_deviceOpened) {
          await _closeDevice();
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Fingerprint Enrollment', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.blue.shade700,
          elevation: 2,
          automaticallyImplyLeading: true,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Header Card with Device Status
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.fingerprint,
                        size: 100,
                        color: _deviceOpened ? Colors.green.shade300 : Colors.orange.shade300,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _deviceOpened ? 'Device Connected' : 'Device Disconnected',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _deviceOpened ? '✓ Ready' : '✗ Not Ready',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Status and Instructions Card
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _isEnrolling
                                    ? Colors.blue.withOpacity(0.2)
                                    : _deviceOpened
                                        ? Colors.green.withOpacity(0.2)
                                        : Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _isEnrolling
                                    ? Icons.hourglass_top
                                    : _deviceOpened
                                        ? Icons.check_circle
                                        : Icons.info,
                                color: _isEnrolling
                                    ? Colors.blue
                                    : _deviceOpened
                                        ? Colors.green
                                        : Colors.orange,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Current Status',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _status,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),
                        const Text(
                          'Instructions:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInstructionStep(
                          '1',
                          'Connect your fingerprint device and tap "Open Device"',
                          _deviceOpened,
                        ),
                        const SizedBox(height: 8),
                        _buildInstructionStep(
                          '2',
                          'Once connected, tap "Enroll Template"',
                          _deviceOpened && !_isEnrolling,
                        ),
                        const SizedBox(height: 8),
                        _buildInstructionStep(
                          '3',
                          'Place your finger on the device and wait for capture',
                          _isEnrolling,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Control Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Open Device Button
                    ElevatedButton.icon(
                      onPressed: _deviceOpened ? null : _openDevice,
                      icon: const Icon(Icons.usb),
                      label: const Text('Open Device'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.blue.shade600,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Enroll Template Button
                    ElevatedButton.icon(
                      onPressed: isDeviceReady ? _enrollTemplate : null,
                      icon: _isEnrolling
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withOpacity(0.7),
                                ),
                              ),
                            )
                          : const Icon(Icons.fingerprint),
                      label: Text(_isEnrolling ? 'Enrolling...' : 'Enroll Template'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.green.shade600,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Close Device Button
                    OutlinedButton.icon(
                      onPressed: !_deviceOpened ? null : _closeDevice,
                      icon: const Icon(Icons.close),
                      label: const Text('Close Device'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: _deviceOpened ? Colors.red.shade600 : Colors.grey.shade300,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Success Message
              if (_fingerprintTemplate != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    color: Colors.green.shade50,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.green.shade200, width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Fingerprint successfully captured!',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text, bool isActive) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isActive ? Colors.blue.shade600 : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isActive ? Colors.black87 : Colors.grey.shade600,
                fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

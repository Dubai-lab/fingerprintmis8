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
    return WillPopScope(
      onWillPop: () async => true, // Enable back button to allow navigation
      child: Scaffold(
        appBar: AppBar(
          title: Text('Fingerprint Enrollment'),
          automaticallyImplyLeading: true, // Enable back button as second option
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fingerprint, size: 120, color: _deviceOpened ? Colors.green : Colors.red),
                SizedBox(height: 20),
                Text('Status: $_status'),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _deviceOpened ? null : _openDevice,
                  child: Text('Open Device'),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: !_deviceOpened ? null : _closeDevice,
                  child: Text('Close Device'),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: (_deviceOpened && !_isEnrolling) ? _enrollTemplate : null,
                  child: Text('Enroll Template'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

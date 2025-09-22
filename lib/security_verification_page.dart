import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'fingerprint_sdk.dart';

class SecurityVerificationPage extends StatefulWidget {
  @override
  _SecurityVerificationPageState createState() => _SecurityVerificationPageState();
}

class _SecurityVerificationPageState extends State<SecurityVerificationPage> {
  final FingerprintSdk _fingerprintSdk = FingerprintSdk();

  String _status = 'Idle';
  bool _deviceOpened = false;
  bool _scanning = false;
  Uint8List? _currentTemplate;

  Map<String, Map<String, dynamic>> _students = {}; // regNumber -> student data
  Map<String, String> _studentTemplates = {}; // regNumber -> base64 fingerprint template

  Map<String, dynamic>? _matchedStudent;

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
          _currentTemplate = null;
          _matchedStudent = null;
        }
      });
    });
    _fingerprintSdk.templateStream.listen((template) {
      setState(() {
        _currentTemplate = template;
        _scanning = false;
        _status = 'Fingerprint template captured';
      });
      if (_currentTemplate != null) {
        _matchFingerprint(_currentTemplate!);
      }
    });
    _loadRegisteredStudents();
  }

  Future<void> _loadRegisteredStudents() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('students').get();
      final Map<String, Map<String, dynamic>> studentsMap = {};
      final Map<String, String> templatesMap = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('regNumber') && data.containsKey('fingerprintTemplate')) {
          studentsMap[data['regNumber']] = data;
          templatesMap[data['regNumber']] = data['fingerprintTemplate'];
        }
      }
      setState(() {
        _students = studentsMap;
        _studentTemplates = templatesMap;
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to load registered students: $e';
      });
    }
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
      setState(() {
        _status = 'Device closed';
        _deviceOpened = false;
        _matchedStudent = null;
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to close device: $e';
      });
    }
  }

  Future<void> _startScanning() async {
    if (!_deviceOpened) {
      setState(() {
        _status = 'Device not opened';
      });
      return;
    }
    setState(() {
      _scanning = true;
      _status = 'Scan fingerprint to verify student';
    });
    try {
      await _fingerprintSdk.generateTemplate();
    } catch (e) {
      setState(() {
        _status = 'Failed to generate template: $e';
        _scanning = false;
      });
    }
  }

  Future<void> _matchFingerprint(Uint8List scannedTemplate) async {
    int bestScore = -1;
    String? bestMatchRegNumber;

    for (var entry in _studentTemplates.entries) {
      final regNumber = entry.key;
      final storedBase64 = entry.value;
      final storedTemplate = base64Decode(storedBase64);

      try {
        final int score = await _fingerprintSdk.matchTemplates(scannedTemplate, storedTemplate);
        if (score > bestScore) {
          bestScore = score;
          bestMatchRegNumber = regNumber;
        }
      } catch (e) {
        // Handle error if needed
      }
    }

    if (bestScore > 40 && bestMatchRegNumber != null) {
      setState(() {
        _matchedStudent = _students[bestMatchRegNumber];
        _status = 'Match found: ${_matchedStudent?['name']} (score: $bestScore)';
      });
    } else {
      setState(() {
        _matchedStudent = null;
        _status = 'No match found';
      });
    }
  }

  @override
  void dispose() {
    _fingerprintSdk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Security Verification'),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        elevation: 4,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/security_dashboard');
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade50, Colors.deepPurple.shade200],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(
                Icons.fingerprint,
                size: 140,
                color: _deviceOpened ? Colors.green : Colors.red,
              ),
              SizedBox(height: 24),
              Text(
                'Status:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
              SizedBox(height: 8),
              Text(
                _status,
                style: TextStyle(fontSize: 18, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.45),
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.usb),
                          label: Text('Open Device', style: TextStyle(color: Colors.white)),
                          onPressed: _deviceOpened ? null : _openDevice,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            textStyle: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.45),
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.usb_off, color: Colors.white),
                          label: Text('Close Device', style: TextStyle(color: Colors.white)),
                          onPressed: !_deviceOpened ? null : _closeDevice,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            textStyle: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: 40),
              ElevatedButton.icon(
                icon: Icon(Icons.fingerprint),
                label: Text('Scan Fingerprint', style: TextStyle(color: Colors.white)),
                onPressed: (_deviceOpened && !_scanning) ? _startScanning : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  textStyle: TextStyle(fontSize: 16),
                ),
              ),
              SizedBox(height: 40),
              _matchedStudent != null
                  ? Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: theme.colorScheme.primary.withOpacity(0.15),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Name: ${_matchedStudent?['name'] ?? ''}',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Registration Number: ${_matchedStudent?['regNumber'] ?? ''}',
                              style: TextStyle(fontSize: 18),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Department: ${_matchedStudent?['department'] ?? 'N/A'}',
                              style: TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Text(
                      'No student matched',
                      style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: const Color.fromARGB(255, 8, 8, 8)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

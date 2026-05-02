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

  static const int MATCH_THRESHOLD = 80; // Professional threshold

  String _status = 'Idle';
  bool _deviceOpened = false;
  bool _scanning = false;
  Uint8List? _currentTemplate;

  Map<String, Map<String, dynamic>> _students = {};
  Map<String, String> _studentTemplates = {};

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

    if (bestScore >= MATCH_THRESHOLD && bestMatchRegNumber != null) {
      setState(() {
        _matchedStudent = _students[bestMatchRegNumber];
        _status = '✅ Match found: ${_matchedStudent?['name']} (score: $bestScore)';
      });
      
      // Record verification to database
      _recordVerification(bestMatchRegNumber, bestScore);
    } else {
      setState(() {
        _matchedStudent = null;
        _status = bestScore >= 0
            ? '❌ Weak match (Score: $bestScore) - Threshold is $MATCH_THRESHOLD'
            : '❌ No fingerprint recognized';
      });
    }
  }

  Future<void> _recordVerification(String regNumber, int score) async {
    try {
      await FirebaseFirestore.instance.collection('security_verifications').add({
        'regNumber': regNumber,
        'studentName': _matchedStudent?['name'] ?? 'Unknown',
        'timestamp': FieldValue.serverTimestamp(),
        'matchScore': score,
        'status': 'VERIFIED',
      });
      print('Verification recorded successfully');
    } catch (e) {
      print('Error recording verification: $e');
    }
  }

  @override
  void dispose() {
    _fingerprintSdk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Student Security Verification'),
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
              // ============ DEVICE STATUS ============
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _deviceOpened ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _deviceOpened ? Colors.green : Colors.red,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _deviceOpened ? Icons.verified : Icons.close,
                      size: 32,
                      color: _deviceOpened ? Colors.green : Colors.red,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _deviceOpened ? 'Device: Connected' : 'Device: Disconnected',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _deviceOpened ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _deviceOpened ? 'Fingerprint scanner ready' : 'Please open device',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 32),

              // ============ FINGERPRINT ICON ============
              Icon(
                Icons.fingerprint,
                size: 120,
                color: _deviceOpened ? Colors.deepPurple : Colors.grey,
              ),

              SizedBox(height: 24),

              // ============ STATUS CARD ============
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Status:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _status,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _status.contains('✅') ? Colors.green :
                                 _status.contains('❌') ? Colors.red :
                                 Colors.deepPurple,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 32),

              // ============ DEVICE CONTROL BUTTONS ============
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 150),
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.usb),
                      label: Text('Open', style: TextStyle(color: Colors.white)),
                      onPressed: _deviceOpened ? null : _openDevice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        disabledBackgroundColor: Colors.grey,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 150),
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.usb_off, color: Colors.white),
                      label: Text('Close', style: TextStyle(color: Colors.white)),
                      onPressed: !_deviceOpened ? null : _closeDevice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        disabledBackgroundColor: Colors.grey,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24),

              // ============ SCAN BUTTON ============
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.fingerprint),
                  label: Text(
                    _scanning ? 'Scanning...' : 'Scan Fingerprint',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  onPressed: (_deviceOpened && !_scanning) ? _startScanning : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    disabledBackgroundColor: Colors.grey,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 40),

              // ============ STUDENT INFO CARD ============
              if (_matchedStudent != null)
                _buildStudentCard(_matchedStudent!)
              else
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: Colors.grey.shade50,
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.person_outline, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'No student verified yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Open device and scan fingerprint',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade50, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.verified_user, size: 40, color: Colors.deepPurple),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['name'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      Text(
                        'Reg: ${student['regNumber'] ?? ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 16),

            // Student Information
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDetailChip(
                  Icons.apartment,
                  'Department',
                  student['department'] ?? 'N/A',
                  Colors.blue,
                ),
                _buildDetailChip(
                  Icons.schedule,
                  'Session',
                  student['session'] ?? 'N/A',
                  Colors.orange,
                ),
              ],
            ),

            SizedBox(height: 16),

            // Verification Status
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.done_all, color: Colors.green, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Student Verified',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, size: 28, color: color),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

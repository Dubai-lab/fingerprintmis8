import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'fingerprint_sdk.dart';

class StudentVerificationPage extends StatefulWidget {
  @override
  _StudentVerificationPageState createState() => _StudentVerificationPageState();
}

class _StudentVerificationPageState extends State<StudentVerificationPage> {
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
        title: Text('Student Verification'),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        elevation: 4,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              ElevatedButton.icon(
                icon: Icon(Icons.usb, color: Colors.white),
                label: Text('Open Device', style: TextStyle(color: Colors.white)),
                onPressed: _deviceOpened ? null : _openDevice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  textStyle: TextStyle(fontSize: 16),
                ),
              ),
              SizedBox(width: 16),
              ElevatedButton.icon(
                icon: Icon(Icons.usb_off, color: Colors.white),
                label: Text('Close Device', style: TextStyle(color: Colors.white)),
                onPressed: !_deviceOpened ? null : _closeDevice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  textStyle: TextStyle(fontSize: 16),
                ),
              ),
                ],
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
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [Colors.green.shade50, Colors.green.shade100],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade600,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.verified_user, color: Colors.white, size: 28),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Student Verified',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                        Text(
                                          '✓ Fingerprint match successful',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Divider(height: 24),

                              // Personal Information
                              Text(
                                'Personal Information',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple.shade700,
                                ),
                              ),
                              SizedBox(height: 12),
                              _buildInfoRow('Name', _matchedStudent?['name'] ?? ''),
                              SizedBox(height: 8),
                              _buildInfoRow('Reg Number', _matchedStudent?['regNumber'] ?? ''),
                              SizedBox(height: 8),
                              _buildInfoRow('Department', _matchedStudent?['department'] ?? 'N/A'),
                              SizedBox(height: 8),
                              _buildInfoRow('Session', _matchedStudent?['session'] ?? 'N/A'),
                              SizedBox(height: 16),

                              // Payment Information
                              Text(
                                'Payment Information',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple.shade700,
                                ),
                              ),
                              SizedBox(height: 12),
                              _buildPaymentStatusRow(
                                'Payment Status',
                                _matchedStudent?['paymentStatus'] ?? 'UNKNOWN',
                              ),
                              SizedBox(height: 8),
                              _buildPaymentInfoRow(
                                'Total Fees',
                                _matchedStudent?['totalFees']?.toString() ?? '0.00',
                                Icons.attach_money,
                              ),
                              SizedBox(height: 8),
                              _buildPaymentInfoRow(
                                'Due Balance',
                                _matchedStudent?['dueBalance']?.toString() ?? '0.00',
                                Icons.money_off,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Icon(Icons.person_search, size: 80, color: Colors.grey.shade400),
                          SizedBox(height: 16),
                          Text(
                            'No student matched',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Place your finger on the device to verify',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentStatusRow(String label, String status) {
    Color statusColor;
    IconData statusIcon;

    if (status == 'CLEARED') {
      statusColor = Colors.green.shade600;
      statusIcon = Icons.check_circle;
    } else if (status == 'PENDING') {
      statusColor = Colors.orange.shade600;
      statusIcon = Icons.schedule;
    } else {
      // OVERDUE
      statusColor = Colors.red.shade600;
      statusIcon = Icons.error_outline;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, color: statusColor, size: 16),
              SizedBox(width: 6),
              Text(
                status,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentInfoRow(String label, String value, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.orange.shade600, size: 18),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        Text(
          'AED ${value}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
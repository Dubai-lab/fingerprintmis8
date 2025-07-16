import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'fingerprint_sdk.dart';

class InvigilatorAttendancePage extends StatefulWidget {
  const InvigilatorAttendancePage({Key? key}) : super(key: key);

  @override
  _InvigilatorAttendancePageState createState() => _InvigilatorAttendancePageState();
}

class _InvigilatorAttendancePageState extends State<InvigilatorAttendancePage> {
  final FingerprintSdk _fingerprintSdk = FingerprintSdk();

  String _status = 'Idle';
  bool _scanning = false;
  bool _deviceOpened = false;
  Uint8List? _currentTemplate;

  String? _selectedActivity;
  String? _selectedCourseId;

  List<String> _activities = ['CAT', 'EXAM', 'CONFERENCE'];
  List<Map<String, dynamic>> _courses = [];

  Map<String, String> _students = {}; // regNumber -> base64 fingerprint template

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
        _markAttendance(_currentTemplate!);
      }
    });
    _loadActivities();
    _loadCourses();
    _loadRegisteredStudents();
  }

  void _loadActivities() {
    // Activities are predefined, so no async loading needed here
    setState(() {
      _selectedActivity = _activities.first;
    });
  }

  Future<void> _loadCourses() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('instructor_courses')
          .get();

      setState(() {
        _courses = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['courseName'] ?? 'Unnamed Course',
          };
        }).toList();
        if (_courses.isNotEmpty) {
          _selectedCourseId = _courses.first['id'];
        }
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to load courses: $e';
      });
    }
  }

  Future<void> _loadRegisteredStudents() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('students').get();
      final Map<String, String> studentsMap = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('regNumber') && data.containsKey('fingerprintTemplate')) {
          studentsMap[data['regNumber']] = data['fingerprintTemplate'];
        }
      }
      setState(() {
        _students = studentsMap;
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to load registered students: $e';
      });
    }
  }

  Future<void> _startScanning() async {
    setState(() {
      _scanning = true;
      _status = 'Opening device...';
      _deviceOpened = false;
    });

    try {
      await _fingerprintSdk.openDevice();
    } catch (e) {
      setState(() {
        _status = 'Failed to open device: $e';
        _scanning = false;
        _deviceOpened = false;
      });
      return;
    }

    setState(() {
      _status = 'Place finger on scanner...';
      _deviceOpened = true;
    });

    try {
      await _fingerprintSdk.enrollTemplate();
    } catch (e) {
      setState(() {
        _status = 'Failed to scan fingerprint: $e';
        _scanning = false;
        _deviceOpened = false;
      });
      return;
    }
  }

  void _markAttendance(Uint8List scannedTemplate) async {
    int bestScore = -1;
    String? bestMatchRegNumber;

    for (var entry in _students.entries) {
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
      try {
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);

        final sanitizedRegNumber = bestMatchRegNumber.replaceAll('/', '_');

        if (_selectedActivity == 'CAT' || _selectedActivity == 'EXAM') {
          if (_selectedCourseId == null) {
            setState(() {
              _status = 'Please select a course for CAT or EXAM attendance.';
              _scanning = false;
            });
            return;
          }

          // Check if student has joined the selected course
          final joinedStudent = await FirebaseFirestore.instance
              .collection('instructor_courses')
              .doc(_selectedCourseId)
              .collection('students')
              .doc(sanitizedRegNumber)
              .get();

          if (!joinedStudent.exists) {
            setState(() {
              _status = 'Student $bestMatchRegNumber has not joined the selected course. Attendance not marked.';
              _scanning = false;
            });
            return;
          }
        }

        // Check if attendance already marked for this activity today
        final attendanceDocId = "${sanitizedRegNumber}_${_selectedActivity}_${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}";

        final attendanceDocRef = FirebaseFirestore.instance
            .collection('invigilator_activities')
            .doc(_selectedActivity)
            .collection('attendance')
            .doc(attendanceDocId);

        final attendanceDoc = await attendanceDocRef.get();

        if (attendanceDoc.exists) {
          setState(() {
            _status = 'Attendance already marked for $bestMatchRegNumber today for $_selectedActivity.';
            _scanning = false;
          });
          return;
        }

        await attendanceDocRef.set({
          'regNumber': sanitizedRegNumber,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'Present',
          'activity': _selectedActivity,
          'courseId': _selectedActivity == 'CONFERENCE' ? null : _selectedCourseId,
        });

        setState(() {
          _status = 'Attendance marked Present for $bestMatchRegNumber (score: $bestScore) for $_selectedActivity';
          _scanning = false;
        });
      } catch (e) {
        setState(() {
          _status = 'Failed to mark attendance: $e';
          _scanning = false;
        });
      }
    } else {
      setState(() {
        _status = 'Fingerprint not recognized or student not in system, attendance not marked';
        _scanning = false;
      });
    }
  }

  Future<void> _closeDevice() async {
    try {
      await _fingerprintSdk.closeDevice();
      setState(() {
        _status = 'Device closed';
        _deviceOpened = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to close device: $e';
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Invigilator Attendance'),
        backgroundColor: Colors.deepPurple,
        elevation: 4,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Select Activity',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              value: _selectedActivity,
              items: _activities.map((activity) {
                return DropdownMenuItem<String>(
                  value: activity,
                  child: Text(activity),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedActivity = value;
                  if (_selectedActivity == 'CONFERENCE') {
                    _selectedCourseId = null;
                  } else if (_courses.isNotEmpty) {
                    _selectedCourseId = _courses.first['id'];
                  }
                });
              },
            ),
            SizedBox(height: 20),
            if (_selectedActivity != 'CONFERENCE')
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Select Course',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                value: _selectedCourseId,
                items: _courses.map((course) {
                  return DropdownMenuItem<String>(
                    value: course['id'],
                    child: Text(course['name']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCourseId = value;
                  });
                },
              ),
            SizedBox(height: 30),
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                leading: Icon(Icons.fingerprint, color: Colors.deepPurple, size: 40),
                title: Text(
                  'Fingerprint Scanner Status',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                subtitle: Container(
                  height: 100,
                  child: SingleChildScrollView(
                    child: Text(
                      _status,
                      style: TextStyle(fontSize: 18, color: Colors.black87),
                    ),
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.refresh, color: Colors.deepPurple),
                  onPressed: () {
                    if (!_scanning) {
                      _startScanning();
                    }
                  },
                ),
              ),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 60),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _scanning ? null : _startScanning,
              child: Text(
                _scanning ? 'Scanning...' : 'Start Scanning',
                style: TextStyle(fontSize: 18),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 60),
                backgroundColor: Colors.grey[300],
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _closeDevice,
              child: Text(
                'Close Device',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

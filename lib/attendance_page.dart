import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'fingerprint_sdk.dart';
import 'package:fingerprintmis8/instructor_dashboard_page.dart';

class AttendancePage extends StatefulWidget {
  final String courseId;
  final String sessionId;

  const AttendancePage({Key? key, required this.courseId, required this.sessionId}) : super(key: key);

  @override
  _AttendancePageState createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final FingerprintSdk _fingerprintSdk = FingerprintSdk();

  String _status = 'Idle';
  bool _scanning = false;
  bool _deviceOpened = false;
  Uint8List? _currentTemplate;
  Map<String, String> _students = {}; // regNumber -> base64 fingerprint template
  Map<String, Map<String, dynamic>> _attendanceRecords = {}; // regNumber -> attendance data

  String? _selectedCourseId;
  List<Map<String, dynamic>> _courses = [];

  String _selectedCourseName = '';
  String _selectedSessionName = '';

  bool _loadingCourses = true;

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
    _loadCourses();
    _loadRegisteredStudents();
    _loadTodayAttendance();
  }

  Future<void> _loadCourses() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) {
      setState(() {
        _status = 'User not logged in';
        _loadingCourses = false;
      });
      return;
    }

    setState(() {
      _loadingCourses = true;
      _status = '';
    });

    try {
      final now = DateTime.now();
      final querySnapshot = await FirebaseFirestore.instance
          .collection('instructor_courses')
          .where('instructorId', isEqualTo: userId)
          .where('endDate', isGreaterThan: now)
          .get();

      setState(() {
        _courses = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['courseName'] ?? 'Unnamed Course',
            'session': data['session'] ?? '',
          };
        }).toList();
        _loadingCourses = false;
      });

      if (_selectedCourseId != null) {
        await loadSelectedCourseDetails(_selectedCourseId!);
      }
    } catch (e) {
      setState(() {
        _status = 'Failed to load courses: $e';
        _loadingCourses = false;
      });
    }
  }

  Future<void> loadSelectedCourseDetails(String courseId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('instructor_courses').doc(courseId).get();
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _selectedCourseName = data?['courseName'] ?? '';
          _selectedSessionName = data?['session'] ?? '';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Failed to load course details: $e';
      });
    }
  }

  Future<void> _loadSelectedCourseDetails(String courseId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('instructor_courses').doc(courseId).get();
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _selectedCourseName = data?['courseName'] ?? '';
          _selectedSessionName = data?['session'] ?? '';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Failed to load course details: $e';
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

  Future<void> _loadTodayAttendance() async {
    if (_selectedCourseId == null) {
      setState(() {
        _status = 'Please select a course to load attendance.';
      });
      return;
    }
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final snapshot = await FirebaseFirestore.instance
          .collection('instructor_courses')
          .doc(_selectedCourseId)
          .collection('attendance')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .get();
      final Map<String, Map<String, dynamic>> records = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('regNumber')) {
          records[data['regNumber']] = data;
        }
      }
      setState(() {
        _attendanceRecords = records;
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to load attendance records: $e';
      });
    }
  }

  Future<void> _startScanning() async {
    setState(() {
      _scanning = true;
      _status = 'Opening device...';
      _deviceOpened = false;
    });

    if (_selectedCourseId == null) {
      setState(() {
        _status = 'Please select a course before scanning.';
        _scanning = false;
      });
      return;
    }

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

      // Check if student has joined the course
      final sanitizedRegNumber = bestMatchRegNumber.replaceAll('/', '_');
      final joinedStudent = await FirebaseFirestore.instance
          .collection('instructor_courses')
          .doc(_selectedCourseId)
          .collection('students')
          .doc(sanitizedRegNumber)
          .get();

      if (!joinedStudent.exists) {
        setState(() {
          _status = 'Student $bestMatchRegNumber has not joined this course. Attendance not marked.';
          _scanning = false;
        });
        return;
      }

      final existingAttendance = await FirebaseFirestore.instance
          .collection('instructor_courses')
          .doc(_selectedCourseId)
          .collection('attendance')
          .where('regNumber', isEqualTo: sanitizedRegNumber)
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .get();

        if (existingAttendance.docs.isNotEmpty) {
          setState(() {
            _status = 'Attendance already marked for $bestMatchRegNumber today.';
            _scanning = false;
          });
          return;
        }

        // Refactored to use combined document ID to avoid composite index
        final todayDateStr = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2,'0')}-${DateTime.now().day.toString().padLeft(2,'0')}";
        final attendanceDocId = "${sanitizedRegNumber}_$todayDateStr";

        final attendanceDocRef = FirebaseFirestore.instance
            .collection('instructor_courses')
            .doc(_selectedCourseId)
            .collection('attendance')
            .doc(attendanceDocId);
        final attendanceDoc = await attendanceDocRef.get();

        if (attendanceDoc.exists) {
          setState(() {
            _status = 'Attendance already marked for $bestMatchRegNumber today.';
            _scanning = false;
          });
          return;
        }

        await attendanceDocRef.set({
          'regNumber': sanitizedRegNumber,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'Present',
          'courseId': _selectedCourseId,
          'courseName': _selectedCourseName,
          'sessionId': widget.sessionId,
        });

        setState(() {
          _status = 'Attendance marked Present for $bestMatchRegNumber (score: $bestScore)';
          _attendanceRecords[bestMatchRegNumber!] = {
            'regNumber': bestMatchRegNumber,
            'status': 'Present',
            'timestamp': DateTime.now(),
          };
          _scanning = false;
        });
      } catch (e) {
        setState(() {
          _status = 'Failed to mark attendance: $e';
          _scanning = false;
        });
        print('Firestore error: $e');
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

  Map<String, bool> _absentStudents = {};

  Future<void> _markAbsentStudents() async {
    if (_selectedCourseId == null) {
      setState(() {
        _status = 'Please select a course before marking absences.';
      });
      return;
    }

    final today = DateTime.now();
    final todayDateStr = "${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}";

    try {
      // Get all students who joined the course
      final joinedStudentsSnapshot = await FirebaseFirestore.instance
          .collection('instructor_courses')
          .doc(_selectedCourseId)
          .collection('students')
          .get();

      final joinedStudents = joinedStudentsSnapshot.docs.map((doc) => doc.id).toSet();

      // Get students who have attendance records today
      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('instructor_courses')
          .doc(_selectedCourseId)
          .collection('attendance')
          .where('timestamp', isGreaterThanOrEqualTo: DateTime(today.year, today.month, today.day))
          .get();

      final attendedStudents = attendanceSnapshot.docs.map((doc) => doc.id.split('_')[0]).toSet();

      // Students who joined but did not attend
      final absentStudents = joinedStudents.difference(attendedStudents);

      for (var regNumber in absentStudents) {
        final sanitizedRegNumber = regNumber.replaceAll('/', '_');
        final attendanceDocId = "${sanitizedRegNumber}_$todayDateStr";

        final attendanceDocRef = FirebaseFirestore.instance
            .collection('instructor_courses')
            .doc(_selectedCourseId)
            .collection('attendance')
            .doc(attendanceDocId);

        final attendanceDoc = await attendanceDocRef.get();

        if (!attendanceDoc.exists) {
          await attendanceDocRef.set({
            'regNumber': sanitizedRegNumber,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'Absent',
            'courseId': _selectedCourseId,
            'sessionId': widget.sessionId,
          });
        }
      }

      setState(() {
        _status = 'Absent students marked successfully.';
      });

      await _loadTodayAttendance();
    } catch (e) {
      setState(() {
        _status = 'Failed to mark absent students: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance Scanner'),
        backgroundColor: Colors.deepPurple,
        elevation: 4,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => InstructorDashboardPage()),
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _loadingCourses
                ? LinearProgressIndicator()
                : DropdownButtonFormField<String>(
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
                      _loadTodayAttendance();
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
            SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _markAbsentStudents,
              child: Text(
                'Mark Students Absent',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


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
  // ============ CONSTANTS ============
  static const int MATCH_THRESHOLD = 80; // Professional-grade threshold
  static const int DUPLICATE_SCAN_DEBOUNCE_MS = 3000; // 3-second debounce
  
  // ============ FINGERPRINT SDK ============
  final FingerprintSdk _fingerprintSdk = FingerprintSdk();

  // ============ UI STATE ============
  String _status = 'Idle';
  bool _continuousScanning = false;
  bool _deviceOpened = false;
  Uint8List? _currentTemplate;

  // ============ COURSE & SESSION MANAGEMENT ============
  String? _selectedCourseId;
  List<Map<String, dynamic>> _courses = [];
  String _selectedCourseName = '';
  String _selectedSessionName = '';
  bool _loadingCourses = true;

  // ============ SESSION STATE ============
  String? _activeSessionId;
  bool _sessionActive = false;
  DateTime? _sessionStartTime;
  String _attendanceMode = 'CHECK_IN'; // 'CHECK_IN' or 'CHECK_OUT'

  // ============ ATTENDANCE DATA ============
  Map<String, String> _students = {}; // regNumber -> base64 fingerprint template
  Map<String, Map<String, dynamic>> _checkedInStudents = {}; // regNumber -> check-in/out data
  Map<String, Map<String, dynamic>> _checkedOutStudents = {}; // regNumber -> check-out data
  Map<String, DateTime> _lastScanTime = {}; // regNumber -> last scan timestamp (for debouncing)

  // ============ QUALITY FEEDBACK ============
  String _lastMatchedStudent = '';
  int _lastMatchScore = -1;

  @override
  void initState() {
    super.initState();
    _setupFingerprintListeners();
    _loadCourses();
    _loadRegisteredStudents();
  }

  void _setupFingerprintListeners() {
    _fingerprintSdk.statusStream.listen((status) {
      if (!mounted) return;
      setState(() {
        _status = status;
        if (status == 'Open Device OK') {
          _deviceOpened = true;
        } else if (status == 'Close Device' || status == 'Device Detached - Closed') {
          _deviceOpened = false;
          _currentTemplate = null;
          _continuousScanning = false;
        }
      });
    });

    _fingerprintSdk.templateStream.listen((template) {
      if (!mounted) return;
      setState(() {
        _currentTemplate = template;
        _status = 'Fingerprint template captured';
      });
      if (_currentTemplate != null && _sessionActive) {
        _processAttendance(_currentTemplate!);
      }
    });

    _fingerprintSdk.errorStream.listen((error) {
      if (!mounted) return;
      setState(() {
        _status = 'Error: $error';
        _continuousScanning = false;
      });
    });
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
        await _loadSelectedCourseDetails(_selectedCourseId!);
      }
    } catch (e) {
      setState(() {
        _status = 'Failed to load courses: $e';
        _loadingCourses = false;
      });
    }
  }

  Future<void> _loadSelectedCourseDetails(String courseId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('instructor_courses')
          .doc(courseId)
          .get();
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

  // ============ SESSION MANAGEMENT ============
  
  Future<void> _startSession() async {
    if (_selectedCourseId == null) {
      setState(() {
        _status = 'Please select a course first';
      });
      return;
    }

    // Open device if not already open
    if (!_deviceOpened) {
      try {
        await _fingerprintSdk.openDevice();
        setState(() {
          _deviceOpened = true;
          _status = 'Device opened, starting session...';
        });
      } catch (e) {
        setState(() {
          _status = 'Failed to open device: $e';
        });
        return;
      }
    }

    try {
      // Create new attendance session
      final sessionRef = FirebaseFirestore.instance
          .collection('instructor_courses')
          .doc(_selectedCourseId)
          .collection('attendance_sessions')
          .doc();

      await sessionRef.set({
        'sessionId': sessionRef.id,
        'startTime': FieldValue.serverTimestamp(),
        'endTime': null,
        'status': 'ACTIVE',
        'courseName': _selectedCourseName,
        'sessionName': _selectedSessionName,
      });

      setState(() {
        _activeSessionId = sessionRef.id;
        _sessionActive = true;
        _sessionStartTime = DateTime.now();
        _checkedInStudents = {};
        _checkedOutStudents = {};
        _lastScanTime = {};
        _attendanceMode = 'CHECK_IN'; // Reset to check-in mode
        _continuousScanning = true;
        _status = '✅ Session Active - Ready for CHECK-IN. Students scan now.';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to start session: $e';
      });
    }
  }

  Future<void> _stopSession() async {
    if (_activeSessionId == null || _selectedCourseId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('instructor_courses')
          .doc(_selectedCourseId)
          .collection('attendance_sessions')
          .doc(_activeSessionId)
          .update({
            'endTime': FieldValue.serverTimestamp(),
            'status': 'CLOSED',
            'attendanceCount': _checkedInStudents.length,
          });

      // Mark absent students with -10% penalty
      await _markAbsentStudents();

      setState(() {
        _sessionActive = false;
        _continuousScanning = false;
        _activeSessionId = null;
        _status = '✅ Session closed. ${_checkedInStudents.length} students marked present, absent students marked with -10%.';
      });

      // Keep device open for potential new sessions
    } catch (e) {
      setState(() {
        _status = 'Failed to close session: $e';
      });
    }
  }

  // ============ CONTINUOUS SCANNING ============

  Future<void> _startContinuousScanning() async {
    if (!_sessionActive) {
      setState(() {
        _status = 'Please start a session first';
      });
      return;
    }

    if (!_deviceOpened) {
      setState(() {
        _status = 'Device not opened';
      });
      return;
    }

    setState(() {
      _continuousScanning = true;
      _status = '🔄 Continuous scanning... Place finger on scanner';
    });

    try {
      await _fingerprintSdk.generateTemplate();
    } catch (e) {
      setState(() {
        _status = 'Failed to start scanning: $e';
        _continuousScanning = false;
      });
    }
  }

  void _pauseContinuousScanning() {
    setState(() {
      _continuousScanning = false;
      _status = '⏸️ Scanning paused. Click to resume or close session.';
    });
  }

  // ============ ATTENDANCE PROCESSING ============

  void _processAttendance(Uint8List scannedTemplate) async {
    if (!_sessionActive || _selectedCourseId == null || _activeSessionId == null) {
      return;
    }

    int bestScore = -1;
    String bestMatchRegNumber = '';

    // Match against all enrolled students
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
        // Continue matching other students
      }
    }

    // Check if match meets threshold
    if (bestScore < MATCH_THRESHOLD || bestMatchRegNumber.isEmpty) {
      setState(() {
        _lastMatchScore = bestScore;
        _lastMatchedStudent = '';
        _status = bestScore >= 0 
            ? '❌ Weak match (Score: $bestScore). Try again.' 
            : '❌ No fingerprint recognized';
      });
      
      // Continue scanning if in continuous mode
      if (_continuousScanning) {
        await Future.delayed(Duration(milliseconds: 500));
        try {
          await _fingerprintSdk.generateTemplate();
        } catch (e) {
          // Error already handled
        }
      }
      return;
    }

    final sanitizedRegNumber = bestMatchRegNumber.replaceAll('/', '_');

    // Check for duplicate scan (debounce)
    if (_lastScanTime.containsKey(sanitizedRegNumber)) {
      final timeSinceLastScan = DateTime.now()
          .difference(_lastScanTime[sanitizedRegNumber]!)
          .inMilliseconds;
      
      if (timeSinceLastScan < DUPLICATE_SCAN_DEBOUNCE_MS) {
        setState(() {
          _status = '⚠️ Duplicate scan detected. Wait ${((DUPLICATE_SCAN_DEBOUNCE_MS - timeSinceLastScan) / 1000).toStringAsFixed(1)}s';
          _lastMatchScore = bestScore;
          _lastMatchedStudent = bestMatchRegNumber;
        });
        
        if (_continuousScanning) {
          await Future.delayed(Duration(milliseconds: 500));
          try {
            await _fingerprintSdk.generateTemplate();
          } catch (e) {
            // Error already handled
          }
        }
        return;
      }
    }

    // Check if student enrolled in course
    try {
      final joinedStudent = await FirebaseFirestore.instance
          .collection('instructor_courses')
          .doc(_selectedCourseId)
          .collection('students')
          .doc(sanitizedRegNumber)
          .get();

      if (!joinedStudent.exists) {
        setState(() {
          _status = '❌ Student not enrolled in this course';
          _lastMatchScore = bestScore;
          _lastMatchedStudent = bestMatchRegNumber;
        });
        
        if (_continuousScanning) {
          await Future.delayed(Duration(milliseconds: 500));
          try {
            await _fingerprintSdk.generateTemplate();
          } catch (e) {
            // Error already handled
          }
        }
        return;
      }

      // Record check-in or check-out based on current mode
      if (_attendanceMode == 'CHECK_IN') {
        // Check if student has already checked in today
        final existingCheckIn = await FirebaseFirestore.instance
            .collection('instructor_courses')
            .doc(_selectedCourseId)
            .collection('attendance_sessions')
            .doc(_activeSessionId)
            .collection('students')
            .doc(sanitizedRegNumber)
            .get();

        if (existingCheckIn.exists && existingCheckIn.data()!.containsKey('checkInTime')) {
          setState(() {
            _status = '⏳ ${bestMatchRegNumber} has ALREADY CHECKED IN. Wait for check-out time.';
            _lastMatchScore = bestScore;
            _lastMatchedStudent = bestMatchRegNumber;
          });
          
          if (_continuousScanning) {
            await Future.delayed(Duration(milliseconds: 500));
            try {
              await _fingerprintSdk.generateTemplate();
            } catch (e) {
              // Error already handled
            }
          }
          return;
        }

        // Get course details to calculate percentage dynamically
        final courseDoc = await FirebaseFirestore.instance
            .collection('instructor_courses')
            .doc(_selectedCourseId)
            .get();
        
        final totalDays = (courseDoc.data()?['totalDays'] as int?) ?? 10;
        final percentagePerDay = 100.0 / totalDays; // Dynamic: 10% for 10 days, 6.67% for 15, 5% for 20
        final checkInPercentage = percentagePerDay / 2; // Half for check-in

        await FirebaseFirestore.instance
            .collection('instructor_courses')
            .doc(_selectedCourseId)
            .collection('attendance_sessions')
            .doc(_activeSessionId)
            .collection('students')
            .doc(sanitizedRegNumber)
            .set({
              'regNumber': sanitizedRegNumber,
              'checkInTime': FieldValue.serverTimestamp(),
              'checkInPercentage': checkInPercentage, // Dynamic percentage
              'matchScore': bestScore,
              'status': 'PRESENT',
              'matchQuality': _getQualityLevel(bestScore),
            }, SetOptions(merge: true));

        // Update local state for check-in
        setState(() {
          _checkedInStudents[sanitizedRegNumber] = {
            'regNumber': bestMatchRegNumber,
            'checkInTime': DateTime.now(),
            'matchScore': bestScore,
          };
          _lastScanTime[sanitizedRegNumber] = DateTime.now();
          _lastMatchScore = bestScore;
          _lastMatchedStudent = bestMatchRegNumber;
          _status = '✅ ${bestMatchRegNumber} CHECKED IN (Score: $bestScore)';
        });
      } else if (_attendanceMode == 'CHECK_OUT') {
        // Check if student has already checked out today
        final existingCheckOut = await FirebaseFirestore.instance
            .collection('instructor_courses')
            .doc(_selectedCourseId)
            .collection('attendance_sessions')
            .doc(_activeSessionId)
            .collection('students')
            .doc(sanitizedRegNumber)
            .get();

        if (existingCheckOut.exists && existingCheckOut.data()!.containsKey('checkOutTime')) {
          setState(() {
            _status = '⏳ ${bestMatchRegNumber} has ALREADY CHECKED OUT. Cannot check out twice.';
            _lastMatchScore = bestScore;
            _lastMatchedStudent = bestMatchRegNumber;
          });
          
          if (_continuousScanning) {
            await Future.delayed(Duration(milliseconds: 500));
            try {
              await _fingerprintSdk.generateTemplate();
            } catch (e) {
              // Error already handled
            }
          }
          return;
        }

        if (!existingCheckOut.exists || !existingCheckOut.data()!.containsKey('checkInTime')) {
          setState(() {
            _status = '❌ ${bestMatchRegNumber} must CHECK IN before checking out.';
            _lastMatchScore = bestScore;
            _lastMatchedStudent = bestMatchRegNumber;
          });
          
          if (_continuousScanning) {
            await Future.delayed(Duration(milliseconds: 500));
            try {
              await _fingerprintSdk.generateTemplate();
            } catch (e) {
              // Error already handled
            }
          }
          return;
        }

        // Get course details to calculate percentage dynamically
        final courseDoc = await FirebaseFirestore.instance
            .collection('instructor_courses')
            .doc(_selectedCourseId)
            .get();
        
        final totalDays = (courseDoc.data()?['totalDays'] as int?) ?? 10;
        final percentagePerDay = 100.0 / totalDays; // Dynamic: 10% for 10 days, 6.67% for 15, 5% for 20
        final checkOutPercentage = percentagePerDay / 2; // Half for check-out
        final totalDayPercentage = percentagePerDay; // Full percentage for the day

        await FirebaseFirestore.instance
            .collection('instructor_courses')
            .doc(_selectedCourseId)
            .collection('attendance_sessions')
            .doc(_activeSessionId)
            .collection('students')
            .doc(sanitizedRegNumber)
            .set({
              'checkOutTime': FieldValue.serverTimestamp(),
              'checkOutPercentage': checkOutPercentage, // Dynamic percentage
              'totalDayPercentage': totalDayPercentage, // Dynamic total for day
              'checkOutScore': bestScore,
              'checkOutQuality': _getQualityLevel(bestScore),
            }, SetOptions(merge: true));

        // Update local state for check-out
        setState(() {
          _checkedOutStudents[sanitizedRegNumber] = {
            'regNumber': bestMatchRegNumber,
            'checkOutTime': DateTime.now(),
            'matchScore': bestScore,
          };
          _lastScanTime[sanitizedRegNumber] = DateTime.now();
          _lastMatchScore = bestScore;
          _lastMatchedStudent = bestMatchRegNumber;
          _status = '👋 ${bestMatchRegNumber} CHECKED OUT (Score: $bestScore)';
        });
      }

      // Continue scanning if in continuous mode
      if (_continuousScanning) {
        await Future.delayed(Duration(milliseconds: 500));
        try {
          await _fingerprintSdk.generateTemplate();
        } catch (e) {
          // Error already handled
        }
      }
    } catch (e) {
      setState(() {
        _status = '❌ Error recording attendance: $e';
        _lastMatchScore = bestScore;
        _lastMatchedStudent = bestMatchRegNumber;
      });
    }
  }

  // ============ HELPER METHODS ============

  /// Calculate student's current attendance percentage for the course
  Future<double> _calculateStudentAttendancePercentage(String studentRegNumber) async {
    if (_selectedCourseId == null) return 0.0;

    try {
      // Get course details for total days
      final courseDoc = await FirebaseFirestore.instance
          .collection('instructor_courses')
          .doc(_selectedCourseId)
          .get();

      if (!courseDoc.exists) return 0.0;

      final totalDays = courseDoc.data()?['totalDays'] as int? ?? 1;

      // Get all attendance sessions for this student
      final sessionsSnapshot = await FirebaseFirestore.instance
          .collection('instructor_courses')
          .doc(_selectedCourseId)
          .collection('attendance_sessions')
          .get();

      double totalPercentage = 0.0;

      for (var session in sessionsSnapshot.docs) {
        final studentAttendanceDoc = await FirebaseFirestore.instance
            .collection('instructor_courses')
            .doc(_selectedCourseId)
            .collection('attendance_sessions')
            .doc(session.id)
            .collection('students')
            .doc(studentRegNumber)
            .get();

        if (studentAttendanceDoc.exists) {
          final data = studentAttendanceDoc.data();
          if (data != null && data.containsKey('totalDayPercentage')) {
            totalPercentage += (data['totalDayPercentage'] as num).toDouble();
          }
        }
      }

      // Calculate final percentage based on total days
      final attendancePercentage = totalDays > 0 ? (totalPercentage / totalDays) * 100 : 0.0;
      return attendancePercentage.clamp(0.0, 100.0);
    } catch (e) {
      return 0.0;
    }
  }

  String _getQualityLevel(int score) {
    if (score >= 90) return 'EXCELLENT';
    if (score >= 80) return 'GOOD';
    if (score >= 70) return 'FAIR';
    return 'WEAK';
  }

  Color _getQualityColor(int score) {
    if (score >= 85) return Colors.green;
    if (score >= 75) return Colors.orange;
    return Colors.red;
  }

  Future<void> _closeDevice() async {
    try {
      await _fingerprintSdk.closeDevice();
      setState(() {
        _status = 'Device closed';
        _deviceOpened = false;
        _continuousScanning = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to close device: $e';
      });
    }
  }

  Future<void> _markAbsentStudents() async {
    if (_selectedCourseId == null || _activeSessionId == null) {
      setState(() {
        _status = 'No active session to mark absences.';
      });
      return;
    }

    try {
      // Get course details for penalty calculation
      final courseDoc = await FirebaseFirestore.instance
          .collection('instructor_courses')
          .doc(_selectedCourseId)
          .get();
      
      final totalDays = (courseDoc.data()?['totalDays'] as int?) ?? 10;
      final percentagePerDay = 100.0 / totalDays; // Dynamic calculation
      final absentPenalty = -percentagePerDay; // Negative percentage for the day

      // Get all students who joined the course
      final joinedStudentsSnapshot = await FirebaseFirestore.instance
          .collection('instructor_courses')
          .doc(_selectedCourseId)
          .collection('students')
          .get();

      final joinedStudents = joinedStudentsSnapshot.docs.map((doc) => doc.id).toSet();
      final checkedInStudents = _checkedInStudents.keys.toSet();

      // Students who joined but did not check in
      final absentStudents = joinedStudents.difference(checkedInStudents);

      if (absentStudents.isEmpty) {
        setState(() {
          _status = 'No absent students to mark.';
        });
        return;
      }

      int markedCount = 0;
      for (var regNumber in absentStudents) {
        try {
          await FirebaseFirestore.instance
              .collection('instructor_courses')
              .doc(_selectedCourseId)
              .collection('attendance_sessions')
              .doc(_activeSessionId)
              .collection('students')
              .doc(regNumber)
              .set({
                'regNumber': regNumber,
                'status': 'ABSENT',
                'checkInPercentage': 0.0,
                'checkOutPercentage': 0.0,
                'totalDayPercentage': absentPenalty,  // Dynamic penalty based on totalDays
                'absentMarkedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
          markedCount++;
        } catch (e) {
          // Continue marking other absences
        }
      }

      setState(() {
        _status = '✅ Marked $markedCount absent students with penalty';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to mark absent students: $e';
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
        title: Text('Class Attendance - Fingerprint Scanner'),
        backgroundColor: Colors.deepPurple,
        elevation: 4,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            if (_sessionActive) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please close the session first')),
              );
              return;
            }
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const InstructorDashboardPage()),
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ============ COURSE SELECTION ============
            if (!_sessionActive)
              _loadingCourses
                  ? const LinearProgressIndicator()
                  : Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Course',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'Course',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
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
                                if (value != null) {
                                  _loadSelectedCourseDetails(value);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
            
            const SizedBox(height: 24),

            // ============ SESSION STATUS ============
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              color: _sessionActive ? Colors.green.shade50 : Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.fingerprint,
                          color: _deviceOpened ? Colors.green : Colors.red,
                          size: 40,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Session Status',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _sessionActive
                                    ? '✅ ACTIVE - Students scanning...'
                                    : '⏹️ No active session',
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      _sessionActive ? Colors.green : Colors.grey.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Students Checked In: ${_checkedInStudents.length}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ============ STATUS MESSAGE ============
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: _lastMatchScore >= MATCH_THRESHOLD
                  ? Colors.green.shade50
                  : _lastMatchScore >= 70
                      ? Colors.orange.shade50
                      : Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scanner Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: TextStyle(
                        fontSize: 16,
                        color: _sessionActive
                            ? Colors.black87
                            : Colors.grey.shade700,
                        height: 1.5,
                      ),
                    ),
                    if (_lastMatchScore >= 0 && _lastMatchedStudent.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Last Match: $_lastMatchedStudent',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getQualityColor(_lastMatchScore),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Score: $_lastMatchScore',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ============ CONTROL BUTTONS ============
            if (!_sessionActive)
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('START SESSION',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _selectedCourseId == null ? null : _startSession,
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: _continuousScanning
                          ? const Icon(Icons.pause)
                          : const Icon(Icons.fingerprint),
                      label: Text(
                        _continuousScanning ? 'PAUSE' : 'SCAN',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _continuousScanning
                            ? Colors.orange
                            : Colors.deepPurple,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _deviceOpened
                          ? (_continuousScanning
                              ? _pauseContinuousScanning
                              : _startContinuousScanning)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.stop),
                      label: const Text(
                        'CLOSE',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _stopSession,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // ============ CHECK-IN / CHECK-OUT MODE TOGGLE ============
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text('CHECK-IN MODE',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _attendanceMode == 'CHECK_IN'
                            ? Colors.blue
                            : Colors.grey,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        setState(() {
                          _attendanceMode = 'CHECK_IN';
                          _status = '👉 Switched to CHECK-IN mode. Students scan now.';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('CHECK-OUT MODE',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _attendanceMode == 'CHECK_OUT'
                            ? Colors.deepOrange
                            : Colors.grey,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        setState(() {
                          _attendanceMode = 'CHECK_OUT';
                          _status = '👉 Switched to CHECK-OUT mode. Students scan to check out.';
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.power_off),
              label: const Text('CLOSE DEVICE',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _closeDevice,
            ),

            const SizedBox(height: 24),

            // ============ ATTENDANCE SUMMARY ============
            Row(
              children: [
                if (_checkedInStudents.isNotEmpty)
                  Expanded(
                    child: Card(
                      elevation: 4,
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            const Icon(Icons.login, color: Colors.blue, size: 24),
                            const SizedBox(height: 8),
                            Text(
                              'Checked In',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_checkedInStudents.length}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_checkedInStudents.isNotEmpty && _checkedOutStudents.isNotEmpty)
                  const SizedBox(width: 12),
                if (_checkedOutStudents.isNotEmpty)
                  Expanded(
                    child: Card(
                      elevation: 4,
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            const Icon(Icons.logout, color: Colors.deepOrange, size: 24),
                            const SizedBox(height: 8),
                            Text(
                              'Checked Out',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_checkedOutStudents.length}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 24),

            // ============ CHECKED-IN STUDENTS LIST ============
            if (_checkedInStudents.isNotEmpty)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Checked In (${_checkedInStudents.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      ..._checkedInStudents.entries.map((entry) {
                        final regNumber = entry.key;
                        final data = entry.value;
                        final score = data['matchScore'] as int? ?? -1;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(regNumber,
                                    style: const TextStyle(fontSize: 14)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getQualityColor(score),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Score: $score',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // ============ CHECKED-OUT STUDENTS LIST ============
            if (_checkedOutStudents.isNotEmpty)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Checked Out (${_checkedOutStudents.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      ..._checkedOutStudents.entries.map((entry) {
                        final regNumber = entry.key;
                        final data = entry.value;
                        final score = data['matchScore'] as int? ?? -1;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Icon(Icons.exit_to_app,
                                  color: Colors.deepOrange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(regNumber,
                                    style: const TextStyle(fontSize: 14)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getQualityColor(score),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Score: $score',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

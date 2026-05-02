import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'fingerprint_sdk.dart';
import 'widgets/student_payment_card.dart'; // NEW: Import student payment card

class InvigilatorAttendancePage extends StatefulWidget {
  const InvigilatorAttendancePage({Key? key}) : super(key: key);

  @override
  _InvigilatorAttendancePageState createState() => _InvigilatorAttendancePageState();
}

class _InvigilatorAttendancePageState extends State<InvigilatorAttendancePage> {
  // ============ CONSTANTS ============
  static const int MATCH_THRESHOLD = 80; // Professional threshold
  static const int DUPLICATE_SCAN_DEBOUNCE_MS = 3000;

  // ============ FINGERPRINT SDK ============
  final FingerprintSdk _fingerprintSdk = FingerprintSdk();

  // ============ UI STATE ============
  String _status = 'Idle';
  bool _continuousScanning = false;
  bool _deviceOpened = false;
  Uint8List? _currentTemplate;

  // ============ ACTIVITY SELECTION ============
  String? _selectedActivity;
  String? _selectedCourseId;
  String? _selectedScheduledActivityId;

  List<String> _activities = ['CAT', 'EXAM', 'CONFERENCE'];
  List<Map<String, dynamic>> _scheduledActivities = [];

  // ============ SESSION STATE (For CONFERENCE only) ============
  bool _sessionActive = false;
  String? _activeSessionId;
  String _sessionType = 'CHECK_IN'; // CHECK_IN, PAUSE, CHECK_OUT
  Map<String, DateTime> _lastScanTime = {};

  // ============ ATTENDANCE DATA ============
  Map<String, String> _students = {}; // regNumber -> base64 fingerprint template
  Map<String, Map<String, dynamic>> _attendedStudents = {}; // regNumber -> attendance data
  int _lastMatchScore = -1;

  @override
  void initState() {
    super.initState();
    _setupFingerprintListeners();
    _loadActivities();
    _loadScheduledActivities();
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
      if (_currentTemplate != null) {
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

  void _loadActivities() {
    setState(() {
      _selectedActivity = _activities.first;
    });
  }

  Future<void> _loadScheduledActivities() async {
    try {
      final now = DateTime.now();
      List<Map<String, dynamic>> activities = [];

      // Load CAT and EXAM from scheduled_activities
      final catExamSnapshot = await FirebaseFirestore.instance
          .collection('scheduled_activities')
          .where('status', isEqualTo: 'scheduled')
          .where('activityType', whereIn: ['CAT', 'EXAM'])
          .get();

      final catExamActivities = catExamSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'courseId': data['courseId'] ?? '',
          'courseName': data['courseName'] ?? '',
          'activityType': data['activityType'] ?? '',
          'scheduledDate': data['scheduledDate']?.toDate(),
          'startTime': data['startTime'] ?? '',
          'endTime': data['endTime'] ?? '',
          'status': data['status'] ?? 'scheduled',
          'source': 'scheduled_activities', // Mark source
        };
      }).toList();

      // Filter available CAT/EXAM activities
      final availableCatExam = catExamActivities.where((activity) {
        if (activity['endTime'].isEmpty) return true;
        try {
          final scheduledDate = activity['scheduledDate'];
          final endTime = activity['endTime'];
          if (scheduledDate == null || endTime.isEmpty) return true;

          final timeParts = endTime.split(':');
          if (timeParts.length != 2) return true;

          final endHour = int.parse(timeParts[0]);
          final endMinute = int.parse(timeParts[1]);
          final endDateTime = DateTime(scheduledDate.year, scheduledDate.month,
              scheduledDate.day, endHour, endMinute);

          return now.isBefore(endDateTime) || now.isAtSameMomentAs(endDateTime);
        } catch (e) {
          return true;
        }
      }).toList();

      // Load CONFERENCE from conferences collection
      final conferencesSnapshot = await FirebaseFirestore.instance
          .collection('conferences')
          .get();

      final conferenceActivities = conferencesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'courseId': '', // Conferences don't have courseId
          'courseName': data['conferenceName'] ?? '',
          'activityType': 'CONFERENCE',
          'scheduledDate': data['startDate']?.toDate(),
          'endDate': data['endDate']?.toDate(),
          'startTime': '',
          'endTime': '',
          'status': 'scheduled',
          'source': 'conferences', // Mark source
        };
      }).toList();

      // Filter available conferences (ongoing or upcoming)
      final availableConferences = conferenceActivities.where((activity) {
        try {
          final startDate = activity['scheduledDate'];
          final endDate = activity['endDate'];
          if (startDate == null || endDate == null) return false;

          // Include ongoing and upcoming conferences
          return endDate.isAfter(now);
        } catch (e) {
          return false;
        }
      }).toList();

      // Combine all activities
      activities = [...availableCatExam, ...availableConferences];

      setState(() {
        _scheduledActivities = activities;
        if (_scheduledActivities.isNotEmpty) {
          _selectedScheduledActivityId = _scheduledActivities.first['id'];
          _selectedCourseId = _scheduledActivities.first['courseId'];
        } else {
          _selectedScheduledActivityId = null;
          _selectedCourseId = null;
        }
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to load scheduled activities: $e';
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

  // ============ SESSION MANAGEMENT (For CONFERENCE only) ============

  Future<void> _startConferenceSession() async {
    if (_selectedScheduledActivityId == null) {
      setState(() {
        _status = 'Please select a conference first';
      });
      return;
    }

    if (!_deviceOpened) {
      try {
        await _fingerprintSdk.openDevice();
        setState(() {
          _deviceOpened = true;
          _status = 'Device opened';
        });
      } catch (e) {
        setState(() {
          _status = 'Failed to open device: $e';
        });
        return;
      }
    }

    try {
      // Determine collection source based on selected activity
      final selectedActivity = _scheduledActivities.firstWhere(
        (a) => a['id'] == _selectedScheduledActivityId,
        orElse: () => {'source': 'conferences', 'courseName': ''},
      );
      final source = selectedActivity['source'] ?? 'conferences';
      final conferenceNameForDisplay = selectedActivity['courseName'] ?? 'Conference';

      final sessionRef = FirebaseFirestore.instance
          .collection(source)
          .doc(_selectedScheduledActivityId)
          .collection('attendance_sessions')
          .doc();

      await sessionRef.set({
        'sessionId': sessionRef.id,
        'type': 'CHECK_IN',
        'startTime': FieldValue.serverTimestamp(),
        'endTime': null,
        'status': 'ACTIVE',
      });

      setState(() {
        _activeSessionId = sessionRef.id;
        _sessionActive = true;
        _attendedStudents = {};
        _lastScanTime = {};
        _continuousScanning = true;
        _status = '✅ $conferenceNameForDisplay Check-In Session Active';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to start session: $e';
      });
    }
  }

  Future<void> _stopConferenceSession() async {
    if (_activeSessionId == null || _selectedScheduledActivityId == null) return;

    try {
      // Determine collection source
      final selectedActivity = _scheduledActivities.firstWhere(
        (a) => a['id'] == _selectedScheduledActivityId,
        orElse: () => {'source': 'conferences'},
      );
      final source = selectedActivity['source'] ?? 'conferences';

      await FirebaseFirestore.instance
          .collection(source)
          .doc(_selectedScheduledActivityId)
          .collection('attendance_sessions')
          .doc(_activeSessionId)
          .update({
            'endTime': FieldValue.serverTimestamp(),
            'status': 'CLOSED',
            'attendanceCount': _attendedStudents.length,
          });

      setState(() {
        _sessionActive = false;
        _continuousScanning = false;
        _activeSessionId = null;
        _sessionType = 'CHECK_IN';
        _status = '✅ Session closed. ${_attendedStudents.length} participants.';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to close session: $e';
      });
    }
  }

  // ============ CONFERENCE SESSION PHASE MANAGEMENT ============

  Future<void> _startCheckInPhase() async {
    setState(() {
      _sessionType = 'CHECK_IN';
      _continuousScanning = true;
      _status = '✅ CHECK-IN PHASE - Place finger on scanner';
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

  Future<void> _pauseSession() async {
    setState(() {
      _sessionType = 'PAUSE';
      _continuousScanning = false;
      _status = '⏸️ SESSION PAUSED - No scanning active';
    });
  }

  Future<void> _startCheckOutPhase() async {
    setState(() {
      _sessionType = 'CHECK_OUT';
      _continuousScanning = true;
      _status = '✅ CHECK-OUT PHASE - Place finger on scanner';
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

  Future<void> _startContinuousScanning() async {
    if (!_deviceOpened) {
      try {
        await _fingerprintSdk.openDevice();
        setState(() {
          _deviceOpened = true;
          _status = 'Device opened, ready to scan';
        });
      } catch (e) {
        setState(() {
          _status = 'Failed to open device: $e';
        });
        return;
      }
    }

    setState(() {
      _continuousScanning = true;
      _status = '🔄 Continuous scanning active - Place finger on scanner';
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

  // ============ ATTENDANCE PROCESSING ============

  void _processAttendance(Uint8List scannedTemplate) async {
    int bestScore = -1;
    String bestMatchRegNumber = '';

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
        // Continue matching
      }
    }

    if (bestScore < MATCH_THRESHOLD || bestMatchRegNumber.isEmpty) {
      setState(() {
        _lastMatchScore = bestScore;
        _status = bestScore >= 0
            ? '❌ Weak match (Score: $bestScore)'
            : '❌ No fingerprint recognized';
      });

      if (_continuousScanning) {
        await Future.delayed(const Duration(milliseconds: 500));
        try {
          await _fingerprintSdk.generateTemplate();
        } catch (e) {
          // Error already handled
        }
      }
      return;
    }

    final sanitizedRegNumber = bestMatchRegNumber.replaceAll('/', '_');

    // NEW: Fetch student data including payment info
    try {
      final studentSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .doc(sanitizedRegNumber)
          .get();

      if (studentSnapshot.exists) {
        final studentData = studentSnapshot.data() as Map<String, dynamic>;
        
        setState(() {
          _status = '✅ Student matched: ${studentData['name'] ?? 'Unknown'}';
        });

        // For CONFERENCE: Skip payment check and mark attendance directly
        if (_selectedActivity == 'CONFERENCE') {
          if (_sessionActive && _activeSessionId != null) {
            await _markConferenceAttendance(sanitizedRegNumber, bestMatchRegNumber, bestScore);
          }
        } else {
          // For CAT/EXAM: Show student card with payment validation
          _showStudentPaymentCard(studentData, sanitizedRegNumber, bestMatchRegNumber, bestScore);
        }
      } else {
        setState(() {
          _status = '❌ Student data not found';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error fetching student data: $e';
      });
    }

    // Continue scanning if continuous
    if (_continuousScanning) {
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        await _fingerprintSdk.generateTemplate();
      } catch (e) {
        // Error already handled
      }
    }
  }

  void _showStudentPaymentCard(Map<String, dynamic> studentData, String sanitizedRegNumber,
      String regNumber, int score) {
    final studentName = studentData['name'] ?? 'Unknown';
    final department = studentData['department'] ?? 'Unknown';
    final dueBalance = (studentData['dueBalance'] ?? 0).toDouble();
    final paymentStatus = studentData['paymentStatus'] ?? 'CLEARED';

    // Calculate attendance percentage for the course
    _calculateCourseAttendancePercentage(sanitizedRegNumber).then((percentage) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => StudentPaymentCard(
          studentName: studentName,
          regNumber: regNumber,
          department: department,
          dueBalance: dueBalance,
          paymentStatus: paymentStatus,
          attendancePercentage: percentage, // Pass calculated percentage
          onApprove: () {
            Navigator.pop(context);
            // Mark attendance only if approved
            if (_selectedActivity == 'CAT' || _selectedActivity == 'EXAM') {
              _markCAT_EXAMAttendance(sanitizedRegNumber, regNumber, score);
            } else if (_selectedActivity == 'CONFERENCE') {
              if (_sessionActive && _activeSessionId != null) {
                _markConferenceAttendance(sanitizedRegNumber, regNumber, score);
              }
            }
          },
          onCancel: () {
            Navigator.pop(context);
            setState(() {
              _status = '❌ Attendance marking cancelled';
            });
          },
        ),
      );
    });
  }

  /// Calculate student's current attendance percentage for the enrolled course
  Future<double> _calculateCourseAttendancePercentage(String studentRegNumber) async {
    if (_selectedCourseId == null) return 0.0;

    try {
      // Get all attendance sessions for this student in the course
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
          if (data != null) {
            // Use totalDayPercentage if available, otherwise calculate from components
            if (data.containsKey('totalDayPercentage')) {
              totalPercentage += (data['totalDayPercentage'] as num).toDouble();
            } else if (data.containsKey('checkInPercentage') || data.containsKey('checkOutPercentage')) {
              // Fallback: sum check-in and check-out percentages
              final checkInPct = (data['checkInPercentage'] as num?)?.toDouble() ?? 0.0;
              final checkOutPct = (data['checkOutPercentage'] as num?)?.toDouble() ?? 0.0;
              totalPercentage += checkInPct + checkOutPct;
            } else if (data['status'] == 'ABSENT') {
              // If it's absent without percentages, apply the penalty
              totalPercentage -= (100.0 / (await FirebaseFirestore.instance
                  .collection('instructor_courses')
                  .doc(_selectedCourseId)
                  .get()
                  .then((doc) => (doc.data()?['totalDays'] as int?) ?? 10)));
            }
          }
        }
      }

      // Return the accumulated percentage (already in percentage form, not divided by days)
      return totalPercentage < 0 ? 0.0 : (totalPercentage > 100 ? 100.0 : totalPercentage);
    } catch (e) {
      return 0.0;
    }
  }

  Future<void> _markCAT_EXAMAttendance(
      String sanitizedRegNumber, String regNumber, int score) async {
    if (_selectedScheduledActivityId == null || _selectedCourseId == null) {
      setState(() {
        _status = 'No activity selected';
      });
      return;
    }

    try {
      // Record attendance directly (Firestore will handle duplicate prevention via client logic)
      await FirebaseFirestore.instance
          .collection('scheduled_activities')
          .doc(_selectedScheduledActivityId)
          .collection('attendance')
          .doc(sanitizedRegNumber) // Use regNumber as document ID to prevent duplicates
          .set({
            'regNumber': sanitizedRegNumber,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'PRESENT',
            'matchScore': score,
            'activityType': _selectedActivity,
            'courseId': _selectedCourseId,
          }, SetOptions(merge: true)); // merge: true allows updates without overwriting

      setState(() {
        _attendedStudents[sanitizedRegNumber] = {
          'regNumber': regNumber,
          'timestamp': DateTime.now(),
          'matchScore': score,
        };
        _lastMatchScore = score;
        _status = '✅ $regNumber marked present (Score: $score)';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to record attendance: $e';
        _lastMatchScore = score;
      });
    }
  }

  Future<void> _markConferenceAttendance(
      String sanitizedRegNumber, String regNumber, int score) async {
    try {
      // Check for duplicate scan (debounce)
      if (_lastScanTime.containsKey(sanitizedRegNumber)) {
        final timeSinceLastScan = DateTime.now()
            .difference(_lastScanTime[sanitizedRegNumber]!)
            .inMilliseconds;

        if (timeSinceLastScan < DUPLICATE_SCAN_DEBOUNCE_MS) {
          setState(() {
            _status = '⚠️ Duplicate scan. Wait...';
            _lastMatchScore = score;
          });
          return;
        }
      }

      // Get student information (department, enrolled courses)
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(sanitizedRegNumber)
          .get();

      String studentDepartment = '';
      String studentName = '';
      String studentSession = '';
      List<String> enrolledCourses = [];

      if (studentDoc.exists) {
        final studentData = studentDoc.data() as Map<String, dynamic>;
        studentDepartment = studentData['department'] ?? '';
        studentName = studentData['name'] ?? ''; // Get actual student name from student document
        studentSession = studentData['session'] ?? ''; // Get student session (Day, Evening, Weekend)

        // Get enrolled courses from instructor_courses collection
        // Query all instructor courses and check if student is enrolled in each
        try {
          final allCoursesSnapshot = await FirebaseFirestore.instance
              .collection('instructor_courses')
              .get();

          for (var courseDoc in allCoursesSnapshot.docs) {
            // Check if this student is in this course's students subcollection
            final studentInCourseDoc = await FirebaseFirestore.instance
                .collection('instructor_courses')
                .doc(courseDoc.id)
                .collection('students')
                .doc(sanitizedRegNumber)
                .get();

            if (studentInCourseDoc.exists) {
              final courseName = courseDoc.data()['courseName'] ?? courseDoc.id;
              enrolledCourses.add(courseName);
            }
          }
        } catch (e) {
          // If course lookup fails, just continue without courses
          // This won't block attendance marking
        }
      }

      // Determine collection source
      final selectedActivity = _scheduledActivities.firstWhere(
        (a) => a['id'] == _selectedScheduledActivityId,
        orElse: () => {'source': 'conferences'},
      );
      final source = selectedActivity['source'] ?? 'conferences';

      // Generate date-based document ID to preserve multi-day attendance records
      // Format: regNumber_YYYY-MM-DD (e.g., "STU001_2025-12-06")
      final now = DateTime.now();
      final dateString = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final documentId = '${sanitizedRegNumber}_$dateString';

      // Prepare attendance update based on session type
      Map<String, dynamic> updateData = {
        'regNumber': sanitizedRegNumber,
        'studentName': studentName,
        'department': studentDepartment,
        'session': studentSession, // Store student's session (Day, Evening, Weekend)
        'enrolledCourses': enrolledCourses,
        'matchScore': score,
        'sessionId': _activeSessionId,
      };

      if (_sessionType == 'CHECK_IN') {
        updateData['checkInTime'] = FieldValue.serverTimestamp();
        updateData['status'] = 'CHECKED_IN';
      } else if (_sessionType == 'CHECK_OUT') {
        updateData['checkOutTime'] = FieldValue.serverTimestamp();
        updateData['status'] = 'CHECKED_IN_OUT'; // Both check-in and check-out done
      }

      // Record attendance with date-based ID to prevent overwriting previous days
      await FirebaseFirestore.instance
          .collection(source)
          .doc(_selectedScheduledActivityId)
          .collection('attendance')
          .doc(documentId)
          .set(updateData, SetOptions(merge: true));

      setState(() {
        _attendedStudents[sanitizedRegNumber] = {
          'regNumber': regNumber,
          'timestamp': DateTime.now(),
          'matchScore': score,
          'department': studentDepartment,
          'sessionType': _sessionType,
        };
        _lastScanTime[sanitizedRegNumber] = DateTime.now();
        _lastMatchScore = score;
        
        if (_sessionType == 'CHECK_IN') {
          _status = '✅ $regNumber checked in (Score: $score)';
        } else if (_sessionType == 'CHECK_OUT') {
          _status = '✅ $regNumber checked out (Score: $score)';
        }
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to record attendance: $e';
        _lastMatchScore = score;
      });
    }
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

  @override
  void dispose() {
    _fingerprintSdk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invigilator Attendance System'),
        backgroundColor: Colors.deepPurple,
        elevation: 4,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ============ ACTIVITY TYPE SELECTION ============
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activity Type',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Select Activity',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
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
                          _attendedStudents = {};
                          _lastScanTime = {};
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ============ SCHEDULED ACTIVITY SELECTION ============
            if (_selectedActivity != null) ...[
              Builder(
                builder: (context) {
                  final activitiesForType = _scheduledActivities
                      .where((activity) => activity['activityType'] == _selectedActivity)
                      .toList();
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedActivity == 'CONFERENCE'
                                    ? 'Select Conference'
                                    : 'Select $_selectedActivity Activity',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              if (activitiesForType.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    border: Border.all(color: Colors.red.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'No available $_selectedActivity activities',
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    labelText: 'Scheduled Activity',
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                  ),
                                  value: _selectedScheduledActivityId,
                                  items: activitiesForType
                                      .map((activity) {
                                    return DropdownMenuItem<String>(
                                      value: activity['id'],
                                      child: Text(activity['courseName']),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedScheduledActivityId = value;
                                      if (value != null) {
                                        final selectedActivity =
                                            _scheduledActivities.firstWhere(
                                          (activity) => activity['id'] == value,
                                        );
                                        _selectedCourseId =
                                            selectedActivity['courseId'];
                                      }
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],

            const SizedBox(height: 24),

            // ============ SESSION STATUS ============
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              color: _selectedActivity == 'CONFERENCE' && _sessionActive
                  ? Colors.green.shade50
                  : Colors.grey.shade50,
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
                                'Device & Session Status',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _selectedActivity == 'CONFERENCE'
                                    ? (_sessionActive
                                        ? '✅ CONFERENCE SESSION ACTIVE'
                                        : '⏹️ No active session')
                                    : (_deviceOpened
                                        ? '✅ Device Ready'
                                        : '⏹️ Device Closed'),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: (_selectedActivity == 'CONFERENCE'
                                          ? _sessionActive
                                          : _deviceOpened)
                                      ? Colors.green
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Attendance Recorded: ${_attendedStudents.length}',
                      style: const TextStyle(
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
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ============ CONTROL BUTTONS ============
            if (_selectedActivity != 'CONFERENCE') ...[
              // Check if activities exist for selected type
              Builder(
                builder: (context) {
                  final activitiesForType = _scheduledActivities
                      .where((activity) => activity['activityType'] == _selectedActivity)
                      .toList();
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (activitiesForType.isEmpty)
                        Card(
                          elevation: 2,
                          color: Colors.orange.shade50,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Icon(Icons.warning, color: Colors.orange.shade700),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'No ${_selectedActivity} activities available',
                                    style: TextStyle(
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (activitiesForType.isEmpty)
                        const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('SCAN FINGERPRINT',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedScheduledActivityId != null && activitiesForType.isNotEmpty
                              ? Colors.deepPurple
                              : Colors.grey.shade400,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _selectedScheduledActivityId != null && activitiesForType.isNotEmpty
                            ? _startContinuousScanning
                            : null,
                      ),
                    ],
                  );
                },
              ),
            ] else ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('START CONFERENCE SESSION',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: (!_sessionActive && _selectedScheduledActivityId != null)
                    ? _startConferenceSession
                    : null,
              ),
              const SizedBox(height: 12),
              if (_sessionActive) ...[
                // ============ SESSION PHASE BUTTONS ============
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.deepPurple, width: 2),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.purple.shade50,
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Conference Session Control',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.login),
                              label: const Text('CHECK-IN',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _sessionType == 'CHECK_IN' ? Colors.blue : Colors.grey.shade300,
                                foregroundColor: _sessionType == 'CHECK_IN' ? Colors.white : Colors.black,
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _sessionType != 'CHECK_IN' ? _startCheckInPhase : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.pause),
                              label: const Text('PAUSE',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _sessionType == 'PAUSE' ? Colors.orange : Colors.grey.shade300,
                                foregroundColor: _sessionType == 'PAUSE' ? Colors.white : Colors.black,
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _sessionType != 'PAUSE' ? _pauseSession : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.logout),
                              label: const Text('CHECK-OUT',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _sessionType == 'CHECK_OUT' ? Colors.teal : Colors.grey.shade300,
                                foregroundColor: _sessionType == 'CHECK_OUT' ? Colors.white : Colors.black,
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _sessionType != 'CHECK_OUT' ? _startCheckOutPhase : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.stop),
                  label: const Text('CLOSE SESSION',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _stopConferenceSession,
                ),
              ],
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

            // ============ ATTENDED STUDENTS LIST ============
            if (_attendedStudents.isNotEmpty)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance Recorded (${_attendedStudents.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      ..._attendedStudents.entries.map((entry) {
                        final regNumber = entry.key;
                        final data = entry.value;
                        final score = data['matchScore'] as int? ?? -1;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
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
                                  color: score >= 85
                                      ? Colors.green
                                      : score >= 75
                                          ? Colors.orange
                                          : Colors.red,
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


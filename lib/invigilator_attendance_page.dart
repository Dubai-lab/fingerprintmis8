import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  DateTime? _selectedConferenceDate;
  String? _selectedScheduledActivityId;

  List<String> _activities = ['CAT', 'EXAM', 'CONFERENCE'];
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _scheduledActivities = [];

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
    _loadScheduledActivities();
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
      final now = DateTime.now();

      // For CAT and EXAM, get courses with attendance already marked today for the selected activity
      List<String> excludedCourseIds = [];
      if (_selectedActivity == 'CAT' || _selectedActivity == 'EXAM') {
        final attendanceSnapshot = await FirebaseFirestore.instance
            .collection('invigilator_activities')
            .doc(_selectedActivity)
            .collection('attendance')
            .where('timestamp', isGreaterThanOrEqualTo: DateTime(now.year, now.month, now.day))
            .get();

        excludedCourseIds = attendanceSnapshot.docs
            .map((doc) => doc.data()['courseId'] as String?)
            .where((courseId) => courseId != null)
            .cast<String>()
            .toSet()
            .toList();
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('instructor_courses')
          .where('endDate', isGreaterThan: now)
          .get();

      List<Map<String, dynamic>> filteredCourses = querySnapshot.docs
          .map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['courseName'] ?? 'Unnamed Course',
            };
          })
          .where((course) => !excludedCourseIds.contains(course['id']))
          .toList();

      setState(() {
        _courses = filteredCourses;
        if (_courses.isNotEmpty) {
          _selectedCourseId = _courses.first['id'];
        } else {
          _selectedCourseId = null;
        }
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to load courses: $e';
      });
    }
  }

  Future<void> _loadScheduledActivities() async {
    try {
      final now = DateTime.now();
      final querySnapshot = await FirebaseFirestore.instance
          .collection('scheduled_activities')
          .where('status', isEqualTo: 'scheduled')
          .get();

      final activities = querySnapshot.docs.map((doc) {
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
        };
      }).toList();

      // Filter out activities that are past their end time
      final availableActivities = activities.where((activity) {
        if (activity['endTime'].isEmpty) return true; // No end time set, keep it

        try {
          final scheduledDate = activity['scheduledDate'];
          final endTime = activity['endTime'];

          if (scheduledDate == null || endTime.isEmpty) return true;

          // Parse end time (format: "HH:mm")
          final timeParts = endTime.split(':');
          if (timeParts.length != 2) return true;

          final endHour = int.parse(timeParts[0]);
          final endMinute = int.parse(timeParts[1]);

          // Create end date time
          final endDateTime = DateTime(
            scheduledDate.year,
            scheduledDate.month,
            scheduledDate.day,
            endHour,
            endMinute,
          );

          // Keep activity if current time is before or at end time
          return now.isBefore(endDateTime) || now.isAtSameMomentAs(endDateTime);
        } catch (e) {
          // If there's an error parsing time, keep the activity
          return true;
        }
      }).toList();

      setState(() {
        _scheduledActivities = availableActivities;
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

  Future<void> _startScanning() async {
    // If device not opened, open it first
    if (!_deviceOpened) {
      setState(() {
        _scanning = true;
        _status = 'Opening device...';
        _deviceOpened = false;
      });

      try {
        await _fingerprintSdk.openDevice();
        setState(() {
          _status = 'Device ready. Place finger on scanner...';
          _deviceOpened = true;
        });
      } catch (e) {
        setState(() {
          _status = 'Failed to open device: $e';
          _scanning = false;
          _deviceOpened = false;
        });
        return;
      }
    }

    // Device is ready, start scanning immediately
    setState(() {
      _scanning = true;
      _status = 'Scanning fingerprint...';
    });

    try {
      await _fingerprintSdk.generateTemplate();
    } catch (e) {
      setState(() {
        _status = 'Failed to scan fingerprint: $e';
        _scanning = false;
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
          if (_selectedScheduledActivityId == null) {
            setState(() {
              _status = 'Please select a scheduled activity for CAT or EXAM attendance.';
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
          if (_selectedActivity == 'CONFERENCE' && _selectedConferenceDate != null)
            'conferenceDate': _selectedConferenceDate,
        });

        // Note: Activity status is managed by admin, not automatically updated by attendance

        setState(() {
          _status = 'Attendance marked Present for $bestMatchRegNumber (score: $bestScore) for $_selectedActivity';
          _scanning = false;
        });

        // Note: Activities remain available for multiple student attendance

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance marked successfully for $bestMatchRegNumber'),
            backgroundColor: Colors.green,
          ),
        );
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
              onChanged: (value) async {
                setState(() {
                  _selectedActivity = value;
                  if (_selectedActivity == 'CONFERENCE') {
                    _selectedCourseId = null;
                    _selectedScheduledActivityId = null;
                  }
                });
                if (_selectedActivity != 'CONFERENCE') {
                  await _loadScheduledActivities();
                }
              },
            ),
            SizedBox(height: 20),
            if (_selectedActivity == 'CONFERENCE')
              Column(
                children: [
                  TextButton(
                    onPressed: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          _selectedConferenceDate = pickedDate;
                        });
                      }
                    },
                    child: Text(
                      _selectedConferenceDate == null
                          ? 'Select Conference Date'
                          : 'Conference Date: ${_selectedConferenceDate!.year}-${_selectedConferenceDate!.month.toString().padLeft(2, '0')}-${_selectedConferenceDate!.day.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedConferenceDate == null ? Colors.deepPurple : Colors.black,
                      ),
                    ),
                  ),
                  if (_selectedConferenceDate == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Please select a conference date',
                        style: TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                ],
              ),
            if (_selectedActivity != 'CONFERENCE')
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Select Scheduled Activity',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                value: _selectedScheduledActivityId,
                items: _scheduledActivities
                    .where((activity) => activity['activityType'] == _selectedActivity)
                    .map((activity) {
                  return DropdownMenuItem<String>(
                    value: activity['id'],
                    child: Text('${activity['courseName']}'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedScheduledActivityId = value;
                    final selectedActivity = _scheduledActivities.firstWhere(
                      (activity) => activity['id'] == value,
                    );
                    _selectedCourseId = selectedActivity['courseId'];
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
              onPressed: _scanning || (_selectedActivity == 'CONFERENCE' && _selectedConferenceDate == null) || (_selectedActivity != 'CONFERENCE' && _selectedScheduledActivityId == null) ? null : _startScanning,
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

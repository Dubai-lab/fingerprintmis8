import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';

class AttendanceViewPage extends StatefulWidget {
  const AttendanceViewPage({Key? key}) : super(key: key);

  @override
  _AttendanceViewPageState createState() => _AttendanceViewPageState();
}

class _AttendanceViewPageState extends State<AttendanceViewPage> {
  String? _selectedCourseId;
  String? _selectedSession;
  List<Map<String, dynamic>> _courses = [];
  List<String> _sessions = [];
  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _loadingCourses = true;
  bool _loadingSessions = false;
  bool _loadingRecords = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadCourses();
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
          .get();

      final validCourses = querySnapshot.docs.where((doc) {
        final data = doc.data();
        final endDate = data['endDate'] as Timestamp?;
        // If endDate is null, we'll still show the course
        // Otherwise, only show if endDate is in the future
        return endDate == null || endDate.toDate().isAfter(now);
      }).toList();

      setState(() {
        _courses = validCourses.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['courseName'] ?? 'Unnamed Course',
            'session': data['session'] ?? 'Day',
          };
        }).toList();
        _loadingCourses = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to load courses: $e';
        _loadingCourses = false;
      });
    }
  }

  void _onCourseSelected(String? courseId) {
    setState(() {
      _selectedCourseId = courseId;
      _selectedSession = null;
      _sessions = [];
      _attendanceRecords = [];
      _loadingSessions = true;
      _loadingRecords = false;
      _status = '';
    });

    if (courseId != null) {
      final course = _courses.firstWhere((c) => c['id'] == courseId, orElse: () => {});
      if (course.isNotEmpty && course['session'] != null) {
        setState(() {
          _sessions = [course['session']];
          _loadingSessions = false;
        });
      } else {
        setState(() {
          _sessions = [];
          _loadingSessions = false;
        });
      }
    } else {
      setState(() {
        _sessions = [];
        _loadingSessions = false;
      });
    }
  }

  Future<void> _onSessionSelected(String? session) async {
    setState(() {
      _selectedSession = session;
      _attendanceRecords = [];
      _loadingRecords = true;
      _status = '';
    });

    if (_selectedCourseId != null && session != null) {
      try {
        // First, get all attendance sessions for this course
        final sessionsSnapshot = await FirebaseFirestore.instance
            .collection('instructor_courses')
            .doc(_selectedCourseId)
            .collection('attendance_sessions')
            .get();

        List<Map<String, dynamic>> allRecords = [];

        // For each attendance session, get all student attendance records
        for (var sessionDoc in sessionsSnapshot.docs) {
          final studentsSnapshot = await FirebaseFirestore.instance
              .collection('instructor_courses')
              .doc(_selectedCourseId)
              .collection('attendance_sessions')
              .doc(sessionDoc.id)
              .collection('students')
              .get();

          for (var studentDoc in studentsSnapshot.docs) {
            final data = studentDoc.data();
            // Get check-in or check-out time (whichever is latest)
            final checkInTime = data['checkInTime'] as Timestamp?;
            final checkOutTime = data['checkOutTime'] as Timestamp?;
            final timestamp = checkOutTime ?? checkInTime;
            
            // Get attendance percentages
            final checkInPercentage = data['checkInPercentage'] as num? ?? 0.0;
            final checkOutPercentage = data['checkOutPercentage'] as num? ?? 0.0;
            final totalDayPercentage = data['totalDayPercentage'] as num? ?? (checkInPercentage + checkOutPercentage);

            allRecords.add({
              'regNumber': data['regNumber'] ?? '',
              'status': data['status'] ?? 'PRESENT',
              'checkInTime': checkInTime,
              'checkOutTime': checkOutTime,
              'checkInPercentage': checkInPercentage,
              'checkOutPercentage': checkOutPercentage,
              'totalDayPercentage': totalDayPercentage,
              'timestamp': timestamp,
              'matchScore': data['matchScore'] ?? 0,
              'matchQuality': data['matchQuality'] ?? 'UNKNOWN',
            });
          }
        }

        // Sort by timestamp (most recent first)
        allRecords.sort((a, b) {
          final timestampA = (a['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
          final timestampB = (b['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
          return timestampB.compareTo(timestampA);
        });

        setState(() {
          _attendanceRecords = allRecords;
          _loadingRecords = false;
          if (_attendanceRecords.isEmpty) {
            _status = 'No attendance records found for selected course and session.';
          }
        });
      } catch (e) {
        setState(() {
          _status = 'Failed to load attendance records: $e';
          _loadingRecords = false;
        });
      }
    } else {
      setState(() {
        _loadingRecords = false;
      });
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final dateTime = (timestamp as Timestamp).toDate();
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _exportToCsv() async {
    if (_attendanceRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attendance records to export')),
      );
      return;
    }

    try {
      // Request storage permissions first
      var storageStatus = await Permission.storage.request();

      // For Android 11+ (API 30+), we need MANAGE_EXTERNAL_STORAGE for Downloads folder
      bool needsManageStorage = false;
      if (await Permission.manageExternalStorage.isGranted == false) {
        needsManageStorage = true;
        var manageStorageStatus = await Permission.manageExternalStorage.request();
        if (!manageStorageStatus.isGranted) {
          // If MANAGE_EXTERNAL_STORAGE is denied, try alternative approach
          _showStoragePermissionExplanation();
          return;
        }
      }

      String courseName = '';
      String sessionName = '';
      if (_selectedCourseId != null) {
        final course = _courses.firstWhere((c) => c['id'] == _selectedCourseId, orElse: () => {});
        courseName = course['name'] ?? '';
      }
      if (_selectedSession != null) {
        sessionName = _selectedSession!;
      }

        String csv =
            'Course:,$courseName\nSession:,$sessionName\n\nS/N,RegNo.,Status,Check-In Time,Check-Out Time,Check-In %,Check-Out %,Day Total %\n';
        for (int i = 0; i < _attendanceRecords.length; i++) {
          final record = _attendanceRecords[i];
          final checkIn = _formatTimestamp(record['checkInTime']);
          final checkOut = _formatTimestamp(record['checkOutTime']);
          final checkInPct = (record['checkInPercentage'] as num?)?.toStringAsFixed(1) ?? '0.0';
          final checkOutPct = (record['checkOutPercentage'] as num?)?.toStringAsFixed(1) ?? '0.0';
          final dayTotalPct = (record['totalDayPercentage'] as num?)?.toStringAsFixed(1) ?? '0.0';
          csv +=
              '${i + 1},${record['regNumber'] ?? ''},${record['status'] ?? 'PRESENT'},$checkIn,$checkOut,$checkInPct%,$checkOutPct%,$dayTotalPct%\n';
        }      // Try to save to Downloads directory first
      try {
        final directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'attendance_${courseName.replaceAll(' ', '_')}_${sessionName}_$timestamp.csv';
        final path = '${directory.path}/$fileName';
        final file = File(path);
        await file.writeAsString(csv);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attendance exported to Downloads: $fileName')),
        );

        // Open the file using the default app
        await OpenFile.open(path);
      } catch (e) {
        // If Downloads folder fails, try app-specific directory
        await _saveToAppDirectory(csv, courseName, sessionName);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export attendance: $e')),
      );
    }
  }

  Future<void> _saveToAppDirectory(String csv, String courseName, String sessionName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'attendance_${courseName.replaceAll(' ', '_')}_${sessionName}_$timestamp.csv';
      final path = '${directory.path}/$fileName';
      final file = File(path);

      await file.writeAsString(csv);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance saved to app documents: $fileName\nYou can find it in your device file manager'),
          duration: Duration(seconds: 5),
        ),
      );

      // Open the file using the default app
      await OpenFile.open(path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving file: $e')),
      );
    }
  }

  void _showStoragePermissionExplanation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Storage Permission Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To export attendance reports to your Downloads folder, this app needs storage access permission.'),
            SizedBox(height: 16),
            Text('Why we need this permission:'),
            SizedBox(height: 8),
            Text('• Save attendance reports as CSV files'),
            Text('• Allow you to access reports from your Downloads folder'),
            Text('• Share reports with other apps'),
            SizedBox(height: 16),
            Text('You can still export reports without this permission, but files will be saved in the app\'s private folder.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Try alternative save method
              String courseName = '';
              String sessionName = '';
              if (_selectedCourseId != null) {
                final course = _courses.firstWhere((c) => c['id'] == _selectedCourseId, orElse: () => {});
                courseName = course['name'] ?? '';
              }
              if (_selectedSession != null) {
                sessionName = _selectedSession!;
              }

              String csv = 'Course:,$courseName\nSession:,$sessionName\n\nS/N,RegNo.,Status,Check-In Time,Check-Out Time\n';
              for (int i = 0; i < _attendanceRecords.length; i++) {
                final record = _attendanceRecords[i];
                final checkIn = _formatTimestamp(record['checkInTime']);
                final checkOut = _formatTimestamp(record['checkOutTime']);
                csv +=
                    '${i + 1},${record['regNumber'] ?? ''},${record['status'] ?? 'PRESENT'},$checkIn,$checkOut\n';
              }
              await _saveToAppDirectory(csv, courseName, sessionName);
            },
            child: Text('Continue Anyway'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('View Attendance'),
        actions: [
          IconButton(
            icon: Icon(Icons.download),
            tooltip: 'Export to CSV',
            onPressed: _attendanceRecords.isEmpty ? null : _exportToCsv,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _loadingCourses
                ? LinearProgressIndicator()
                : DropdownButton<String>(
                    isExpanded: true,
                    hint: Text('Select Course'),
                    value: _selectedCourseId,
                    items: _courses.map((course) {
                      return DropdownMenuItem<String>(
                        value: course['id'],
                        child: Text(course['name']),
                      );
                    }).toList(),
                    onChanged: _onCourseSelected,
                  ),
            SizedBox(height: 16),
            _loadingSessions
                ? LinearProgressIndicator()
                : DropdownButton<String>(
                    isExpanded: true,
                    hint: Text('Select Session'),
                    value: _selectedSession,
                    items: _sessions.map((session) {
                      return DropdownMenuItem<String>(
                        value: session,
                        child: Text(session),
                      );
                    }).toList(),
                    onChanged: _onSessionSelected,
                  ),
            SizedBox(height: 16),
            if (_selectedCourseId != null)
              Text('Course: ${_courses.firstWhere((c) => c['id'] == _selectedCourseId)['name']}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (_selectedSession != null)
              Text('Session: $_selectedSession',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 16),
            _loadingRecords
                ? CircularProgressIndicator()
                : Expanded(
                    child: _attendanceRecords.isEmpty
                        ? Center(child: Text(_status.isEmpty ? 'No attendance records' : _status))
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('S/N')),
                                DataColumn(label: Text('RegNo.')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Check-In')),
                                DataColumn(label: Text('Check-Out')),
                                DataColumn(label: Text('Check-In %')),
                                DataColumn(label: Text('Check-Out %')),
                                DataColumn(label: Text('Day Total %')),
                              ],
                              rows: List<DataRow>.generate(
                                _attendanceRecords.length,
                                (index) {
                                  final record = _attendanceRecords[index];
                                  return DataRow(cells: [
                                    DataCell(Text('${index + 1}')),
                                    DataCell(Text(record['regNumber'] ?? '')),
                                    DataCell(Text(record['status'] ?? 'PRESENT')),
                                    DataCell(Text(_formatTimestamp(record['checkInTime']))),
                                    DataCell(Text(_formatTimestamp(record['checkOutTime']))),
                                    DataCell(Text('${(record['checkInPercentage'] as num?)?.toStringAsFixed(1) ?? '0.0'}%')),
                                    DataCell(Text('${(record['checkOutPercentage'] as num?)?.toStringAsFixed(1) ?? '0.0'}%')),
                                    DataCell(Text('${(record['totalDayPercentage'] as num?)?.toStringAsFixed(1) ?? '0.0'}%')),
                                  ]);
                                },
                              ),
                            ),
                          ),
                  ),
          ],
        ),
      ),
    );
  }
}

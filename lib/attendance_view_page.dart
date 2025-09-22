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
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);

        final querySnapshot = await FirebaseFirestore.instance
            .collection('instructor_courses')
            .doc(_selectedCourseId)
            .collection('attendance')
            .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
            .get();

        setState(() {
          _attendanceRecords = querySnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'regNumber': data['regNumber'] ?? '',
              'status': data['status'] ?? '',
              'timestamp': data['timestamp'],
            };
          }).toList();
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

      String csv = 'Course:,$courseName\nSession:,$sessionName\n\nS/N,RegNo.,Attendance,Date\n';
      for (int i = 0; i < _attendanceRecords.length; i++) {
        final record = _attendanceRecords[i];
        final date = _formatTimestamp(record['timestamp']);
        csv +=
            '${i + 1},${record['regNumber'] ?? ''},${record['status'] ?? ''},$date\n';
      }

      // Try to save to Downloads directory first
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

              String csv = 'Course:,$courseName\nSession:,$sessionName\n\nS/N,RegNo.,Attendance,Date\n';
              for (int i = 0; i < _attendanceRecords.length; i++) {
                final record = _attendanceRecords[i];
                final date = _formatTimestamp(record['timestamp']);
                csv +=
                    '${i + 1},${record['regNumber'] ?? ''},${record['status'] ?? ''},$date\n';
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
                                DataColumn(label: Text('Attendance')),
                                DataColumn(label: Text('Date')),
                              ],
                              rows: List<DataRow>.generate(
                                _attendanceRecords.length,
                                (index) {
                                  final record = _attendanceRecords[index];
                                  return DataRow(cells: [
                                    DataCell(Text('${index + 1}')),
                                    DataCell(Text(record['regNumber'] ?? '')),
                                    DataCell(Text(record['status'] ?? '')),
                                    DataCell(Text(_formatTimestamp(record['timestamp']))),
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

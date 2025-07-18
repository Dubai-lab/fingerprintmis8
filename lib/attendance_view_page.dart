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
      final querySnapshot = await FirebaseFirestore.instance
          .collection('instructor_courses')
          .where('instructorId', isEqualTo: userId)
          .get();

      setState(() {
        _courses = querySnapshot.docs.map((doc) {
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
    try {
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

      // Save to Downloads directory
      final directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final path = '${directory.path}/attendance_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path);
      await file.writeAsString(csv);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance exported to $path')),
      );

      // Open the file using the default app
      await OpenFile.open(path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export attendance: $e')),
      );
    }
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

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class InvigilatorAttendanceReportPage extends StatefulWidget {
  const InvigilatorAttendanceReportPage({Key? key}) : super(key: key);

  @override
  _InvigilatorAttendanceReportPageState createState() => _InvigilatorAttendanceReportPageState();
}

class _InvigilatorAttendanceReportPageState extends State<InvigilatorAttendanceReportPage> {
  String? _selectedActivity;
  String? _selectedCourseId;

  List<String> _activities = ['CAT', 'EXAM', 'CONFERENCE'];
  List<Map<String, dynamic>> _courses = [];

  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _loading = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _selectedActivity = _activities.first;
    _loadCourses();
    _fetchAttendanceRecords();
  }

  Future<void> _loadCourses() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance.collection('instructor_courses').get();
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

  Future<void> _fetchAttendanceRecords() async {
    if (_selectedActivity == null) return;
    if ((_selectedActivity == 'CAT' || _selectedActivity == 'EXAM') && _selectedCourseId == null) return;

    setState(() {
      _loading = true;
      _status = '';
      _attendanceRecords = [];
    });

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('invigilator_activities')
          .doc(_selectedActivity)
          .collection('attendance');

      if (_selectedActivity == 'CAT' || _selectedActivity == 'EXAM') {
        query = query.where('courseId', isEqualTo: _selectedCourseId);
      }

      final querySnapshot = await query.orderBy('timestamp', descending: true).get();

      setState(() {
        _attendanceRecords = querySnapshot.docs.map((doc) {
          final data = doc.data();
          String courseId = data['courseId'] ?? '';
          String courseName = '';
          for (var course in _courses) {
            if (course['id'] == courseId) {
              courseName = course['name'];
              break;
            }
          }
          return {
            'regNumber': data['regNumber'] ?? '',
            'timestamp': data['timestamp']?.toDate(),
            'status': data['status'] ?? '',
            'activity': data['activity'] ?? '',
            'courseId': courseId,
            'courseName': courseName ?? '',
          };
        }).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to load attendance records: $e';
        _loading = false;
      });
    }
  }

  Future<void> _exportCSV() async {
    if (_attendanceRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No attendance records to export')),
      );
      return;
    }

      List<List<String>> csvData = [
      ['RegNumber', 'Timestamp', 'Status', 'Activity', 'CourseName'],
      ..._attendanceRecords.map((record) => [
            record['regNumber'],
            record['timestamp'] != null ? record['timestamp'].toString() : '',
            record['status'],
            record['activity'],
            record['courseName'],
          ]),
    ];

    String csv = const ListToCsvConverter().convert(csvData);

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/attendance_report.csv';
    final file = File(path);

    await file.writeAsString(csv);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('CSV exported to $path')),
    );
  }

  Widget _buildAttendanceTable() {
    if (_loading) {
      return Center(child: CircularProgressIndicator());
    }
    if (_attendanceRecords.isEmpty) {
      return Center(child: Text('No attendance records found.'));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('RegNumber')),
          DataColumn(label: Text('Timestamp')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Activity')),
          DataColumn(label: Text('CourseName')),
        ],
        rows: _attendanceRecords.map((record) {
          final timestamp = record['timestamp'] as DateTime?;
          final formattedDate = timestamp != null
              ? '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}'
              : 'Unknown';
          return DataRow(cells: [
            DataCell(Text(record['regNumber'])),
            DataCell(Text(formattedDate)),
            DataCell(Text(record['status'])),
            DataCell(Text(record['activity'])),
            DataCell(Text(record['courseName'] ?? 'Unknown Course')),
          ]);
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Invigilator Attendance Report'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(Icons.download),
            tooltip: 'Download CSV',
            onPressed: _exportCSV,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
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
                _fetchAttendanceRecords();
              },
            ),
            SizedBox(height: 16),
            if (_selectedActivity == 'CAT' || _selectedActivity == 'EXAM')
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
                  _fetchAttendanceRecords();
                },
              ),
            SizedBox(height: 16),
            Expanded(child: _buildAttendanceTable()),
            if (_status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _status,
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

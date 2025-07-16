import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
          return {
            'regNumber': data['regNumber'] ?? '',
            'timestamp': data['timestamp']?.toDate(),
            'status': data['status'] ?? '',
            'activity': data['activity'] ?? '',
            'courseId': data['courseId'] ?? '',
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

  Widget _buildAttendanceList() {
    if (_loading) {
      return Center(child: CircularProgressIndicator());
    }
    if (_attendanceRecords.isEmpty) {
      return Center(child: Text('No attendance records found.'));
    }
    return ListView.builder(
      itemCount: _attendanceRecords.length,
      itemBuilder: (context, index) {
        final record = _attendanceRecords[index];
        final timestamp = record['timestamp'] as DateTime?;
        final formattedDate = timestamp != null ? '${timestamp.year}-${timestamp.month.toString().padLeft(2,'0')}-${timestamp.day.toString().padLeft(2,'0')} ${timestamp.hour.toString().padLeft(2,'0')}:${timestamp.minute.toString().padLeft(2,'0')}' : 'Unknown';
        return ListTile(
          leading: Icon(Icons.person),
          title: Text('Reg#: ${record['regNumber']}'),
          subtitle: Text('Status: ${record['status']} - Date: $formattedDate'),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Invigilator Attendance Report'),
        backgroundColor: Colors.deepPurple,
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
            Expanded(child: _buildAttendanceList()),
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

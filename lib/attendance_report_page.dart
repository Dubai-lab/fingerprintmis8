import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceReportPage extends StatefulWidget {
  final String courseId;
  final String courseName;

  const AttendanceReportPage({
    Key? key,
    required this.courseId,
    required this.courseName,
  }) : super(key: key);

  @override
  _AttendanceReportPageState createState() => _AttendanceReportPageState();
}

class _AttendanceReportPageState extends State<AttendanceReportPage> {
  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _loading = true;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _fetchAttendanceRecords();
  }

  Future<void> _fetchAttendanceRecords() async {
    setState(() {
      _loading = true;
      _status = '';
    });

    try {
      // Fetch all attendance records for this course
      final querySnapshot = await FirebaseFirestore.instance
          .collection('instructor_courses')
          .doc(widget.courseId)
          .collection('attendance')
          .orderBy('timestamp', descending: true)
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
        _loading = false;
        
        if (_attendanceRecords.isEmpty) {
          _status = 'No attendance records found for this course.';
        }
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to load attendance records: $e';
        _loading = false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.courseName} - Attendance Report'),
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance Records',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            _loading
                ? Center(child: CircularProgressIndicator())
                : _attendanceRecords.isEmpty
                    ? Center(child: Text(_status))
                    : Expanded(
                        child: SingleChildScrollView(
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

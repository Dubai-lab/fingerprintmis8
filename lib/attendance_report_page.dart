import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
  int _totalPresent = 0;
  int _totalAbsent = 0;
  int _totalLate = 0;
  Map<String, int> _studentAttendanceCount = {};

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

        // Calculate statistics
        _calculateStatistics();

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

  void _calculateStatistics() {
    _totalPresent = 0;
    _totalAbsent = 0;
    _totalLate = 0;
    _studentAttendanceCount.clear();

    for (var record in _attendanceRecords) {
      final status = record['status'].toString().toLowerCase();
      final regNumber = record['regNumber'].toString();

      // Count attendance by status
      if (status.contains('present')) {
        _totalPresent++;
      } else if (status.contains('absent')) {
        _totalAbsent++;
      } else if (status.contains('late')) {
        _totalLate++;
      }

      // Count attendance per student
      _studentAttendanceCount[regNumber] = (_studentAttendanceCount[regNumber] ?? 0) + 1;
    }
  }

  Widget _buildStatCard(String title, int count, Color color) {
    return Card(
      elevation: 3,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 1),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final dateTime = (timestamp as Timestamp).toDate();
      return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
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
              '${widget.courseName} - Attendance Report',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),

            // Statistics Cards
            if (!_loading && _attendanceRecords.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('Present', _totalPresent, Colors.green),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard('Absent', _totalAbsent, Colors.red),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard('Late', _totalLate, Colors.orange),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                'Total Records: ${_attendanceRecords.length} | Students: ${_studentAttendanceCount.length}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 16),
            ],

            Text(
              'Attendance Records',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
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

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AdminReportPage extends StatefulWidget {
  final String courseId;
  final String courseName;
  final String courseCode;
  final String instructorName;
  final String reportType;
  final String startDate;
  final String endDate;

  const AdminReportPage({
    Key? key,
    required this.courseId,
    required this.courseName,
    required this.courseCode,
    required this.instructorName,
    required this.reportType,
    required this.startDate,
    required this.endDate,
  }) : super(key: key);

  @override
  _AdminReportPageState createState() => _AdminReportPageState();
}

class _AdminReportPageState extends State<AdminReportPage> {
  List<Map<String, dynamic>> _attendanceReports = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadAttendanceReports();
  }

  Future<void> _loadAttendanceReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      DateTime? startDate;
      if (widget.startDate.isNotEmpty) {
        startDate = DateTime.parse(widget.startDate);
      }

      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('instructor_courses')
          .doc(widget.courseId)
          .collection('attendance');

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
      }

      final attendanceSnapshot = await query.get();

      _attendanceReports = attendanceSnapshot.docs.map((doc) {
        final data = doc.data();
        String studentName = data['studentName'] ?? 'Unknown';

        // If studentName is unknown, try to fetch from students collection using regNumber
        if (studentName == 'Unknown' && data.containsKey('regNumber')) {
          final regNumber = data['regNumber'];
          // For now set as Unknown, you can implement async fetch here if needed
          studentName = 'Unknown';
        }

        return {
          'id': doc.id,
          'studentName': studentName,
          'regNumber': data['regNumber'] ?? '',
          'timestamp': data['timestamp']?.toDate() ?? DateTime.now(),
          'status': data['status'] ?? 'Present',
          'type': data['type'] ?? widget.reportType,
          'courseName': widget.courseName,
        };
      }).toList();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading attendance reports: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _exportToCSV() async {
    if (_attendanceReports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attendance records to export')),
      );
      return;
    }

    try {
      List<List<String>> csvData = [
        ['RegNumber', 'Student Name', 'Date', 'Status', 'Type', 'Course'],
        ..._attendanceReports.map((record) => [
              record['regNumber'],
              record['studentName'],
              record['timestamp'] != null
                  ? DateFormat('yyyy-MM-dd HH:mm').format(record['timestamp'])
                  : '',
              record['status'],
              record['type'],
              record['courseName'] ?? '',
            ]),
      ];

      String csv = const ListToCsvConverter().convert(csvData);

      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${widget.courseCode}_${widget.reportType}_report.csv';
      final path = '${directory.path}/$fileName';
      final file = File(path);

      await file.writeAsString(csv);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV exported to $path')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting CSV: $e')),
      );
    }
  }

  Future<void> _printReport() async {
    if (_attendanceReports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attendance records to print')),
      );
      return;
    }

    try {
      List<List<String>> csvData = [
        ['RegNumber', 'Student Name', 'Date', 'Status', 'Type', 'Course'],
        ..._attendanceReports.map((record) => [
              record['regNumber'],
              record['studentName'],
              record['timestamp'] != null
                  ? DateFormat('yyyy-MM-dd HH:mm').format(record['timestamp'])
                  : '',
              record['status'],
              record['type'],
              record['courseName'] ?? '',
            ]),
      ];

      String csv = const ListToCsvConverter().convert(csvData);

      // Show print preview dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Print Preview - ${widget.courseName} (${widget.courseCode})'),
          content: Container(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(csv),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Print functionality - In a real app, this would open the system print dialog')),
                );
              },
              child: const Text('Print'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error preparing print: $e')),
      );
    }
  }

  Widget _buildAttendanceTable() {
    if (_attendanceReports.isEmpty) {
      return const Center(child: Text('No attendance records found.'));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('RegNumber')),
          DataColumn(label: Text('Student Name')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Activity')),
          DataColumn(label: Text('Course')),
        ],
        rows: _attendanceReports.map((record) {
          final timestamp = record['timestamp'] as DateTime?;
          final formattedDate = timestamp != null
              ? '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}'
              : 'Unknown';
          return DataRow(cells: [
            DataCell(Text(record['regNumber'])),
            DataCell(Text(record['studentName'])),
            DataCell(Text(formattedDate)),
            DataCell(Text(record['status'])),
            DataCell(Text(record['type'])),
            DataCell(Text(record['courseName'] ?? '')),
          ]);
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.courseName} - ${widget.reportType} Report'),
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download CSV',
            onPressed: _exportToCSV,
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print Report',
            onPressed: _printReport,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAttendanceReports,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Course Information
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Course Information',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text('Course Name: ${widget.courseName}'),
                              Text('Course Code: ${widget.courseCode}'),
                              Text('Instructor: ${widget.instructorName}'),
                              Text('Report Type: ${widget.reportType}'),
                              if (widget.startDate.isNotEmpty)
                                Text('Start Date: ${widget.startDate}'),
                              if (widget.endDate.isNotEmpty)
                                Text('End Date: ${widget.endDate}'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Summary Information
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Records: ${_attendanceReports.length}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.download),
                                    onPressed: _exportToCSV,
                                    tooltip: 'Download CSV',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.print),
                                    onPressed: _printReport,
                                    tooltip: 'Print Report',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Attendance Table
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Attendance Records',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 16),
                                Expanded(child: _buildAttendanceTable()),
                              ],
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

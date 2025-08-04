import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AdminAttendanceReportsPage extends StatefulWidget {
  const AdminAttendanceReportsPage({Key? key}) : super(key: key);

  @override
  _AdminAttendanceReportsPageState createState() => _AdminAttendanceReportsPageState();
}

class _AdminAttendanceReportsPageState extends State<AdminAttendanceReportsPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  
  String _selectedReportType = 'CAT';
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _filteredCourses = [];
  List<Map<String, dynamic>> _attendanceReports = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCourses();
    _startDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 30)));
    _endDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  final TextEditingController _manualSearchController = TextEditingController();

  void _onSearchChanged() {
    // Remove automatic filtering on text change
  }

  void _onManualSearch() {
    _filterCourses(_manualSearchController.text);
  }

  Future<void> _loadCourses() async {
    setState(() => _isLoading = true);
    try {
      DateTime? filterStartDate;
      DateTime? filterEndDate;
      if (_startDateController.text.isNotEmpty) {
        filterStartDate = DateTime.parse(_startDateController.text);
      }
      if (_endDateController.text.isNotEmpty) {
        filterEndDate = DateTime.parse(_endDateController.text).add(const Duration(days: 1));
      }

      final snapshot = await FirebaseFirestore.instance.collection('instructor_courses').get();
      _courses = snapshot.docs.map((doc) {
        final data = doc.data();
        final courseStartDate = data['startDate']?.toDate();
        final courseEndDate = data['endDate']?.toDate();

        bool includeCourse = true;
        if (filterStartDate != null && courseEndDate != null) {
          // Include course if courseEndDate is on or after filterStartDate
          includeCourse = includeCourse && !courseEndDate.isBefore(filterStartDate);
        }
        if (filterEndDate != null && courseStartDate != null) {
          // Include course if courseStartDate is on or before filterEndDate
          includeCourse = includeCourse && !courseStartDate.isAfter(filterEndDate);
        }
        // Additional check: if courseStartDate or courseEndDate is null, include the course
        if (courseStartDate == null || courseEndDate == null) {
          includeCourse = true;
        }

        if (!includeCourse) {
          return null;
        }

        return {
          'id': doc.id,
          'courseName': data['courseName'] ?? 'Unnamed Course',
          'courseCode': data['courseCode'] ?? '',
          'startDate': courseStartDate ?? DateTime.now(),
          'instructorName': data['instructorName'] ?? '',
        };
      }).where((course) => course != null).cast<Map<String, dynamic>>().toList();

      _filteredCourses = List.from(_courses);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading courses: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAttendanceReports(String courseId) async {
    setState(() => _isLoading = true);
    try {
      if (courseId.isEmpty) {
        setState(() {
          _attendanceReports = [];
          _isLoading = false;
        });
        return;
      }

      DateTime? startDate;
      if (_startDateController.text.isNotEmpty) {
        startDate = DateTime.parse(_startDateController.text);
      }

      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('instructor_courses')
          .doc(courseId)
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
          // We will fetch student name asynchronously later, for now set as Unknown
          studentName = 'Unknown';
          // Optionally, you can implement a method to fetch student name by regNumber here
        }
        return {
          'id': doc.id,
          'studentName': studentName,
          'regNumber': data['regNumber'] ?? '',
          'timestamp': data['timestamp']?.toDate() ?? DateTime.now(),
          'status': data['status'] ?? 'Present',
          'type': data['type'] ?? _selectedReportType,
        };
      }).toList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading attendance reports: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterCourses(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCourses = List.from(_courses);
      } else {
        _filteredCourses = _courses.where((course) =>
          course['courseName'].toString().toLowerCase().contains(query.toLowerCase()) ||
          course['courseCode'].toString().toLowerCase().contains(query.toLowerCase())
        ).toList();
      }
    });
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
      final path = directory.path.isNotEmpty ? '${directory.path}/admin_attendance_report.csv' : 'admin_attendance_report.csv';
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
          DataColumn(label: Text('CourseName')),
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
        title: const Text('CAT & EXAM Attendance Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () async {
              if (_attendanceReports.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No attendance records to print')),
                );
                return;
              }

              // Generate CSV content for printing
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

              // For now, just show the CSV content in a dialog for preview
              await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Print Preview (CSV)'),
                  content: SingleChildScrollView(
                    child: Text(csv),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );

              // TODO: Integrate with actual print functionality or export to PDF
            },
            tooltip: 'Print Report',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Report Type Selection
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedReportType,
                          decoration: const InputDecoration(labelText: 'Report Type'),
                          items: const [
                            DropdownMenuItem(value: 'CAT', child: Text('CAT')),
                            DropdownMenuItem(value: 'EXAM', child: Text('EXAM')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedReportType = value!;
                              _loadAttendanceReports('');
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _startDateController,
                          decoration: const InputDecoration(
                            labelText: 'Start Date',
                            hintText: 'yyyy-MM-dd',
                          ),
                          readOnly: true,
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              _startDateController.text = DateFormat('yyyy-MM-dd').format(date);
                              if (_filteredCourses.isNotEmpty) {
                                _loadAttendanceReports(_filteredCourses.first['id']);
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _endDateController,
                          decoration: const InputDecoration(
                            labelText: 'End Date',
                            hintText: 'yyyy-MM-dd',
                          ),
                          readOnly: true,
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              _endDateController.text = DateFormat('yyyy-MM-dd').format(date);
                              if (_filteredCourses.isNotEmpty) {
                                _loadAttendanceReports(_filteredCourses.first['id']);
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search Field
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualSearchController,
                          decoration: const InputDecoration(
                            labelText: 'Search by Course Name or Code',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _onManualSearch,
                        child: const Text('Search'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Course List
                  Expanded(
                    child: ListView.builder(
                      itemCount: _filteredCourses.length,
                      itemBuilder: (context, index) {
                        final course = _filteredCourses[index];
                        return Card(
                          child: ListTile(
                            title: Text(course['courseName']),
                            subtitle: Text('Code: ${course['courseCode']} | Instructor: ${course['instructorName']}'),
                            trailing: ElevatedButton(
                              onPressed: () => _loadAttendanceReports(course['id']),
                              child: const Text('View Report'),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Attendance Reports
                  if (_attendanceReports.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Attendance Reports',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _attendanceReports.length,
                        itemBuilder: (context, index) {
                          final report = _attendanceReports[index];
                          return Card(
                            child: ListTile(
                              title: Text(report['studentName']),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Reg No: ${report['regNumber']}'),
                                  Text('Date: ${DateFormat('yyyy-MM-dd').format(report['timestamp'])}'),
                                  Text('Status: ${report['status']}'),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
  }
}

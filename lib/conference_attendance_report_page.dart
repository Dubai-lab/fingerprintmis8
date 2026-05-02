import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConferenceAttendanceReportPage extends StatefulWidget {
  const ConferenceAttendanceReportPage({Key? key}) : super(key: key);

  @override
  _ConferenceAttendanceReportPageState createState() =>
      _ConferenceAttendanceReportPageState();
}

class _ConferenceAttendanceReportPageState
    extends State<ConferenceAttendanceReportPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _conferences = [];
  List<String> _departments = [];
  List<String> _sessions = [];
  String? _selectedConferenceId;
  String? _selectedDepartment;
  String? _selectedSession;
  bool _isLoading = true;
  bool _isLoadingReport = false;
  List<Map<String, dynamic>> _attendanceReport = [];

  @override
  void initState() {
    super.initState();
    _loadConferences();
    _loadDepartments();
  }

  Future<void> _loadConferences() async {
    try {
      final querySnapshot =
          await _firestore.collection('conferences').orderBy('startDate', descending: true).get();

      final conferences = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'conferenceName': data['conferenceName'] ?? '',
          'startDate': data['startDate']?.toDate(),
          'endDate': data['endDate']?.toDate(),
        };
      }).toList();

      setState(() {
        _conferences = conferences;
        if (conferences.isNotEmpty) {
          _selectedConferenceId = conferences.first['id'];
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load conferences: $e')),
      );
    }
  }

  Future<void> _loadDepartments() async {
    try {
      final querySnapshot = await _firestore.collection('departments').get();
      final departments = querySnapshot.docs
          .map((doc) => doc.data()['name'] as String?)
          .whereType<String>()
          .toList();
      departments.sort();

      setState(() {
        _departments = departments;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load departments: $e')),
      );
    }
  }

  Future<void> _generateReport() async {
    if (_selectedConferenceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a conference')),
      );
      return;
    }

    setState(() {
      _isLoadingReport = true;
      _attendanceReport = [];
    });

    try {
      // Get all attendance records for this conference
      final attendanceSnapshot = await _firestore
          .collection('conferences')
          .doc(_selectedConferenceId)
          .collection('attendance')
          .get();

      final rawReportData = <Map<String, dynamic>>[];

      for (var doc in attendanceSnapshot.docs) {
        final data = doc.data();
        final department = data['department'] as String? ?? '';
        final regNumber = data['regNumber'] as String? ?? '';
        final session = data['session'] as String? ?? '';

        // Filter by department if selected
        if (_selectedDepartment != null && department != _selectedDepartment) {
          continue;
        }

        // Filter by session if selected
        if (_selectedSession != null && session != _selectedSession) {
          continue;
        }

        rawReportData.add({
          'regNumber': regNumber,
          'studentName': data['studentName'] as String? ?? 'Unknown',
          'department': department,
          'session': session,
          'enrolledCourses': data['enrolledCourses'] as List<dynamic>? ?? [],
          'checkInTime': data['checkInTime']?.toDate(),
          'checkOutTime': data['checkOutTime']?.toDate(),
          'status': data['status'] as String? ?? '',
          'matchScore': data['matchScore'] as int? ?? 0,
          'sessionId': data['sessionId'] as String? ?? '',
        });
      }

      // Group by student to calculate multi-day attendance
      final studentSummary = <String, Map<String, dynamic>>{};

      for (var record in rawReportData) {
        final regNumber = record['regNumber'] as String;
        final checkInTime = record['checkInTime'] as DateTime?;
        
        if (!studentSummary.containsKey(regNumber)) {
          studentSummary[regNumber] = {
            'studentName': record['studentName'] as String? ?? 'Unknown',
            'department': record['department'] as String? ?? '',
            'session': record['session'] as String? ?? '',
            'enrolledCourses': Set<String>.from((record['enrolledCourses'] as List?)?.whereType<String>() ?? []),
            'daysAttended': <String>{},
            'records': <Map<String, dynamic>>[],
          };
        }

        // Track unique days (extract date from checkInTime)
        if (checkInTime != null) {
          final dayKey = '${checkInTime.year}-${checkInTime.month.toString().padLeft(2, '0')}-${checkInTime.day.toString().padLeft(2, '0')}';
          (studentSummary[regNumber]!['daysAttended'] as Set<String>).add(dayKey);
        }
        
        (studentSummary[regNumber]!['records'] as List<Map<String, dynamic>>).add(record);
      }

      // Create final report with aggregated days attended
      final finalReport = <Map<String, dynamic>>[];
      for (var entry in studentSummary.entries) {
        final regNumber = entry.key;
        final data = entry.value;
        final daysAttended = data['daysAttended'] as Set<String>;
        final records = data['records'] as List<Map<String, dynamic>>;
        
        finalReport.add({
          'regNumber': regNumber,
          'studentName': data['studentName'] as String,
          'department': data['department'] as String,
          'session': data['session'] as String,
          'daysAttended': daysAttended.length,
          'totalRecords': records.length,
          'enrolledCourses': (data['enrolledCourses'] as Set<String>).toList(),
          'lastCheckInTime': records.isNotEmpty ? records.last['checkInTime'] : null,
          'status': records.isNotEmpty ? records.last['status'] : 'UNKNOWN',
        });
      }

      // Sort by session, then department, then reg number
      finalReport.sort((a, b) {
        int sessionCompare = (a['session'] as String).compareTo(b['session'] as String);
        if (sessionCompare != 0) return sessionCompare;
        int deptCompare = (a['department'] as String).compareTo(b['department'] as String);
        if (deptCompare != 0) return deptCompare;
        return (a['regNumber'] as String).compareTo(b['regNumber'] as String);
      });

      setState(() {
        _attendanceReport = finalReport;
        _isLoadingReport = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingReport = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate report: $e')),
      );
    }
  }

  String _calculateAttendancePercentage(String status) {
    if (status == 'CHECKED_IN_OUT') {
      return '10%';
    } else if (status == 'CHECKED_IN') {
      return '5%';
    }
    return '0%';
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return '-';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conference Attendance Reports'),
        backgroundColor: Colors.deepPurple,
        elevation: 4,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ============ FILTER SECTION ============
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Generate Report',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Conference Selection
                    _isLoading
                        ? const CircularProgressIndicator()
                        : DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Select Conference',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              prefixIcon: const Icon(Icons.event),
                            ),
                            value: _selectedConferenceId,
                            items: _conferences.map((conf) {
                              return DropdownMenuItem<String>(
                                value: conf['id'],
                                child: Text(
                                  '${conf['conferenceName']} (${_formatDate(conf['startDate'])} - ${_formatDate(conf['endDate'])})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedConferenceId = value;
                                _attendanceReport = [];
                              });
                            },
                          ),
                    const SizedBox(height: 12),
                    // Department Filter
                    DropdownButtonFormField<String?>(
                      decoration: InputDecoration(
                        labelText: 'Filter by Department (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.domain),
                      ),
                      value: _selectedDepartment,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Departments'),
                        ),
                        ..._departments.map((dept) {
                          return DropdownMenuItem<String?>(
                            value: dept,
                            child: Text(dept),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedDepartment = value;
                          _attendanceReport = [];
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    // Session Filter
                    DropdownButtonFormField<String?>(
                      decoration: InputDecoration(
                        labelText: 'Filter by Session (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.schedule),
                      ),
                      value: _selectedSession,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Sessions'),
                        ),
                        const DropdownMenuItem<String?>(
                          value: 'Day',
                          child: Text('Day'),
                        ),
                        const DropdownMenuItem<String?>(
                          value: 'Evening',
                          child: Text('Evening'),
                        ),
                        const DropdownMenuItem<String?>(
                          value: 'Weekend',
                          child: Text('Weekend'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedSession = value;
                          _attendanceReport = [];
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Generate Report Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoadingReport ? null : _generateReport,
                        icon: const Icon(Icons.assessment),
                        label: _isLoadingReport
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Generate Report'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ============ REPORT SECTION ============
            if (_attendanceReport.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 2,
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Total Students: ${_attendanceReport.length}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Report Table Header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Reg Number',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            'Session',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Department',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            'Days',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Report Rows
                  ..._attendanceReport.asMap().entries.map((entry) {
                    int index = entry.key;
                    final record = entry.value;
                    final isAlternate = index.isEven;

                    return Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isAlternate
                                ? Colors.grey.shade100
                                : Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      record['regNumber'] as String,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      record['session'] as String? ?? '-',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      record['department'] as String,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '${record['daysAttended'] ?? 1} days',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                              // Enrolled Courses
                              if ((record['enrolledCourses'] as List).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    'Courses: ${(record['enrolledCourses'] as List).join(', ')}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    );
                  }).toList(),
                ],
              )
            else if (!_isLoadingReport && _attendanceReport.isEmpty)
              Card(
                elevation: 2,
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedConferenceId != null
                              ? 'No attendance records found for selected conference'
                              : 'Select a conference and click "Generate Report"',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

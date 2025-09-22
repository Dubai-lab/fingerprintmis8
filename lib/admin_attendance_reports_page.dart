import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fingerprintmis8/admin/admin_report_page.dart';

class AdminAttendanceReportsPage extends StatefulWidget {
  const AdminAttendanceReportsPage({super.key});

  @override
  State<AdminAttendanceReportsPage> createState() => _AdminAttendanceReportsPageState();
}

class _AdminAttendanceReportsPageState extends State<AdminAttendanceReportsPage> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedReportType = 'CAT';
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _filteredCourses = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCourses();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterCourses(_searchController.text);
  }

  Future<void> _loadCourses() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('instructor_courses').get();
      _courses = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'courseName': data['courseName'] ?? 'Unnamed Course',
          'courseCode': data['courseCode'] ?? '',
          'instructorName': data['instructorName'] ?? '',
        };
      }).toList();

      _filteredCourses = List.from(_courses);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading courses: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CAT & EXAM Attendance Reports'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Report Type Selection
                  DropdownButtonFormField<String>(
                    value: _selectedReportType,
                    decoration: const InputDecoration(labelText: 'Report Type'),
                    items: const [
                      DropdownMenuItem(value: 'CAT', child: Text('CAT')),
                      DropdownMenuItem(value: 'EXAM', child: Text('EXAM')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedReportType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Search Field
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search by Course Name or Code',
                      prefixIcon: Icon(Icons.search),
                    ),
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
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AdminReportPage(
                                      courseId: course['id'],
                                      courseName: course['courseName'],
                                      courseCode: course['courseCode'],
                                      instructorName: course['instructorName'],
                                      reportType: _selectedReportType,
                                    ),
                                  ),
                                );
                              },
                              child: const Text('View Report'),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
  }
}

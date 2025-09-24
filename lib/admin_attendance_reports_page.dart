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
  List<Map<String, dynamic>> _scheduledActivities = [];
  List<Map<String, dynamic>> _filteredActivities = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadScheduledActivities();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterActivities(_searchController.text);
  }

  Future<void> _loadScheduledActivities() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('scheduled_activities').get();
      _scheduledActivities = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'courseId': data['courseId'] ?? '',
          'courseName': data['courseName'] ?? 'Unnamed Course',
          'courseCode': data['courseCode'] ?? '',
          'instructorName': data['instructorName'] ?? '',
          'activityType': data['activityType'] ?? '',
          'scheduledDate': data['scheduledDate']?.toDate(),
          'status': data['status'] ?? 'scheduled',
        };
      }).toList();

      _filteredActivities = List.from(_scheduledActivities);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading scheduled activities: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }



  void _filterActivities(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredActivities = List.from(_scheduledActivities);
      } else {
        _filteredActivities = _scheduledActivities.where((activity) =>
          activity['courseName'].toString().toLowerCase().contains(query.toLowerCase()) ||
          activity['courseCode'].toString().toLowerCase().contains(query.toLowerCase()) ||
          activity['instructorName'].toString().toLowerCase().contains(query.toLowerCase())
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
                      labelText: 'Search by Course Name, Code, or Instructor',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Activities List
                  Expanded(
                    child: ListView.builder(
                      itemCount: _filteredActivities.length,
                      itemBuilder: (context, index) {
                        final activity = _filteredActivities[index];
                        return Card(
                          child: ListTile(
                            title: Text(activity['courseName']),
                            subtitle: Text('Code: ${activity['courseCode']} | Instructor: ${activity['instructorName']} | Type: ${activity['activityType']}'),
                            trailing: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AdminReportPage(
                                      courseId: activity['courseId'],
                                      courseName: activity['courseName'],
                                      courseCode: activity['courseCode'],
                                      instructorName: activity['instructorName'],
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

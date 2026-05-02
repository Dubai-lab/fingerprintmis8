import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'attendance_report_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> _endedCourses = [];
  bool _loading = true;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _fetchEndedCourses();
  }

  Future<void> _fetchEndedCourses() async {
    setState(() {
      _loading = true;
      _status = '';
      _endedCourses = [];
    });

    try {
      // Get current instructor ID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _status = 'User not authenticated';
          _loading = false;
        });
        return;
      }

      final instructorId = user.uid;
      final now = DateTime.now();
      
      // Create a DateTime for the end of today to include courses ending today
      final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // Query only courses taught by current instructor that have ended
      // NOTE: Sorting done in-memory to avoid requiring composite Firestore index
      final querySnapshot = await FirebaseFirestore.instance
          .collection('instructor_courses')
          .where('instructorId', isEqualTo: instructorId)
          .where('endDate', isLessThanOrEqualTo: endOfToday)
          .get();

      final endedCourses = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'courseName': data['courseName'] ?? 'Unnamed Course',
          'session': data['session'] ?? '',
          'startDate': (data['startDate'] as Timestamp?)?.toDate(),
          'endDate': (data['endDate'] as Timestamp?)?.toDate(),
          'instructorName': data['instructorName'] ?? '',
        };
      }).toList();

      // Sort by endDate descending (newest first) in Dart instead of Firestore
      endedCourses.sort((a, b) {
        final dateA = a['endDate'] as DateTime?;
        final dateB = b['endDate'] as DateTime?;
        if (dateA == null || dateB == null) return 0;
        return dateB.compareTo(dateA); // descending order
      });

      setState(() {
        _endedCourses = endedCourses;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to load ended courses: $e';
        _loading = false;
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Course History'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _loading
            ? Center(child: CircularProgressIndicator())
            : _endedCourses.isEmpty
                ? Center(child: Text('No ended courses found.'))
                : ListView.builder(
                    itemCount: _endedCourses.length,
                    itemBuilder: (context, index) {
                      final course = _endedCourses[index];
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text(course['courseName']),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Session: ${course['session']}'),
                              Text('Start Date: ${_formatDate(course['startDate'])}'),
                              Text('End Date: ${_formatDate(course['endDate'])}'),
                            ],
                          ),
                          onTap: () {
                            // Navigate to attendance report for this course
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AttendanceReportPage(courseId: course['id'], courseName: course['courseName']),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

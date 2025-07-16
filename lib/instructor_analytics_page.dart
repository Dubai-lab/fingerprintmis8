import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class InstructorAnalyticsPage extends StatefulWidget {
  const InstructorAnalyticsPage({Key? key}) : super(key: key);

  @override
  _InstructorAnalyticsPageState createState() => _InstructorAnalyticsPageState();
}

class _InstructorAnalyticsPageState extends State<InstructorAnalyticsPage> {
  List<Map<String, dynamic>> _courses = [];
  String? _selectedCourseId;
  bool _loading = true;

  Map<String, int> _weeklySummary = {};
  Map<String, int> _monthlySummary = {};

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    final coursesSnapshot = await FirebaseFirestore.instance
        .collection('instructor_courses')
        .where('instructorId', isEqualTo: userId)
        .get();

    setState(() {
      _courses = coursesSnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'name': doc['courseName'] ?? 'Unnamed Course',
        };
      }).toList();
      if (_courses.isNotEmpty) {
        _selectedCourseId = _courses[0]['id'];
        _fetchAnalytics(_selectedCourseId!);
      } else {
        _loading = false;
      }
    });
  }

  Future<void> _fetchAnalytics(String courseId) async {
    setState(() {
      _loading = true;
      _weeklySummary.clear();
      _monthlySummary.clear();
    });

    // Fetch attendance sessions for the course
    final sessionsSnapshot = await FirebaseFirestore.instance
        .collection('attendance_sessions')
        .where('courseId', isEqualTo: courseId)
        .get();

    if (sessionsSnapshot.size == 0) {
      setState(() {
        _loading = false;
      });
      return;
    }

    // Fetch attendance records for the course
    final attendanceSnapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where('courseId', isEqualTo: courseId)
        .get();

    Map<String, List<DateTime>> attendanceDates = {};

    for (var doc in attendanceSnapshot.docs) {
      final regNumber = doc['regNumber'] ?? '';
      final timestamp = (doc['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

      attendanceDates.putIfAbsent(regNumber, () => []).add(timestamp);
    }

    Map<String, int> weeklySummary = {};
    Map<String, int> monthlySummary = {};

    for (var dates in attendanceDates.values) {
      for (var date in dates) {
        final week = DateFormat('yyyy-ww').format(date);
        final month = DateFormat('yyyy-MM').format(date);
        weeklySummary[week] = (weeklySummary[week] ?? 0) + 1;
        monthlySummary[month] = (monthlySummary[month] ?? 0) + 1;
      }
    }

    setState(() {
      _weeklySummary = weeklySummary;
      _monthlySummary = monthlySummary;
      _loading = false;
    });
  }

  Widget _buildDropdown() {
    return DropdownButton<String>(
      value: _selectedCourseId,
      isExpanded: true,
      items: _courses.map((course) {
        return DropdownMenuItem<String>(
          value: course['id'],
          child: Text(course['name']),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedCourseId = value;
          });
          _fetchAnalytics(value);
        }
      },
    );
  }

  Widget _buildSummary(Map<String, int> summary, String title) {
    if (summary.isEmpty) {
      return Text('No data for $title.');
    }
    final sortedKeys = summary.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        ...sortedKeys.map((key) {
          return ListTile(
            title: Text(key),
            trailing: Text(summary[key].toString()),
          );
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Analytics & Reports'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _loading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDropdown(),
                    SizedBox(height: 16),
                    Divider(),
                    _buildSummary(_weeklySummary, 'Attendance Summary by Week'),
                    Divider(),
                    _buildSummary(_monthlySummary, 'Attendance Summary by Month'),
                  ],
                ),
              ),
      ),
    );
  }
}

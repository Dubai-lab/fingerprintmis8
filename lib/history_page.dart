import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      final now = DateTime.now();
      final querySnapshot = await FirebaseFirestore.instance
          .collection('instructor_courses')
          .where('endDate', isLessThanOrEqualTo: now)
          .orderBy('endDate', descending: true)
          .get();

      setState(() {
        _endedCourses = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'courseName': data['courseName'] ?? 'Unnamed Course',
            'session': data['session'] ?? '',
            'startDate': (data['startDate'] as Timestamp?)?.toDate(),
            'endDate': (data['endDate'] as Timestamp?)?.toDate(),
          };
        }).toList();
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
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

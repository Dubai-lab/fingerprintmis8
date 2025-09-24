import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({Key? key}) : super(key: key);

  @override
  _ActivityPageState createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _scheduledActivities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCourses();
    _loadScheduledActivities();
  }

  Future<void> _loadCourses() async {
    try {
      final querySnapshot = await _firestore.collection('instructor_courses').get();
      final courses = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'courseName': data['courseName'] ?? 'Unnamed Course',
          'courseCode': data['courseCode'] ?? '',
          'instructorName': data['instructorName'] ?? '',
          'department': data['department'] ?? '',
          'session': data['session'] ?? 'Day',
          'startDate': data['startDate']?.toDate(),
          'endDate': data['endDate']?.toDate(),
        };
      }).toList();

      setState(() {
        _courses = courses;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading courses: $e')),
      );
    }
  }

  Future<void> _loadScheduledActivities() async {
    try {
      final querySnapshot = await _firestore.collection('scheduled_activities').get();
      final activities = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'courseId': data['courseId'] ?? '',
          'courseName': data['courseName'] ?? '',
          'activityType': data['activityType'] ?? '',
          'scheduledDate': data['scheduledDate']?.toDate(),
          'startTime': data['startTime'] ?? '',
          'endTime': data['endTime'] ?? '',
          'status': data['status'] ?? 'scheduled', // scheduled, completed
        };
      }).toList();

      setState(() {
        _scheduledActivities = activities;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading activities: $e')),
      );
    }
  }

  Future<void> _scheduleActivity(String courseId, String courseName, String activityType) async {
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selectedDate == null) return;

    // Select start time
    TimeOfDay? startTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );

    if (startTime == null) return;

    // Select end time
    TimeOfDay? endTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: startTime.hour + 1, minute: startTime.minute),
    );

    if (endTime == null) return;

    // Validate that end time is after start time
    final startDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      startTime.hour,
      startTime.minute,
    );

    final endDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      endTime.hour,
      endTime.minute,
    );

    if (endDateTime.isBefore(startDateTime) || endDateTime.isAtSameMomentAs(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    try {
      // Check if activity already exists for this course and type
      final existingQuery = await _firestore
          .collection('scheduled_activities')
          .where('courseId', isEqualTo: courseId)
          .where('activityType', isEqualTo: activityType)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$activityType already scheduled for this course')),
        );
        return;
      }

      await _firestore.collection('scheduled_activities').add({
        'courseId': courseId,
        'courseName': courseName,
        'activityType': activityType,
        'scheduledDate': selectedDate,
        'startTime': '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
        'endTime': '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
        'status': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _loadScheduledActivities();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$activityType scheduled successfully for $courseName')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scheduling activity: $e')),
      );
    }
  }

  Future<void> _markActivityComplete(String activityId) async {
    try {
      await _firestore.collection('scheduled_activities').doc(activityId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      _loadScheduledActivities();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Activity marked as completed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating activity: $e')),
      );
    }
  }

  Future<void> _deleteActivity(String activityId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Activity'),
        content: Text('Are you sure you want to delete this scheduled activity?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('scheduled_activities').doc(activityId).delete();
        _loadScheduledActivities();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Activity deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting activity: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Schedule Activities'),
        backgroundColor: Colors.deepPurple,
        elevation: 4,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Courses',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _courses.length,
                      itemBuilder: (context, index) {
                        final course = _courses[index];
                        final courseActivities = _scheduledActivities
                            .where((activity) => activity['courseId'] == course['id'])
                            .toList();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            course['courseName'],
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Instructor: ${course['instructorName']}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          Text(
                                            'Department: ${course['department']} | Session: ${course['session']}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'cat') {
                                          _scheduleActivity(course['id'], course['courseName'], 'CAT');
                                        } else if (value == 'exam') {
                                          _scheduleActivity(course['id'], course['courseName'], 'EXAM');
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'cat',
                                          child: Text('Schedule CAT'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'exam',
                                          child: Text('Schedule EXAM'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (courseActivities.isNotEmpty) ...[
                                  const Text(
                                    'Scheduled Activities:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...courseActivities.map((activity) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: activity['status'] == 'completed'
                                            ? Colors.green[100]
                                            : Colors.blue[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  activity['activityType'],
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  'Date: ${activity['scheduledDate'].day}/${activity['scheduledDate'].month}/${activity['scheduledDate'].year}',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                if (activity['startTime'].isNotEmpty && activity['endTime'].isNotEmpty)
                                                  Text(
                                                    'Time: ${activity['startTime']} - ${activity['endTime']}',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                Text(
                                                  'Status: ${activity['status']}',
                                                  style: TextStyle(
                                                    color: activity['status'] == 'completed'
                                                        ? Colors.green
                                                        : Colors.blue,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (activity['status'] != 'completed')
                                            Row(
                                              children: [
                                                IconButton(
                                                  onPressed: () => _markActivityComplete(activity['id']),
                                                  icon: const Icon(Icons.check_circle),
                                                  color: Colors.green,
                                                  tooltip: 'Mark Complete',
                                                ),
                                                IconButton(
                                                  onPressed: () => _deleteActivity(activity['id']),
                                                  icon: const Icon(Icons.delete),
                                                  color: Colors.red,
                                                  tooltip: 'Delete Activity',
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ],
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

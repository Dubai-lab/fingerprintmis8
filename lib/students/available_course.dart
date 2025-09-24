import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AvailableCoursesWidget extends StatefulWidget {
  final Map<String, dynamic>? studentData;
  final VoidCallback? onCourseJoined;

  const AvailableCoursesWidget({
    Key? key,
    this.studentData,
    this.onCourseJoined,
  }) : super(key: key);

  @override
  _AvailableCoursesWidgetState createState() => _AvailableCoursesWidgetState();
}

class _AvailableCoursesWidgetState extends State<AvailableCoursesWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _availableCourses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableCourses();
  }

  Future<void> _loadAvailableCourses() async {
    try {
      final snapshot = await _firestore.collection('instructor_courses').get();
      final courses = snapshot.docs.where((doc) {
        final data = doc.data();
        final department = data['department'] ?? '';
        final studentDepartment = widget.studentData?['department'] ?? '';

        return department == studentDepartment || department == 'General';
      }).map((doc) {
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
        _availableCourses = courses;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading available courses: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _joinCourse(String courseId) async {
    if (widget.studentData == null) return;

    try {
      final studentId = widget.studentData!['id'];
      final courseRef = _firestore.collection('instructor_courses').doc(courseId);
      final studentCourseRef = courseRef.collection('students').doc(studentId);

      await studentCourseRef.set({
        'joinedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully joined the course!')),
      );

      // Reload courses
      await _loadAvailableCourses();

      // Notify parent
      if (widget.onCourseJoined != null) {
        widget.onCourseJoined!();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to join course: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_availableCourses.isEmpty) {
      return const Center(
        child: Text('No courses available for your department.'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _availableCourses.length,
      itemBuilder: (context, index) {
        final course = _availableCourses[index];
        final startDate = course['startDate'] as DateTime?;
        final endDate = course['endDate'] as DateTime?;
        final isExpired = endDate != null && endDate.isBefore(DateTime.now());

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
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
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            course['courseCode'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isExpired ? Colors.red.shade100 : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isExpired ? 'Expired' : 'Active',
                        style: TextStyle(
                          color: isExpired ? Colors.red.shade800 : Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.person, color: Colors.grey.shade600, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      course['instructorName'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.school, color: Colors.grey.shade600, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      course['department'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.grey.shade600, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      course['session'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.date_range, color: Colors.grey.shade600, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      startDate != null && endDate != null
                          ? '${startDate.day}/${startDate.month}/${startDate.year} - ${endDate.day}/${endDate.month}/${endDate.year}'
                          : 'Dates not specified',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isExpired ? null : () => _showCourseDetails(context, course),
                        icon: const Icon(Icons.visibility),
                        label: const Text('View Details'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.deepPurple.shade600,
                          side: BorderSide(color: Colors.deepPurple.shade600),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isExpired ? null : () => _joinCourse(course['id']),
                        icon: const Icon(Icons.add),
                        label: const Text('Join'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple.shade600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCourseDetails(BuildContext context, Map<String, dynamic> course) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(course['courseName']),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Course Code: ${course['courseCode']}'),
              const SizedBox(height: 8),
              Text('Instructor: ${course['instructorName']}'),
              const SizedBox(height: 8),
              Text('Department: ${course['department']}'),
              const SizedBox(height: 8),
              Text('Session: ${course['session']}'),
              const SizedBox(height: 8),
              if (course['startDate'] != null && course['endDate'] != null)
                Text('Duration: ${course['startDate'].day}/${course['startDate'].month}/${course['startDate'].year} - ${course['endDate'].day}/${course['endDate'].month}/${course['endDate'].year}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

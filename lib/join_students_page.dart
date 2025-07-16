import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JoinStudentsPage extends StatefulWidget {
  const JoinStudentsPage({Key? key}) : super(key: key);

  @override
  _JoinStudentsPageState createState() => _JoinStudentsPageState();
}

class _JoinStudentsPageState extends State<JoinStudentsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedCourseId;
  List<String> _selectedStudentIds = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Join Students to Course'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Course dropdown
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('instructor_courses').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                final courses = snapshot.data!.docs;
                return DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Select Course',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedCourseId,
                  items: courses.map((course) {
                    return DropdownMenuItem<String>(
                      value: course.id,
                      child: Text(course['courseName'] ?? 'Unnamed Course'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCourseId = value;
                    });
                  },
                );
              },
            ),
            SizedBox(height: 16),
            // Students list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('students').orderBy('name').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();
                  final students = snapshot.data!.docs;
                  return ListView(
                    children: students.map((student) {
                      final studentId = student.id;
                      final studentName = student['name'] ?? 'Unnamed Student';
                      final isSelected = _selectedStudentIds.contains(studentId);
                      return CheckboxListTile(
                        title: Text(studentName),
                        value: isSelected,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedStudentIds.add(studentId);
                            } else {
                              _selectedStudentIds.remove(studentId);
                            }
                          });
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: _selectedCourseId != null && _selectedStudentIds.isNotEmpty ? _joinStudents : null,
              child: Text('Join Students to Course'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinStudents() async {
    if (_selectedCourseId == null || _selectedStudentIds.isEmpty) return;

    try {
      final batch = _firestore.batch();
      final courseRef = _firestore.collection('instructor_courses').doc(_selectedCourseId);

      for (final studentId in _selectedStudentIds) {
        final studentCourseRef = courseRef.collection('students').doc(studentId);
        batch.set(studentCourseRef, {'joinedAt': FieldValue.serverTimestamp()});
      }

      await batch.commit();

      setState(() {
        _selectedStudentIds.clear();
        _selectedCourseId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Students joined to course successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to join students: $e')),
      );
    }
  }
}

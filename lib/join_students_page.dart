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
  String _searchRegNumber = '';
  String? _courseDepartment;

  Future<List<String>> _getJoinedStudentIds() async {
    if (_selectedCourseId == null) return [];
    final snapshot = await _firestore.collection('instructor_courses').doc(_selectedCourseId).collection('students').get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  Future<void> _fetchCourseDepartment() async {
    if (_selectedCourseId == null) {
      setState(() {
        _courseDepartment = null;
      });
      return;
    }
    final courseDoc = await _firestore.collection('instructor_courses').doc(_selectedCourseId).get();
    if (courseDoc.exists) {
      setState(() {
        _courseDepartment = courseDoc.get('department') ?? null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Join Students to Course'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade200, Colors.deepPurple.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Course dropdown
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('instructor_courses').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                final now = DateTime.now();
                final courses = snapshot.data!.docs.where((course) {
                  final endDate = course['endDate'] as Timestamp?;
                  // If endDate is null, we'll still show the course
                  // Otherwise, only show if endDate is in the future
                  return endDate == null || endDate.toDate().isAfter(now);
                }).toList();
                return DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Select Course',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  value: _selectedCourseId,
                  items: courses.map((course) {
                    return DropdownMenuItem<String>(
                      value: course.id,
                      child: Text(course['courseName'] ?? 'Unnamed Course'),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    setState(() {
                      _selectedCourseId = value;
                      _selectedStudentIds.clear();
                    });
                    await _fetchCourseDepartment();
                  },
                );
              },
            ),
            SizedBox(height: 16),
            // Search field
            TextField(
              decoration: InputDecoration(
                labelText: 'Search by Registration Number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _searchRegNumber = value.trim();
                });
              },
            ),
            SizedBox(height: 16),
            // Students list
            Expanded(
              child: FutureBuilder<List<String>>(
                future: _getJoinedStudentIds(),
                builder: (context, joinedSnapshot) {
                  if (!joinedSnapshot.hasData) return Center(child: CircularProgressIndicator());
                  final joinedStudentIds = joinedSnapshot.data!;
                  return StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('students')
                        .orderBy('name')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                      final students = snapshot.data!.docs.where((student) {
                        final studentId = student.id;
                        final regNumber = student['regNumber'] ?? '';
                        final department = student['department'] ?? '';
                        final matchesSearch = _searchRegNumber.isEmpty || regNumber.contains(_searchRegNumber);
                        final notJoined = !joinedStudentIds.contains(studentId);
                        return matchesSearch && notJoined;
                      }).toList();

                      // Filter students by selected course's department
                      // If course department is "General", show all students
                      // Otherwise, filter by department
                      if (_selectedCourseId != null && _courseDepartment != null && _courseDepartment != 'General') {
                        students.retainWhere((student) {
                          final studentDept = student['department'] ?? '';
                          return studentDept == _courseDepartment;
                        });
                      }

                      return ListView(
                        children: students.map((student) {
                          final studentId = student.id;
                          final studentName = student['name'] ?? 'Unnamed Student';
                          final isSelected = _selectedStudentIds.contains(studentId);
                          return Card(
                            elevation: 4,
                            margin: EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: CheckboxListTile(
                              title: Text(
                                '$studentName (${student['regNumber'] ?? ''})',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
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
                            ),
                          );
                        }).toList(),
                      );
                    },
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _selectedCourseId != null && _selectedStudentIds.isNotEmpty ? _joinStudents : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Join Students to Course', style: TextStyle(fontSize: 18, color: Colors.white)),
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

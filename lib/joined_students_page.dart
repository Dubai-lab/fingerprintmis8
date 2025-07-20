import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JoinedStudentsPage extends StatefulWidget {
  const JoinedStudentsPage({Key? key}) : super(key: key);

  @override
  _JoinedStudentsPageState createState() => _JoinedStudentsPageState();
}

class _JoinedStudentsPageState extends State<JoinedStudentsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedCourseId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Joined Students'),
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
                final courses = snapshot.data!.docs;
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
              child: _selectedCourseId == null
                  ? Center(child: Text('Please select a course'))
                  : StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('instructor_courses').doc(_selectedCourseId).collection('students').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                        final studentDocs = snapshot.data!.docs;
                        if (studentDocs.isEmpty) {
                          return Center(child: Text('No students have joined this course.'));
                        }
                        return FutureBuilder<List<DocumentSnapshot>>(
                          future: Future.wait(studentDocs.map((studentDoc) => _firestore.collection('students').doc(studentDoc.id).get()).toList()),
                          builder: (context, studentsSnapshot) {
                            if (!studentsSnapshot.hasData) return Center(child: CircularProgressIndicator());
                            final studentsData = studentsSnapshot.data!;
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('S/N')),
                                  DataColumn(label: Text('Registration Number')),
                                  DataColumn(label: Text('Name')),
                                ],
                                rows: List<DataRow>.generate(
                                  studentsData.length,
                                  (index) {
                                    final student = studentsData[index].data() as Map<String, dynamic>;
                                    final regNumber = student['regNumber'] ?? '';
                                    final name = student['name'] ?? 'Unnamed Student';
                                    return DataRow(
                                      cells: [
                                        DataCell(Text('${index + 1}')),
                                        DataCell(Text(regNumber)),
                                        DataCell(Text(name)),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            );
                          },
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

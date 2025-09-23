import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JoinedStudentsPage extends StatefulWidget {
  const JoinedStudentsPage({Key? key}) : super(key: key);
  
  @override
  _JoinedStudentsPageState createState() => _JoinedStudentsPageState();
}

class _JoinedStudentsPageState extends State<JoinedStudentsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedCourseId;

  Future<String?> _getCurrentInstructorId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('DEBUG: No user logged in');
      return null;
    }

    print('DEBUG: Current user UID: ${user.uid}');
    print('DEBUG: Current user email: ${user.email}');

    // Return the Firebase Auth UID directly - this is used as instructorId in courses
    return user.uid;
  }

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
            // Course dropdown - Only show courses assigned to current instructor
            FutureBuilder<String?>(
              future: _getCurrentInstructorId(),
              builder: (context, instructorSnapshot) {
                if (!instructorSnapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final currentInstructorId = instructorSnapshot.data;

                if (currentInstructorId == null) {
                  return Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey),
                        SizedBox(width: 12),
                        Text(
                          'No Data',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('instructor_courses')
                      .where('instructorId', isEqualTo: currentInstructorId)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    print('DEBUG: StreamBuilder state: ${snapshot.connectionState}');
                    print('DEBUG: Has error: ${snapshot.hasError}');
                    if (snapshot.hasError) {
                      print('DEBUG: Error: ${snapshot.error}');
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }

                    print('DEBUG: Found ${snapshot.data!.docs.length} courses for instructor $currentInstructorId');

                    final now = DateTime.now();
                    final courses = snapshot.data!.docs.where((course) {
                      final endDate = course['endDate'] as Timestamp?;
                      // If endDate is null, we'll still show the course
                      // Otherwise, only show if endDate is in the future
                      return endDate == null || endDate.toDate().isAfter(now);
                    }).toList();

                    print('DEBUG: After filtering by date: ${courses.length} courses');

                    // If no courses are available, show "No Data" message
                    if (courses.isEmpty) {
                      return Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.grey),
                            SizedBox(width: 12),
                            Text(
                              'No Data',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

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
                        if (!snapshot.hasData) {
                          return Center(child: CircularProgressIndicator());
                        }
                        final studentDocs = snapshot.data!.docs;
                        if (studentDocs.isEmpty) {
                          return Center(child: Text('No students have joined this course.'));
                        }
                        return FutureBuilder<List<DocumentSnapshot>>(
                          future: Future.wait(studentDocs.map((studentDoc) => _firestore.collection('students').doc(studentDoc.id).get()).toList()),
                          builder: (context, studentsSnapshot) {
                            if (!studentsSnapshot.hasData) {
                              return Center(child: CircularProgressIndicator());
                            }
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

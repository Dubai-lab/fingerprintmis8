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
  List<Map<String, dynamic>> _instructorCourses = [];
  List<Map<String, dynamic>> _enrolledStudents = [];
  bool _isLoadingCourses = true;
  bool _isLoadingStudents = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadInstructorCourses();
  }

  /// Load all courses assigned to the current instructor
  Future<void> _loadInstructorCourses() async {
    try {
      final instructorId = FirebaseAuth.instance.currentUser?.uid;
      if (instructorId == null) {
        setState(() {
          _status = '❌ Not logged in';
          _isLoadingCourses = false;
        });
        return;
      }

      final now = DateTime.now();
      final querySnapshot = await _firestore
          .collection('instructor_courses')
          .where('instructorId', isEqualTo: instructorId)
          .get();

      // Filter courses that are still active
      final courses = querySnapshot.docs
          .map((doc) {
            final data = doc.data();
            final endDate = data['endDate'] as Timestamp?;
            return {
              'id': doc.id,
              'name': data['courseName'] ?? 'Unnamed Course',
              'credits': data['credits'] ?? 0,
              'session': data['session'] ?? 'Day',
              'endDate': endDate?.toDate(),
            };
          })
          .where((course) {
            // Show active courses (no end date or end date in future)
            final endDate = course['endDate'] as DateTime?;
            return endDate == null || endDate.isAfter(now);
          })
          .toList();

      setState(() {
        _instructorCourses = courses;
        if (courses.isEmpty) {
          _status = 'ℹ️ No courses assigned to you';
        } else {
          _status = '';
        }
        _isLoadingCourses = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error loading courses: $e';
        _isLoadingCourses = false;
      });
    }
  }

  /// Load all students enrolled in the selected course
  Future<void> _loadEnrolledStudents(String courseId) async {
    setState(() {
      _isLoadingStudents = true;
      _enrolledStudents = [];
    });

    try {
      final studentsSnapshot = await _firestore
          .collection('instructor_courses')
          .doc(courseId)
          .collection('students')
          .get();

      final students = <Map<String, dynamic>>[];

      for (var doc in studentsSnapshot.docs) {
        final studentId = doc.id;
        final studentData = doc.data();
        
        // Calculate attendance percentage
        final attendance = await _calculateStudentAttendancePercentage(courseId, studentId);

        students.add({
          'regNumber': studentId,
          'name': studentData['name'] ?? 'Unknown',
          'department': studentData['department'] ?? 'Unknown',
          'attendance': attendance,
          'joinedAt': studentData['joinedAt'],
        });
      }

      // Sort by name
      students.sort((a, b) => (a['name'] as String).compareTo(b['name']));

      setState(() {
        _enrolledStudents = students;
        if (students.isEmpty) {
          _status = '⚠️ No students enrolled in this course';
        } else {
          _status = '';
        }
        _isLoadingStudents = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error loading students: $e';
        _isLoadingStudents = false;
      });
    }
  }

  /// Calculate student's attendance percentage in the course
  Future<double> _calculateStudentAttendancePercentage(
      String courseId, String studentRegNumber) async {
    try {
      // Get all attendance sessions for this student in the course
      final sessionsSnapshot = await _firestore
          .collection('instructor_courses')
          .doc(courseId)
          .collection('attendance_sessions')
          .get();

      double totalPercentage = 0.0;

      for (var session in sessionsSnapshot.docs) {
        final studentAttendanceDoc = await _firestore
            .collection('instructor_courses')
            .doc(courseId)
            .collection('attendance_sessions')
            .doc(session.id)
            .collection('students')
            .doc(studentRegNumber)
            .get();

        if (studentAttendanceDoc.exists) {
          final data = studentAttendanceDoc.data();
          if (data != null) {
            // First priority: use totalDayPercentage if it exists
            if (data.containsKey('totalDayPercentage')) {
              final dayPct = (data['totalDayPercentage'] as num).toDouble();
              totalPercentage += dayPct;
            } 
            // Second priority: calculate from check-in/check-out if totalDayPercentage missing
            else if (data.containsKey('checkInPercentage') || data.containsKey('checkOutPercentage')) {
              final checkInPct = (data['checkInPercentage'] as num?)?.toDouble() ?? 0.0;
              final checkOutPct = (data['checkOutPercentage'] as num?)?.toDouble() ?? 0.0;
              totalPercentage += checkInPct + checkOutPct;
            }
            // Third priority: if status is ABSENT but no percentages, it's -10%
            else if (data['status'] == 'ABSENT') {
              totalPercentage -= 10.0;
            }
          }
        }
      }

      // Clamp to 0-100 range
      return totalPercentage < 0 ? 0.0 : (totalPercentage > 100 ? 100.0 : totalPercentage);
    } catch (e) {
      return 0.0;
    }
  }

  /// Get color based on attendance percentage
  Color _getAttendanceColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }

  /// Get status text based on attendance percentage
  String _getAttendanceStatus(double percentage) {
    if (percentage >= 80) return '✅ EXCELLENT';
    if (percentage >= 60) return '⚠️ ACCEPTABLE';
    return '❌ POOR';
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Course Students'),
        backgroundColor: Colors.deepPurple,
        elevation: 4,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ============ COURSE SELECTION ============
            Text(
              'Select Course',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_isLoadingCourses)
              const LinearProgressIndicator()
            else if (_instructorCourses.isEmpty)
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.orange, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No courses assigned to you',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Choose a course',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                value: _selectedCourseId,
                items: _instructorCourses.map((course) {
                  return DropdownMenuItem<String>(
                    value: course['id'],
                    child: Text(
                      '${course['name']} (${course['credits']} Credits - ${course['session']})',
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCourseId = value;
                    });
                    _loadEnrolledStudents(value);
                  }
                },
              ),
            const SizedBox(height: 24),

            // ============ STUDENTS LIST ============
            if (_selectedCourseId != null)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enrolled Students (${_enrolledStudents.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingStudents)
                      const Center(child: CircularProgressIndicator())
                    else if (_enrolledStudents.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Card(
                            color: Colors.blue.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person_outline,
                                      size: 48, color: Colors.blue),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No Students Enrolled',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No students have enrolled in this course yet',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.blue.shade700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: _enrolledStudents.length,
                          itemBuilder: (context, index) {
                            final student = _enrolledStudents[index];
                            final attendance = student['attendance'] as double;
                            final attendanceColor = _getAttendanceColor(attendance);

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 12.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Student name and registration
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                student['name'],
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Reg: ${student['regNumber']}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: attendanceColor.withOpacity(0.2),
                                            border: Border.all(
                                              color: attendanceColor,
                                              width: 2,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '${attendance.toStringAsFixed(2)}%',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: attendanceColor,
                                                ),
                                              ),
                                              Text(
                                                'Attendance',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: attendanceColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Divider(color: Colors.grey.shade300),
                                    const SizedBox(height: 12),
                                    // Attendance status and department
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Status',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _getAttendanceStatus(attendance),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: attendanceColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Department',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              student['department'],
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
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
            if (_status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Card(
                  color: _status.contains('❌')
                      ? Colors.red.shade50
                      : _status.contains('⚠️')
                          ? Colors.orange.shade50
                          : Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(
                          _status.contains('❌')
                              ? Icons.error_outline
                              : _status.contains('⚠️')
                                  ? Icons.warning_outlined
                                  : Icons.info_outlined,
                          color: _status.contains('❌')
                              ? Colors.red
                              : _status.contains('⚠️')
                                  ? Colors.orange
                                  : Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _status,
                            style: TextStyle(
                              fontSize: 13,
                              color: _status.contains('❌')
                                  ? Colors.red.shade700
                                  : _status.contains('⚠️')
                                      ? Colors.orange.shade700
                                      : Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

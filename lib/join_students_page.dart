import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JoinStudentsPage extends StatefulWidget {
  const JoinStudentsPage({Key? key}) : super(key: key);

  @override
  _JoinStudentsPageState createState() => _JoinStudentsPageState();
}

class _JoinStudentsPageState extends State<JoinStudentsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  String _searchStatus = '';
  Map<String, dynamic>? _foundStudent;
  List<Map<String, dynamic>> _availableCourses = [];
  bool _isSearching = false;
  bool _isLoadingCourses = false;

  Future<String?> _getCurrentInstructorId() async {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  Future<void> _searchStudent(String regNumber) async {
    if (regNumber.isEmpty) {
      setState(() {
        _searchStatus = 'Please enter a registration number';
        _foundStudent = null;
        _availableCourses = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchStatus = 'Searching...';
    });

    try {
      final sanitizedRegNumber = regNumber.replaceAll('/', '_');
      final studentDoc =
          await _firestore.collection('students').doc(sanitizedRegNumber).get();

      if (!studentDoc.exists) {
        setState(() {
          _searchStatus = '❌ Student not found';
          _foundStudent = null;
          _availableCourses = [];
          _isSearching = false;
        });
        return;
      }

      final studentData = studentDoc.data() as Map<String, dynamic>;
      final studentDepartment = studentData['department'] ?? '';
      final studentSession = studentData['session'] ?? '';

      setState(() {
        _foundStudent = {
          ...studentData,
          'docId': sanitizedRegNumber,
        };
        _searchStatus = '✅ Student found: ${studentData['name']}';
      });

      // Load available courses for this student's department and session
      await _loadAvailableCoursesForStudent(
        studentDepartment,
        studentSession,
        sanitizedRegNumber,
      );

      setState(() {
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchStatus = '❌ Error: $e';
        _foundStudent = null;
        _availableCourses = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _loadAvailableCoursesForStudent(
    String department,
    String session,
    String studentDocId,
  ) async {
    setState(() {
      _isLoadingCourses = true;
    });

    try {
      final now = DateTime.now();

      // Query ALL courses (Admin can see all courses, not just their instructor's)
      // Instead of filtering by instructorId, we filter by department and session
      final allCoursesSnapshot = await _firestore
          .collection('instructor_courses')
          .get();

      print('DEBUG: Found ${allCoursesSnapshot.docs.length} total courses');

      // Filter in code to match student's department and session
      final List<Map<String, dynamic>> available = [];

      for (var courseDoc in allCoursesSnapshot.docs) {
        final courseData = courseDoc.data();
        
        print('DEBUG: Course - name: ${courseData['courseName']}, session: ${courseData['session']}, department: ${courseData['department']}, endDate: ${courseData['endDate']}');
        
        // Apply filters in code
        // Check 1: Session must match
        if (courseData['session'] != session) {
          print('DEBUG: Skipped - session mismatch (${courseData['session']} != $session)');
          continue;
        }
        
        // Check 2: Department filter
        // If course department is "General", student from ANY department can join
        // If course department is specific, only students from that department can join
        final courseDepartment = (courseData['department'] as String? ?? '').trim();
        final isGeneral = courseDepartment == 'General';
        
        print('DEBUG: Department check - courseDepartment: "$courseDepartment", isGeneral: $isGeneral, studentDept: "$department"');
        
        if (!isGeneral && courseDepartment != department) {
          print('DEBUG: Skipped - department mismatch ("$courseDepartment" != "$department" and not General)');
          continue;
        }
        
        final endDate = courseData['endDate'] as Timestamp?;
        if (endDate == null) {
          print('DEBUG: Skipped - endDate is null');
          continue;
        }
        if (endDate.toDate().isBefore(now)) {
          print('DEBUG: Skipped - endDate is in the past (${endDate.toDate()} < $now)');
          continue;
        }

        // NEW: Check if registration deadline has passed
        final registrationDeadline = courseData['registrationDeadline'] as Timestamp?;
        if (registrationDeadline == null) {
          print('DEBUG: Skipped - registrationDeadline is null (legacy course)');
          continue;
        }
        if (registrationDeadline.toDate().isBefore(now)) {
          print('DEBUG: Skipped - registrationDeadline has passed (${registrationDeadline.toDate()} < $now)');
          continue;
        }

        // Check if student already joined this course
        final studentInCourse = await _firestore
            .collection('instructor_courses')
            .doc(courseDoc.id)
            .collection('students')
            .doc(studentDocId)
            .get();

        if (!studentInCourse.exists) {
          available.add({
            'id': courseDoc.id,
            'name': courseData['courseName'] ?? 'Unnamed Course',
            'session': courseData['session'] ?? '',
            'code': courseData['courseCode'] ?? '',
            'unit': courseData['unit'] ?? 0,
          });
          print('DEBUG: Added course - ${courseData['courseName']}');
        }
      }

      setState(() {
        _availableCourses = available;
        if (available.isEmpty) {
          _searchStatus =
              '⚠️ No available courses for ${_foundStudent?['name']} in $session session';
        } else {
          _searchStatus =
              '✅ Found ${available.length} available course(s) for $session session';
        }
        _isLoadingCourses = false;
      });
    } catch (e) {
      setState(() {
        _searchStatus = '❌ Error loading courses: $e';
        _availableCourses = [];
        _isLoadingCourses = false;
      });
    }
  }

  Future<void> _joinStudentToCourse(String courseId) async {
    if (_foundStudent == null) return;

    try {
      await _firestore
          .collection('instructor_courses')
          .doc(courseId)
          .collection('students')
          .doc(_foundStudent!['docId'])
          .set({
            'regNumber': _foundStudent!['regNumber'],
            'name': _foundStudent!['name'],
            'department': _foundStudent!['department'],
            'session': _foundStudent!['session'],
            'joinedAt': FieldValue.serverTimestamp(),
          });

      // Show success message
      final courseName = _availableCourses
          .firstWhere((c) => c['id'] == courseId)['name'];

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ ${_foundStudent!['name']} joined $courseName',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Reload available courses
      await _loadAvailableCoursesForStudent(
        _foundStudent!['department'],
        _foundStudent!['session'],
        _foundStudent!['docId'],
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Students to Courses'),
        backgroundColor: Colors.deepPurple,
        elevation: 4,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ============ SEARCH SECTION ============
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search Student by Registration Number',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'e.g., 20136/2022',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: Icon(Icons.search, color: Colors.deepPurple),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (value) => _searchStudent(value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.search),
                          label: const Text('Search'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _searchStudent(_searchController.text),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ============ STATUS MESSAGE ============
            if (_searchStatus.isNotEmpty)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: _searchStatus.contains('❌')
                    ? Colors.red.shade50
                    : _searchStatus.contains('⚠️')
                        ? Colors.orange.shade50
                        : Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _searchStatus,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _searchStatus.contains('❌')
                          ? Colors.red
                          : _searchStatus.contains('⚠️')
                              ? Colors.orange
                              : Colors.green,
                    ),
                  ),
                ),
              ),

            if (_searchStatus.isNotEmpty) const SizedBox(height: 24),

            // ============ STUDENT DETAILS ============
            if (_foundStudent != null)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, color: Colors.deepPurple, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _foundStudent!['name'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _foundStudent!['regNumber'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                _foundStudent!['department'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Session',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _foundStudent!['session'] == 'Day'
                                      ? Colors.blue
                                      : _foundStudent!['session'] == 'Evening'
                                          ? Colors.orange
                                          : Colors.purple,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _foundStudent!['session'] ?? 'Unknown',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            if (_foundStudent != null) const SizedBox(height: 24),

            // ============ AVAILABLE COURSES ============
            if (_availableCourses.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Courses (${_availableCourses.length})',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  ..._availableCourses.map((course) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      course['name'],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Code: ${course['code'] ?? 'N/A'} | Units: ${course['unit'] ?? 0}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        course['session'],
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Join'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => _joinStudentToCourse(course['id']),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),

            if (_isLoadingCourses)
              const Padding(
                padding: EdgeInsets.only(top: 24.0),
                child: LinearProgressIndicator(),
              ),

            if (_foundStudent != null && _availableCourses.isEmpty && !_isLoadingCourses)
              Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No available courses for this student in their session',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange.shade900,
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

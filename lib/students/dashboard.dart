import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'available_course.dart';
import 'accessed_course.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({Key? key}) : super(key: key);

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic>? _studentData;
  int _availableCoursesCount = 0;
  int _joinedCoursesCount = 0;
  bool _isLoading = true;
  bool _showAvailableCourses = false;
  bool _showJoinedCourses = false;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get student data using email
      final studentQuery = await _firestore
          .collection('students')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (studentQuery.docs.isNotEmpty) {
        final studentDoc = studentQuery.docs.first;
        final studentData = studentDoc.data();
        if (studentData != null) {
          studentData['id'] = studentDoc.id;
        }

        setState(() {
          _studentData = studentData;
        });

        // Load counts
        await _loadCounts();
      }
    } catch (e) {
      print('Error loading student data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCounts() async {
    if (_studentData == null) return;

    try {
      final studentId = _studentData!['id'];

      // Load available courses count
      final availableSnapshot = await _firestore.collection('instructor_courses').get();
      final availableCourses = availableSnapshot.docs.where((doc) {
        final data = doc.data();
        final department = data['department'] ?? '';
        final studentDepartment = _studentData!['department'] ?? '';

        return department == studentDepartment || department == 'General';
      }).length;

      // Load joined courses count
      final QuerySnapshot joinedSnapshot = await _firestore
          .collectionGroup('students')
          .where('joinedAt', isNull: false)
          .get();

      final joinedCount = joinedSnapshot.docs.where((doc) => doc.id == studentId).length;

      setState(() {
        _availableCoursesCount = availableCourses;
        _joinedCoursesCount = joinedCount;
      });
    } catch (e) {
      print('Error loading counts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        backgroundColor: Colors.deepPurple.shade600,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.pushNamed(context, '/user_profile'),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade200, Colors.deepPurple.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              _buildWelcomeCard(),

              const SizedBox(height: 24),

              // Quick Actions
              _buildQuickActions(),

              const SizedBox(height: 24),

              // Available Courses Widget (shown when toggled)
              if (_showAvailableCourses) ...[
                _buildAvailableCoursesWidget(),
                const SizedBox(height: 24),
              ],

              // Joined Courses Dropdown (shown when toggled)
              if (_showJoinedCourses) ...[
                _buildJoinedCoursesWidget(),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final name = _studentData?['name'] ?? 'Student';
    final regNumber = _studentData?['regNumber'] ?? '';
    final department = _studentData?['department'] ?? '';

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white.withOpacity(0.9),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.deepPurple.shade100,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'S',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade600,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, $name!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Registration: $regNumber',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    'Department: $department',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            title: 'Available Classes',
            subtitle: '$_availableCoursesCount courses',
            icon: Icons.school,
            color: Colors.blue,
            onTap: () {
              setState(() {
                _showAvailableCourses = !_showAvailableCourses;
                _showJoinedCourses = false;
              });
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionCard(
            title: 'Joined Classes',
            subtitle: '$_joinedCoursesCount courses',
            icon: Icons.check_circle,
            color: Colors.green,
            onTap: () {
              setState(() {
                _showJoinedCourses = !_showJoinedCourses;
                _showAvailableCourses = false;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailableCoursesWidget() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white.withOpacity(0.9),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school, color: Colors.deepPurple.shade600, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Available Courses',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(_showAvailableCourses ? Icons.expand_less : Icons.expand_more),
                  onPressed: () {
                    setState(() {
                      _showAvailableCourses = !_showAvailableCourses;
                    });
                  },
                ),
              ],
            ),
            if (_showAvailableCourses) ...[
              const SizedBox(height: 16),
              _buildAvailableCoursesList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildJoinedCoursesWidget() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white.withOpacity(0.9),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.deepPurple.shade600, size: 24),
                const SizedBox(width: 12),
                Text(
                  'My Courses',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(_showJoinedCourses ? Icons.expand_less : Icons.expand_more),
                  onPressed: () {
                    setState(() {
                      _showJoinedCourses = !_showJoinedCourses;
                    });
                  },
                ),
              ],
            ),
            if (_showJoinedCourses) ...[
              const SizedBox(height: 16),
              _buildJoinedCoursesList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableCoursesList() {
    return AvailableCoursesWidget(
      studentData: _studentData,
      onCourseJoined: () {
        // Reload counts when a course is joined
        _loadCounts();
      },
    );
  }

  Widget _buildJoinedCoursesList() {
    return JoinedCoursesWidget(
      studentData: _studentData,
      onCourseLeft: () {
        // Reload counts when a course is left
        _loadCounts();
      },
    );
  }


}

import 'package:fingerprintmis8/attendance_page.dart';
import 'package:fingerprintmis8/attendance_view_page.dart';
import 'package:fingerprintmis8/joined_students_page.dart';
import 'package:fingerprintmis8/settings_page.dart';
import 'package:fingerprintmis8/widgets/default_password_warning_widget.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InstructorDashboardPage extends StatefulWidget {
  const InstructorDashboardPage({Key? key}) : super(key: key);

  @override
  _InstructorDashboardPageState createState() => _InstructorDashboardPageState();
}

class _InstructorDashboardPageState extends State<InstructorDashboardPage> {
  int _dailyAttendanceCount = 0;
  int _totalCoursesCount = 0;
  int _totalStudentsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    await _fetchDailyAttendanceCount();
    await _fetchCoursesAndStudentsCount();
  }

  Future<void> _fetchDailyAttendanceCount() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    try {
      final coursesSnapshot = await FirebaseFirestore.instance
          .collection('instructor_courses')
          .where('instructorId', isEqualTo: userId)
          .get();

      int totalAttendanceCount = 0;

      for (var courseDoc in coursesSnapshot.docs) {
        // Query all attendance sessions for this course
        final sessionsSnapshot = await FirebaseFirestore.instance
            .collection('instructor_courses')
            .doc(courseDoc.id)
            .collection('attendance_sessions')
            .get();

        for (var sessionDoc in sessionsSnapshot.docs) {
          // Get all students in this session
          final studentsSnapshot = await FirebaseFirestore.instance
              .collection('instructor_courses')
              .doc(courseDoc.id)
              .collection('attendance_sessions')
              .doc(sessionDoc.id)
              .collection('students')
              .get();

          // Count only check-ins from today
          for (var studentDoc in studentsSnapshot.docs) {
            final data = studentDoc.data();
            final checkInTime = data['checkInTime'] as Timestamp?;
            if (checkInTime != null) {
              final checkInDate = checkInTime.toDate();
              if (checkInDate.year == startOfDay.year &&
                  checkInDate.month == startOfDay.month &&
                  checkInDate.day == startOfDay.day) {
                totalAttendanceCount++;
              }
            }
          }
        }
      }

      setState(() {
        _dailyAttendanceCount = totalAttendanceCount;
      });
    } catch (e) {
      setState(() {
        _dailyAttendanceCount = 0;
      });
    }
  }

  Future<void> _fetchCoursesAndStudentsCount() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    try {
      final coursesSnapshot = await FirebaseFirestore.instance
          .collection('instructor_courses')
          .where('instructorId', isEqualTo: userId)
          .get();

      setState(() {
        _totalCoursesCount = coursesSnapshot.size;
      });

      int totalStudents = 0;
      for (var courseDoc in coursesSnapshot.docs) {
        final studentsSnapshot = await FirebaseFirestore.instance
            .collection('instructor_courses')
            .doc(courseDoc.id)
            .collection('students')
            .get();
        totalStudents += studentsSnapshot.size;
      }

      setState(() {
        _totalStudentsCount = totalStudents;
      });
    } catch (e) {
      setState(() {
        _totalCoursesCount = 0;
        _totalStudentsCount = 0;
      });
    }
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  Widget _buildDrawerSectionHeader(String title, Color color) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Instructor Dashboard'),
        backgroundColor: Colors.deepPurple,
        elevation: 4,
        centerTitle: true,
      ),
      drawer: Drawer(
        child: Container(
          color: Colors.white,
          child: Column(
            children: <Widget>[
              // Modern Drawer Header with Gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: EdgeInsets.fromLTRB(20, 40, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.school, size: 48, color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'Instructor',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Control Panel',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // ATTENDANCE SECTION
                    _buildDrawerSectionHeader('ATTENDANCE', Colors.deepPurple),
                    ListTile(
                      leading: Icon(Icons.dashboard, color: Colors.deepPurple),
                      title: Text('Dashboard', style: TextStyle(fontSize: 16)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushReplacementNamed(context, '/instructor_dashboard');
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.check_circle, color: Colors.deepPurple),
                      title: Text('Mark Attendance', style: TextStyle(fontSize: 16)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AttendancePage(courseId: '', sessionId: ''),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.view_list, color: Colors.deepPurple),
                      title: Text('View Attendance', style: TextStyle(fontSize: 16)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => AttendanceViewPage()),
                        );
                      },
                    ),

                    // STUDENTS SECTION
                    _buildDrawerSectionHeader('STUDENTS', Colors.orange),
                    ListTile(
                      leading: Icon(Icons.group, color: Colors.orange),
                      title: Text('View Students', style: TextStyle(fontSize: 16)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => JoinedStudentsPage()),
                        );
                      },
                    ),

                    // REPORTS SECTION
                    _buildDrawerSectionHeader('REPORTS', Colors.green),
                    ListTile(
                      leading: Icon(Icons.history, color: Colors.green),
                      title: Text('Course History', style: TextStyle(fontSize: 16)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/history');
                      },
                    ),

                    // ADMINISTRATION SECTION
                    _buildDrawerSectionHeader('ADMINISTRATION', Colors.red),
                    ListTile(
                      leading: Icon(Icons.settings, color: Colors.red),
                      title: Text('Settings', style: TextStyle(fontSize: 16)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SettingsPage()),
                        );
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.person, color: Colors.red),
                      title: Text('Profile', style: TextStyle(fontSize: 16)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/user_profile');
                      },
                    ),
                  ],
                ),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text('Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onTap: () => _logout(context),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade50, Colors.deepPurple.shade100],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Default Password Warning
              const DefaultPasswordWarningWidget(),
              SizedBox(height: 24),

              // Welcome Section
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple.shade600, Colors.deepPurple.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Manage your courses and track student attendance',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 32),

              // Statistics Cards - 3 Column Layout
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.calendar_today,
                      label: 'Today',
                      value: _dailyAttendanceCount.toString(),
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.school,
                      label: 'Courses',
                      value: _totalCoursesCount.toString(),
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.group,
                      label: 'Students',
                      value: _totalStudentsCount.toString(),
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.refresh,
                      label: 'Refresh',
                      value: '↻',
                      color: Colors.purple,
                      onTap: _loadDashboardData,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 32),

              // Quick Actions Title
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),

              SizedBox(height: 16),

              // Quick Actions Grid (2x2)
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildActionCard(
                    icon: Icons.check_circle,
                    title: 'Mark Attendance',
                    color: Colors.deepPurple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AttendancePage(courseId: '', sessionId: ''),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    icon: Icons.view_list,
                    title: 'View Reports',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AttendanceViewPage()),
                      );
                    },
                  ),
                  _buildActionCard(
                    icon: Icons.group,
                    title: 'View Students',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pushNamed(context, '/joined_students');
                    },
                  ),
                  _buildActionCard(
                    icon: Icons.history,
                    title: 'Course History',
                    color: Colors.red,
                    onTap: () {
                      Navigator.pushNamed(context, '/history');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


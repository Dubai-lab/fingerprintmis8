import 'dart:async';
import 'package:fingerprintmis8/activity_page.dart';
import 'package:fingerprintmis8/admin_attendance_reports_page.dart';
import 'package:fingerprintmis8/admin_registration_page.dart';
import 'package:fingerprintmis8/join_students_page.dart';
import 'package:fingerprintmis8/joined_students_page.dart';
import 'package:fingerprintmis8/manage_courses_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'student_registration_page.dart';
import 'package:fingerprintmis8/create_courses_page.dart';
import 'package:fingerprintmis8/student_verification_page.dart';
import 'admin_dashboard_chart.dart';
import 'package:fingerprintmis8/auth/registeration_page.dart';
import 'package:fingerprintmis8/manage_scheduled_activities_page.dart';
import 'package:fingerprintmis8/manage_departments_page.dart';
import 'package:fingerprintmis8/manage_conferences_page.dart';
import 'package:fingerprintmis8/conference_attendance_report_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({Key? key}) : super(key: key);

  @override
  _AdminDashboardPageState createState() => _AdminDashboardPageState();
}



class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int studentCount = 0;
  int instructorCount = 0;
  int invigilatorCount = 0;
  int securityCount = 0;
  bool loading = true;

  StreamSubscription? _studentsSubscription;
  StreamSubscription? _instructorsSubscription;
  StreamSubscription? _invigilatorsSubscription;
  StreamSubscription? _securitySubscription;

  @override
  void initState() {
    super.initState();
    _listenToCounts();
  }

  void _listenToCounts() {
    _studentsSubscription = FirebaseFirestore.instance.collection('students').snapshots().listen((snapshot) {
      setState(() {
        studentCount = snapshot.size;
      });
    });

    _instructorsSubscription = FirebaseFirestore.instance.collection('instructors').snapshots().listen((snapshot) {
      setState(() {
        instructorCount = snapshot.size;
      });
    });

    _invigilatorsSubscription = FirebaseFirestore.instance.collection('invigilators').snapshots().listen((snapshot) {
      setState(() {
        invigilatorCount = snapshot.size;
        loading = false;
      });
    });

    _securitySubscription = FirebaseFirestore.instance.collection('security').snapshots().listen((snapshot) {
      print('Security snapshot received with ${snapshot.size} documents');
      for (var doc in snapshot.docs) {
        print('Security doc id: ${doc.id}, data: ${doc.data()}');
      }
      setState(() {
        securityCount = snapshot.size;
        print('Security count updated: $securityCount');
      });
    });
  }

  @override
  void dispose() {
    _studentsSubscription?.cancel();
    _instructorsSubscription?.cancel();
    _invigilatorsSubscription?.cancel();
    _securitySubscription?.cancel();
    super.dispose();
  }

  Widget _buildDrawerSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
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
        title: Text('Admin Dashboard'),
        backgroundColor: Colors.deepPurple,
        elevation: 4,
        centerTitle: true,
      ),
      drawer: Drawer(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // ============ DRAWER HEADER ============
                  DrawerHeader(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.admin_panel_settings, size: 48, color: Colors.white),
                        SizedBox(height: 12),
                        Text(
                          'Admin Portal',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Management Panel',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ============ HOME ============
                  ListTile(
                    leading: Icon(Icons.dashboard, color: Colors.deepPurple),
                    title: Text('Dashboard', style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacementNamed(context, '/admin_dashboard');
                    },
                  ),

                  Divider(height: 20),

                  // ============ REGISTRATION SECTION ============
                  _buildDrawerSectionHeader('REGISTRATION', Colors.purple),
                  ListTile(
                    leading: Icon(Icons.person_add, color: Colors.purple),
                    title: Text('Register Student'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => StudentRegistrationPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.person_add_alt_1, color: Colors.purple),
                    title: Text('Staff Registration'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RegistrationPage()),
                      );
                    },
                  ),

                  Divider(height: 20),

                  // ============ COURSES SECTION ============
                  _buildDrawerSectionHeader('COURSES', Colors.blue),
                  ListTile(
                    leading: Icon(Icons.add_circle, color: Colors.blue),
                    title: Text('Create Course'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CreateCoursesPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.edit, color: Colors.blue),
                    title: Text('Manage Courses'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ManageCoursesPage()),
                      );
                    },
                  ),

                  Divider(height: 20),

                  // ============ STUDENTS SECTION ============
                  _buildDrawerSectionHeader('STUDENTS', Colors.green),
                  ListTile(
                    leading: Icon(Icons.verified_user, color: Colors.green),
                    title: Text('Verify Students'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => StudentVerificationPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.group_add, color: Colors.green),
                    title: Text('Join Students'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => JoinStudentsPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.apartment, color: Colors.green),
                    title: Text('Manage Departments'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ManageDepartmentsPage()),
                      );
                    },
                  ),

                  Divider(height: 20),

                  // ============ ACTIVITIES SECTION ============
                  _buildDrawerSectionHeader('ACTIVITIES & REPORTS', Colors.orange),
                  ListTile(
                    leading: Icon(Icons.schedule, color: Colors.orange),
                    title: Text('Schedule Activity'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ActivityPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.list, color: Colors.orange),
                    title: Text('Manage Activities'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ManageScheduledActivitiesPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.assessment, color: Colors.orange),
                    title: Text('View Reports'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AdminAttendanceReportsPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.event, color: Colors.orange),
                    title: Text('Manage Conferences'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ManageConferencesPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.assessment_outlined, color: Colors.orange),
                    title: Text('Conference Reports'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ConferenceAttendanceReportPage()),
                      );
                    },
                  ),

                  Divider(height: 20),

                  // ============ ADMINISTRATION SECTION ============
                  _buildDrawerSectionHeader('ADMINISTRATION', Colors.red),
                  ListTile(
                    leading: Icon(Icons.group, color: Colors.red),
                    title: Text('User Management'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/user_management');
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.settings, color: Colors.red),
                    title: Text('Settings'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/settings');
                    },
                  ),
                ],
              ),
            ),
            Divider(height: 1),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.grey.shade700),
              title: Text('Logout', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(context);
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: null,
      body: loading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ============ WELCOME SECTION ============
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [Colors.deepPurple.shade300, Colors.deepPurple.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.admin_panel_settings, size: 40, color: Colors.white),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome, Admin',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      DateTime.now().toString().split('.').first,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 24),

                  // ============ COUNT BOXES ============
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(child: _buildCountBox('Students', studentCount, Colors.blue)),
                      SizedBox(width: 8),
                      Expanded(child: _buildCountBox('Instructors', instructorCount, Colors.green)),
                      SizedBox(width: 8),
                      Expanded(child: _buildCountBox('Invigilators', invigilatorCount, Colors.orange)),
                      SizedBox(width: 8),
                      Expanded(child: _buildCountBox('Security', securityCount, Colors.red)),
                    ],
                  ),

                  SizedBox(height: 28),

                  // ============ QUICK ACTIONS TITLE ============
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),

                  SizedBox(height: 16),

                  // ============ REGISTRATION SECTION ============
                  _buildActionCategory(
                    'REGISTRATION',
                    Colors.purple,
                    [
                      _buildQuickActionButton(
                        'Register Student',
                        Icons.person_add,
                        Colors.purple,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => StudentRegistrationPage()),
                        ),
                      ),
                      _buildQuickActionButton(
                        'Staff Registration',
                        Icons.person_add_alt_1,
                        Colors.purple,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => RegistrationPage()),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // ============ COURSES SECTION ============
                  _buildActionCategory(
                    'COURSES',
                    Colors.blue,
                    [
                      _buildQuickActionButton(
                        'Create Course',
                        Icons.add_circle,
                        Colors.blue,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => CreateCoursesPage()),
                        ),
                      ),
                      _buildQuickActionButton(
                        'Manage Courses',
                        Icons.edit,
                        Colors.blue,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ManageCoursesPage()),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // ============ STUDENTS SECTION ============
                  _buildActionCategory(
                    'STUDENTS',
                    Colors.green,
                    [
                      _buildQuickActionButton(
                        'Verify Students',
                        Icons.verified_user,
                        Colors.green,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => StudentVerificationPage()),
                        ),
                      ),
                      _buildQuickActionButton(
                        'Join Students',
                        Icons.group_add,
                        Colors.green,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => JoinStudentsPage()),
                        ),
                      ),
                      _buildQuickActionButton(
                        'Manage Departments',
                        Icons.apartment,
                        Colors.green,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ManageDepartmentsPage()),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // ============ ACTIVITIES SECTION ============
                  _buildActionCategory(
                    'ACTIVITIES & REPORTS',
                    Colors.orange,
                    [
                      _buildQuickActionButton(
                        'Schedule Activity',
                        Icons.schedule,
                        Colors.orange,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ActivityPage()),
                        ),
                      ),
                      _buildQuickActionButton(
                        'Manage Activities',
                        Icons.list,
                        Colors.orange,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ManageScheduledActivitiesPage()),
                        ),
                      ),
                      _buildQuickActionButton(
                        'View Reports',
                        Icons.assessment,
                        Colors.orange,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AdminAttendanceReportsPage()),
                        ),
                      ),
                      _buildQuickActionButton(
                        'Manage Conferences',
                        Icons.event,
                        Colors.orange,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ManageConferencesPage()),
                        ),
                      ),
                      _buildQuickActionButton(
                        'Conference Reports',
                        Icons.assessment_outlined,
                        Colors.orange,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ConferenceAttendanceReportPage()),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // ============ SETTINGS SECTION ============
                  _buildActionCategory(
                    'ADMINISTRATION',
                    Colors.red,
                    [
                      _buildQuickActionButton(
                        'User Management',
                        Icons.group,
                        Colors.red,
                        () => Navigator.pushNamed(context, '/user_management'),
                      ),
                      _buildQuickActionButton(
                        'Settings',
                        Icons.settings,
                        Colors.red,
                        () => Navigator.pushNamed(context, '/settings'),
                      ),
                    ],
                  ),

                  SizedBox(height: 28),

                  // ============ CHART SECTION ============
                  Text(
                    'System Overview',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),

                  SizedBox(height: 16),

                  AdminDashboardChart(
                    studentCount: studentCount,
                    instructorCount: instructorCount,
                    invigilatorCount: invigilatorCount,
                    securityCount: securityCount,
                  ),

                  SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildCountBox(String label, int count, Color color) {
    IconData icon;
    switch (label) {
      case 'Students':
        icon = Icons.school;
        break;
      case 'Instructors':
        icon = Icons.person_3;
        break;
      case 'Invigilators':
        icon = Icons.supervisor_account;
        break;
      case 'Security':
        icon = Icons.security;
        break;
      default:
        icon = Icons.info;
    }

    return Card(
      elevation: 4,
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
            Icon(
              icon,
              size: 40,
              color: color,
            ),
            SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCategory(String title, Color color, List<Widget> buttons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Header
        Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        // Buttons Grid
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          children: buttons,
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.05), color.withOpacity(0.02)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: color.withOpacity(0.2), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: color,
              ),
              SizedBox(height: 12),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

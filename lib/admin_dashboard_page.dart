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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
      ),
      drawer: Drawer(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                    ),
                    child: Text(
                      'Admin Menu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.dashboard, color: Colors.deepPurple),
                    title: Text('Dashboard', style: TextStyle(fontSize: 18)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacementNamed(context, '/admin_dashboard');
                    },
                  ),
                   Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Registeration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.person_add),
                    title: Text('Student Registration'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => StudentRegistrationPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.person_add_sharp),
                    title: Text('Admin Registration'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AdminRegistrationPage()),
                      );
                    },
                  ),
                  Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Others',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromARGB(255, 142, 22, 179),
                      ),
                    ),
                  ),
                  ListTile(
              leading: Icon(Icons.person_add, color: Colors.deepPurple),
              title: Text('Staff Registration'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegistrationPage()),
                );
              },
            ),
                  ListTile(
                    leading: Icon(Icons.group, color: Colors.deepPurple),
                    title: Text('User Management'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/user_management');
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.verified_user, color: Colors.deepPurple),
                    title: Text('Student Verification'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => StudentVerificationPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.book, color: Colors.deepPurple),
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
                    leading: Icon(Icons.book, color: Colors.deepPurple),
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
                    leading: Icon(Icons.schedule, color: Colors.deepPurple),
                    title: Text('Manage Scheduled Activities'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ManageScheduledActivitiesPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.group_add, color: Colors.deepPurple),
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
                    leading: Icon(Icons.group, color: Colors.deepPurple),
                    title: Text('Joined Students'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => JoinedStudentsPage()),
                      );
                    },
                  ),
                   ListTile(
              leading: Icon(Icons.book, color: Colors.deepPurple),
              title: Text('Manage Courses'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ManageCoursesPage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.assessment, color: Colors.deepPurple),
              title: Text('CAT & EXAM Reports'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminAttendanceReportsPage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.settings, color: Colors.deepPurple),
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
              leading: Icon(Icons.logout),
              title: Text('Logout'),
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
                  
                  SizedBox(height: 20),
                  Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: const Color.fromARGB(255, 0, 0, 0)),
                  ),
                  SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      double buttonWidth = (constraints.maxWidth - 12) / 2;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: buttonWidth,
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.person_add),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Register Student'),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => StudentRegistrationPage()),
                                );
                              },
                            ),
                          ),
                          SizedBox(
                            width: buttonWidth,
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.person_add_alt_1),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Staff Registration'),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => RegistrationPage()),
                                );
                              },
                            ),
                          ),
                          SizedBox(
                            width: buttonWidth,
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.book),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Create Course'),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => CreateCoursesPage()),
                                );
                              },
                            ),
                          ),
                          SizedBox(
                            width: buttonWidth,
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.verified_user),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Student Verification'),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => StudentVerificationPage()),
                                );
                              },
                            ),
                          ),
                          SizedBox(
                            width: buttonWidth,
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.book),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Manage Courses'),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => ManageCoursesPage()),
                                );
                              },
                            ),
                          ),
                          SizedBox(
                            width: buttonWidth,
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.group),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('User Management'),
                              ),
                              onPressed: () {
                                Navigator.pushNamed(context, '/user_management');
                              },
                            ),
                          ),
                          SizedBox(
                            width: buttonWidth,
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.group_add),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Join Students'),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => JoinStudentsPage()),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Chart Graph',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromARGB(255, 0, 0, 0),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  AdminDashboardChart(
                    studentCount: studentCount,
                    instructorCount: instructorCount,
                    invigilatorCount: invigilatorCount,
                    securityCount: securityCount,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCountBox(String label, int count, Color color) {
    return Container(
      // width: 100,  // Removed fixed width to allow Expanded to control size
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: color,
            ),
          ),
          SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

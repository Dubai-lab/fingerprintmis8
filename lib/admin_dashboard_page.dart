import 'dart:async';
import 'package:fingerprintmis8/admin_registration_page.dart';
import 'package:fingerprintmis8/join_students_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'student_registration_page.dart';
import 'instructor_registration_page.dart';
import 'invigilator_registration_page.dart';
import 'package:fingerprintmis8/create_courses_page.dart';
import 'package:fingerprintmis8/student_verification_page.dart';
import 'package:fingerprintmis8/security_registration_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({Key? key}) : super(key: key);

  @override
  _AdminDashboardPageState createState() => _AdminDashboardPageState();
}



class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int studentCount = 0;
  int instructorCount = 0;
  int invigilatorCount = 0;
  bool loading = true;

  StreamSubscription? _studentsSubscription;
  StreamSubscription? _instructorsSubscription;
  StreamSubscription? _invigilatorsSubscription;

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
  }

  @override
  void dispose() {
    _studentsSubscription?.cancel();
    _instructorsSubscription?.cancel();
    _invigilatorsSubscription?.cancel();
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Registrations',
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
                    leading: Icon(Icons.person_add_alt_1),
                    title: Text('Instructor Registration'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => InstructorRegistrationPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.person_search),
                    title: Text('Invigilator Registration'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => InvigilatorRegistrationPage()),
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
                  ListTile(
                    leading: Icon(Icons.security),
                    title: Text('Security Registration'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SecurityRegistrationPage()),
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
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.group),
                    title: Text('User Management'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/user_management');
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.verified_user),
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
                    leading: Icon(Icons.book),
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
                    leading: Icon(Icons.group_add),
                    title: Text('Join Students to Course'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => JoinStudentsPage()),
                      );
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
      body: Center(
        child: loading
            ? CircularProgressIndicator()
            : Column(
                children: [
                  SizedBox(height: 20),
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade100,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildCountBox('Students', studentCount, Colors.blue),
                        _buildCountBox('Instructors', instructorCount, Colors.green),
                        _buildCountBox('Invigilators', invigilatorCount, Colors.orange),
                      ],
                    ),
                  ),
                  SizedBox(height: 40),
                  Text('Welcome to the Admin Dashboard', style: TextStyle(fontSize: 20)),
                  SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ElevatedButton.icon(
                          icon: Icon(Icons.person_add),
                          label: Text('Register Student'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => StudentRegistrationPage()),
                            );
                          },
                        ),
                        ElevatedButton.icon(
                          icon: Icon(Icons.person_add_alt_1),
                          label: Text('Register Instructor'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => InstructorRegistrationPage()),
                            );
                          },
                        ),
                        ElevatedButton.icon(
                          icon: Icon(Icons.book),
                          label: Text('Create Course'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => CreateCoursesPage()),
                            );
                          },
                        ),
                        ElevatedButton.icon(
                          icon: Icon(Icons.group),
                          label: Text('User Management'),
                          onPressed: () {
                            Navigator.pushNamed(context, '/user_management');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCountBox(String label, int count, Color color) {
    return Container(
      width: 100,
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

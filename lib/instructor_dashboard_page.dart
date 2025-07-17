import 'package:fingerprintmis8/attendance_page.dart';
import 'package:fingerprintmis8/attendance_view_page.dart';
import 'package:fingerprintmis8/instructor_settings_page.dart';
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
  bool _showChangePasswordPrompt = false;

  @override
  void initState() {
    super.initState();
    _fetchDailyAttendanceCount();
    _checkDefaultPassword();
  }

  void _checkDefaultPassword() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    final userDoc = await FirebaseFirestore.instance.collection('instructors').doc(userId).get();
    if (userDoc.exists) {
      bool defaultPassword = userDoc.get('defaultPassword') ?? false;
      String role = userDoc.get('role') ?? '';
      if (defaultPassword && role != 'admin') {
        setState(() {
          _showChangePasswordPrompt = true;
        });
      }
    }
  }

  void _fetchDailyAttendanceCount() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    try {
      // Fetch all courses for the instructor
      final coursesSnapshot = await FirebaseFirestore.instance
          .collection('instructor_courses')
          .where('instructorId', isEqualTo: userId)
          .get();

      int totalAttendanceCount = 0;

      for (var courseDoc in coursesSnapshot.docs) {
        final attendanceSnapshot = await FirebaseFirestore.instance
            .collection('instructor_courses')
            .doc(courseDoc.id)
            .collection('attendance')
            .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
            .get();

        totalAttendanceCount += attendanceSnapshot.size;
      }

      setState(() {
        _dailyAttendanceCount = totalAttendanceCount;
      });
    } catch (e) {
      // Handle error if needed
      setState(() {
        _dailyAttendanceCount = 0;
      });
    }
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
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
        child: Column(
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple, Colors.purpleAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'Instructor Menu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: Icon(Icons.dashboard, color: Colors.deepPurple),
                    title: Text('Dashboard', style: TextStyle(fontSize: 18)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacementNamed(context, '/instructor_dashboard');
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.check_circle, color: Colors.deepPurple),
                    title: Text('Attendance', style: TextStyle(fontSize: 18)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AttendancePage(courseId: '', sessionId: '',)),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.view_list, color: Colors.deepPurple),
                    title: Text('View Attendance', style: TextStyle(fontSize: 18)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AttendanceViewPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.settings, color: Colors.deepPurple),
                    title: Text('Settings', style: TextStyle(fontSize: 18)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => InstructorSettingsPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.history, color: Colors.deepPurple),
              title: Text('Course History', style: TextStyle(fontSize: 18)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/history');
              },
            ),
            Divider(height: 1),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.deepPurple),
              title: Text('Logout', style: TextStyle(fontSize: 18)),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            if (_showChangePasswordPrompt)
              Card(
                color: Colors.amber.shade100,
                margin: EdgeInsets.only(bottom: 20),
                child: ListTile(
                  leading: Icon(Icons.warning, color: Colors.amber.shade800),
                  title: Text(
                    'You are using a default password. Please change it.',
                    style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.bold),
                  ),
                  trailing: ElevatedButton(
                    child: Text('Change Password'),
                    onPressed: () {
                      Navigator.pushNamed(context, '/change-password');
                    },
                  ),
                ),
              ),
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                leading: Icon(Icons.calendar_today, color: Colors.deepPurple, size: 40),
                title: Text(
                  'Daily Attendance',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '$_dailyAttendanceCount',
                  style: TextStyle(fontSize: 18, color: Colors.black87),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.refresh, color: Colors.deepPurple),
                  onPressed: _fetchDailyAttendanceCount,
                ),
              ),
            ),
            SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => AttendancePage(courseId: '', sessionId: '',)),
                        );
                      },
                      child: Container(
                        height: 120,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 50, color: Colors.deepPurple),
                            SizedBox(height: 10),
                            Text(
                              'Attendance',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 30),
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AttendanceViewPage()),
                  );
                },
                child: Container(
                  height: 60,
                  alignment: Alignment.center,
                  child: Text(
                    'View Attendance Report',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
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


import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InvigilatorDashboardPage extends StatefulWidget {
  const InvigilatorDashboardPage({Key? key}) : super(key: key);

  @override
  _InvigilatorDashboardPageState createState() => _InvigilatorDashboardPageState();
}

class _InvigilatorDashboardPageState extends State<InvigilatorDashboardPage> {
  bool _showChangePasswordPrompt = false;

  @override
  void initState() {
    super.initState();
    _checkDefaultPassword();
  }

  void _checkDefaultPassword() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    final userDoc = await FirebaseFirestore.instance.collection('invigilators').doc(userId).get();
    if (userDoc.exists) {
      bool defaultPassword = userDoc.get('defaultPassword') ?? false;
      if (defaultPassword) {
        setState(() {
          _showChangePasswordPrompt = true;
        });
      }
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
        title: Text('Invigilator Dashboard'),
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
                      'Invigilator Menu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.check_circle_outline, color: Colors.deepPurple),
                    title: Text('Invigilator Attendance'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/invigilator_attendance');
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.list_alt, color: Colors.deepPurple),
                    title: Text('Invigilator Attendance Report'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/invigilator_attendance_report');
                    },
                  ),
                ],
              ),
            ),
            Divider(height: 1),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            Text(
              'Welcome to the Invigilator Dashboard',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            ElevatedButton.icon(
              icon: Icon(Icons.check_circle_outline, size: 28, color: Colors.white),
              label: Text('Invigilator Attendance', style: TextStyle(fontSize: 22, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                minimumSize: Size(double.infinity, 60),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/invigilator_attendance');
              },
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              icon: Icon(Icons.list_alt, size: 28, color: Colors.white),
              label: Text('Invigilator Attendance Report', style: TextStyle(fontSize: 22, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                minimumSize: Size(double.infinity, 60),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/invigilator_attendance_report');
              },
            ),
          ],
        ),
      ),
    );
  }
}

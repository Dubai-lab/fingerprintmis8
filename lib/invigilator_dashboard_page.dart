import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fingerprintmis8/widgets/default_password_warning_widget.dart';

class InvigilatorDashboardPage extends StatefulWidget {
  const InvigilatorDashboardPage({Key? key}) : super(key: key);

  @override
  _InvigilatorDashboardPageState createState() => _InvigilatorDashboardPageState();
}

class _InvigilatorDashboardPageState extends State<InvigilatorDashboardPage> {

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
            const DefaultPasswordWarningWidget(),
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

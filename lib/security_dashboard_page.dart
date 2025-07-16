import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'student_verification_page.dart';
import 'security_registration_page.dart';

class SecurityDashboardPage extends StatefulWidget {
  const SecurityDashboardPage({Key? key}) : super(key: key);

  @override
  _SecurityDashboardPageState createState() => _SecurityDashboardPageState();
}

class _SecurityDashboardPageState extends State<SecurityDashboardPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Security Dashboard'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: StudentVerificationPage(),
    );
  }
}

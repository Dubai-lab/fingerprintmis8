import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'student_verification_page.dart';
import 'security_registration_page.dart';

class SecurityDashboardPage extends StatefulWidget {
  const SecurityDashboardPage({Key? key}) : super(key: key);

  @override
  _SecurityDashboardPageState createState() => _SecurityDashboardPageState();
}

class _SecurityDashboardPageState extends State<SecurityDashboardPage> {
  bool _showChangePasswordPrompt = false;

  @override
  void initState() {
    super.initState();
    _checkDefaultPassword();
  }

  void _checkDefaultPassword() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    final userDoc = await FirebaseFirestore.instance.collection('security').doc(userId).get();
    if (userDoc.exists) {
      bool defaultPassword = userDoc.get('defaultPassword') ?? false;
      if (defaultPassword) {
        setState(() {
          _showChangePasswordPrompt = true;
        });
      }
    }
  }

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
      body: Column(
        children: [
          if (_showChangePasswordPrompt)
            Card(
              color: Colors.amber.shade100,
              margin: EdgeInsets.all(10),
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
          Expanded(child: StudentVerificationPage()),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
        automaticallyImplyLeading: false,
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
                      'Security Menu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.verified_user, color: Colors.deepPurple),
                    title: Text('Security Verification'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/security_verification');
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
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: Icon(Icons.verified_user),
              label: Text('Go to Security Verification'),
              onPressed: () {
                Navigator.pushNamed(context, '/security_verification');
              },
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

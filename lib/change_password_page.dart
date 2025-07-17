import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({Key? key}) : super(key: key);

  @override
  _ChangePasswordPageState createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  String _status = 'Idle';
  bool _loading = false;

  Future<void> _changePassword() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _status = 'Passwords do not match';
      });
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Changing password...';
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _status = 'No user logged in';
          _loading = false;
        });
        return;
      }

      await user.updatePassword(_passwordController.text);
      await user.reload();

      // Update Firestore to clear defaultPassword flag
      // Try updating in instructors, invigilators, and security collections
      try {
        await FirebaseFirestore.instance.collection('instructors').doc(user.uid).update({
          'defaultPassword': false,
          'passwordSetTime': null,
        });
      } catch (_) {
        try {
          await FirebaseFirestore.instance.collection('invigilators').doc(user.uid).update({
            'defaultPassword': false,
            'passwordSetTime': null,
          });
        } catch (_) {
          await FirebaseFirestore.instance.collection('security').doc(user.uid).update({
            'defaultPassword': false,
            'passwordSetTime': null,
          });
        }
      }

      setState(() {
        _status = 'Password changed successfully';
      });

      // Navigate to appropriate dashboard or login page
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      setState(() {
        _status = 'Failed to change password: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Change Password'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade200, Colors.deepPurple.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: EdgeInsets.all(16),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              color: Colors.white.withOpacity(0.9),
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Change Your Password',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      SizedBox(height: 20),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Icon(Icons.lock_outline, color: Colors.deepPurple),
                        ),
                        obscureText: true,
                        validator: (value) =>
                            value == null || value.length < 6 ? 'Password must be at least 6 characters' : null,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Icon(Icons.lock_outline, color: Colors.deepPurple),
                        ),
                        obscureText: true,
                        validator: (value) =>
                            value == null || value.length < 6 ? 'Password must be at least 6 characters' : null,
                      ),
                      SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                          backgroundColor: Colors.deepPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _loading ? null : _changePassword,
                        child: _loading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                                'Change Password',
                                style: TextStyle(fontSize: 18, color: Colors.white),
                              ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        _status,
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

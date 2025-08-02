import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({Key? key}) : super(key: key);

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}


class _UserProfilePageState extends State<UserProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  String? _role;
  String? _userId;
  bool _loading = true;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _loading = true;
      _status = '';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _status = 'No user logged in';
          _loading = false;
        });
        return;
      }
      _userId = user.uid;

      // Try to find user role and data in collections: instructors, invigilators, security
      final firestore = FirebaseFirestore.instance;

      final instructorDoc = await firestore.collection('instructors').doc(_userId).get();
      if (instructorDoc.exists) {
        _role = 'instructor';
        final data = instructorDoc.data()!;
        _nameController.text = data['name'] ?? '';
        _emailController.text = data['email'] ?? user.email ?? '';
        setState(() {
          _loading = false;
        });
        return;
      }

      final invigilatorDoc = await firestore.collection('invigilators').doc(_userId).get();
      if (invigilatorDoc.exists) {
        _role = 'invigilator';
        final data = invigilatorDoc.data()!;
        _nameController.text = data['name'] ?? '';
        _emailController.text = data['email'] ?? user.email ?? '';
        setState(() {
          _loading = false;
        });
        return;
      }

      final securityDoc = await firestore.collection('security').doc(_userId).get();
      if (securityDoc.exists) {
        _role = 'security';
        final data = securityDoc.data()!;
        _nameController.text = data['name'] ?? '';
        _emailController.text = data['email'] ?? user.email ?? '';
        setState(() {
          _loading = false;
        });
        return;
      }

      setState(() {
        _status = 'User profile not found';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to load profile: $e';
        _loading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) return;

    setState(() {
      _status = '';
      _loading = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();

      if (_role == 'instructor') {
        await firestore.collection('instructors').doc(_userId).update({
          'name': name,
          'email': email,
        });
      } else if (_role == 'invigilator') {
        await firestore.collection('invigilators').doc(_userId).update({
          'name': name,
          'email': email,
        });
      } else if (_role == 'security') {
        await firestore.collection('security').doc(_userId).update({
          'name': name,
          'email': email,
        });
      } else {
        setState(() {
          _status = 'Unknown user role';
          _loading = false;
        });
        return;
      }

      setState(() {
        _status = 'Profile updated successfully';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to update profile: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Profile'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (_status.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Text(
                            _status,
                            style: TextStyle(
                              color: _status.toLowerCase().contains('success') ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: Icon(Icons.person, color: Colors.deepPurple),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Enter your name' : null,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: Icon(Icons.email, color: Colors.deepPurple),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Enter your email';
                          final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                          if (!emailRegex.hasMatch(value)) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                          backgroundColor: Colors.deepPurple,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Save Profile', style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

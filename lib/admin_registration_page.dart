import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminRegistrationPage extends StatefulWidget {
  @override
  _AdminRegistrationPageState createState() => _AdminRegistrationPageState();
}

class _AdminRegistrationPageState extends State<AdminRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _status = 'Idle';

  Future<void> _saveAdmin() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) return;

    String name = _nameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await FirebaseFirestore.instance.collection('admins').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'role': 'admin',
      });

      setState(() {
        _status = 'Admin registered successfully';
        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to save admin: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Registration'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text('Status: $_status'),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Admin Name'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter admin name' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter email' : null,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter password' : null,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveAdmin,
                child: Text('Save Admin'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

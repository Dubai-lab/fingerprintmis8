import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InvigilatorRegistrationPage extends StatefulWidget {
  @override
  _InvigilatorRegistrationPageState createState() => _InvigilatorRegistrationPageState();
}

class _InvigilatorRegistrationPageState extends State<InvigilatorRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _status = 'Idle';

  Future<void> _saveInvigilator() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) return;

    String name = _nameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await FirebaseFirestore.instance.collection('invigilators').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'role': 'invigilator',
      });

      setState(() {
        _status = 'Invigilator registered successfully';
        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to save invigilator: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Invigilator Registration'),
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
                decoration: InputDecoration(labelText: 'Invigilator Name'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter invigilator name' : null,
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
                onPressed: _saveInvigilator,
                child: Text('Save Invigilator'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

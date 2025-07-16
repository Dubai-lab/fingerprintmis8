import 'package:flutter/material.dart';

class InstructorSettingsPage extends StatefulWidget {
  const InstructorSettingsPage({Key? key}) : super(key: key);

  @override
  _InstructorSettingsPageState createState() => _InstructorSettingsPageState();
}

class _InstructorSettingsPageState extends State<InstructorSettingsPage> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Instructor Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            SwitchListTile(
              title: Text('Enable Notifications'),
              value: _notificationsEnabled,
              onChanged: (bool value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
            ),
            Divider(),
            ListTile(
              title: Text('Change Password'),
              trailing: Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pushNamed(context, '/change-password');
              },
            ),
          ],
        ),
      ),
    );
  }
}

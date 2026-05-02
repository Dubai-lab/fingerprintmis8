import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fingerprintmis8/widgets/default_password_warning_widget.dart';

class InvigilatorDashboardPage extends StatefulWidget {
  const InvigilatorDashboardPage({Key? key}) : super(key: key);

  @override
  _InvigilatorDashboardPageState createState() => _InvigilatorDashboardPageState();
}

class _InvigilatorDashboardPageState extends State<InvigilatorDashboardPage> {
  int _todayAttendanceCount = 0;
  int _totalActivitiesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    await _fetchTodayAttendance();
    await _fetchActivitiesCount();
  }

  Future<void> _fetchTodayAttendance() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final snapshot = await FirebaseFirestore.instance
          .collection('invigilator_attendance')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .get();

      setState(() {
        _todayAttendanceCount = snapshot.size;
      });
    } catch (e) {
      setState(() {
        _todayAttendanceCount = 0;
      });
    }
  }

  Future<void> _fetchActivitiesCount() async {
    try {
      final now = DateTime.now();

      final snapshot = await FirebaseFirestore.instance
          .collection('scheduled_activities')
          .where('endDate', isGreaterThan: now)
          .get();

      setState(() {
        _totalActivitiesCount = snapshot.size;
      });
    } catch (e) {
      setState(() {
        _totalActivitiesCount = 0;
      });
    }
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  Widget _buildDrawerSectionHeader(String title, Color color) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Invigilator Dashboard'),
        backgroundColor: Colors.blue.shade700,
        elevation: 4,
        centerTitle: true,
      ),
      drawer: Drawer(
        child: Container(
          color: Colors.white,
          child: Column(
            children: <Widget>[
              // Modern Drawer Header with Gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: EdgeInsets.fromLTRB(20, 40, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_user, size: 48, color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'Invigilator',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Control Panel',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // ATTENDANCE SECTION
                    _buildDrawerSectionHeader('ATTENDANCE', Colors.blue),
                    ListTile(
                      leading: Icon(Icons.dashboard, color: Colors.blue),
                      title: Text('Dashboard', style: TextStyle(fontSize: 16)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushReplacementNamed(context, '/invigilator_dashboard');
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.check_circle_outline, color: Colors.blue),
                      title: Text('Mark Attendance', style: TextStyle(fontSize: 16)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/invigilator_attendance');
                      },
                    ),

                    // REPORTS SECTION
                    _buildDrawerSectionHeader('REPORTS', Colors.orange),
                    ListTile(
                      leading: Icon(Icons.list_alt, color: Colors.orange),
                      title: Text('Attendance Report', style: TextStyle(fontSize: 16)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/invigilator_attendance_report');
                      },
                    ),

                    // ADMINISTRATION SECTION
                    _buildDrawerSectionHeader('ADMINISTRATION', Colors.red),
                    ListTile(
                      leading: Icon(Icons.settings, color: Colors.red),
                      title: Text('Settings', style: TextStyle(fontSize: 16)),
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
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text('Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onTap: () => _logout(context),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade100],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Default Password Warning
              const DefaultPasswordWarningWidget(),
              SizedBox(height: 24),

              // Welcome Section
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Monitor and record student attendance',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 32),

              // Statistics Cards - 2 Column Layout
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.calendar_today,
                      label: 'Today',
                      value: _todayAttendanceCount.toString(),
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.event,
                      label: 'Activities',
                      value: _totalActivitiesCount.toString(),
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.refresh,
                      label: 'Refresh',
                      value: '↻',
                      color: Colors.blue,
                      onTap: _loadDashboardData,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Container(), // Placeholder for balance
                  ),
                ],
              ),

              SizedBox(height: 32),

              // Quick Actions Title
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),

              SizedBox(height: 16),

              // Quick Actions Grid (2x2)
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildActionCard(
                    icon: Icons.check_circle_outline,
                    title: 'Mark Attendance',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pushNamed(context, '/invigilator_attendance');
                    },
                  ),
                  _buildActionCard(
                    icon: Icons.list_alt,
                    title: 'View Reports',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pushNamed(context, '/invigilator_attendance_report');
                    },
                  ),
                  _buildActionCard(
                    icon: Icons.event,
                    title: 'Activities',
                    color: Colors.green,
                    onTap: () {
                      // Can be expanded for activities management
                    },
                  ),
                  _buildActionCard(
                    icon: Icons.settings,
                    title: 'Settings',
                    color: Colors.red,
                    onTap: () {
                      Navigator.pushNamed(context, '/settings');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

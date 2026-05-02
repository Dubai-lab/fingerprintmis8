import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fingerprintmis8/widgets/default_password_warning_widget.dart';

class SecurityDashboardPage extends StatefulWidget {
  const SecurityDashboardPage({Key? key}) : super(key: key);

  @override
  _SecurityDashboardPageState createState() => _SecurityDashboardPageState();
}

class _SecurityDashboardPageState extends State<SecurityDashboardPage> {
  String _securityName = 'Security Officer';
  bool _isLoadingName = true;
  int _todayVerifications = 0;
  int _totalVerifications = 0; // NEW
  int _thisWeekVerifications = 0; // NEW
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadSecurityPersonnelData();
    _loadTodayVerifications();
  }

  Future<void> _loadSecurityPersonnelData() async {
    setState(() {
      _isLoadingName = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _securityName = 'Security Officer';
          _isLoadingName = false;
        });
        return;
      }

      final userId = user.uid;
      if (userId.isEmpty) {
        setState(() {
          _securityName = 'Security Officer';
          _isLoadingName = false;
        });
        return;
      }

      final userDoc = await FirebaseFirestore.instance.collection('security').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        String name = data['name'] ?? data['fullName'] ?? 'Security Officer';

        setState(() {
          _securityName = name;
          _isLoadingName = false;
        });
      } else {
        setState(() {
          _securityName = 'Security Officer';
          _isLoadingName = false;
        });
      }
    } catch (e) {
      print('Error loading security personnel data: $e');
      setState(() {
        _securityName = 'Security Officer';
        _isLoadingName = false;
      });
    }
  }

  Future<void> _loadTodayVerifications() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      // Get today's security verifications
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Query security verifications for today
      final todaySnapshot = await FirebaseFirestore.instance
          .collection('security_verifications')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThan: endOfDay)
          .get();

      // Get total verifications all time
      final totalSnapshot = await FirebaseFirestore.instance
          .collection('security_verifications')
          .get();

      // Get this week's verifications
      final weekAgo = today.subtract(const Duration(days: 7));
      final weekStartTime = DateTime(weekAgo.year, weekAgo.month, weekAgo.day);
      final weekSnapshot = await FirebaseFirestore.instance
          .collection('security_verifications')
          .where('timestamp', isGreaterThanOrEqualTo: weekStartTime)
          .get();

      setState(() {
        _todayVerifications = todaySnapshot.docs.length;
        _totalVerifications = totalSnapshot.docs.length;
        _thisWeekVerifications = weekSnapshot.docs.length;
        _isLoadingStats = false;
      });
    } catch (e) {
      print('Error loading security statistics: $e');
      setState(() {
        _todayVerifications = 0;
        _totalVerifications = 0;
        _thisWeekVerifications = 0;
        _isLoadingStats = false;
      });
    }
  }

  Widget _buildDrawerSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.deepPurple,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
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
        title: const Text('Security Dashboard'),
        backgroundColor: Colors.deepPurple,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTodayVerifications,
            tooltip: 'Refresh Statistics',
            color: Colors.black,
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.security, size: 48, color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    'Security Portal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Welcome, $_securityName',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerSectionHeader('VERIFICATION'),
                  ListTile(
                    leading: Icon(Icons.verified_user, color: Colors.deepPurple),
                    title: Text('Verify Students', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Fingerprint verification'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/security_verification');
                    },
                  ),
                  Divider(height: 20),
                  _buildDrawerSectionHeader('REPORTS'),
                  ListTile(
                    leading: Icon(Icons.analytics, color: Colors.deepPurple),
                    title: Text('View Statistics', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Verification analytics'),
                    onTap: () {
                      Navigator.pop(context);
                      _showStatisticsDialog(context);
                    },
                  ),
                  Divider(height: 20),
                  _buildDrawerSectionHeader('SETTINGS'),
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
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text('Logout', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section with Personal Name
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.security, size: 32, color: Colors.deepPurple),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _isLoadingName
                                  ? const Text(
                                      'Loading...',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepPurple,
                                      ),
                                    )
                                  : Text(
                                      'Welcome, $_securityName!',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepPurple.shade800,
                                      ),
                                    ),
                                const SizedBox(height: 4),
                                Text(
                                  'Fingerprint Verification System',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Default Password Warning Widget
              const DefaultPasswordWarningWidget(),

              const SizedBox(height: 24),

              // Statistics Section
              const Text(
                '📊 Today\'s Statistics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 16),

              _isLoadingStats
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Today',
                              _todayVerifications.toString(),
                              Icons.calendar_today,
                              Colors.blue,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'This Week',
                              _thisWeekVerifications.toString(),
                              Icons.show_chart,
                              Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Total',
                              _totalVerifications.toString(),
                              Icons.assessment,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

              const SizedBox(height: 32),

              // Quick Actions
              const Text(
                '⚡ Quick Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 16),

              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                children: [
                  _buildActionCard(
                    'Verify Students',
                    'Fingerprint scan',
                    Icons.verified_user,
                    Colors.deepPurple,
                    () => Navigator.pushNamed(context, '/security_verification'),
                  ),
                  _buildActionCard(
                    'View Reports',
                    'Statistics',
                    Icons.assessment,
                    Colors.orange,
                    () => _showStatisticsDialog(context),
                  ),
                  _buildActionCard(
                    'Device Status',
                    'Check device',
                    Icons.hardware,
                    Colors.green,
                    () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Device status: Ready')),
                    ),
                  ),
                  _buildActionCard(
                    'Settings',
                    'Preferences',
                    Icons.settings,
                    Colors.red,
                    () => Navigator.pushNamed(context, '/settings'),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Recent Activity Section
              const Text(
                '📋 Recent Activity',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 16),

              _buildRecentActivityCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, String description, IconData icon, Color color, VoidCallback onTap, {bool isFullWidth = false}) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 28, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Activity logs will appear here after verifications are performed.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• Go to Security Verification to start verifying students',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatisticsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verification Statistics'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatCard('Today\'s Verifications', _todayVerifications.toString(), Icons.fingerprint, Colors.green),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

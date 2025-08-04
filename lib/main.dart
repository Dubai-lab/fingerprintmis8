import 'package:fingerprintmis8/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'admin_dashboard_page.dart';
import 'student_registration_page.dart';
import 'fingerprint_enrollment_page.dart';
import 'attendance_page.dart';
import 'instructor_registration_page.dart';
import 'invigilator_registration_page.dart';
import 'instructor_dashboard_page.dart';
import 'invigilator_dashboard_page.dart';
import 'invigilator_attendance_page.dart';
import 'invigilator_attendance_report_page.dart';
import 'login_page.dart';
import 'invigilator_attendance_selection_page.dart';
import 'change_password_page.dart';
import 'admin_registration_page.dart';
import 'attendance_sessions_page.dart';
import 'attendance_view_page.dart';
import 'user_management_page.dart';
import 'security_registration_page.dart';
import 'security_dashboard_page.dart';
import 'security_verification_page.dart';
import 'manage_courses_page.dart';
import 'history_page.dart';
import 'joined_students_page.dart';
import 'user_profile_page.dart';
import 'settings_page.dart';
import 'change_user_password_page.dart';
import 'admin_attendance_reports_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fingerprint MIS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      initialRoute: '/login',
      routes: {
        '/admin_dashboard': (context) => const AdminDashboardPage(),
        '/student_registration': (context) => StudentRegistrationPage(),
        '/instructor_registration': (context) => InstructorRegistrationPage(),
        '/invigilator_registration': (context) => InvigilatorRegistrationPage(),
        '/instructor_dashboard': (context) => const InstructorDashboardPage(),
        '/invigilator_dashboard': (context) => const InvigilatorDashboardPage(),
        '/invigilator_attendance_selection': (context) => const InvigilatorAttendanceSelectionPage(),
        '/invigilator_attendance': (context) => const InvigilatorAttendancePage(),
        '/invigilator_attendance_report': (context) => const InvigilatorAttendanceReportPage(),
        '/attendance': (context) => AttendancePage(courseId: '', sessionId: ''),
        '/login': (context) => const LoginPage(),
        '/fingerprint_enrollment': (context) => FingerprintEnrollmentPage(),
        '/change-password': (context) => const ChangePasswordPage(),
        '/admin_registration': (context) => AdminRegistrationPage(),
        '/attendance_sessions': (context) => AttendanceSessionsPage(courseId: '', courseName: ''),
        '/attendance_view': (context) => const AttendanceViewPage(),
        '/user_management': (context) => const UserManagementPage(),
        '/security_registration': (context) => const SecurityRegistrationPage(),
        '/security_dashboard': (context) => const SecurityDashboardPage(),
        '/security_verification': (context) => SecurityVerificationPage(),
        '/manage_courses': (context) => ManageCoursesPage(),
        '/history': (context) => const HistoryPage(),
        '/joined_students': (context) => const JoinedStudentsPage(),
        '/user_profile': (context) => const UserProfilePage(),
        '/settings': (context) => const SettingsPage(),
        '/change_user_password': (context) => ChangeUserPasswordPage(),
        '/admin_attendance_reports': (context) => const AdminAttendanceReportsPage(),
      },
    );
  }
}

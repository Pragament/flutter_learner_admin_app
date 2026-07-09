import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/admin_firestore_service.dart';
import '../models/school.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'join_or_create_school_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _auth = AuthService();
  final _service = AdminFirestoreService();
  School? _school;
  bool _checkingSchool = false;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _auth.authState.listen((user) {
      if (user != null && user != _currentUser) {
        _currentUser = user;
        _checkSchool(user);
      } else if (user == null) {
        setState(() {
          _currentUser = null;
          _school = null;
        });
      }
    });
  }

  Future<void> _checkSchool(User user) async {
    setState(() => _checkingSchool = true);
    final school = await _service.findSchoolByStaffEmail(user.email ?? '');
    if (mounted) {
      setState(() {
        _school = school;
        _checkingSchool = false;
      });
    }
  }

  // Called after joining/creating school to refresh
  void refreshSchool() {
    if (_currentUser != null) _checkSchool(_currentUser!);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authState,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting ||
            _checkingSchool) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Checking access...'),
                ],
              ),
            ),
          );
        }

        final user = snap.data;
        if (user == null) return const LoginScreen();

        if (_school != null) {
          return DashboardScreen();
        }

        return JoinOrCreateSchoolScreen(
          userEmail: user.email ?? '',
          uid: user.uid,
          displayName: user.displayName ?? '',
          onSchoolJoinedOrCreated: refreshSchool,
        );
      },
    );
  }
}

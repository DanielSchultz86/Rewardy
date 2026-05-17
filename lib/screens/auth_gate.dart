import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'login_screen.dart';
import 'forside_screen.dart';
import 'borne_dashboard_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Vi lytter konstant på, om der er en aktiv Firebase-session
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Mens den lige tænker, viser vi en tom sort skærm (eller et logo)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF121214),
            body: Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35))),
          );
        }

        // Hvis der er en bruger gemt i systemet
        if (snapshot.hasData) {
          final user = snapshot.data!;

          // 1. Er det en forælder (Admin)?
          if (!user.isAnonymous) {
            return const ForsideScreen();
          } 
          // 2. Er det et barn (Anonym)?
          else {
            final box = Hive.box('authBox');
            final userType = box.get('userType');

            // Tjek om vi har gemt barnets info lokalt
            if (userType == 'child') {
              return BorneDashboardScreen(
                familyId: box.get('familyId'),
                familyName: box.get('familyName'),
                memberId: box.get('memberId'),
              );
            }
          }
        }

        // Hvis ingen af delene er sande, send dem til Login!
        return const LoginScreen();
      },
    );
  }
}
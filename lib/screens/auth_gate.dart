import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
        // Mens den lige tænker, viser vi en tom sort skærm
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF121214),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF6B35),
              ),
            ),
          );
        }

        // Hvis der er en bruger gemt i systemet
        if (snapshot.hasData) {
          final user = snapshot.data!;

          // 1. Er det en forælder/admin?
          if (!user.isAnonymous) {
            // Vi lytter live på forælderens dokument i Firestore
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, userSnapshot) {
                
                // --- HÅNDTERING AF FIREBASE PERMISSION ERRORS ---
                if (userSnapshot.hasError) {
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    if (Navigator.canPop(context)) {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    }
                    await Hive.box('authBox').delete('userType');
                    await FirebaseAuth.instance.signOut();
                  });
                  return const Scaffold(backgroundColor: Color(0xFF121214));
                }

                // 1. TJEK FOR LÅS FØR VI GØR ANDET
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                  
                  // NYT: Spørger vi cachen eller live-serveren?
                  final isFromCache = userSnapshot.data!.metadata.isFromCache; 

                  if (userData != null && (userData['isBlocked'] ?? false) == true) {
                    
                    // --- CACHE-LØSNINGEN ---
                    // Hvis telefonens hukommelse tror vi er låst, venter vi lige
                    // på at serveren svarer, før vi smider brugeren ud!
                    if (isFromCache) {
                      return const Scaffold(
                        backgroundColor: Color(0xFF121214),
                        body: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFFF6B35),
                          ),
                        ),
                      );
                    }
                    // -----------------------
                        
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      // Fej alle skærme væk
                      if (Navigator.canPop(context)) {
                        Navigator.popUntil(context, (route) => route.isFirst);
                      }
                      
                      await Hive.box('authBox').delete('userType');
                      await FirebaseAuth.instance.signOut();
                    });

                    // Vis en tom mørk skærm imens udlogningen sker
                    return const Scaffold(
                      backgroundColor: Color(0xFF121214),
                    );
                  }
                }

                // 2. HVIS VI ER HER, ER BRUGEREN IKKE LÅST
                // Vi viser loader, hvis Firestore stadig henter brugerdata
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    backgroundColor: Color(0xFF121214),
                    body: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF6B35),
                      ),
                    ),
                  );
                }

                // Hvis alt er i orden, og brugeren ikke er låst, vises forsiden
                return const ForsideScreen();
              },
            );
          }

          // 2. Er det et barn/anonym bruger?
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

        // Hvis ingen af delene er sande, send dem til login
        return const LoginScreen();
      },
    );
  }
}
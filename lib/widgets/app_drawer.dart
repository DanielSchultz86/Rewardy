import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/dashboard_screen.dart';
import '../screens/opret_familie_screen.dart';
import '../screens/profil.dart';
import '../screens/medlemmer_screen.dart';
import '../screens/forside_screen.dart';
import '../screens/login_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Drawer(
      backgroundColor: const Color(0xFF202024),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // HEADER
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF2A2A30),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 40,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Menu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // FORSIDE
          ListTile(
            leading: const Icon(Icons.dashboard_rounded, color: Colors.white70),
            title: const Text('Forside', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const ForsideScreen()),
              );
            },
          ),
          const Divider(color: Color(0xFF3F3F46)),

          // DYNAMISKE FAMILIE-PUNKTER (Max 4)
          if (currentUserId != null)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('families')
                  .where('createdBy', isEqualTo: currentUserId)
                  .limit(4)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }

                final families = snapshot.data!.docs;

                return Column(
                  children: [
                    ...families.map((doc) {
                      final familyName = doc['name'] ?? 'Ukendt familie';
                      return ListTile(
                        leading: const Icon(Icons.home_rounded, color: Colors.white70),
                        title: Text(familyName, style: const TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
  builder: (context) => DashboardScreen(
    familyId: doc.id, // ID'et fra Firebase dokumentet
    familyName: familyName, // Navnet fra Firebase dokumentet
  ),
),
                          );
                        },
                      );
                    }),
                    const Divider(color: Color(0xFF3F3F46)),
                  ],
                );
              },
            ),

          // OPRET FAMILIE
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: Colors.white70),
            title: const Text('Opret familie', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const OpretFamiliePopup(),
              );
            },
          ),

          // MEDLEMMER
          ListTile(
            leading: const Icon(Icons.people_alt_outlined, color: Colors.white70),
            title: const Text('Medlemmer', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MedlemmerScreen()),
              );
            },
          ),

          // PROFIL
          ListTile(
            leading: const Icon(Icons.person_outline, color: Colors.white70),
            title: const Text('Profil', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilScreen()),
              );
            },
          ),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFF3F3F46)),

         // LOG UD
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Log ud', style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              // 1. Lukker menuen
              Navigator.pop(context); 
              
              // 2. Logger brugeren ud af Firebase
              await FirebaseAuth.instance.signOut();
              
              // 3. Fjerner hele historikken og sender brugeren til Login-skærmen
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (Route<dynamic> route) => false, // false betyder at "Tilbage"-knappen nulstilles
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
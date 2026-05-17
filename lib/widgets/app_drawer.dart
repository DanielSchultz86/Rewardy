import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart'; // NYT: Importeret Hive

import '../screens/dashboard_screen.dart';
import '../screens/opret_familie_screen.dart';
import '../screens/profil_screen.dart';
import '../screens/medlemmer_screen.dart';
import '../screens/forside_screen.dart';
import '../screens/login_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid;
    
    // Tjekker om det er et barn (anonym bruger) der er logget ind
    final bool isChild = currentUser?.isAnonymous ?? false; 

    return Drawer(
      backgroundColor: const Color(0xFF202024),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // HEADER (Vises for alle)
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

          // VOKSEN MENU-PUNKTER (Skjules for børn)
          if (!isChild) ...[
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
                                  familyId: doc.id,
                                  familyName: familyName,
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
          ], // Slut på voksen-sektion

          // LOG UD (Vises for alle, både børn og voksne)
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Log ud', style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              // 1. Tøm lokal hukommelse for børnedata, så de ikke logges automatisk ind igen
              final box = Hive.box('authBox');
              await box.clear();
              
              // 2. Fjerner hele historikken og sender brugeren til Login-skærmen FØRST.
              // Dette sikrer, at vi forlader Dashboardet og lukker for database-lytterne.
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (Route<dynamic> route) => false, 
                );
              }

              // Vi venter lige et halvt sekund, så skærmskiftet er helt færdigt
              await Future.delayed(const Duration(milliseconds: 500));
              
              // 3. Ryd op i Firebase (Slet anonym bruger vs log ud for voksne)
              if (isChild && currentUser != null) {
                try {
                  await currentUser.delete(); // Sletter brugeren helt
                } catch (e) {
                  debugPrint("Kunne ikke slette anonym bruger: $e");
                  await FirebaseAuth.instance.signOut(); // Fallback
                }
              } else {
                await FirebaseAuth.instance.signOut(); // Normal log ud for voksne
              }
            },
          ),
        ],
      ),
    );
  }
}
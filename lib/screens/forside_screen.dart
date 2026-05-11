import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 
import 'opret_familie_screen.dart';
import 'profil.dart';
import 'dashboard_screen.dart'; 
import 'medlemmer_screen.dart'; 
import '../widgets/app_drawer.dart';
import 'login_screen.dart';

class ForsideScreen extends StatelessWidget {
  const ForsideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Hent den aktuelle brugers ID
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      drawer: const AppDrawer(), 
      
      appBar: AppBar(
        title: const Text(
          'Velkommen til Rewardy!',
          style: TextStyle(fontSize: 18),
        ),
      ),
      body: SafeArea(
        // NYT: LayoutBuilder og SingleChildScrollView lader os scrolle, 
        // mens IntrinsicHeight lader Spacer() virke perfekt!
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 30),
                        
                        // LOGO
                        Image.asset(
                          'assets/images/logo.png',
                          height: 180,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 180,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white24, style: BorderStyle.solid),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text('Pladsholder til Logo\n(assets/images/logo.png)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 40),

                        // 1. DYNAMISKE FAMILIE-KNAPPER (Nu med max 4!)
                        if (currentUserId != null)
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('families')
                                .where('createdBy', isEqualTo: currentUserId)
                                .limit(4)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.only(bottom: 16.0),
                                  child: Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35))),
                                );
                              }
                              
                              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return const SizedBox.shrink(); 
                              }

                              final families = snapshot.data!.docs;

                              return Column(
                                children: families.map((doc) {
                                  final familyName = doc['name'] ?? 'Ukendt familie';
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16.0),
                                    child: _buildMenuButton(
                                      icon: Icons.home_rounded,
                                      text: familyName, 
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => DashboardScreen(
                                              familyId: doc.id,
                                              familyName: familyName,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),

                        // OPRET FAMILIE
                        _buildMenuButton(
                          icon: Icons.add_circle_outline,
                          text: 'Opret familie',
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true, 
                              backgroundColor: Colors.transparent, 
                              builder: (context) => const OpretFamiliePopup(),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // MEDLEMMER
                        _buildMenuButton(
                          icon: Icons.people_alt_outlined, 
                          text: 'Medlemmer',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const MedlemmerScreen()),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // PROFIL
                        _buildMenuButton(
                          icon: Icons.person_outline,
                          text: 'Profil',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ProfilScreen()),
                            );
                          },
                        ),
                        
                        const Spacer(),
                        const SizedBox(height: 24), // Sikrer at log-ud ikke sidder helt klistret til ovenstående, når vi scroller

                        // LOG UD
                        _buildOutlinedButton(
                          icon: Icons.logout,
                          text: 'Log ud',
                          color: Colors.redAccent,
                          onTap: () async {
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (context) => const LoginScreen()),
                                (Route<dynamic> route) => false,
                              );
                            }
                          },
                        ),
                        
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- HJÆLPE-WIDGETS ---
  Widget _buildMenuButton({required IconData icon, required String text, required VoidCallback onTap}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2A2A30), 
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        alignment: Alignment.centerLeft,
      ),
      onPressed: onTap,
      child: Row(
        children: [
          Icon(icon, size: 28, color: Colors.white70),
          const SizedBox(width: 16),
          Text(text, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildOutlinedButton({required IconData icon, required String text, required Color color, required VoidCallback onTap}) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerLeft,
      ),
      onPressed: onTap,
      child: Row(
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 16),
          Text(text, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
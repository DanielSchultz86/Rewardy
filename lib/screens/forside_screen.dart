import 'package:flutter/material.dart';
import 'opret_familie.dart';
import 'profil.dart';
import 'dashboard_screen.dart'; // Importerer det rigtige dashboard
import '../widgets/app_drawer.dart';

class ForsideScreen extends StatelessWidget {
  const ForsideScreen({super.key});

  // Dummy-variabel: Sæt til "true" for at teste "Gå til hold"-knappen
  final bool hasFamily = true; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 1. HER INDSÆTTER VI MENUEN
      drawer: const AppDrawer(), 
      
      appBar: AppBar(
        // 2. DEN GAMLE 'leading' ER NU SLETTET HERFRA
        title: const Text(
          'Velkommen til Rewardy!',
          style: TextStyle(fontSize: 18),
        ),
      ),
      body: SafeArea(
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

              // GÅ TIL FAMILIE KNAP (Vises KUN, hvis hasFamily er true)
              if (hasFamily) ...[
                _buildMenuButton(
                  icon: Icons.home_rounded,
                  text: 'Gå til dit Hold',
                  onTap: () {
                    // Naviger til det rigtige dashboard!
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DashboardScreen()),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],

              // OPRET FAMILIE / GRUPPE
              _buildMenuButton(
                icon: Icons.add_circle_outline,
                text: 'Opret familie/gruppe',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const OpretFamilieScreen()),
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

              // LOG UD
              _buildOutlinedButton(
                icon: Icons.logout,
                text: 'Log ud',
                color: Colors.redAccent,
                onTap: () {
                  // TODO: Firebase sign out
                },
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // --- HJÆLPE-WIDGETS ---
  Widget _buildMenuButton({required IconData icon, required String text, required VoidCallback onTap}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2A2A30), // Lidt lysere grå til knapperne
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
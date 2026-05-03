import 'package:flutter/material.dart';
import '../screens/dashboard_screen.dart';
import '../screens/opret_familie_screen.dart';
import '../screens/profil.dart';
import '../screens/medlemmer_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  // Dummy-variabel for at teste logikken.
  // Sæt til 'false' for at skjule holdet i menuen.
  final bool hasFamily = true;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      // Vi bruger appens mørke baggrundsfarve
      backgroundColor: const Color(0xFF202024),
      child: ListView(
        padding: EdgeInsets.zero, // Fjerner standard padding i toppen
        children: [
          // HEADER: Det øverste område af menuen
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Color(0xFF2A2A30), // Lidt lysere end baggrunden
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.stars_rounded, color: Color(0xFFFFD166), size: 40), // Vores stjerne-farve
                SizedBox(height: 10),
                Text(
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

          // 0. GÅ TIL HOLD (Vises kun hvis hasFamily er true)
          if (hasFamily) ...[
            ListTile(
              leading: const Icon(Icons.home_rounded, color: Colors.white70),
              title: const Text('Gå til dit Hold', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context); // Lukker swipe-menuen ned
                Navigator.pushReplacement( // Skifter siden ud (så man ikke får en uendelig 'tilbage' stak)
                  context,
                  MaterialPageRoute(builder: (context) => const DashboardScreen()),
                );
              },
            ),
            // En tynd streg til at adskille holdet fra de generelle ting
            const Divider(color: Color(0xFF3F3F46)), 
          ],

          // 1. OPRET FAMILIE
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: Colors.white70),
            title: const Text('Opret familie/gruppe', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context); // Lukker menuen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OpretFamilieScreen()),
              );
            },
          ),

          // 2. MEDLEMMER
          ListTile(
            leading: const Icon(Icons.people_alt_outlined, color: Colors.white70),
            title: const Text('Medlemmer', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context); // Lukker menuen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MedlemmerScreen()),
              );
            },
          ),

          // 2. PROFIL
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
          const Divider(color: Color(0xFF3F3F46)), // Tynd grå streg

          // 3. LOG UD (Rød styling)
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Log ud', style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              // TODO: Logik til log ud
            },
          ),
        ],
      ),
    );
  }
}
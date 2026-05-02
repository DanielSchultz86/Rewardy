import 'package:flutter/material.dart';
import 'screens/forside_screen.dart';

void main() {
  // Senere tilføjer vi initialisering af Firebase og Hive her
  runApp(const RewardyApp());
}

class RewardyApp extends StatelessWidget {
  const RewardyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rewardy',
      debugShowCheckedModeBanner: false, // Fjerner "Debug"-banneret i hjørnet
      theme: ThemeData(
        // Vores lækre, bløde, mørkegrå baggrund (#202024)
        scaffoldBackgroundColor: const Color(0xFF202024),
        
        // Vores farvepalette (Midnat & Ild)
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF6B35),    // Varm orange (Primær)
          secondary: Color(0xFFFFD166),  // Glad gul (Accent/Stjerner)
          surface: Color(0xFF2A2A30),    // Kort & Topbjælke
        ),
        
        // Standard-styling for vores topbjælke
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2A2A30), // Samme farve som overflader/kort
          elevation: 0, // Gør den flad uden skygge for et moderne look
          centerTitle: true,
        ),
        
        useMaterial3: true,
      ),
      home: const ForsideScreen(), // Peger på vores forside
    );
  }
}
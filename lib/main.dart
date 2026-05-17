import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart'; // NYT: Tilføjet til lokal hukommelse
import 'firebase_options.dart';
import 'screens/auth_gate.dart'; // NYT: Importerer dørmanden
import 'screens/forside_screen.dart'; 
import 'screens/login_screen.dart'; 
import 'screens/opret_bruger_screen.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); 
  
  // Starter Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // NYT: Initialiserer Hive og åbner en boks til at huske login
  await Hive.initFlutter();
  await Hive.openBox('authBox');

  runApp(const RewardyApp());
}

class RewardyApp extends StatelessWidget {
  const RewardyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rewardy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF202024),
        
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF6B35),    // Varm orange (Primær)
          secondary: Color(0xFFFFD166),  // Glad gul (Accent/Stjerner)
          surface: Color(0xFF2A2A30),    // Kort & Topbjælke
        ),
        
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2A2A30),
          elevation: 0, 
          centerTitle: true,
        ),
        
        useMaterial3: true,
      ),
      // NYT: Ændret fra LoginScreen() til AuthGate()
      home: const AuthGate(), 
    );
  }
}
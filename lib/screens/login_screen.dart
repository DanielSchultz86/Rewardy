import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'forside_screen.dart';
import 'opret_bruger_screen.dart';
import 'borne_dashboard_screen.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _loginController = TextEditingController(); 
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _showPassword = false; 

  String? _validateLoginId(String? value) {
    if (value == null || value.trim().isEmpty) return 'Indtast email eller unik kode';
    
    final trimmed = value.trim();
    if (trimmed.contains('@')) {
      final regex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
      if (!regex.hasMatch(trimmed)) return 'Ugyldig email';
    } else {
      if (trimmed.length < 6) return 'Koden skal være mindst 6 tegn';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Indtast adgangskode';
    if (value.length < 6) return 'Adgangskoden skal være mindst 6 tegn';
    return null;
  }

  Future<void> _sendPasswordReset() async {
    final loginId = _loginController.text.trim();

    if (loginId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Indtast din email for at nulstille adgangskode.'), backgroundColor: Colors.redAccent));
      return;
    }

    if (!loginId.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Børn kan ikke nulstille adgangskoden her. Bed en forælder om at ændre den inde på deres profil.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: loginId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hvis emailen findes, er der sendt et link til nulstilling.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kunne ikke sende link.'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------- Log Ind Logik ----------
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final loginId = _loginController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _isLoading = true);

    try {
      final box = Hive.box('authBox');

      // 1. LOG IND SOM ADMIN (EMAIL)
      if (loginId.contains('@')) {
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: loginId, password: password);
        final uid = cred.user?.uid;
        
        if (uid == null) throw Exception('Login fejlede.');

final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(uid)
    .get(const GetOptions(source: Source.server));
    
        if (!userDoc.exists) {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil mangler.'), backgroundColor: Colors.redAccent));
          return;
        }

        // --- NYT: TJEK OM BRUGER ER LÅST ---
        final userData = userDoc.data();
        if (userData != null && userData['isBlocked'] == true) {
          // Log straks ud igen
          await FirebaseAuth.instance.signOut();
          
          if (!mounted) return;
          
          // Hent evt. den årsag vi indtastede på dashboardet
          final lockReason = userData['lockReason'] ?? 'Kontakt administratoren for mere information.';
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Din konto er låst.\nÅrsag: $lockReason'), 
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 5),
            )
          );
          return; // Stop login her!
        }
        // -----------------------------------

        await box.delete('userType');

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ForsideScreen()), 
        );
      } 
      // 2. LOG IND SOM MEDLEM (UNIK KODE)
      else {
        if (FirebaseAuth.instance.currentUser == null) {
          await FirebaseAuth.instance.signInAnonymously();
        }

        final querySnap = await FirebaseFirestore.instance
            .collection('members')
            .where('loginKode', isEqualTo: loginId)
            .where('password', isEqualTo: password)
            .limit(1)
            .get();

        if (querySnap.docs.isNotEmpty) {
          final memberDoc = querySnap.docs.first;
          final memberId = memberDoc.id;
          
          final List<dynamic> families = memberDoc['familier'] ?? [];
          if (families.isEmpty) {
            throw Exception('Du er ikke tilknyttet en familie endnu.');
          }
          final String familyId = families.first;

          final familySnap = await FirebaseFirestore.instance.collection('families').doc(familyId).get();
          final String familyName = familySnap.exists ? (familySnap.data()?['name'] ?? 'Min Familie') : 'Min Familie';

          await box.put('userType', 'child');
          await box.put('familyId', familyId);
          await box.put('familyName', familyName);
          await box.put('memberId', memberId);

          if (!mounted) return;
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => BorneDashboardScreen(
                familyId: familyId,
                familyName: familyName,
                memberId: memberId,
              ),
            ),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Forkert kode eller adgangskode.'), backgroundColor: Colors.redAccent),
          );
        }
      }

    } on FirebaseAuthException catch (e) {
      String message = 'Fejl ved login.';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') message = 'Forkert adgangskode.';
      else if (e.code == 'user-not-found') message = 'Email findes ikke.';

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fejl: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log ind'),
        automaticallyImplyLeading: false, 
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 120, 
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(height: 120, color: Colors.white10, alignment: Alignment.center, child: const Text('Logo')),
                ),
                const SizedBox(height: 40),
                
                const Text('Velkommen tilbage!', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                const Text('Log ind for at se dine opgaver', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.white54)),
                const SizedBox(height: 30),

                _buildTextField(
                  controller: _loginController,
                  label: 'Email eller Unik kode',
                  validator: _validateLoginId,
                ),
                const SizedBox(height: 16),
                
                _buildTextField(
                  controller: _passwordController,
                  label: 'Adgangskode',
                  obscureText: !_showPassword,
                  validator: _validatePassword,
                  suffixIcon: IconButton(
                    icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _sendPasswordReset,
                    child: const Text('Glemt adgangskode?', style: TextStyle(color: Color(0xFFFFD166))), 
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF008D3D), 
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text('Log ind', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const OpretBrugerScreen()),
                    );
                  },
                  child: const Text('Har du ikke en bruger? Opret her', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF2A2A30),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        suffixIcon: suffixIcon,
      ),
      validator: validator,
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'forside_screen.dart';
import 'opret_bruger_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _showPassword = false; // Tilføjet for bedre UX i det mørke tema

  // ---------- Genbrugte Validators ----------
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Indtast en email';
    final regex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    if (!regex.hasMatch(value.trim())) return 'Ugyldig email';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Indtast password';
    if (value.length < 6) return 'Password skal være mindst 6 tegn';
    return null;
  }

  // ---------- Nulstil Password ----------
  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();

    final emailError = _validateEmail(email);
    if (emailError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(emailError), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hvis emailen findes, er der sendt et link til nulstilling. Tjek din indbakke.'), backgroundColor: Colors.green),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Kunne ikke sende reset-link. Prøv igen.';
      if (e.code == 'invalid-email') message = 'Email-adressen er ikke gyldig.';
      else if (e.code == 'network-request-failed') message = 'Tjek din internetforbindelse.';
      else if (e.code == 'too-many-requests') message = 'For mange forsøg. Vent lidt og prøv igen.';
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------- Log Ind Logik ----------
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoading = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      final uid = cred.user?.uid;
      
      if (uid == null) throw Exception('Login fejlede: ingen bruger-id.');

      // Sikkerhedstjek: Tjekker at brugerprofilen eksisterer i Firestore
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Din konto er ikke oprettet korrekt (mangler profil). Prøv at oprette brugeren igen.'), backgroundColor: Colors.redAccent),
        );
        return;
      }

      if (!mounted) return;

      // Navigerer til forsiden, og fjerner login-skærmen fra historikken
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ForsideScreen()),
      );

    } on FirebaseAuthException catch (e) {
      String message = 'Ukendt fejl';
      if (e.code == 'user-not-found') message = 'Denne email findes ikke.';
      else if (e.code == 'wrong-password' || e.code == 'invalid-credential') message = 'Forkert password.';
      else if (e.code == 'invalid-email') message = 'Email-adressen er ikke gyldig.';
      else if (e.code == 'too-many-requests') message = 'For mange forsøg. Vent lidt og prøv igen.';

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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---------- UI (Dark Mode) ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log ind'),
        automaticallyImplyLeading: false, // Fjerner "tilbage" pilen
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Image.asset(
  'assets/images/logo.png',
  height: 120, // Gerne lidt stort på login skærmen
  fit: BoxFit.contain,
),
const SizedBox(height: 40),
                
                const Text('Velkommen tilbage!', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                const Text('Log ind for at se dine opgaver', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.white54)),
                const SizedBox(height: 30),

                // Email felt
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),
                
                // Password felt (Nu med "vis/skjul" knap)
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

                // Glemt password knap
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _sendPasswordReset,
                    child: const Text('Glemt password?', style: TextStyle(color: Color(0xFFFFD166))), // Gul accentfarve
                  ),
                ),
                const SizedBox(height: 16),

                // Log Ind Knap
                SizedBox(
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF008D3D), // Orange primærfarve
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
                
                // Opret bruger link
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

  // Hjælpe-widget til styling af tekstfelter
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
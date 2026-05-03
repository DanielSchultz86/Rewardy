import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'forside_screen.dart'; // Peger nu på vores Forside
import 'login_screen.dart'; // Udkommenteret indtil vi bygger denne

class OpretBrugerScreen extends StatefulWidget {
  const OpretBrugerScreen({super.key});

  @override
  State<OpretBrugerScreen> createState() => _OpretBrugerScreenState();
}

class _OpretBrugerScreenState extends State<OpretBrugerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _loading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  // ---------- Genbrugte Validators ----------
  String? _validateUsername(String? value) {
    if (value == null || value.trim().length < 4) return 'Brugernavn skal være mindst 4 tegn';
    if (value.trim().length > 30) return 'Brugernavn må maks være 30 tegn';
    if (!RegExp(r'^[a-zA-Z0-9_æøåÆØÅ]+$').hasMatch(value.trim())) return 'Kun bogstaver, tal og underscore er tilladt';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.length < 6) return 'Adgangskoden skal være mindst 6 tegn';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Bekræft adgangskoden';
    if (value != _passwordController.text) return 'Adgangskoderne er ikke ens';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Indtast en email';
    if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(value)) return 'Ugyldig email';
    return null;
  }

  // ---------- Opret bruger Logik ----------
  Future<void> _opretBruger() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    UserCredential? cred;

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final username = _usernameController.text.trim();

      // Opretter auth brugeren
      cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final uid = cred.user!.uid;
      final firestore = FirebaseFirestore.instance;

      // 1) Private user-profil
      await firestore.collection('users').doc(uid).set({
        'username': username,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'isBlocked': false,
      }, SetOptions(merge: true));

      // 2) Public user-profil
      await firestore.collection('publicUsers').doc(uid).set({
        'username': username,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bruger oprettet succesfuldt!"), backgroundColor: Colors.green),
      );

      // Navigerer til forsiden, og fjerner "tilbage" knappen fra historikken
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ForsideScreen()),
        (route) => false,
      );

    } on FirebaseAuthException catch (e) {
      String msg = 'Fejl ved oprettelse.';
      if (e.code == 'email-already-in-use') msg = 'Emailen bruges allerede af en anden bruger.';
      else if (e.code == 'invalid-email') msg = 'Email-adressen er ikke gyldig.';
      else if (e.code == 'weak-password') msg = 'Adgangskoden er for svag (min. 6 tegn).';
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
    } catch (e) {
      try { await cred?.user?.delete(); } catch (_) {}
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fejl: $e"), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ---------- UI (Dark Mode) ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Opret bruger'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo i toppen
                Image.asset(
                  'assets/images/logo.png',
                  height: 100,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.stars_rounded, size: 80, color: Color(0xFFFFD166)),
                ),
                const SizedBox(height: 30),
                
                const Text('Velkommen til Rewardy', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                const Text('Opret en konto for at komme i gang', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.white54)),
                const SizedBox(height: 30),

                // Felter
                _buildTextField(controller: _usernameController, label: 'Brugernavn', validator: _validateUsername),
                const SizedBox(height: 16),
                _buildTextField(controller: _emailController, label: 'Email', keyboardType: TextInputType.emailAddress, validator: _validateEmail),
                const SizedBox(height: 16),
                
                // Password felt
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
                const SizedBox(height: 16),

                // Bekræft password felt
                _buildTextField(
                  controller: _confirmPasswordController,
                  label: 'Bekræft adgangskode',
                  obscureText: !_showConfirmPassword,
                  validator: _validateConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(_showConfirmPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
                    onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                  ),
                ),
                const SizedBox(height: 30),

                // Opret Knap
                SizedBox(
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35), // Vores varme orange
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _loading ? null : _opretBruger,
                    child: _loading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text('Opret konto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Log ind link
                TextButton(
                  onPressed: () {
                    // TODO: Naviger til LoginScreen
                  },
                  child: const Text('Har du allerede en bruger? Log ind', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Hjælpe-widget til at style tekstfelterne ensartet i mørkt tema
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
        fillColor: const Color(0xFF2A2A30), // Lidt lysere grå end baggrunden
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        suffixIcon: suffixIcon,
      ),
      validator: validator,
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class OpretMedlemPopup extends StatefulWidget {
  final String? familyId; 

  const OpretMedlemPopup({
    super.key,
    this.familyId, 
  });

  @override
  State<OpretMedlemPopup> createState() => _OpretMedlemPopupState();
}

class _OpretMedlemPopupState extends State<OpretMedlemPopup> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _navnController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController(); 
  
  late String _unikKode;
  bool _isLoading = false;
  bool _obscurePassword = true; 

  final List<Map<String, dynamic>> _farveMuligheder = [
    {'navn': 'Orange (Standard)', 'farve': const Color(0xFFFF6B35)},
    {'navn': 'Glad Gul', 'farve': const Color(0xFFFFD166)},
    {'navn': 'Dyb Grøn', 'farve': const Color(0xFF008D3D)},
    {'navn': 'Bølgebryder Blå', 'farve': Colors.blueAccent},
    {'navn': 'Lilla Magi', 'farve': Colors.deepPurpleAccent},
    {'navn': 'Hindbær Rød', 'farve': Colors.pinkAccent},
    {'navn': 'Koral Rød', 'farve': Colors.redAccent},
    {'navn': 'Skildpadde Grøn', 'farve': Colors.teal},
    {'navn': 'Himmelblå', 'farve': Colors.cyan},
    {'navn': 'Sølv Grå', 'farve': Colors.grey},
  ];

  late Color _valgtFarve;

  @override
  void initState() {
    super.initState();
    _unikKode = _genererUnikKode();
    _valgtFarve = _farveMuligheder[0]['farve']; 
  }

  String _genererUnikKode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  // OPDATERET VALIDERINGSFUNKTION
  String? _validerNavn(String? value) {
    if (value == null || value.trim().isEmpty) return 'Indtast venligst et navn';
    
    // Vi trimmer teksten for validering, så mellemrum til sidst ikke udløser fejl
    final trimmedValue = value.trim();
    
    if (trimmedValue.length > 40) return 'Navnet må maksimalt være 40 tegn';
    if (!RegExp(r'^[a-zA-ZæøåÆØÅ0-9 ]+$').hasMatch(trimmedValue)) return 'Kun bogstaver og tal er tilladt';
    return null;
  }

  Future<void> _opretMedlem() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final db = FirebaseFirestore.instance;
      final adminUser = FirebaseAuth.instance.currentUser;

      if (adminUser == null) throw Exception("Du er ikke logget ind.");

      final docRef = db.collection('members').doc();

      final List<String> initialFamilies = widget.familyId != null ? [widget.familyId!] : [];

      await docRef.set({
        'id': docRef.id,
        'navn': _navnController.text.trim(), // Trimmer automatisk ved gem!
        'loginKode': _unikKode,
        'password': _passwordController.text.trim(), 
        'ikonFarve': _valgtFarve.value, 
        'familier': initialFamilies, 
        'rewardsEarned': 0,
        'tasksCompleted': 0,
        'oprettetAf': adminUser.uid, 
        'oprettetDato': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Medlemmet ${_navnController.text.trim()} blev oprettet!'),
          backgroundColor: const Color(0xFF008D3D),
        ),
      );
      
      Navigator.pop(context); 
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fejl ved oprettelse: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _navnController.dispose();
    _passwordController.dispose(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFF202024), 
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Opret medlem',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A30),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF3F3F46)),
                        ),
                        child: Column(
                          children: [
                            const Text('Unik Login-kode', style: TextStyle(color: Colors.white54, fontSize: 14)),
                            const SizedBox(height: 8),
                            Text(
                              _unikKode,
                              style: const TextStyle(
                                color: Color(0xFFFFD166), 
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4.0, 
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Gem denne kode. Den skal bruges senere, når medlemmet skal logge ind på sin egen enhed.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 30),

                      const Text('Navn på medlem', style: TextStyle(color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _navnController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'F.eks. Oskar',
                          hintStyle: const TextStyle(color: Colors.white24),
                          filled: true,
                          fillColor: const Color(0xFF2A2A30),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        validator: _validerNavn,
                      ),

                      const SizedBox(height: 24),

                      const Text('Ikon farve', style: TextStyle(color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<Color>(
                        value: _valgtFarve,
                        dropdownColor: const Color(0xFF2A2A30), 
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF2A2A30),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        items: _farveMuligheder.map((map) {
                          return DropdownMenuItem<Color>(
                            value: map['farve'],
                            child: Row(
                              children: [
                                Container(
                                  width: 16, height: 16,
                                  decoration: BoxDecoration(color: map['farve'], shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 12),
                                Text(map['navn']),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (Color? nyFarve) {
                          if (nyFarve != null) {
                            setState(() => _valgtFarve = nyFarve);
                          }
                        },
                      ),
                      const SizedBox(height: 24),

                      const Text('Password (Til login)', style: TextStyle(color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Mindst 6 tegn', 
                          hintStyle: const TextStyle(color: Colors.white24),
                          filled: true, 
                          fillColor: const Color(0xFF2A2A30),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.white54,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Password må ikke være tomt';
                          if (v.trim().length < 6) return 'Password skal være mindst 6 tegn';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              bottom: true,
              child: InkWell(
                onTap: _isLoading ? null : _opretMedlem,
                child: Container(
                  height: 70, 
                  width: double.infinity,
                  color: const Color(0xFF008D3D), 
                  alignment: Alignment.center,
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('Opret medlem', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
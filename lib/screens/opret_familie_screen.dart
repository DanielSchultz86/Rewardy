import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

// VIGTIGT: Sørg for at filnavnet passer til der, hvor din OpretMedlemPopup bor
import 'opret_medlem_screen.dart'; 

class OpretFamiliePopup extends StatefulWidget {
  const OpretFamiliePopup({super.key});

  @override
  State<OpretFamiliePopup> createState() => _OpretFamiliePopupState();
}

class _OpretFamiliePopupState extends State<OpretFamiliePopup> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _navnController = TextEditingController();
  
  bool _isLoading = false;
  bool _isFetchingMembers = true;

  // Lister til at styre UI'et
  List<Map<String, dynamic>> _medlemmerUdenFam = [];
  List<Map<String, dynamic>> _medlemmerTilfojet = [];

  @override
  void initState() {
    super.initState();
    _hentMedlemmer();
  }

  // Henter medlemmer oprettet af den nuværende admin
  Future<void> _hentMedlemmer() async {
    setState(() => _isFetchingMembers = true);
    try {
      final adminUser = FirebaseAuth.instance.currentUser;
      if (adminUser == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('members')
          .where('oprettetAf', isEqualTo: adminUser.uid) // RETTET: Matcher nu din database!
          .get();

      final alleMedlemmer = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();

      setState(() {
        // Vi nulstiller listerne og sætter dem ind i "Uden familie"
        _medlemmerUdenFam = alleMedlemmer;
        _medlemmerTilfojet = [];
      });
    } catch (e) {
      debugPrint('Fejl ved hentning af medlemmer: $e');
    } finally {
      if (mounted) setState(() => _isFetchingMembers = false);
    }
  }

  String _genererUnikKode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  String? _validerNavn(String? value) {
    if (value == null || value.isEmpty) return 'Indtast venligst et navn';
    if (value.length > 40) return 'Navnet må maksimalt være 40 tegn';
    if (value.endsWith(' ')) return 'Navnet må ikke slutte med et mellemrum';
    if (!RegExp(r'^[a-zA-ZæøåÆØÅ0-9 ]+$').hasMatch(value)) return 'Kun bogstaver og tal er tilladt';
    return null;
  }

  void _tilfojTilFamilie(Map<String, dynamic> medlem) {
    setState(() {
      _medlemmerUdenFam.remove(medlem);
      _medlemmerTilfojet.add(medlem);
    });
  }

  void _fjernFraFamilie(Map<String, dynamic> medlem) {
    setState(() {
      _medlemmerTilfojet.remove(medlem);
      _medlemmerUdenFam.add(medlem);
    });
  }

  Future<void> _opretFamilie() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final db = FirebaseFirestore.instance;
      final adminUser = FirebaseAuth.instance.currentUser;

      if (adminUser == null) throw Exception("Du er ikke logget ind.");

      // Opret en WriteBatch for at sikre at både familie og medlemmer opdateres samtidig
      final batch = db.batch();
      
      // 1. Opret Familien
      final familyRef = db.collection('families').doc();
      final List<String> valgteMedlemmerIds = _medlemmerTilfojet.map((m) => m['id'] as String).toList();

      batch.set(familyRef, {
        'id': familyRef.id,
        'name': _navnController.text.trim(),
        'inviteCode': _genererUnikKode(),
        'admins': [adminUser.uid], // Array med admins
        'members': valgteMedlemmerIds, // Array med medlems-ID'er
        'createdBy': adminUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Opdater hvert valgt medlem til at inkludere denne familie i deres array
      for (String memberId in valgteMedlemmerIds) {
        final memberRef = db.collection('members').doc(memberId);
        batch.update(memberRef, {
          'familier': FieldValue.arrayUnion([familyRef.id])
        });
      }

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Familien blev oprettet!'),
          backgroundColor: Color(0xFF008D3D),
        ),
      );
      
      // Lukker popuppen
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

  // RETTET: Aktiveret funktion der åbner popup og opdaterer listen bagefter
  Future<void> _aabenOpretMedlem() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const OpretMedlemPopup(),
    );
    
    // Når Opret Medlem popuppen lukkes, henter vi listen igen, så det nye medlem vises!
    _hentMedlemmer();
  }

  @override
  void dispose() {
    _navnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.90, // Lidt højere så der er plads til lister
      decoration: const BoxDecoration(
        color: Color(0xFF202024), // Midnat & Ild baggrund
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- POPUP HEADER ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Opret ny familie',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            
            // --- INDHOLD ---
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      
                      // NAVN FELT
                      const Text('Navn', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _navnController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Hvad er navnet på din familie?',
                          hintStyle: const TextStyle(color: Colors.white24),
                          filled: true,
                          fillColor: const Color(0xFF2A2A30),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12), 
                            borderSide: const BorderSide(color: Color(0xFF3F3F46)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12), 
                            borderSide: const BorderSide(color: Color(0xFF3F3F46)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12), 
                            borderSide: const BorderSide(color: Color(0xFFFF6B35)), // Orange accent
                          ),
                        ),
                        validator: _validerNavn,
                      ),

                      const SizedBox(height: 30),

                      // MEDLEMMER UDEN FAMILIE KORT
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A30),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF3F3F46)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Medlemmer uden fam', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                                  // OPRET NY KNAP
                                  InkWell(
                                    onTap: _aabenOpretMedlem, // Nu virker knappen!
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF008D3D), // Dyb grøn
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text('Opret ny', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    ),
                                  )
                                ],
                              ),
                            ),
                            const Divider(color: Color(0xFF3F3F46), height: 1),
                            
                            // LISTE MED MEDLEMMER
                            if (_isFetchingMembers)
                              const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35))))
                            else if (_medlemmerUdenFam.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text('Ingen medlemmer fundet. Opret et nyt!', style: TextStyle(color: Colors.white54)),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _medlemmerUdenFam.length,
                                itemBuilder: (context, index) {
                                  final medlem = _medlemmerUdenFam[index];
                                  return ListTile(
                                    title: Text(medlem['navn'] ?? 'Ukendt', style: const TextStyle(color: Colors.white70)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () => _tilfojTilFamilie(medlem),
                                          child: const CircleAvatar(
                                            radius: 14,
                                            backgroundColor: Color(0xFF008D3D),
                                            child: Icon(Icons.add, size: 18, color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // MEDLEMMER TILFØJET KORT (Orange border)
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A30),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFF6B35)), // Orange border som på designet
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Medlemmer tilføjet familie', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                                  // Tæller-badge
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: const Color(0xFF008D3D).withOpacity(0.2),
                                    child: Text(
                                      '${_medlemmerTilfojet.length}', 
                                      style: const TextStyle(color: Color(0xFF008D3D), fontSize: 12, fontWeight: FontWeight.bold)
                                    ),
                                  )
                                ],
                              ),
                            ),
                            const Divider(color: Color(0xFF3F3F46), height: 1),
                            
                            // LISTE MED VALGTE MEDLEMMER
                            if (_medlemmerTilfojet.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text('Tilføj medlemmer fra listen ovenfor', style: TextStyle(color: Colors.white54)),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _medlemmerTilfojet.length,
                                itemBuilder: (context, index) {
                                  final medlem = _medlemmerTilfojet[index];
                                  return ListTile(
                                    title: Text(medlem['navn'] ?? 'Ukendt', style: const TextStyle(color: Colors.white)),
                                    trailing: InkWell(
                                      onTap: () => _fjernFraFamilie(medlem),
                                      child: const CircleAvatar(
                                        radius: 14,
                                        backgroundColor: Colors.redAccent, // Rød minus-knap
                                        child: Icon(Icons.remove, size: 18, color: Colors.white),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),

            // --- DEN GRØNNE GEM-KNAP I BUNDEN ---
            SafeArea(
              bottom: true,
              child: InkWell(
                onTap: _isLoading ? null : _opretFamilie,
                child: Container(
                  height: 70, 
                  width: double.infinity,
                  color: const Color(0xFF008D3D), 
                  alignment: Alignment.center,
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('Opret familie', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
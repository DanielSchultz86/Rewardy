import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RedigerMedlemPopup extends StatefulWidget {
  final QueryDocumentSnapshot memberDoc;

  const RedigerMedlemPopup({super.key, required this.memberDoc});

  @override
  State<RedigerMedlemPopup> createState() => _RedigerMedlemPopupState();
}

class _RedigerMedlemPopupState extends State<RedigerMedlemPopup> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _navnController;
  late TextEditingController _passwordController; 
  late String _unikKode;
  
  bool _isLoading = false;
  bool _obscurePassword = true; // NYT: Styrer om passwordet er skjult eller synligt

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
    final data = widget.memberDoc.data() as Map<String, dynamic>;
    _navnController = TextEditingController(text: data['navn'] ?? '');
    _passwordController = TextEditingController(text: data['password'] ?? ''); 
    _unikKode = data['unikKode'] ?? data['loginKode'] ?? 'FEJL'; 
    
    // Find den rigtige farve fra listen
    final int colorValue = data['ikonFarve'] ?? Colors.grey.value;
    final valgtColor = Color(colorValue);
    
    // Tjekker om farven findes i vores liste, ellers vælges den første
    try {
       _valgtFarve = _farveMuligheder.firstWhere((map) => (map['farve'] as Color).value == valgtColor.value)['farve'];
    } catch(e){
       _valgtFarve = _farveMuligheder[0]['farve'];
    }
  }

  String? _validerNavn(String? value) {
    if (value == null || value.isEmpty) return 'Indtast venligst et navn';
    if (value.length > 40) return 'Navnet må maksimalt være 40 tegn';
    if (value.endsWith(' ')) return 'Navnet må ikke slutte med et mellemrum';
    if (!RegExp(r'^[a-zA-ZæøåÆØÅ0-9 ]+$').hasMatch(value)) return 'Kun bogstaver og tal er tilladt';
    return null;
  }

  Future<void> _gemAendringer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('members').doc(widget.memberDoc.id).update({
        'navn': _navnController.text.trim(),
        'password': _passwordController.text.trim(), 
        'ikonFarve': _valgtFarve.value,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ændringer gemt!'), backgroundColor: Color(0xFF008D3D)),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fejl ved gemning: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sletMedlem() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A30),
        title: const Text('Slet medlem?', style: TextStyle(color: Colors.white)),
        content: Text('Er du sikker på, at du vil slette ${_navnController.text}? Dette kan ikke fortrydes.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuller', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Slet', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm != true) return; 

    try {
      await widget.memberDoc.reference.delete();
      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Medlemmet blev slettet.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fejl ved sletning: $e'), backgroundColor: Colors.redAccent));
      }
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
            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Rediger medlem',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // --- FORMULAR ---
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // KODE KORT (Låst - read only)
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
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 30),

                      // NAVN FELT
                      const Text('Navn på medlem', style: TextStyle(color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _navnController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF2A2A30),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        validator: _validerNavn,
                      ),

                      const SizedBox(height: 24),

                      // FARVE DROPDOWN
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

                      // PASSWORD FELT MED ØJE-IKON
                      const Text('Password (Til login)', style: TextStyle(color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword, // NYT: Styres nu af variablen
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Mindst 6 tegn', 
                          hintStyle: const TextStyle(color: Colors.white24),
                          filled: true, 
                          fillColor: const Color(0xFF2A2A30),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          // NYT: Suffix ikon der lader brugeren skifte synligheden
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

            // --- KNAPPER I BUNDEN ---
            SafeArea(
              bottom: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    // SLET MEDLEM KNAP 
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _sletMedlem,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.redAccent, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Slet medlem', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ANNULLER OG GEM KNAPPER
                    Row(
                      children: [
                        // Annuller-knap
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Annuller', style: TextStyle(color: Colors.white54, fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Gem-knap
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _gemAendringer,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: const Color(0xFF008D3D),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading 
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Gem', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
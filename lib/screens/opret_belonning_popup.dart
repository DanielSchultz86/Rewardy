import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OpretBelonningPopup extends StatefulWidget {
  final String familyId;
  final String? rewardId; // NYT: Hvis denne er udfyldt, er vi i "Kun opgave" mode!

  const OpretBelonningPopup({
    super.key, 
    required this.familyId, 
    this.rewardId, // NYT
  });

  @override
  State<OpretBelonningPopup> createState() => _OpretBelonningPopupState();
}

class _OpretBelonningPopupState extends State<OpretBelonningPopup> {
  int _currentStep = 1;

  // --- TRIN 1: BELØNNING DATA ---
  final _rewardFormKey = GlobalKey<FormState>();
  final TextEditingController _rewardNameCtrl = TextEditingController();
  final TextEditingController _rewardDescCtrl = TextEditingController();
  double _completionCriteria = 50.0;

  // --- TRIN 2: OPGAVE DATA ---
  final _taskFormKey = GlobalKey<FormState>();
  final TextEditingController _taskNameCtrl = TextEditingController();
  final TextEditingController _taskDescCtrl = TextEditingController();
  bool _isMandatory = false;
  int _taskRepetitions = 1;
  List<String> _selectedMembers = [];

  // --- DATA FRA DATABASE ---
  List<Map<String, dynamic>> _familyMembers = [];
  bool _isLoadingMembers = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // NYT: Hvis vi har modtaget et rewardId, starter vi direkte på trin 2
    if (widget.rewardId != null) {
      _currentStep = 2;
    }
    _fetchMembers();
  }

  @override
  void dispose() {
    _rewardNameCtrl.dispose();
    _rewardDescCtrl.dispose();
    _taskNameCtrl.dispose();
    _taskDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMembers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('members')
          .where('familier', arrayContains: widget.familyId)
          .get();

      setState(() {
        _familyMembers = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
        _isLoadingMembers = false;
      });
    } catch (e) {
      debugPrint("Fejl ved hentning af medlemmer: $e");
      setState(() => _isLoadingMembers = false);
    }
  }

  // --- VALIDERINGER ---
  String? _validateNavn(String? value, int maxLength) {
    if (value == null || value.trim().isEmpty) return 'Feltet må ikke være tomt';
    if (value.length > maxLength) return 'Maks $maxLength tegn';
    if (value.endsWith(' ')) return 'Må ikke slutte med mellemrum';
    if (!RegExp(r'^[a-zA-ZæøåÆØÅ0-9 ]+$').hasMatch(value)) return 'Kun bogstaver og tal er tilladt her';
    return null;
  }

  String? _validateBeskrivelse(String? value, int maxLength) {
    if (value == null || value.trim().isEmpty) return 'Beskrivelsen må ikke være tom';
    if (value.length > maxLength) return 'Beskrivelsen er for lang (Maks $maxLength tegn)';
    if (value.endsWith(' ')) return 'Beskrivelsen må ikke slutte med et mellemrum';
    return null;
  }

  Future<bool> _showExitDialog() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A30),
        title: const Text('Annuller oprettelse?', style: TextStyle(color: Colors.white)),
        content: const Text('Er du sikker på, at du vil lukke? Dine indtastninger vil gå tabt.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Nej, fortsæt', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ja, annuller', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    return shouldPop ?? false;
  }

  Future<void> _saveToDatabase() async {
    if (!_taskFormKey.currentState!.validate()) return;
    if (_selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vælg mindst ét medlem!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      DocumentReference rewardRef;

      // NYT: Tjekker om vi skal oprette en ny belønning, eller bruge den eksisterende
      if (widget.rewardId == null) {
        // Vi opretter en helt ny belønning
        rewardRef = db.collection('families').doc(widget.familyId).collection('rewards').doc();
        batch.set(rewardRef, {
          'navn': _rewardNameCtrl.text.trim(),
          'beskrivelse': _rewardDescCtrl.text.trim(),
          'fuldfoertKriterie': _completionCriteria,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Vi tilføjer blot til en eksisterende belønning
        rewardRef = db.collection('families').doc(widget.familyId).collection('rewards').doc(widget.rewardId);
      }

      for (String memberId in _selectedMembers) {
        final taskRef = rewardRef.collection('tasks').doc();
        batch.set(taskRef, {
          'navn': _taskNameCtrl.text.trim(),
          'beskrivelse': _taskDescCtrl.text.trim(),
          'erMandatory': _isMandatory,
          'antalGange': _taskRepetitions,
          'udfoertGange': 0,
          'medlemId': memberId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.rewardId == null ? 'Belønning oprettet!' : 'Opgave tilføjet!'), 
            backgroundColor: const Color(0xFF008D3D)
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fejl: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldExit = await _showExitDialog();
        if (shouldExit && context.mounted) Navigator.of(context).pop();
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.90,
        decoration: const BoxDecoration(
          color: Color(0xFF202024),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () async {
                      final shouldExit = await _showExitDialog();
                      if (shouldExit && context.mounted) Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      // NYT: Titlen skifter baseret på mode
                      widget.rewardId != null 
                        ? 'Opret opgave' 
                        : (_currentStep == 1 ? 'Opret belønning' : 'Tilføj opgaver'),
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  // NYT: Skjuler tilbage-knappen, hvis vi er i "Kun opgave" mode
                  if (_currentStep == 2 && widget.rewardId == null)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFFF6B35)),
                      onPressed: () => setState(() => _currentStep = 1),
                    ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF3F3F46), height: 1),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _currentStep == 1 ? _buildStep1() : _buildStep2(),
              ),
            ),

            SafeArea(
              child: InkWell(
                onTap: () {
                  if (_currentStep == 1) {
                    if (_rewardFormKey.currentState!.validate()) {
                      setState(() => _currentStep = 2);
                    }
                  } else {
                    _saveToDatabase();
                  }
                },
                child: Container(
                  height: 70,
                  width: double.infinity,
                  color: const Color(0xFFFF6B35),
                  alignment: Alignment.center,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          // NYT: Teksten på knappen skifter baseret på mode
                          widget.rewardId != null 
                            ? 'Opret opgave' 
                            : (_currentStep == 1 ? 'Tilføj opgaver' : 'Opret belønning'),
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Form(
      key: _rewardFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Belønnings navn'),
          _buildTextField(_rewardNameCtrl, 'Giv din belønning et navn..', (v) => _validateNavn(v, 30)),
          
          const SizedBox(height: 24),
          _buildLabel('Beskrivelse'),
          _buildTextField(_rewardDescCtrl, 'Hvad får man for at løse opgaverne?', (v) => _validateBeskrivelse(v, 60), maxLines: 3),
          
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLabel('Fuldført kriterie'),
              Text('${_completionCriteria.toInt()}%', style: const TextStyle(color: Color(0xFFFF6B35), fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFFF6B35),
              inactiveTrackColor: const Color(0xFF3F3F46),
              thumbColor: const Color(0xFFFF6B35),
              trackHeight: 6.0,
            ),
            child: Slider(
              value: _completionCriteria,
              min: 0,
              max: 100,
              divisions: 20,
              onChanged: (value) => setState(() => _completionCriteria = value),
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0%', style: TextStyle(color: Colors.white54, fontSize: 12)),
              Text('100%', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 50),
          const Divider(color: Color(0xFF3F3F46)),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history, color: Colors.white70),
            title: const Text('Opret fra tidligere belønning', style: TextStyle(color: Colors.white)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bygges senere!')));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Form(
      key: _taskFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Opgave overskrift'),
          _buildTextField(_taskNameCtrl, 'F.eks. Tøm opvaskemaskinen', (v) => _validateNavn(v, 20)),
          
          const SizedBox(height: 24),
          _buildLabel('Beskrivelse'),
          _buildTextField(_taskDescCtrl, 'Hvad skal der præcis gøres?', (v) => _validateBeskrivelse(v, 50), maxLines: 2),
          
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLabel('Er opgaven obligatorisk?'),
              Switch(
                value: _isMandatory,
                activeColor: const Color(0xFFFF6B35),
                onChanged: (val) => setState(() => _isMandatory = val),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLabel('Antal gange'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFF6B35), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, color: Colors.black),
                      onPressed: () {
                        if (_taskRepetitions > 1) setState(() => _taskRepetitions--);
                      },
                    ),
                    Text('$_taskRepetitions', style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.black),
                      onPressed: () {
                        if (_taskRepetitions < 50) setState(() => _taskRepetitions++);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildLabel('Vælg hvem der skal udføre opgaven'),
          const SizedBox(height: 12),
          if (_isLoadingMembers)
            const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
          else
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _familyMembers.map((member) {
                final String name = member['navn'] ?? 'Ukendt';
                final String shortName = name.split(' ')[0];
                final bool isSelected = _selectedMembers.contains(member['id']);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedMembers.remove(member['id']);
                      } else {
                        _selectedMembers.add(member['id']);
                      }
                    });
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFFF6B35).withOpacity(0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFFF6B35) : const Color(0xFF3F3F46),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.person_outline,
                          color: isSelected ? const Color(0xFFFF6B35) : Colors.white54,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        shortName,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFFFF6B35) : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600));
  }

  Widget _buildTextField(TextEditingController controller, String hint, String? Function(String?) validator, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24),
          filled: true,
          fillColor: const Color(0xFF2A2A30),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFF6B35))),
          errorStyle: const TextStyle(color: Colors.redAccent),
        ),
        validator: validator,
      ),
    );
  }
}
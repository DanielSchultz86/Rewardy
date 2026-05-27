import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OpretBelonningPopup extends StatefulWidget {
  final String familyId;
  final String? rewardId;
  final QueryDocumentSnapshot? taskDoc; // Bruges når vi skal redigere en specifik opgave

  const OpretBelonningPopup({
    super.key, 
    required this.familyId, 
    this.rewardId, 
    this.taskDoc,
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

  // --- HUSKE-VARIABLER TIL AT TJEKKE UGEMTE ÆNDRINGER ---
  String _initTaskName = '';
  String _initTaskDesc = '';
  bool _initIsMandatory = false;
  int _initTaskRepetitions = 1;
  List<String> _initSelectedMembers = [];

  // --- DATA FRA DATABASE ---
  List<Map<String, dynamic>> _familyMembers = [];
  bool _isLoadingMembers = true;
  bool _isSaving = false;
  String? _existingRewardMemberId; // Gemmer ejeren af belønningen, hvis vi tilføjer en ny opgave

  @override
  void initState() {
    super.initState();
    
    // Hop direkte til Trin 2 (Opgaver), hvis vi har et rewardId eller taskDoc
    if (widget.rewardId != null || widget.taskDoc != null) {
      _currentStep = 2;
    }

    // Hvis vi er i REDIGER mode, så udfyld felterne automatisk og gem start-værdier
    if (widget.taskDoc != null) {
      final data = widget.taskDoc!.data() as Map<String, dynamic>;
      
      // Sæt start-værdierne til at tjekke ugemte ændringer senere
      _initTaskName = data['navn'] ?? '';
      _initTaskDesc = data['beskrivelse'] ?? '';
      _initIsMandatory = data['erMandatory'] ?? false;
      _initTaskRepetitions = data['antalGange'] ?? 1;
      _initSelectedMembers = [data['medlemId']];

      // Udfyld formen
      _taskNameCtrl.text = _initTaskName;
      _taskDescCtrl.text = _initTaskDesc;
      _isMandatory = _initIsMandatory;
      _taskRepetitions = _initTaskRepetitions;
      _selectedMembers = List.from(_initSelectedMembers); 
    } else if (widget.rewardId != null) {
      // Hvis vi TILFØJER en ny opgave til en eksisterende belønning, skal vi finde ud af, hvem belønningen tilhører
      _fetchExistingRewardMember();
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

  Future<void> _fetchExistingRewardMember() async {
    try {
      final tasksSnap = await FirebaseFirestore.instance
          .collection('families')
          .doc(widget.familyId)
          .collection('rewards')
          .doc(widget.rewardId)
          .collection('tasks')
          .limit(1)
          .get();

      if (tasksSnap.docs.isNotEmpty) {
        setState(() {
          _existingRewardMemberId = tasksSnap.docs.first['medlemId'];
          _selectedMembers = [_existingRewardMemberId!]; 
        });
      }
    } catch (e) {
      debugPrint("Kunne ikke hente ejer af belønning: $e");
    }
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
    if (value.trim().length > maxLength) return 'Maks $maxLength tegn';
    if (!RegExp(r'^[a-zA-ZæøåÆØÅ0-9 ]+$').hasMatch(value.trim())) return 'Kun bogstaver og tal er tilladt her';
    return null;
  }

  String? _validateBeskrivelse(String? value, int maxLength) {
    if (value != null && value.trim().isNotEmpty) {
      if (value.trim().length > maxLength) return 'Maks $maxLength tegn';
    }
    return null; 
  }

  bool _hasUnsavedChanges() {
    bool rewardChanged = _rewardNameCtrl.text.trim().isNotEmpty ||
                         _rewardDescCtrl.text.trim().isNotEmpty ||
                         _completionCriteria != 50.0;
    
    String currentMembers = (_selectedMembers.toList()..sort()).join(',');
    String initialMembers = (_initSelectedMembers.toList()..sort()).join(',');

    bool taskChanged = _taskNameCtrl.text.trim() != _initTaskName ||
                       _taskDescCtrl.text.trim() != _initTaskDesc ||
                       _isMandatory != _initIsMandatory ||
                       _taskRepetitions != _initTaskRepetitions ||
                       currentMembers != initialMembers;

    if (widget.taskDoc != null || widget.rewardId != null) {
      return taskChanged;
    } else {
      return rewardChanged || taskChanged;
    }
  }

  Future<bool> _showExitDialog() async {
    final shouldPop = await showDialog<bool>(
      useRootNavigator: true,
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

  // --- FUNKTION: KOPIER OPGAVE ---
  void _showKopierOpgave() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => KopierOpgaveSheet(
        familyId: widget.familyId,
        initTaskName: _taskNameCtrl.text.trim(),
        initTaskDesc: _taskDescCtrl.text.trim(),
        initIsMandatory: _isMandatory,
        initTaskRepetitions: _taskRepetitions,
      ),
    );
  }

  // --- FUNKTION: Slet Opgave ---
  Future<void> _deleteTask() async {
    final confirm = await showDialog<bool>(
      useRootNavigator: true,
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A30),
        title: const Text('Slet opgave?', style: TextStyle(color: Colors.white)),
        content: const Text('Er du sikker på, at du vil slette denne opgave? Det kan ikke fortrydes.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuller', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Slet', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      await widget.taskDoc!.reference.delete();
      if (mounted) {
        Navigator.of(context).pop(); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opgaven blev slettet.'), backgroundColor: Color(0xFF008D3D))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fejl ved sletning: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveToDatabase() async {
    if (!_taskFormKey.currentState!.validate()) return;
    
    if (_selectedMembers.isEmpty && _existingRewardMemberId == null) {
      showDialog(
        useRootNavigator: true,
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A30),
          title: const Text('Hov!', style: TextStyle(color: Colors.white)),
          content: const Text('Du skal vælge mindst ét medlem for at gemme eller oprette opgaven.', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Color(0xFFFF6B35))),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // SCENARIE 1: Vi redigerer en eksisterende opgave
      if (widget.taskDoc != null) {
        final originalMemberId = widget.taskDoc!['medlemId'];
        
        batch.update(widget.taskDoc!.reference, {
          'navn': _taskNameCtrl.text.trim(),
          'beskrivelse': _taskDescCtrl.text.trim(),
          'erMandatory': _isMandatory,
          'antalGange': _taskRepetitions,
        });

        // Hent info om den belønning opgaven ligger i
        final String rId = widget.rewardId ?? widget.taskDoc!.reference.parent.parent!.id;
        final originalRewardSnap = await db.collection('families').doc(widget.familyId).collection('rewards').doc(rId).get();
        final Map<String, dynamic>? rewardData = originalRewardSnap.data();

        final String rewardName = rewardData?['navn'] ?? _taskNameCtrl.text.trim();
        final String rewardDesc = rewardData?['beskrivelse'] ?? '';
        final double completionCriteria = (rewardData?['fuldfoertKriterie'] ?? 50.0).toDouble();

        // TJEK: Hvilke af de valgte medlemmer har i forvejen en belønning med dette navn?
        final sameNameRewardsSnap = await db.collection('families').doc(widget.familyId).collection('rewards').where('navn', isEqualTo: rewardName).get();
        Map<String, String> existingMemberRewards = {};
        for (var rewDoc in sameNameRewardsSnap.docs) {
          final tasksSnap = await rewDoc.reference.collection('tasks').limit(1).get();
          if (tasksSnap.docs.isNotEmpty) {
            final String? memId = tasksSnap.docs.first.data()['medlemId'];
            if (memId != null) {
              existingMemberRewards[memId] = rewDoc.id;
            }
          }
        }

        for (String memberId in _selectedMembers) {
          if (memberId != originalMemberId) {
             DocumentReference newRewardRef;

             // Har medlemmet allerede belønningen?
             if (existingMemberRewards.containsKey(memberId)) {
                newRewardRef = db.collection('families').doc(widget.familyId).collection('rewards').doc(existingMemberRewards[memberId]);
             } else {
                newRewardRef = db.collection('families').doc(widget.familyId).collection('rewards').doc();
                batch.set(newRewardRef, {
                  'navn': rewardName,
                  'beskrivelse': rewardDesc,
                  'fuldfoertKriterie': completionCriteria,
                  'createdAt': FieldValue.serverTimestamp(),
                });
             }

            final newTaskRef = newRewardRef.collection('tasks').doc();
            batch.set(newTaskRef, {
              'navn': _taskNameCtrl.text.trim(),
              'beskrivelse': _taskDescCtrl.text.trim(),
              'erMandatory': _isMandatory,
              'antalGange': _taskRepetitions,
              'udfoertGange': 0,
              'medlemId': memberId,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
      } 
      // SCENARIE 2: Vi tilføjer en NY opgave til en eksisterende belønning
      else if (widget.rewardId != null) {
        final rewardRef = db.collection('families').doc(widget.familyId).collection('rewards').doc(widget.rewardId);
        
        final taskRef = rewardRef.collection('tasks').doc();
        batch.set(taskRef, {
          'navn': _taskNameCtrl.text.trim(),
          'beskrivelse': _taskDescCtrl.text.trim(),
          'erMandatory': _isMandatory,
          'antalGange': _taskRepetitions,
          'udfoertGange': 0,
          'medlemId': _existingRewardMemberId ?? _selectedMembers.first, 
          'createdAt': FieldValue.serverTimestamp(),
        });
      } 
      // SCENARIE 3: Vi opretter en helt ny belønning
      else {
        for (String memberId in _selectedMembers) {
          final rewardRef = db.collection('families').doc(widget.familyId).collection('rewards').doc();
          batch.set(rewardRef, {
            'navn': _rewardNameCtrl.text.trim(),
            'beskrivelse': _rewardDescCtrl.text.trim(),
            'fuldfoertKriterie': _completionCriteria,
            'createdAt': FieldValue.serverTimestamp(),
          });

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
      }

      await batch.commit();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.taskDoc != null ? 'Opgaven er opdateret!' : 'Oprettet med succes!'), 
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
    // Vi viser kun medlemsvalg, når vi opretter en HELT NY belønning (Trin 1 -> Trin 2)
    // Når vi redigerer (taskDoc != null) eller tilføjer til eksisterende (rewardId != null), skjules det.
    bool showMemberSelection = (widget.rewardId == null && widget.taskDoc == null);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        if (!_hasUnsavedChanges()) {
          Navigator.of(context).pop();
          return;
        }
        
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
                      if (!_hasUnsavedChanges()) {
                        Navigator.of(context).pop();
                        return;
                      }
                      
                      final shouldExit = await _showExitDialog();
                      if (shouldExit && context.mounted) Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.taskDoc != null 
                        ? 'Ret opgave' 
                        : (widget.rewardId != null ? 'Opret opgave' : (_currentStep == 1 ? 'Opret belønning' : 'Tilføj opgaver')),
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_currentStep == 2 && widget.rewardId == null && widget.taskDoc == null)
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
                child: _currentStep == 1 ? _buildStep1() : _buildStep2(showMemberSelection),
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
                          widget.taskDoc != null 
                            ? 'Gem ændringer' 
                            : (widget.rewardId != null ? 'Opret opgave' : (_currentStep == 1 ? 'Tilføj opgaver' : 'Opret belønning')),
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
          _buildTextField(_rewardNameCtrl, 'Giv din belønning et navn..', (v) => _validateNavn(v, 50)),
          
          const SizedBox(height: 24),
          _buildLabel('Beskrivelse'),
          _buildTextField(_rewardDescCtrl, 'Hvad får man for at løse opgaverne?', (v) => _validateBeskrivelse(v, 100), maxLines: 3),
          
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
        ],
      ),
    );
  }

  Widget _buildStep2(bool showMemberSelection) {
    return Form(
      key: _taskFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Opgave overskrift'),
          _buildTextField(_taskNameCtrl, 'F.eks. Tøm opvaskemaskinen', (v) => _validateNavn(v, 50)),
          
          const SizedBox(height: 24),
          _buildLabel('Beskrivelse'),
          _buildTextField(_taskDescCtrl, 'Hvad skal der præcis gøres?', (v) => _validateBeskrivelse(v, 100), maxLines: 2),
          
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
                        if (_taskRepetitions < 7) setState(() => _taskRepetitions++);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // SKJULER MEDLEMSVALG HVIS VI RETTER EN OPGAVE ELLER TILFØJER TIL EKSISTERENDE BELØNNING
          if (showMemberSelection && _familyMembers.isNotEmpty) ...[
            const SizedBox(height: 32),
            _buildLabel('Tildel belønning og opgave til:'),
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

          // KNAPPER DER KUN VISES NÅR MAN REDIGERER EN OPGAVE (Kopier & Slet)
          if (widget.taskDoc != null) ...[
            const SizedBox(height: 32),
            const Divider(color: Color(0xFF3F3F46), height: 1),
            const SizedBox(height: 24),
            
            // KOPIER OPGAVE KNAP
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showKopierOpgave,
                icon: const Icon(Icons.copy, color: Color(0xFF008D3D)),
                label: const Text('Kopier opgave', style: TextStyle(color: Color(0xFF008D3D), fontSize: 16, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Color(0xFF008D3D), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SLET KNAP
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isSaving ? null : _deleteTask,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Slet opgave', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ]
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

// ==============================================================================
// NYT BUND-SHEET TIL "KOPIER BELØNNING" (Inkl. valg af opgaver og medlemmer)
// ==============================================================================
class KopierBelonningSheet extends StatefulWidget {
  final String familyId;
  final String rewardId; // Det originale belønnings ID vi kopierer fra

  const KopierBelonningSheet({
    super.key,
    required this.familyId,
    required this.rewardId,
  });

  @override
  State<KopierBelonningSheet> createState() => _KopierBelonningSheetState();
}

class _KopierBelonningSheetState extends State<KopierBelonningSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  double _criteria = 50.0;
  
  bool _isLoading = true;
  bool _isSaving = false;
  
  List<Map<String, dynamic>> _allTasks = [];
  List<Map<String, dynamic>> _members = [];
  
  List<String> _selectedTaskIds = [];
  List<String> _selectedMembers = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final db = FirebaseFirestore.instance;
    
    // 1. Hent original belønning info for at forudfylde formular
    final rewDoc = await db.collection('families').doc(widget.familyId).collection('rewards').doc(widget.rewardId).get();
    if (rewDoc.exists) {
      _nameCtrl.text = rewDoc.data()?['navn'] ?? '';
      _descCtrl.text = rewDoc.data()?['beskrivelse'] ?? '';
      _criteria = (rewDoc.data()?['fuldfoertKriterie'] ?? 50.0).toDouble();
    }

    // Hent opgaver som tilhører præcis denne belønning (til auto-markering)
    List<String> currentRewardTaskNames = [];
    final currentTasksSnap = await rewDoc.reference.collection('tasks').get();
    for (var t in currentTasksSnap.docs) {
       currentRewardTaskNames.add(t.data()['navn'] ?? '');
    }

    // 2. Hent familiens medlemmer
    final memSnap = await db.collection('members').where('familier', arrayContains: widget.familyId).get();
    
    // 3. Hent ALLE unikke opgaver i hele familien (på tværs af alle belønninger)
    final allRewSnap = await db.collection('families').doc(widget.familyId).collection('rewards').get();
    
    Set<String> seenTaskNames = {};
    List<Map<String, dynamic>> tempTasks = [];

    for (var r in allRewSnap.docs) {
      final tSnap = await r.reference.collection('tasks').get();
      for (var t in tSnap.docs) {
        final data = t.data();
        final name = data['navn'] ?? '';
        
        if (!seenTaskNames.contains(name) && name.isNotEmpty) {
          seenTaskNames.add(name);
          tempTasks.add({
            'id': t.id,
            'navn': name,
            'beskrivelse': data['beskrivelse'] ?? '',
            'erMandatory': data['erMandatory'] ?? false,
            'antalGange': data['antalGange'] ?? 1,
          });
          
          // Auto-vælg opgaven, hvis den lå i den oprindelige belønning vi trykkede 'kopier' på
          if (currentRewardTaskNames.contains(name)) {
            _selectedTaskIds.add(t.id);
          }
        }
      }
    }
    
    setState(() {
      _members = memSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      _allTasks = tempTasks;
      _isLoading = false;
    });
  }

  Future<void> _gemKopiering() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vælg venligst mindst ét medlem'), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => _isSaving = true);
    
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      
      // Find de faktiske opgave-objekter som brugeren har markeret
      final selectedTaskObjects = _allTasks.where((t) => _selectedTaskIds.contains(t['id'])).toList();

      for (var memId in _selectedMembers) {
        // 1. Opret ny belønning pr. medlem
        final newRewardRef = db.collection('families').doc(widget.familyId).collection('rewards').doc();
        batch.set(newRewardRef, {
          'navn': _nameCtrl.text.trim(),
          'beskrivelse': _descCtrl.text.trim(),
          'fuldfoertKriterie': _criteria,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 2. Kopier alle de valgte opgaver ind i den nye belønning
        for (var tObj in selectedTaskObjects) {
          final newTaskRef = newRewardRef.collection('tasks').doc();
          batch.set(newTaskRef, {
            'navn': tObj['navn'],
            'beskrivelse': tObj['beskrivelse'],
            'erMandatory': tObj['erMandatory'],
            'antalGange': tObj['antalGange'],
            'udfoertGange': 0,
            'medlemId': memId,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
      
      await batch.commit();
      
      if (mounted) {
        Navigator.pop(context); // Luk "Kopier Belønning" popup
        Navigator.pop(context); // Luk bagvedliggende "Ret Opgave" popup
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Belønningen og opgaver blev kopieret!'), backgroundColor: Color(0xFF008D3D)),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fejl: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Kopier Belønning', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(color: Color(0xFF3F3F46), height: 1),

          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF008D3D)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- BELØNNINGS INFO ---
                        const Text('Belønnings navn', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameCtrl,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Navn mangler' : null,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true, fillColor: const Color(0xFF2A2A30),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        const Text('Beskrivelse', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _descCtrl,
                          maxLines: 2,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true, fillColor: const Color(0xFF2A2A30),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),

                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Fuldført kriterie', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                            Text('${_criteria.toInt()}%', style: const TextStyle(color: Color(0xFF008D3D), fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                        Slider(
                          value: _criteria,
                          min: 0, max: 100, divisions: 20,
                          activeColor: const Color(0xFF008D3D),
                          inactiveColor: const Color(0xFF3F3F46),
                          onChanged: (v) => setState(() => _criteria = v),
                        ),

                        const SizedBox(height: 32),
                        const Divider(color: Color(0xFF3F3F46), height: 1),
                        const SizedBox(height: 32),

                        // --- VÆLG OPGAVER ---
                        const Text('1. Vælg opgaver der skal kopieres med', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        if (_allTasks.isEmpty)
                          const Text('Ingen opgaver fundet', style: TextStyle(color: Colors.white54))
                        else
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: _allTasks.map((task) {
                              final bool isSelected = _selectedTaskIds.contains(task['id']);
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) _selectedTaskIds.remove(task['id']);
                                    else _selectedTaskIds.add(task['id']);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF008D3D).withOpacity(0.2) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isSelected ? const Color(0xFF008D3D) : const Color(0xFF3F3F46), width: 2),
                                  ),
                                  child: Text(
                                    task['navn'],
                                    style: TextStyle(
                                      color: isSelected ? const Color(0xFF008D3D) : Colors.white70,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                        const SizedBox(height: 32),

                        // --- VÆLG MEDLEMMER ---
                        const Text('2. Vælg medlemmer', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: _members.map((member) {
                            final String shortName = (member['navn'] ?? 'Ukendt').split(' ')[0];
                            final bool isSelected = _selectedMembers.contains(member['id']);

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) _selectedMembers.remove(member['id']);
                                  else _selectedMembers.add(member['id']);
                                });
                              },
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF008D3D).withOpacity(0.2) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: isSelected ? const Color(0xFF008D3D) : const Color(0xFF3F3F46), width: 2),
                                    ),
                                    child: Icon(Icons.person_outline, color: isSelected ? const Color(0xFF008D3D) : Colors.white54, size: 30),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(shortName, style: TextStyle(color: isSelected ? const Color(0xFF008D3D) : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
          
          SafeArea(
            child: InkWell(
              onTap: _isSaving ? null : _gemKopiering,
              child: Container(
                height: 70,
                width: double.infinity,
                color: const Color(0xFF008D3D),
                alignment: Alignment.center,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Gem belønning', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==============================================================================
// BUND-SHEET TIL "KOPIER OPGAVE" (DEN OPRINDELIGE - URØRT)
// ==============================================================================
class KopierOpgaveSheet extends StatefulWidget {
  final String familyId;
  final String initTaskName;
  final String initTaskDesc;
  final bool initIsMandatory;
  final int initTaskRepetitions;

  const KopierOpgaveSheet({
    super.key,
    required this.familyId,
    required this.initTaskName,
    required this.initTaskDesc,
    required this.initIsMandatory,
    required this.initTaskRepetitions,
  });

  @override
  State<KopierOpgaveSheet> createState() => _KopierOpgaveSheetState();
}

class _KopierOpgaveSheetState extends State<KopierOpgaveSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  
  // Controllers til ny belønning
  final _newRewardFormKey = GlobalKey<FormState>(); 
  final TextEditingController _newRewardNameCtrl = TextEditingController();
  final TextEditingController _newRewardDescCtrl = TextEditingController();
  double _newRewardCriteria = 50.0;
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isCreatingNew = false;
  
  List<Map<String, dynamic>> _uniqueRewards = [];
  List<Map<String, dynamic>> _members = [];
  
  String? _selectedRewardId;
  List<String> _selectedMembers = [];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initTaskName);
    _descCtrl = TextEditingController(text: widget.initTaskDesc);
    _fetchData();
  }

  Future<void> _fetchData() async {
    final db = FirebaseFirestore.instance;
    
    // Hent alle familiens medlemmer
    final memSnap = await db.collection('members').where('familier', arrayContains: widget.familyId).get();
    
    // Hent familiens belønninger
    final rewSnap = await db.collection('families').doc(widget.familyId).collection('rewards').get();
    
    final seenNames = <String>{};
    final uniqueRewardsList = <Map<String, dynamic>>[];
    for (var doc in rewSnap.docs) {
      final data = doc.data();
      final name = data['navn'] ?? '';
      if (!seenNames.contains(name)) {
        seenNames.add(name);
        uniqueRewardsList.add({'id': doc.id, 'navn': name});
      }
    }
    
    setState(() {
      _members = memSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      _uniqueRewards = uniqueRewardsList;
      _isLoading = false;
    });
  }

  String? _validateNavn(String? value, int maxLength) {
    if (value == null || value.trim().isEmpty) return 'Feltet må ikke være tomt';
    return null;
  }

  Future<void> _gemKopieretOpgave() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    
    // VALIDERINGS-TJEK
    if (_isCreatingNew) {
      if (!_newRewardFormKey.currentState!.validate()) return;
    } else if (_selectedRewardId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vælg venligst en belønning først'), backgroundColor: Colors.redAccent));
      return;
    }
    
    if (_selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vælg mindst ét medlem'), backgroundColor: Colors.redAccent));
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      
      String rewardName = '';
      String rewardDesc = '';
      double completionCriteria = 50.0;
      
      // LOGIK HVIS VI OPRETTER NY BELØNNING
      if (_isCreatingNew) {
         rewardName = _newRewardNameCtrl.text.trim();
         rewardDesc = _newRewardDescCtrl.text.trim();
         completionCriteria = _newRewardCriteria;
      } else {
         // Hent eksisterende
         final originalRewardSnap = await db.collection('families').doc(widget.familyId).collection('rewards').doc(_selectedRewardId).get();
         final Map<String, dynamic>? rewardData = originalRewardSnap.data();
         if (rewardData == null) throw Exception("Kunne ikke finde den valgte belønning");
         rewardName = rewardData['navn'] ?? 'Kopieret belønning';
         rewardDesc = rewardData['beskrivelse'] ?? '';
         completionCriteria = (rewardData['fuldfoertKriterie'] ?? 50.0).toDouble();
      }

      // --- Tjek for eksisterende belønninger med samme navn ---
      final sameNameRewardsSnap = await db.collection('families').doc(widget.familyId).collection('rewards').where('navn', isEqualTo: rewardName).get();
      Map<String, String> existingMemberRewards = {};

      for (var rewDoc in sameNameRewardsSnap.docs) {
        final tasksSnap = await rewDoc.reference.collection('tasks').limit(1).get();
        if (tasksSnap.docs.isNotEmpty) {
          final String? memId = tasksSnap.docs.first.data()['medlemId'];
          if (memId != null) {
            existingMemberRewards[memId] = rewDoc.id;
          }
        }
      }
         
      // 2. Loop igennem alle valgte medlemmer
      for (var memId in _selectedMembers) {
        DocumentReference rewardRef;

        // Tjek om medlemmet allerede har denne belønning (Kun hvis vi IKKE lige har oprettet en helt ny)
        if (!_isCreatingNew && existingMemberRewards.containsKey(memId)) {
           rewardRef = db.collection('families').doc(widget.familyId).collection('rewards').doc(existingMemberRewards[memId]);
        } else {
           // Opret en NY belønning til dette medlem
           rewardRef = db.collection('families').doc(widget.familyId).collection('rewards').doc();
           batch.set(rewardRef, {
             'navn': rewardName,
             'beskrivelse': rewardDesc,
             'fuldfoertKriterie': completionCriteria,
             'createdAt': FieldValue.serverTimestamp(),
           });
        }

        // Opret opgaven INDE i belønningen
        final taskRef = rewardRef.collection('tasks').doc();
        batch.set(taskRef, {
          'navn': _nameCtrl.text.trim(),
          'beskrivelse': _descCtrl.text.trim(),
          'erMandatory': widget.initIsMandatory,
          'antalGange': widget.initTaskRepetitions,
          'udfoertGange': 0,
          'medlemId': memId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      
      if (mounted) {
        Navigator.pop(context); // Luk "Kopier" popup
        Navigator.pop(context); // Luk "Ret opgave" popup
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opgaven blev kopieret!'), backgroundColor: Color(0xFF008D3D)),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fejl: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Kopier Opgave', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(color: Color(0xFF3F3F46), height: 1),

          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF008D3D)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Navn', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true, fillColor: const Color(0xFF2A2A30),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      const Text('Beskrivelse', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _descCtrl,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true, fillColor: const Color(0xFF2A2A30),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),

                      const SizedBox(height: 32),
                      
                      // LOGIK FOR VALG ELLER OPRETTELSE AF BELØNNING
                      if (_isCreatingNew) ...[
                        const Text('Opret ny belønning', style: TextStyle(color: Color(0xFFFF6B35), fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        
                        Form(
                          key: _newRewardFormKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _newRewardNameCtrl, 
                                validator: (v) => _validateNavn(v, 50),
                                style: const TextStyle(color: Colors.white), 
                                decoration: const InputDecoration(hintText: 'Belønnings navn', filled: true, fillColor: Color(0xFF2A2A30), border: OutlineInputBorder(borderSide: BorderSide.none))
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _newRewardDescCtrl, 
                                style: const TextStyle(color: Colors.white), 
                                decoration: const InputDecoration(hintText: 'Beskrivelse', filled: true, fillColor: Color(0xFF2A2A30), border: OutlineInputBorder(borderSide: BorderSide.none))
                              ),
                            ]
                          )
                        ),

                        const SizedBox(height: 16),
                        Slider(value: _newRewardCriteria, min: 0, max: 100, divisions: 20, onChanged: (v) => setState(() => _newRewardCriteria = v), activeColor: const Color(0xFFFF6B35)),
                        Center(child: Text('${_newRewardCriteria.toInt()}% kriterie', style: const TextStyle(color: Colors.white54))),
                        TextButton(onPressed: () => setState(() => _isCreatingNew = false), child: const Text('Annuller oprettelse af ny')),
                      ] else ...[
                        const Text('1. Vælg skabelon til belønning', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedRewardId,
                          dropdownColor: const Color(0xFF2A2A30),
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(filled: true, fillColor: const Color(0xFF2A2A30), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                          hint: const Text('Hvilken belønning skal kopieres?', style: TextStyle(color: Colors.white54)),
                          items: _uniqueRewards.map((r) => DropdownMenuItem<String>(value: r['id'], child: Text(r['navn']))).toList(),
                          onChanged: (val) => setState(() => _selectedRewardId = val),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () => setState(() => _isCreatingNew = true),
                          child: const Text('Opret ny belønning til opgave'),
                        ),
                      ],

                      const SizedBox(height: 32),
                      const Text('2. Vælg medlemmer', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: _members.map((member) {
                          final String shortName = (member['navn'] ?? 'Ukendt').split(' ')[0];
                          final bool isSelected = _selectedMembers.contains(member['id']);

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) _selectedMembers.remove(member['id']);
                                else _selectedMembers.add(member['id']);
                              });
                            },
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF008D3D).withOpacity(0.2) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isSelected ? const Color(0xFF008D3D) : const Color(0xFF3F3F46), width: 2),
                                  ),
                                  child: Icon(Icons.person_outline, color: isSelected ? const Color(0xFF008D3D) : Colors.white54, size: 30),
                                ),
                                const SizedBox(height: 6),
                                Text(shortName, style: TextStyle(color: isSelected ? const Color(0xFF008D3D) : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
          ),
          
          SafeArea(
            child: InkWell(
              onTap: _isSaving ? null : _gemKopieretOpgave,
              child: Container(
                height: 70,
                width: double.infinity,
                color: const Color(0xFF008D3D),
                alignment: Alignment.center,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Gem kopi', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
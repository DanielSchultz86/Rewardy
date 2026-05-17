import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/app_drawer.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Formular controllere for Profil-info
  final _infoFormKey = GlobalKey<FormState>();
  late TextEditingController _navnCtrl;
  late TextEditingController _emailCtrl;
  bool _isSavingInfo = false;

  // Formular controllere for Adgangskode
  final _passwordFormKey = GlobalKey<FormState>();
  final TextEditingController _oldPasswordCtrl = TextEditingController();
  final TextEditingController _newPasswordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();
  bool _isSavingPassword = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    // Vi sætter et midlertidigt navn fra Auth, indtil vi har hentet fra databasen
    _navnCtrl = TextEditingController(text: currentUser?.displayName ?? '');
    _emailCtrl = TextEditingController(text: currentUser?.email ?? '');
    
    // Hent det rigtige username fra Firestore
    _hentBrugerData();
  }

  @override
  void dispose() {
    _navnCtrl.dispose();
    _emailCtrl.dispose();
    _oldPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  // --- HENT USERNAME FRA FIRESTORE ---
  Future<void> _hentBrugerData() async {
    if (currentUser == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (doc.exists && doc.data()!.containsKey('username')) {
        setState(() {
          _navnCtrl.text = doc.data()!['username'];
        });
      }
    } catch (e) {
      debugPrint("Kunne ikke hente username fra Firestore: $e");
    }
  }

  // Hjælpefunktion til at vise beskeder i toppen (svævende)
  void _showPopupMessage(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.8,
          left: 24,
          right: 24,
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // --- OPDATER PROFILINFO (Navn & Email) ---
  Future<void> _updateProfileInfo() async {
    if (!_infoFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSavingInfo = true);

    try {
      final newName = _navnCtrl.text.trim();
      final newEmail = _emailCtrl.text.trim();

      bool didUpdate = false;

      // Opdater navn i BÅDE Firebase Auth og Firestore
      if (newName.isNotEmpty) {
        // Opdater Auth
        await currentUser?.updateDisplayName(newName);
        
        // Opdater Firestore (users kollektionen)
        await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).set({
          'username': newName,
        }, SetOptions(merge: true)); // merge: true sørger for, at vi ikke overskriver andet data
        
        didUpdate = true;
      }

      // Opdater email hvis ændret
      if (newEmail != currentUser?.email) {
        await currentUser?.verifyBeforeUpdateEmail(newEmail);
        _showPopupMessage('Vi har sendt et bekræftelseslink til din nye email. Tjek din indbakke.', const Color(0xFF008D3D));
        didUpdate = true;
      }

      if (didUpdate && newEmail == currentUser?.email) {
        _showPopupMessage('Profiloplysninger blev opdateret!', const Color(0xFF008D3D));
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showPopupMessage('Ændring af email kræver, at du logger ud og ind igen for sikkerhedens skyld.', Colors.redAccent);
      } else {
        _showPopupMessage(e.message ?? 'Der opstod en fejl', Colors.redAccent);
      }
    } catch (e) {
      _showPopupMessage('Der opstod en database-fejl', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isSavingInfo = false);
    }
  }

  // --- SKIFT ADGANGSKODE ---
  Future<void> _updatePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSavingPassword = true);

    try {
      // 1. Re-authentificer brugeren med det gamle password
      final email = currentUser?.email;
      if (email == null) throw Exception("Ingen email fundet på brugeren.");

      final credential = EmailAuthProvider.credential(
        email: email,
        password: _oldPasswordCtrl.text,
      );

      await currentUser?.reauthenticateWithCredential(credential);

      // 2. Opdater til det nye password
      await currentUser?.updatePassword(_newPasswordCtrl.text);

      _showPopupMessage('Adgangskode blev ændret med succes!', const Color(0xFF008D3D));
      
      // Ryd felterne
      _oldPasswordCtrl.clear();
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();

    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _showPopupMessage('Den nuværende adgangskode er forkert.', Colors.redAccent);
      } else {
        _showPopupMessage(e.message ?? 'Kunne ikke skifte adgangskode.', Colors.redAccent);
      }
    } catch (e) {
      _showPopupMessage('Der opstod en uventet fejl.', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isSavingPassword = false);
    }
  }

  // --- SLET PROFIL ---
  void _bekraeftSletProfil() {
    final passwordCtrl = TextEditingController();
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF2A2A30),
            title: const Text('Slet profil permanent?', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Er du helt sikker? Dette sletter din bruger, alle dine familier, belønninger, opgaver og medlemmer for altid. Dette kan IKKE fortrydes.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                const Text('Indtast adgangskode for at bekræfte:', style: TextStyle(color: Colors.white, fontSize: 14)),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true, fillColor: const Color(0xFF121214),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Annuller', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: isDeleting ? null : () async {
                  if (passwordCtrl.text.isEmpty) return;
                  setDialogState(() => isDeleting = true);

                  try {
                    // 1. Re-auth for at bekræfte identitet
                    final credential = EmailAuthProvider.credential(
                      email: currentUser!.email!,
                      password: passwordCtrl.text,
                    );
                    await currentUser!.reauthenticateWithCredential(credential);

                    // 2. Slet data i databasen
                    await _sletAlData();

                    // 3. Slet selve brugerkontoen
                    await currentUser!.delete();

                    // 4. Naviger til login skærmen (fjern alle tidligere skærme)
                    if (mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                    }

                  } on FirebaseAuthException catch (e) {
                    if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
                      _showPopupMessage('Forkert adgangskode.', Colors.redAccent);
                    } else {
                      _showPopupMessage(e.message ?? 'Fejl ved sletning.', Colors.redAccent);
                    }
                    setDialogState(() => isDeleting = false);
                  } catch (e) {
                    _showPopupMessage('Der opstod en fejl under sletning af data.', Colors.redAccent);
                    setDialogState(() => isDeleting = false);
                  }
                },
                child: isDeleting 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Slet alt permanent', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }

  // Hjælpefunktion til at rydde op i databasen før brugeren slettes
  Future<void> _sletAlData() async {
    final uid = currentUser!.uid;
    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    // 1. Slet brugerens eget dokument i 'users' kollektionen
    final userDocRef = db.collection('users').doc(uid);
    batch.delete(userDocRef);

    // 2. Slet alle medlemmer oprettet af denne bruger
    final membersSnap = await db.collection('members').where('oprettetAf', isEqualTo: uid).get();
    for (var doc in membersSnap.docs) {
      batch.delete(doc.reference);
    }

    // 3. Slet alle familier oprettet af denne bruger (hvis du gemmer createdBy på familier)
    final familiesSnap = await db.collection('families').where('createdBy', isEqualTo: uid).get();
    
    for (var familyDoc in familiesSnap.docs) {
      // Find og slet alle rewards i denne familie
      final rewardsSnap = await familyDoc.reference.collection('rewards').get();
      for (var rewardDoc in rewardsSnap.docs) {
        
        // Find og slet alle opgaver under denne reward
        final tasksSnap = await rewardDoc.reference.collection('tasks').get();
        for (var taskDoc in tasksSnap.docs) {
          batch.delete(taskDoc.reference);
        }
        
        batch.delete(rewardDoc.reference);
      }
      
      // Slet selve familien
      batch.delete(familyDoc.reference);
    }

    await batch.commit();
  }

  // --- UI BYGGEKLODSER ---

  Widget _buildTextField({
    required String label, 
    required TextEditingController controller, 
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? toggleObscure,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true, fillColor: const Color(0xFF121214),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            suffixIcon: isPassword 
                ? IconButton(
                    icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
                    onPressed: toggleObscure,
                  ) 
                : null,
          ),
          validator: validator,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Min Profil', style: TextStyle(fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            
            // --- KORT 1: PROFIL OPLYSNINGER ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A30),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Form(
                key: _infoFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.person, color: Color(0xFFFF6B35)),
                        SizedBox(width: 8),
                        Text('Profiloplysninger', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    _buildTextField(
                      label: 'Dit navn',
                      controller: _navnCtrl,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Navn kan ikke være tomt' : null,
                    ),
                    
                    _buildTextField(
                      label: 'Email adresse',
                      controller: _emailCtrl,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email kan ikke være tom';
                        if (!v.contains('@')) return 'Indtast en gyldig email';
                        return null;
                      },
                    ),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSavingInfo ? null : _updateProfileInfo,
                        child: _isSavingInfo
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Gem oplysninger', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),

            // --- KORT 2: ADGANGSKODE ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A30),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Form(
                key: _passwordFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lock, color: Color(0xFFFFD166)),
                        SizedBox(width: 8),
                        Text('Skift Adgangskode', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    _buildTextField(
                      label: 'Nuværende adgangskode',
                      controller: _oldPasswordCtrl,
                      isPassword: true,
                      obscureText: _obscureOld,
                      toggleObscure: () => setState(() => _obscureOld = !_obscureOld),
                      validator: (v) => v == null || v.isEmpty ? 'Indtast din nuværende adgangskode' : null,
                    ),

                    _buildTextField(
                      label: 'Ny adgangskode',
                      controller: _newPasswordCtrl,
                      isPassword: true,
                      obscureText: _obscureNew,
                      toggleObscure: () => setState(() => _obscureNew = !_obscureNew),
                      validator: (v) => v != null && v.length < 6 ? 'Skal være mindst 6 tegn' : null,
                    ),

                    _buildTextField(
                      label: 'Bekræft ny adgangskode',
                      controller: _confirmPasswordCtrl,
                      isPassword: true,
                      obscureText: _obscureConfirm,
                      toggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      validator: (v) {
                        if (v != _newPasswordCtrl.text) return 'Adgangskoderne er ikke ens';
                        return null;
                      },
                    ),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3F3F46),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSavingPassword ? null : _updatePassword,
                        child: _isSavingPassword
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Skift adgangskode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 48),
            
            // --- DANGER ZONE ---
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _bekraeftSletProfil,
                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                label: const Text('Slet profil permanent', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
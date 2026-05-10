import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/app_drawer.dart';
import 'opret_belonning_popup.dart';

class DashboardScreen extends StatefulWidget {
  final String familyId;
  final String familyName;

  const DashboardScreen({
    super.key,
    required this.familyId,
    required this.familyName,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String selectedMember = 'Alle';
  int _currentTab = 0; // 0 = Igangværende, 1 = Opnåede

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(widget.familyName, style: const TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // TODO: Indstillinger for familien
            },
          ),
        ],
      ),
      // NYT: Fast bundmenu med de to tabs
      bottomNavigationBar: _buildBottomTabs(),
      body: Stack(
        children: [
          Column(
            children: [
              _buildMemberFilter(),
              
              // Hvis vi er på "Opnåede", viser vi en lille overskrift
              if (_currentTab == 1)
                const Padding(
                  padding: EdgeInsets.only(top: 10, bottom: 5),
                  child: Text('🏆 Jeres opnåede belønninger', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
                ),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('families')
                      .doc(widget.familyId)
                      .collection('rewards')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState();
                    }

                    final rewardDocs = snapshot.data!.docs;

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: rewardDocs.length,
                      itemBuilder: (context, index) {
                        return _buildRewardBox(rewardDocs[index]);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          
          // STOR ORANGE KNAP (Skjules på "Opnåede" fanen)
          if (_currentTab == 0)
            Positioned(
              bottom: 30,
              right: 24,
              child: FloatingActionButton.extended(
                onPressed: () => _showCreateRewardPopup(context),
                backgroundColor: const Color(0xFFFF6B35),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                label: const Icon(Icons.add, color: Colors.white, size: 30),
              ),
            ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  // NYT: Designet til bundmenuen
  Widget _buildBottomTabs() {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1E),
        border: Border(top: BorderSide(color: Color(0xFF3F3F46))),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentTab = 0),
              child: Container(
                color: _currentTab == 0 ? const Color(0xFFCC5225) : Colors.transparent, // Mørkere orange hvis aktiv
                alignment: Alignment.center,
                child: Text(
                  'Igangværende', 
                  style: TextStyle(color: _currentTab == 0 ? Colors.white : Colors.white54, fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentTab = 1),
              child: Container(
                color: _currentTab == 1 ? const Color(0xFFCC5225) : Colors.transparent, // Mørkere orange hvis aktiv
                alignment: Alignment.center,
                child: Text(
                  'Opnåede', 
                  style: TextStyle(color: _currentTab == 1 ? Colors.white : Colors.white54, fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('members')
          .where('familier', arrayContains: widget.familyId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35))));
        }
        List<String> memberNames = ['Alle'];
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          for (var doc in snapshot.data!.docs) {
            memberNames.add((doc['navn'] as String).split(' ')[0]);
          }
        }
        return Container(
          height: 60,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: memberNames.length,
            itemBuilder: (context, index) {
              final name = memberNames[index];
              final isSelected = selectedMember == name;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ChoiceChip(
                  label: Text(name),
                  selected: isSelected,
                  onSelected: (val) => setState(() => selectedMember = name),
                  selectedColor: const Color(0xFFFF6B35),
                  backgroundColor: const Color(0xFF2A2A30),
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white60),
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRewardBox(QueryDocumentSnapshot rewardDoc) {
    final rewardData = rewardDoc.data() as Map<String, dynamic>;
    final String title = rewardData['navn'] ?? 'Ingen titel';
    final double criteria = (rewardData['fuldfoertKriterie'] ?? 50.0).toDouble();

    return StreamBuilder<QuerySnapshot>(
      stream: rewardDoc.reference.collection('tasks').snapshots(),
      builder: (context, taskSnapshot) {
        // --- LOGIK TIL BEREGNING AF FULDFØRELSE ---
        double progress = 0.0;
        if (taskSnapshot.hasData && taskSnapshot.data!.docs.isNotEmpty) {
          double totalStars = 0;
          double earnedStars = 0;
          for (var doc in taskSnapshot.data!.docs) {
            totalStars += (doc['antalGange'] ?? 1);
            earnedStars += (doc['udfoertGange'] ?? 0);
          }
          if (totalStars > 0) progress = earnedStars / totalStars;
        }

        final bool isCompleted = (progress * 100) >= criteria;

        // --- FILTRERING BASERET PÅ AKTIV TAB ---
        if (_currentTab == 0 && isCompleted) return const SizedBox.shrink(); // Skjul på Igangværende
        if (_currentTab == 1 && !isCompleted) return const SizedBox.shrink(); // Skjul på Opnåede

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            border: Border.all(color: isCompleted ? const Color(0xFF008D3D) : const Color(0xFF3F3F46)), // Grøn border hvis udført
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF1A1A1E),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _showRewardInfoPopup(rewardDoc),
                      child: const Icon(Icons.info_outline, color: Colors.white54, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      children: [
                        Text('${(progress * 100).toInt()}%', style: TextStyle(color: isCompleted ? const Color(0xFF008D3D) : Colors.white70, fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal)),
                        const SizedBox(width: 8),
                        CustomPaint(
                          size: const Size(20, 20),
                          painter: TriangleProgressPainter(
                            progress: progress,
                            fillColor: isCompleted ? const Color(0xFF008D3D) : const Color(0xFFFF6B35), // Bliver grøn når færdig
                          ),
                        ),
                      ],
                    ),
                    
                    // NYT: Plus-knappen skjules hvis vi er på "Opnåede" fanen
                    if (_currentTab == 0) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => _showCreateTaskOnlyPopup(rewardDoc),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: const Color(0xFFFF6B35), borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.add, color: Colors.white, size: 20),
                        ),
                      ),
                    ] else ...[
                      // Lidt luft i stedet for knappen
                      const SizedBox(width: 16),
                    ]
                  ],
                ),
              ),
              const Divider(color: Color(0xFF3F3F46), height: 1),
              
              if (!taskSnapshot.hasData || taskSnapshot.data!.docs.isEmpty)
                const Padding(padding: EdgeInsets.all(16.0), child: Text('Ingen opgaver endnu', style: TextStyle(color: Colors.white24)))
              else
                Column(
                  children: List.generate(taskSnapshot.data!.docs.length, (index) {
                    return _buildTaskItem(taskSnapshot.data!.docs[index], rewardDoc, isLast: index == taskSnapshot.data!.docs.length - 1);
                  }),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskItem(QueryDocumentSnapshot taskDoc, QueryDocumentSnapshot rewardDoc, {required bool isLast}) {
    final taskData = taskDoc.data() as Map<String, dynamic>;
    final String name = taskData['navn'] ?? 'Opgave';
    final String desc = taskData['beskrivelse'] ?? '';
    final int done = taskData['udfoertGange'] ?? 0;
    final int total = taskData['antalGange'] ?? 1;
    final String memberId = taskData['medlemId'] ?? '';

    return InkWell(
      onTap: () => _showTaskDetailPopup(taskDoc),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(color: Colors.white, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(desc, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(total, (i) => Icon(
                            Icons.star_rounded, 
                            size: 16, 
                            color: i < done ? Colors.amber : Colors.white10
                          )),
                        ),
                        const SizedBox(height: 4),
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('members').doc(memberId).get(),
                          builder: (context, memberSnap) {
                            final memberData = memberSnap.data?.data() as Map<String, dynamic>?;
                            final memberName = memberData?['navn']?.split(' ')[0] ?? '...';
                            final colorVal = memberData?['ikonFarve'] ?? Colors.grey.value;

                            return Column(
                              children: [
                                CircleAvatar(
                                  radius: 12, backgroundColor: Color(colorVal),
                                  child: const Icon(Icons.person, size: 14, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(memberName, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    _buildTaskMenu(taskDoc, done, total),
                  ],
                ),
              ],
            ),
          ),
          if (!isLast) const Divider(color: Color(0xFF3F3F46), height: 1, indent: 16, endIndent: 16),
        ],
      ),
    );
  }

  Widget _buildTaskMenu(QueryDocumentSnapshot taskDoc, int done, int total) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white54),
      color: const Color(0xFF2A2A30),
      onSelected: (value) async {
        if (value == 'complete') {
          await taskDoc.reference.update({'udfoertGange': done + 1});
        } else if (value == 'undo') {
          await taskDoc.reference.update({'udfoertGange': 0});
        } else if (value == 'delete') {
          await taskDoc.reference.delete();
        }
      },
      itemBuilder: (context) => [
        if (done < total)
          const PopupMenuItem(value: 'complete', child: Text('Opgave udført', style: TextStyle(color: Colors.white))),
        if (done == total)
          const PopupMenuItem(value: 'undo', child: Text('Fortryd fuldførelse', style: TextStyle(color: Colors.white))),
        const PopupMenuItem(value: 'delete', child: Text('Slet opgave', style: TextStyle(color: Colors.redAccent))),
      ],
    );
  }

  // --- POPUPS & NAVIGERING ---

  void _showRewardInfoPopup(QueryDocumentSnapshot doc) {
    // TODO: Senere kan vi skjule redigeringsknapperne, hvis currentUser ikke er Admin.
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1E),
        title: Text(doc['navn'], style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Beskrivelse: ${doc['beskrivelse']}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            Text('Kriterie: ${doc['fuldfoertKriterie']}%', style: const TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          // SLET KNAP
          TextButton(
            onPressed: () => _deleteReward(doc),
            child: const Text('Slet belønning', style: TextStyle(color: Colors.redAccent)),
          ),
          // LUK KNAP
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Luk', style: TextStyle(color: Colors.white54))
          ),
          // RET INFO KNAP
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Lukker info boksen
              _showEditRewardPopup(doc); // Åbner redigerings boksen
            }, 
            child: const Text('Ret info', style: TextStyle(color: Color(0xFFFF6B35)))
          ),
        ],
      ),
    );
  }

  // --- NY FUNKTION: Slet Belønning og dens opgaver ---
  Future<void> _deleteReward(QueryDocumentSnapshot rewardDoc) async {
    // 1. Bed om bekræftelse først
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A30),
        title: const Text('Slet belønning?', style: TextStyle(color: Colors.white)),
        content: const Text('Er du sikker? Dette vil også slette alle opgaver, der er tilknyttet denne belønning.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuller', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Slet', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm != true) return; // Hvis brugeren trykkede Annuller

    if (context.mounted) Navigator.pop(context); // Lukker info popuppen

    // 2. Vi bruger en "Batch" til at slette det hele på én gang
    final batch = FirebaseFirestore.instance.batch();
    
    // Hent alle opgaver knyttet til belønningen
    final tasksSnap = await rewardDoc.reference.collection('tasks').get();
    for (var doc in tasksSnap.docs) {
      batch.delete(doc.reference); // Slet opgaven
    }
    
    // Slet selve belønningen
    batch.delete(rewardDoc.reference);
    
    // Udfør sletningen i databasen
    await batch.commit();
  }

  // --- NY FUNKTION: Rediger Belønning ---
  void _showEditRewardPopup(QueryDocumentSnapshot rewardDoc) {
    final formKey = GlobalKey<FormState>();
    // Vi pre-udfylder tekstfelterne med den eksisterende data
    final nameCtrl = TextEditingController(text: rewardDoc['navn']);
    final descCtrl = TextEditingController(text: rewardDoc['beskrivelse']);
    double completionCriteria = (rewardDoc['fuldfoertKriterie'] ?? 50.0).toDouble();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Lader den rykke op, når tastaturet åbnes
      backgroundColor: Colors.transparent,
      builder: (context) {
        // StatefulBuilder gør at vi kan opdatere slideren live inde i popuppen
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF202024),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom, // Plads til tastatur
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Ret belønning', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      const Text('Belønnings navn', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: nameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true, fillColor: const Color(0xFF2A2A30),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        validator: (v) => v!.trim().isEmpty ? 'Feltet må ikke være tomt' : null,
                      ),
                      
                      const SizedBox(height: 24),
                      const Text('Beskrivelse', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true, fillColor: const Color(0xFF2A2A30),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        validator: (v) => v!.trim().isEmpty ? 'Feltet må ikke være tomt' : null,
                      ),
                      
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Fuldført kriterie', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                          Text('${completionCriteria.toInt()}%', style: const TextStyle(color: Color(0xFFFF6B35), fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFFFF6B35),
                          inactiveTrackColor: const Color(0xFF3F3F46),
                          thumbColor: const Color(0xFFFF6B35),
                        ),
                        child: Slider(
                          value: completionCriteria,
                          min: 0, max: 100, divisions: 20,
                          onChanged: (val) => setState(() => completionCriteria = val),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B35), 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          onPressed: isSaving ? null : () async {
                            if (!formKey.currentState!.validate()) return;
                            setState(() => isSaving = true);
                            
                            // Opdaterer data i Firestore
                            await rewardDoc.reference.update({
                              'navn': nameCtrl.text.trim(),
                              'beskrivelse': descCtrl.text.trim(),
                              'fuldfoertKriterie': completionCriteria,
                            });
                            
                            if (context.mounted) Navigator.pop(context); // Lukker popuppen
                          },
                          child: isSaving 
                            ? const CircularProgressIndicator(color: Colors.white) 
                            : const Text('Gem ændringer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          }
        );
      }
    );
  }

  void _showTaskDetailPopup(QueryDocumentSnapshot taskDoc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OpretBelonningPopup(
        familyId: widget.familyId,
        rewardId: taskDoc.reference.parent.parent!.id, // Finder rewardId via stien i Firebase
        taskDoc: taskDoc, // Sender selve opgaven med til redigering
      ),
    );
  }

  void _showCreateTaskOnlyPopup(QueryDocumentSnapshot rewardDoc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OpretBelonningPopup(
        familyId: widget.familyId,
        rewardId: rewardDoc.id, 
      ),
    );
  }

  void _showCreateRewardPopup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OpretBelonningPopup(familyId: widget.familyId),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.card_giftcard, size: 80, color: Colors.white10),
            const SizedBox(height: 20),
            Text(
              _currentTab == 0 ? 'Ingen belønninger endnu' : 'Ingen opnåede belønninger', 
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 10),
            Text(
              _currentTab == 0 
                ? 'Tryk på den store orange knap for at oprette familiens første belønning!' 
                : 'Når I gennemfører opgaver, vil belønningerne lande her.', 
              textAlign: TextAlign.center, 
              style: const TextStyle(color: Colors.white54)
            ),
          ],
        ),
      ),
    );
  }
}

class TriangleProgressPainter extends CustomPainter {
  final double progress;
  final Color fillColor; // Tilføjet så vi kan gøre den grøn når udført

  TriangleProgressPainter({required this.progress, required this.fillColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paintBase = Paint()..color = Colors.white10..style = PaintingStyle.fill;
    final paintFill = Paint()..color = fillColor..style = PaintingStyle.fill;
    final path = Path()..moveTo(size.width / 2, 0)..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(path, paintBase);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, size.height * (1.0 - progress), size.width, size.height * progress));
    canvas.drawPath(path, paintFill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
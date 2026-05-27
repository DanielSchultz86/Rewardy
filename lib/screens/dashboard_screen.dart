import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/app_drawer.dart';
import 'opret_belonning_popup.dart';
import 'opret_medlem_screen.dart';

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
  String selectedMemberId = 'Alle'; 
  int _currentTab = 0; 

  late Stream<QuerySnapshot> _rewardsStream;
  late Stream<QuerySnapshot> _membersStream;
  late Stream<QuerySnapshot> _pendingTasksStream;

  @override
  void initState() {
    super.initState();
    _rewardsStream = FirebaseFirestore.instance
        .collection('families')
        .doc(widget.familyId)
        .collection('rewards')
        .orderBy('createdAt', descending: true)
        .snapshots();

    _membersStream = FirebaseFirestore.instance
        .collection('members')
        .where('familier', arrayContains: widget.familyId)
        .snapshots();
        
    _pendingTasksStream = FirebaseFirestore.instance
        .collectionGroup('tasks')
        .where('pendingGodkendelser', isGreaterThan: 0)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('families').doc(widget.familyId).snapshots(),
          builder: (context, snapshot) {
            final title = snapshot.hasData && snapshot.data!.exists
                ? (snapshot.data!.data() as Map<String, dynamic>)['name'] ?? widget.familyName
                : widget.familyName;
            return Text(title, style: const TextStyle(fontSize: 18));
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showFamilySettingsPopup(context),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomTabs(),
      body: Stack(
        children: [
          Column(
            children: [
              _buildMemberFilter(),
              
              _buildPendingApprovalsSection(),
              
              if (_currentTab == 1)
                const Padding(
                  padding: EdgeInsets.only(top: 10, bottom: 5),
                  child: Text('🏆 Jeres opnåede belønninger', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
                ),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _rewardsStream, 
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Der opstod en fejl: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                    }

                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState();
                    }

                    final rewardDocs = snapshot.data!.docs;

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: rewardDocs.length,
                      itemBuilder: (context, index) {
                        return RewardCard(
                          key: ValueKey(rewardDocs[index].id),
                          rewardDoc: rewardDocs[index],
                          currentTab: _currentTab,
                          selectedMemberId: selectedMemberId,
                          onEdit: () => _showEditRewardPopup(rewardDocs[index]),
                          onAddTask: () => _showCreateTaskOnlyPopup(rewardDocs[index]),
                          onTaskTap: (taskDoc) => _showTaskDetailPopup(taskDoc),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          
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
  
  Widget _buildPendingApprovalsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _pendingTasksStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

        final pendingDocs = snapshot.data!.docs.where((doc) => doc.reference.path.contains(widget.familyId)).toList();

        if (pendingDocs.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A30),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD166), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.pending_actions_rounded, color: Color(0xFFFFD166)),
                  const SizedBox(width: 8),
                  const Text('Afventer godkendelse', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFFFD166), borderRadius: BorderRadius.circular(10)),
                    child: Text('${pendingDocs.length}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                children: pendingDocs.map((doc) => _buildPendingTaskItem(doc)).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildPendingTaskItem(QueryDocumentSnapshot taskDoc) {
    final data = taskDoc.data() as Map<String, dynamic>;
    final name = data['navn'] ?? 'Ukendt opgave';
    final memberId = data['medlemId'] ?? '';
    final pendingCount = data['pendingGodkendelser'] ?? 0;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('members').doc(memberId).get(),
            builder: (context, memberSnap) {
              final memberData = memberSnap.data?.data() as Map<String, dynamic>?;
              final memberName = memberData?['navn']?.split(' ')[0] ?? '...';
              final colorVal = memberData?['ikonFarve'] ?? Colors.grey.value;

              return CircleAvatar(
                radius: 14, backgroundColor: Color(colorVal),
                child: Text(memberName.isNotEmpty ? memberName[0] : '?', style: const TextStyle(color: Colors.white, fontSize: 12)),
              );
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                if (pendingCount > 1) 
                  Text('$pendingCount anmodninger', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
            onPressed: () => _handleApproval(taskDoc, false),
            tooltip: 'Afvis',
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF008D3D), size: 28),
            onPressed: () => _handleApproval(taskDoc, true),
            tooltip: 'Godkend',
          ),
        ],
      ),
    );
  }
  
  Future<void> _handleApproval(QueryDocumentSnapshot taskDoc, bool isApproved) async {
    final data = taskDoc.data() as Map<String, dynamic>;
    final int pending = data['pendingGodkendelser'] ?? 0;
    final int done = data['udfoertGange'] ?? 0;
    
    if (pending > 0) {
      if (isApproved) {
        await taskDoc.reference.update({
          'pendingGodkendelser': pending - 1,
          'udfoertGange': done + 1,
        });
      } else {
        await taskDoc.reference.update({
          'pendingGodkendelser': pending - 1,
        });
      }
    }
  }

  Widget _buildBottomTabs() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF232227),
        border: Border(top: BorderSide(color: Color(0xFF3F3F46))),
      ),
      child: SafeArea( 
        child: SizedBox(
          height: 60, 
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _currentTab = 0),
                  child: Container(
                    color: _currentTab == 0 ? const Color(0xFFCC5225) : Colors.transparent,
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
                    color: _currentTab == 1 ? const Color(0xFFCC5225) : Colors.transparent,
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
        ),
      ),
    );
  }

  Widget _buildMemberFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: _membersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35))));
        }
        
        List<Map<String, String>> memberList = [{'id': 'Alle', 'navn': 'Alle'}];
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          for (var doc in snapshot.data!.docs) {
            memberList.add({
              'id': doc.id,
              'navn': (doc['navn'] as String).split(' ')[0]
            });
          }
        }

        return Container(
          height: 60,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: memberList.length,
            itemBuilder: (context, index) {
              final member = memberList[index];
              final isSelected = selectedMemberId == member['id']; 
              
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ChoiceChip(
                  label: Text(member['navn']!),
                  selected: isSelected,
                  onSelected: (val) => setState(() => selectedMemberId = member['id']!), 
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

  void _showFamilySettingsPopup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FamilySettingsSheet(
        familyId: widget.familyId,
        initialName: widget.familyName,
        onDeleteFamily: () => _deleteFamily(sheetContext),
      ),
    );
  }

  Future<void> _deleteFamily(BuildContext sheetContext) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A30),
        title: const Text('Slet familie?', style: TextStyle(color: Colors.white)),
        content: const Text('Er du helt sikker? Dette sletter familien, samt alle belønninger og opgaver for altid. Medlemmerne slettes ikke, men de fjernes fra denne familie.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuller', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Slet', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm != true) return;

    if (sheetContext.mounted) Navigator.pop(sheetContext); 

    try {
      final batch = FirebaseFirestore.instance.batch();
      
      final rewardsSnap = await FirebaseFirestore.instance.collection('families').doc(widget.familyId).collection('rewards').get();
      for (var rewardDoc in rewardsSnap.docs) {
        final tasksSnap = await rewardDoc.reference.collection('tasks').get();
        for (var taskDoc in tasksSnap.docs) {
          batch.delete(taskDoc.reference);
        }
        batch.delete(rewardDoc.reference);
      }

      final membersSnap = await FirebaseFirestore.instance.collection('members').where('familier', arrayContains: widget.familyId).get();
      for (var memberDoc in membersSnap.docs) {
        batch.update(memberDoc.reference, {
          'familier': FieldValue.arrayRemove([widget.familyId])
        });
      }

      final familyRef = FirebaseFirestore.instance.collection('families').doc(widget.familyId);
      batch.delete(familyRef);

      await batch.commit();

      if (context.mounted) Navigator.pop(context);

    } catch (e) {
      debugPrint("Slette fejl af familie: $e");
    }
  }

  Future<void> _deleteReward(QueryDocumentSnapshot rewardDoc, BuildContext sheetContext) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A30),
        title: const Text('Slet belønning?', style: TextStyle(color: Colors.white)),
        content: const Text('Er du sikker? Dette vil også slette alle opgaver, der er tilknyttet denne belønning.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuller', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Slet', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm != true) return;

    if (sheetContext.mounted) Navigator.pop(sheetContext); 

    try {
      final batch = FirebaseFirestore.instance.batch();
      final tasksSnap = await rewardDoc.reference.collection('tasks').get();
      for (var doc in tasksSnap.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(rewardDoc.reference);
      await batch.commit();
    } catch(e) {
      debugPrint("Slette fejl: $e");
    }
  }

  void _showEditRewardPopup(QueryDocumentSnapshot rewardDoc) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: rewardDoc['navn']);
    final descCtrl = TextEditingController(text: rewardDoc['beskrivelse']);
    double completionCriteria = (rewardDoc['fuldfoertKriterie'] ?? 50.0).toDouble();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) { 
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF202024),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty && v.length > 100) return 'Maks 100 tegn';
                          return null;
                        },
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
                      const Divider(color: Color(0xFF3F3F46), height: 1),
                      const SizedBox(height: 24),

                      // --- NY KNAP: KOPIER BELØNNING ---
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => KopierBelonningSheet(
                                familyId: widget.familyId, 
                                rewardId: rewardDoc.id, 
                              ),
                            );
                          },
                          icon: const Icon(Icons.emoji_events, color: Color(0xFF008D3D)),
                          label: const Text('Kopier belønning', style: TextStyle(color: Color(0xFF008D3D), fontSize: 16, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Color(0xFF008D3D), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- SLET BELØNNING ---
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _deleteReward(rewardDoc, sheetContext), 
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Colors.redAccent, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Slet belønning', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- GEM ÆNDRINGER ---
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
                            
                            await rewardDoc.reference.update({
                              'navn': nameCtrl.text.trim(),
                              'beskrivelse': descCtrl.text.trim(),
                              'fuldfoertKriterie': completionCriteria,
                            });
                            
                            if (context.mounted) Navigator.pop(context);
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
        rewardId: taskDoc.reference.parent.parent!.id,
        taskDoc: taskDoc,
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

// ==========================================
// NY WIDGET: INDSTILLINGER FOR FAMILIEN (BottomSheet)
// ==========================================
class FamilySettingsSheet extends StatefulWidget {
  final String familyId;
  final String initialName;
  final VoidCallback onDeleteFamily;

  const FamilySettingsSheet({
    super.key,
    required this.familyId,
    required this.initialName,
    required this.onDeleteFamily,
  });

  @override
  State<FamilySettingsSheet> createState() => _FamilySettingsSheetState();
}

class _FamilySettingsSheetState extends State<FamilySettingsSheet> {
  late TextEditingController _nameCtrl;
  bool _isSavingName = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // NYT: Hjælpefunktion til at vise notifikationer over popup'en!
  void _showPopupMessage(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message, 
          textAlign: TextAlign.center, 
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating, // Gør at den "svæver"
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        // Ved at give den en kæmpe margin i bunden, skubber vi den helt op i toppen af skærmen!
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.8, 
          left: 24,
          right: 24,
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _updateFamilyName() async {
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty || newName == widget.initialName) return;

    setState(() => _isSavingName = true);
    try {
      await FirebaseFirestore.instance.collection('families').doc(widget.familyId).update({
        'name': newName,
      });
      if (mounted) {
        _showPopupMessage('Familienavn opdateret!', const Color(0xFF008D3D));
      }
    } catch (e) {
      if (mounted) {
        _showPopupMessage('Kunne ikke opdatere navn.', Colors.redAccent);
      }
    } finally {
      if (mounted) setState(() => _isSavingName = false);
    }
  }

  Future<void> _removeMemberFromFamily(String memberId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A30),
        title: const Text('Fjern medlem?', style: TextStyle(color: Colors.white)),
        content: const Text('Dette fjerner medlemmet fra familien. Alle deres opgaver (og belønninger, hvis de var alene om dem) i denne familie vil også blive slettet.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuller', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Fjern', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Fjern medlemmet fra familien
      final memberRef = FirebaseFirestore.instance.collection('members').doc(memberId);
      batch.update(memberRef, {
        'familier': FieldValue.arrayRemove([widget.familyId]),
      });

      // 2. Find og slet alle medlemmets opgaver, samt tjekke om belønningen derved bliver "tom"
      final rewardsSnap = await FirebaseFirestore.instance.collection('families').doc(widget.familyId).collection('rewards').get();

      for (var rewardDoc in rewardsSnap.docs) {
        final tasksForMemberSnap = await rewardDoc.reference.collection('tasks').where('medlemId', isEqualTo: memberId).get();
        
        // Slet opgaverne
        for (var taskDoc in tasksForMemberSnap.docs) {
          batch.delete(taskDoc.reference);
        }

        // Tjek om der er andre opgaver tilbage på denne belønning.
        // Hvis alle opgaver på belønningen tilhørte det slettede medlem, sletter vi også belønningen.
        final allTasksSnap = await rewardDoc.reference.collection('tasks').get();
        if (allTasksSnap.docs.length == tasksForMemberSnap.docs.length) {
          batch.delete(rewardDoc.reference);
        }
      }

      await batch.commit();

      if (mounted) {
        _showPopupMessage('Medlem fjernet og data opdateret.', const Color(0xFF008D3D));
      }
    } catch (e) {
      debugPrint('Kunne ikke fjerne medlem: $e');
      if (mounted) {
        _showPopupMessage('Der opstod en fejl.', Colors.redAccent);
      }
    }
  }

  void _showAddMemberDialog() {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (addCtx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Color(0xFF232227),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tilføj medlem', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(addCtx)),
                ],
              ),
              const SizedBox(height: 16),
              
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('members').where('oprettetAf', isEqualTo: currentUserUid).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)));
                    if (!snapshot.hasData) return const Center(child: Text('Ingen medlemmer fundet', style: TextStyle(color: Colors.white54)));

                    final availableMembers = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final List families = data['familier'] ?? [];
                      return !families.contains(widget.familyId);
                    }).toList();

                    if (availableMembers.isEmpty) {
                      return const Center(child: Text('Alle dine oprettede medlemmer er allerede i denne familie.', style: TextStyle(color: Colors.white54), textAlign: TextAlign.center));
                    }

                    return ListView.builder(
                      itemCount: availableMembers.length,
                      itemBuilder: (context, index) {
                        final memberDoc = availableMembers[index];
                        final data = memberDoc.data() as Map<String, dynamic>;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: Color(data['ikonFarve'] ?? Colors.grey.value),
                            child: const Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(data['navn'] ?? 'Ukendt', style: const TextStyle(color: Colors.white)),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle, color: Color(0xFF008D3D)),
                            onPressed: () async {
                              await FirebaseFirestore.instance.collection('members').doc(memberDoc.id).update({
                                'familier': FieldValue.arrayUnion([widget.familyId])
                              });
                              if (context.mounted) Navigator.pop(addCtx);
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(addCtx); 
                    
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => OpretMedlemPopup(familyId: widget.familyId),
                    );
                  },
                  icon: const Icon(Icons.person_add_alt_1, color: Color(0xFFFFD166)),
                  label: const Text('Opret nyt medlem', style: TextStyle(color: Color(0xFFFFD166), fontSize: 16, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFFD166), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF202024),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Familie indstillinger', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 24),
            
            // --- SEKTION: RET NAVN ---
            const Text('Familienavn', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true, fillColor: const Color(0xFF2A2A30),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  onPressed: _isSavingName ? null : _updateFamilyName,
                  child: _isSavingName 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Text('Gem', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Divider(color: Color(0xFF3F3F46), height: 1),
            const SizedBox(height: 24),

            // --- SEKTION: MEDLEMMER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Medlemmer i familien', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.person_add_alt_1, color: Color(0xFF008D3D)),
                  onPressed: _showAddMemberDialog,
                  tooltip: 'Tilføj medlem',
                )
              ],
            ),
            const SizedBox(height: 8),
            
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('members').where('familier', arrayContains: widget.familyId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35))));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Text('Ingen medlemmer i denne familie.', style: TextStyle(color: Colors.white54));

                final members = snapshot.data!.docs;
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: members.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(data['ikonFarve'] ?? Colors.grey.value),
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(data['navn'] ?? 'Ukendt', style: const TextStyle(color: Colors.white)),
                        trailing: IconButton(
                          icon: const Icon(Icons.person_remove_rounded, color: Colors.redAccent),
                          onPressed: () => _removeMemberFromFamily(doc.id),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),
            const Divider(color: Color(0xFF3F3F46), height: 1),
            const SizedBox(height: 24),

            // --- SEKTION: SLET FAMILIE ---
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: widget.onDeleteFamily,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Slet familie', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// REWARD-CARD WIDGET
// ==========================================
class RewardCard extends StatefulWidget {
  final QueryDocumentSnapshot rewardDoc;
  final int currentTab;
  final String selectedMemberId;
  final VoidCallback onEdit;
  final VoidCallback onAddTask;
  final Function(QueryDocumentSnapshot) onTaskTap;

  const RewardCard({
    super.key,
    required this.rewardDoc,
    required this.currentTab,
    required this.selectedMemberId,
    required this.onEdit,
    required this.onAddTask,
    required this.onTaskTap,
  });

  @override
  State<RewardCard> createState() => _RewardCardState();
}

class _RewardCardState extends State<RewardCard> {
  late Stream<QuerySnapshot> _taskStream;

  @override
  void initState() {
    super.initState();
    _taskStream = widget.rewardDoc.reference.collection('tasks').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final rewardData = widget.rewardDoc.data() as Map<String, dynamic>;
    final String title = rewardData['navn'] ?? 'Ingen titel';
    final double criteria = (rewardData['fuldfoertKriterie'] ?? 50.0).toDouble();

    return StreamBuilder<QuerySnapshot>(
      stream: _taskStream,
      builder: (context, taskSnapshot) {
        if (taskSnapshot.hasError) {
          return Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(16),
            color: Colors.redAccent.withOpacity(0.1),
            child: const Text('Kunne ikke hente opgaver.', style: TextStyle(color: Colors.redAccent)),
          );
        }

        if (!taskSnapshot.hasData) return const SizedBox.shrink(); 

        final allTasks = taskSnapshot.data!.docs;

        double progress = 0.0;
        if (allTasks.isNotEmpty) {
          double totalStars = 0;
          double earnedStars = 0;
          for (var doc in allTasks) {
            totalStars += (doc['antalGange'] ?? 1);
            earnedStars += (doc['udfoertGange'] ?? 0); 
          }
          if (totalStars > 0) progress = earnedStars / totalStars;
        }

        final bool isCompleted = (progress * 100) >= criteria;

        if (widget.currentTab == 0 && isCompleted) return const SizedBox.shrink(); 
        if (widget.currentTab == 1 && !isCompleted) return const SizedBox.shrink(); 

        final filteredTasks = widget.selectedMemberId == 'Alle' 
            ? allTasks.toList()
            : allTasks.where((t) => t['medlemId'] == widget.selectedMemberId).toList();

        if (widget.selectedMemberId != 'Alle' && filteredTasks.isEmpty) {
          return const SizedBox.shrink();
        }
        
        filteredTasks.sort((a, b) {
          int pendingA = (a.data() as Map<String, dynamic>)['pendingGodkendelser'] ?? 0;
          int pendingB = (b.data() as Map<String, dynamic>)['pendingGodkendelser'] ?? 0;
          return pendingB.compareTo(pendingA); 
        });

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            border: Border.all(color: isCompleted ? const Color(0xFF008D3D) : const Color(0xFF3F3F46)),
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF232227),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: widget.onEdit,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), 
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title, 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8), 
                      Row(
                        children: [
                          Text('${(progress * 100).toInt()}%', style: TextStyle(color: isCompleted ? const Color(0xFF008D3D) : Colors.white70, fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal)),
                          const SizedBox(width: 8),
                          CustomPaint(
                            size: const Size(20, 20),
                            painter: TriangleProgressPainter(
                              progress: progress,
                              fillColor: isCompleted ? const Color(0xFF008D3D) : const Color(0xFFFF6B35),
                            ),
                          ),
                        ],
                      ),
                      
                      if (widget.currentTab == 0) ...[
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: widget.onAddTask,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: const Color(0xFFFF6B35), borderRadius: BorderRadius.circular(6)),
                            child: const Icon(Icons.add, color: Colors.white, size: 20),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(width: 16),
                      ]
                    ],
                  ),
                ),
              ),
              const Divider(color: Color(0xFF3F3F46), height: 1),
              
              if (filteredTasks.isEmpty)
                const Padding(padding: EdgeInsets.all(16.0), child: Text('Ingen opgaver endnu', style: TextStyle(color: Colors.white24)))
              else
                Column(
                  children: List.generate(filteredTasks.length, (index) {
                    return _buildTaskItem(filteredTasks[index], isLast: index == filteredTasks.length - 1);
                  }),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskItem(QueryDocumentSnapshot taskDoc, {required bool isLast}) {
    final taskData = taskDoc.data() as Map<String, dynamic>;
    final String name = taskData['navn'] ?? 'Opgave';
    final String desc = taskData['beskrivelse'] ?? '';
    final int done = taskData['udfoertGange'] ?? 0;
    final int total = taskData['antalGange'] ?? 1;
    final String memberId = taskData['medlemId'] ?? '';
    
    final int pending = taskData['pendingGodkendelser'] ?? 0;
    final int activeCount = done + pending;
    final bool isCompleted = done >= total;

    DismissDirection swipeDirection;
    if (pending > 0) {
      swipeDirection = DismissDirection.horizontal; 
    } else if (isCompleted) {
      swipeDirection = DismissDirection.endToStart; 
    } else if (done > 0) {
      swipeDirection = DismissDirection.horizontal; 
    } else {
      swipeDirection = DismissDirection.startToEnd; 
    }

    return Dismissible(
      key: Key(taskDoc.id),
      direction: swipeDirection, 
      
      background: Container(
        color: const Color(0xFF008D3D), 
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.check, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.redAccent, 
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(pending > 0 ? Icons.close : Icons.undo, color: Colors.white), 
      ),
      
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) { 
          if (pending > 0) {
            await taskDoc.reference.update({
              'pendingGodkendelser': pending - 1,
              'udfoertGange': done + 1,
            });
          } else if (done < total) {
            await taskDoc.reference.update({'udfoertGange': done + 1});
          }
        } else if (direction == DismissDirection.endToStart) { 
          if (pending > 0) {
            await taskDoc.reference.update({
              'pendingGodkendelser': pending - 1,
            });
          } else if (done > 0) {
            await taskDoc.reference.update({'udfoertGange': done - 1});
          }
        }
        return false; 
      },
      child: InkWell(
        onTap: () => widget.onTaskTap(taskDoc),
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
                        Text(
                          name, 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white, 
                            fontSize: 15,
                            decoration: isCompleted ? TextDecoration.lineThrough : null, 
                            decorationColor: Colors.white54
                          )
                        ),
                        const SizedBox(height: 4),
                        Text(desc, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        
                        if (pending > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.pending_actions_rounded, color: Color(0xFFFFD166), size: 14),
                              const SizedBox(width: 4),
                              Text('Afventer godkendelse', style: const TextStyle(color: Color(0xFFFFD166), fontSize: 12)),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(total, (i) {
                          if (i < done) {
                            return const Icon(Icons.star_rounded, size: 16, color: Colors.amber);
                          } else if (i < activeCount) {
                            return const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFFFFD166)); 
                          } else {
                            return const Icon(Icons.star_rounded, size: 16, color: Colors.white10);
                          }
                        }),
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
                  const SizedBox(width: 4), 
                ],
              ),
            ),
            if (!isLast) const Divider(color: Color(0xFF3F3F46), height: 1, indent: 16, endIndent: 16),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// GRAFIK TIL PROCENTVISNING
// ==========================================
class TriangleProgressPainter extends CustomPainter {
  final double progress;
  final Color fillColor;

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
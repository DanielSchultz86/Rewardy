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
      body: Stack(
        children: [
          Column(
            children: [
              _buildMemberFilter(),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF3F3F46)),
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1A1A1E),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // TITEL (Venstre side)
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                
                // 1. INFO IKON (Flyttet til højre)
                GestureDetector(
                  onTap: () => _showRewardInfoPopup(rewardDoc),
                  child: const Icon(Icons.info_outline, color: Colors.white54, size: 20),
                ),
                const SizedBox(width: 12),
                
                // 2. DYNAMISK PROCENTUDREGNING
                StreamBuilder<QuerySnapshot>(
                  stream: rewardDoc.reference.collection('tasks').snapshots(),
                  builder: (context, taskSnapshot) {
                    double progress = 0.0;
                    if (taskSnapshot.hasData && taskSnapshot.data!.docs.isNotEmpty) {
                      double totalStars = 0;
                      double earnedStars = 0;
                      for (var doc in taskSnapshot.data!.docs) {
                        totalStars += (doc['antalGange'] ?? 1);
                        earnedStars += (doc['udfoertGange'] ?? 0);
                      }
                      progress = earnedStars / totalStars;
                    }
                    return Row(
                      children: [
                        Text('${(progress * 100).toInt()}%', style: const TextStyle(color: Colors.white70)),
                        const SizedBox(width: 8),
                        CustomPaint(
                          size: const Size(20, 20),
                          painter: TriangleProgressPainter(progress: progress),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 16),
                
                // 6. OPRET OPGAVE KNAP
                GestureDetector(
                  onTap: () => _showCreateTaskOnlyPopup(rewardDoc),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: const Color(0xFFFF6B35), borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF3F3F46), height: 1),
          
          StreamBuilder<QuerySnapshot>(
            stream: rewardDoc.reference.collection('tasks').snapshots(),
            builder: (context, taskSnapshot) {
              if (!taskSnapshot.hasData || taskSnapshot.data!.docs.isEmpty) {
                return const Padding(padding: EdgeInsets.all(16.0), child: Text('Ingen opgaver endnu', style: TextStyle(color: Colors.white24)));
              }
              final taskDocs = taskSnapshot.data!.docs;
              return Column(
                children: List.generate(taskDocs.length, (index) {
                  return _buildTaskItem(taskDocs[index], rewardDoc, isLast: index == taskDocs.length - 1);
                }),
              );
            },
          ),
        ],
      ),
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
              crossAxisAlignment: CrossAxisAlignment.center, // Centrerer indholdet horisontalt
              children: [
                // TEKST (Venstre)
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
                
                // HØJRE SIDE (Stjerner, Medlem, Indstillinger)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // GRUPPE: Stjerner og medlem
                    Column(
                      children: [
                        // Stjerner
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(total, (i) => Icon(
                            Icons.star_rounded, 
                            size: 16, // Gjort en anelse mindre for bedre pasform over ikonet
                            color: i < done ? Colors.amber : Colors.white10
                          )),
                        ),
                        const SizedBox(height: 4),
                        // Medlem
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
                    const SizedBox(width: 12), // Afstand fra profilbillede til prikker
                    
                    // 5. INDSTILLINGSKNAP (De tre prikker står nu helt for sig selv)
                    _buildTaskMenu(taskDoc, done, total),
                  ],
                ),
              ],
            ),
          ),
          if (!isLast) const Divider(color: Color(0xFFFF6B35), height: 1, indent: 16, endIndent: 16),
        ],
      ),
    );
  }

  // 5. LOGIK TIL DE TRE PRIKKER
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
    // Her tjekker vi om brugeren er admin (I dette eksempel tjekker vi mod familiens 'createdBy')
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Luk')),
          // Kun admin kan se ret-knappen (TODO: Tilføj rigtig admin-tjek her)
          TextButton(onPressed: () {}, child: const Text('Ret info', style: TextStyle(color: Color(0xFFFF6B35)))),
        ],
      ),
    );
  }

  void _showTaskDetailPopup(QueryDocumentSnapshot taskDoc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1E),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(taskDoc['navn'], style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Her kan brugeren markere opgaven som udført og se flere detaljer.', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35)),
              onPressed: () => Navigator.pop(context),
              child: const Text('Markér som udført'),
            )
          ],
        ),
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
        rewardId: rewardDoc.id, // VIGTIGT: Dette fortæller popuppen, at den er i "Opgave mode"
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
            const Text('Ingen belønninger endnu', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('Tryk på den store orange knap for at oprette familiens første belønning!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

class TriangleProgressPainter extends CustomPainter {
  final double progress;
  TriangleProgressPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paintBase = Paint()..color = Colors.white10..style = PaintingStyle.fill;
    final paintFill = Paint()..color = const Color(0xFFFF6B35)..style = PaintingStyle.fill;
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
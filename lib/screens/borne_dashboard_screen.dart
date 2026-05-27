import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/app_drawer.dart';

class BorneDashboardScreen extends StatefulWidget {
  final String familyId;
  final String familyName;
  final String memberId; // NYT: Vi skal vide hvilket barn der kigger med!

  const BorneDashboardScreen({
    super.key,
    required this.familyId,
    required this.familyName,
    required this.memberId,
  });

  @override
  State<BorneDashboardScreen> createState() => _BorneDashboardScreenState();
}

class _BorneDashboardScreenState extends State<BorneDashboardScreen> {
  int _currentTab = 0; 
  late Stream<QuerySnapshot> _rewardsStream;
  late Stream<QuerySnapshot> _membersStream;
  late Stream<QuerySnapshot> _pendingTasksStream;
  late Stream<QuerySnapshot> _allTasksStream;

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

    // NYT: Stream til at hente alle opgaver, så vi kan beregne stjerner/skattekister i toppen
    _allTasksStream = FirebaseFirestore.instance
        .collectionGroup('tasks')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(widget.familyName, style: const TextStyle(fontSize: 18)),
      ),
      bottomNavigationBar: _buildBottomTabs(),
      body: Column(
        children: [
          const SizedBox(height: 16), 
          
          // HER KALDER VI STATISTIKKEN!
          _buildMemberStats(),
          
          if (_currentTab == 1)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('🏆 Mine opnåede belønninger', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: rewardDocs.length,
                  itemBuilder: (context, index) {
                    return ChildRewardCard(
                      key: ValueKey(rewardDocs[index].id), 
                      rewardDoc: rewardDocs[index],
                      currentTab: _currentTab,
                      memberId: widget.memberId,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

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

  Widget _buildMemberStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: _allTasksStream,
      builder: (context, taskSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: _rewardsStream,
          builder: (context, rewardSnapshot) {
            // Vis ingenting indtil data er loadet
            if (!taskSnapshot.hasData || !rewardSnapshot.hasData) {
              return const SizedBox.shrink(); 
            }

            // Hent KUN de opgaver, der tilhører dette specifikke barn
            final myTasks = taskSnapshot.data!.docs
                .where((doc) => 
                    doc.reference.path.contains(widget.familyId) &&
                    (doc.data() as Map<String, dynamic>)['medlemId'] == widget.memberId)
                .toList();
            
            final allFamilyRewards = rewardSnapshot.data!.docs;

            int totalStars = 0;
            int completedRewards = 0;

            // 1. Grupper opgaverne ud fra deres belønnings-ID
            Map<String, List<QueryDocumentSnapshot>> tasksByReward = {};
            for (var t in myTasks) {
              String rId = t.reference.parent.parent!.id;
              if (!tasksByReward.containsKey(rId)) tasksByReward[rId] = [];
              tasksByReward[rId]!.add(t);
            }

            // 2. Gennemgå alle belønninger for at regne ud, hvad barnet har opnået
            for (var r in allFamilyRewards) {
              double criteria = (r.data() as Map<String, dynamic>)['fuldfoertKriterie'] ?? 50.0;
              var rTasks = tasksByReward[r.id] ?? [];

              if (rTasks.isEmpty) continue;

              int rTotalStars = 0;
              int rEarnedStars = 0;
              
              for (var t in rTasks) {
                final tData = t.data() as Map<String, dynamic>;
                int tTotal = (tData['antalGange'] as num?)?.toInt() ?? 1;
                int tDone = (tData['udfoertGange'] as num?)?.toInt() ?? 0;
                
                rTotalStars += tTotal;
                rEarnedStars += tDone;
                
                // Læg til i den overordnede "Stjerner tjent" tæller
                totalStars += tDone; 
              }

              // Tjek om denne specifikke belønning er låst op (Skattekiste)
              if (rTotalStars > 0) {
                double progress = rEarnedStars / rTotalStars;
                if ((progress * 100) >= criteria) {
                  completedRewards++;
                }
              }
            }

            // 3. Byg selve UI'et med to kasser
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A30),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFD166).withOpacity(0.4), width: 1.5),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFFFD166), size: 36),
                          const SizedBox(height: 8),
                          Text('$totalStars', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          const Text('Mine stjerner', style: TextStyle(color: Colors.white54, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A30),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF008D3D).withOpacity(0.4), width: 1.5),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.inventory_2_rounded, color: Color(0xFF008D3D), size: 32),
                          const SizedBox(height: 12),
                          Text('$completedRewards', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          const Text('Mine kister', style: TextStyle(color: Colors.white54, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star_border_rounded, size: 80, color: Colors.white10),
            const SizedBox(height: 20),
            Text(
              _currentTab == 0 ? 'Ingen opgaver lige nu' : 'Ingen opnåede belønninger', 
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 10),
            Text(
              _currentTab == 0 
                ? 'Når de voksne giver dig en opgave, vil den dukke op her!' 
                : 'Når du har gennemført nok opgaver, lander dine belønninger her.', 
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
// CHILD REWARD CARD (Uden ret/slet muligheder)
// ==========================================
class ChildRewardCard extends StatefulWidget {
  final QueryDocumentSnapshot rewardDoc;
  final int currentTab;
  final String memberId;

  const ChildRewardCard({
    super.key,
    required this.rewardDoc,
    required this.currentTab,
    required this.memberId,
  });

  @override
  State<ChildRewardCard> createState() => _ChildRewardCardState();
}

class _ChildRewardCardState extends State<ChildRewardCard> {
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
          return const SizedBox.shrink();
        }
        if (!taskSnapshot.hasData) return const SizedBox.shrink(); 

        final allTasks = taskSnapshot.data!.docs;

        double progress = 0.0;
        if (allTasks.isNotEmpty) {
          double totalStars = 0;
          double earnedStars = 0;
          for (var doc in allTasks) {
            totalStars += (doc['antalGange'] ?? 1);
            // Procentbaren viser KUN de stjerner Admin har godkendt!
            earnedStars += (doc['udfoertGange'] ?? 0); 
          }
          if (totalStars > 0) progress = earnedStars / totalStars;
        }

        final bool isCompleted = (progress * 100) >= criteria;

        if (widget.currentTab == 0 && isCompleted) return const SizedBox.shrink(); 
        if (widget.currentTab == 1 && !isCompleted) return const SizedBox.shrink(); 

        // Filtrer KUN opgaver for dette bestemte barn
        final filteredTasks = allTasks.where((t) => t['medlemId'] == widget.memberId).toList();

        // Skjul hele belønningskortet, hvis der slet ikke er nogle opgaver til dette barn
        if (filteredTasks.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            border: Border.all(color: isCompleted ? const Color(0xFF008D3D) : const Color(0xFF3F3F46)),
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF232227),
          ),
          child: Column(
            children: [
              Padding(
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
                  ],
                ),
              ),
              const Divider(color: Color(0xFF3F3F46), height: 1),
              
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
    
    // NYT: Hent hvor mange der venter på godkendelse
    final int pending = taskData['pendingGodkendelser'] ?? 0;

    // Den samlede mængde 'handlinger' (udført + afventende)
    final int activeCount = done + pending;
    
    // Opgaven kan ikke swipes mere mod højre, hvis de allerede har udført/sendt det antal gange de skal
    final bool isFullyActioned = activeCount >= total;

    return Dismissible(
      key: Key(taskDoc.id),
      direction: isFullyActioned 
        ? DismissDirection.endToStart 
        : (activeCount > 0 ? DismissDirection.horizontal : DismissDirection.startToEnd), 
      
      background: Container(
        color: const Color(0xFF008D3D), 
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.send_rounded, color: Colors.white), // NYT ikon: Send papirflyver!
      ),
      secondaryBackground: Container(
        color: Colors.redAccent, 
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.undo, color: Colors.white), // Fortryd ikon
      ),
      
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Send Anmodning!
          if (activeCount < total) {
            await taskDoc.reference.update({'pendingGodkendelser': pending + 1});
          }
        } else if (direction == DismissDirection.endToStart) {
          // Fortryd anmodning (træk den tilbage) ELLER fortryd opgave
          if (pending > 0) {
            await taskDoc.reference.update({'pendingGodkendelser': pending - 1});
          } else if (done > 0) {
            await taskDoc.reference.update({'udfoertGange': done - 1});
          }
        }
        return false; 
      },
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
                          // Streg kun over teksten, hvis ADMIN har godkendt (eller hvis man vil strege over når det er sendt, brug 'isFullyActioned')
                          decoration: isFullyActioned ? TextDecoration.lineThrough : null, 
                          decorationColor: Colors.white54
                        )
                      ),
                      const SizedBox(height: 4),
                      Text(desc, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      
                      // NYT: Den orange afventer-besked!
                      if (pending > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.pending_actions_rounded, color: Color(0xFFFFD166), size: 14),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                pending == 1 ? 'Anmodning sendt - afventer godkendelse' : '$pending anmodninger sendt', 
                                style: const TextStyle(color: Color(0xFFFFD166), fontSize: 12, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(total, (i) {
                        // Viser guldstjerne for godkendte, ur-ikon for afventende, og tom for ikke lavet.
                        if (i < done) {
                          return const Icon(Icons.star_rounded, size: 16, color: Colors.amber);
                        } else if (i < done + pending) {
                          return const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFFFFD166)); // Ur ikon!
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
    );
  }
}

// ==========================================
// GRAFIK TIL PROCENTVISNING (Genbrugt)
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
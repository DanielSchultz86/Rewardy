import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/app_drawer.dart';
import 'mat_opg_popup.dart';

class BorneDashboardScreen extends StatefulWidget {
  final String familyId;
  final String familyName;
  final String memberId;

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

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _rewardsStream;

  @override
  void initState() {
    super.initState();

    _rewardsStream = FirebaseFirestore.instance
        .collection('families')
        .doc(widget.familyId)
        .collection('rewards')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      drawer: AppDrawer(),
      appBar: AppBar(
        title: Text(
          widget.familyName,
          style: const TextStyle(fontSize: 18),
        ),
      ),
      bottomNavigationBar: _buildBottomTabs(),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _rewardsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Der opstod en fejl: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF6B35),
              ),
            );
          }

          final rewardDocs = snapshot.data?.docs ?? [];

          return Column(
            children: [
              if (_currentTab == 1) ...[
                const SizedBox(height: 12),

                _MemberStatsBoxes(
                  rewardDocs: rewardDocs,
                  memberId: widget.memberId,
                ),

                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    '🏆 Mine opnåede belønninger',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ] else
                const SizedBox(height: 16),

              Expanded(
                child: rewardDocs.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
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
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomTabs() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF232227),
        border: Border(
          top: BorderSide(color: Color(0xFF3F3F46)),
        ),
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
                    color: _currentTab == 0
                        ? const Color(0xFFCC5225)
                        : Colors.transparent,
                    alignment: Alignment.center,
                    child: Text(
                      'Igangværende',
                      style: TextStyle(
                        color:
                            _currentTab == 0 ? Colors.white : Colors.white54,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _currentTab = 1),
                  child: Container(
                    color: _currentTab == 1
                        ? const Color(0xFFCC5225)
                        : Colors.transparent,
                    alignment: Alignment.center,
                    child: Text(
                      'Opnåede',
                      style: TextStyle(
                        color:
                            _currentTab == 1 ? Colors.white : Colors.white54,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.star_border_rounded,
              size: 80,
              color: Colors.white10,
            ),
            const SizedBox(height: 20),
            Text(
              _currentTab == 0
                  ? 'Ingen opgaver lige nu'
                  : 'Ingen opnåede belønninger',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _currentTab == 0
                  ? 'Når de voksne giver dig en opgave, vil den dukke op her!'
                  : 'Når du har gennemført nok opgaver, lander dine belønninger her.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// TOPBOKSE MED STATISTIK
// ==========================================
class _MemberStatsBoxes extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> rewardDocs;
  final String memberId;

  const _MemberStatsBoxes({
    required this.rewardDocs,
    required this.memberId,
  });

  @override
  State<_MemberStatsBoxes> createState() => _MemberStatsBoxesState();
}

class _MemberStatsBoxesState extends State<_MemberStatsBoxes> {
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _taskSubscriptions = [];

  final Map<String, double> _criteriaByRewardId = {};
  final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _tasksByRewardId = {};
  final Set<String> _loadedRewardIds = {};

  int _totalStars = 0;
  int _completedRewards = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupTaskSubscriptions();
  }

  @override
  void didUpdateWidget(covariant _MemberStatsBoxes oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.memberId != widget.memberId ||
        !_sameRewardSetup(oldWidget.rewardDocs, widget.rewardDocs)) {
      _setupTaskSubscriptions(notify: true);
    }
  }

  @override
  void dispose() {
    _cancelTaskSubscriptions();
    super.dispose();
  }

  bool _sameRewardSetup(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> oldRewards,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> newRewards,
  ) {
    if (oldRewards.length != newRewards.length) {
      return false;
    }

    for (int index = 0; index < oldRewards.length; index++) {
      final oldReward = oldRewards[index];
      final newReward = newRewards[index];

      if (oldReward.id != newReward.id) {
        return false;
      }

      final oldCriteria =
          (oldReward.data()['fuldfoertKriterie'] as num?)?.toDouble() ?? 50.0;
      final newCriteria =
          (newReward.data()['fuldfoertKriterie'] as num?)?.toDouble() ?? 50.0;

      if (oldCriteria != newCriteria) {
        return false;
      }
    }

    return true;
  }

  void _setupTaskSubscriptions({bool notify = false}) {
    _cancelTaskSubscriptions();

    _criteriaByRewardId.clear();
    _tasksByRewardId.clear();
    _loadedRewardIds.clear();

    _totalStars = 0;
    _completedRewards = 0;
    _isLoading = widget.rewardDocs.isNotEmpty;

    if (notify && mounted) {
      setState(() {});
    }

    if (widget.rewardDocs.isEmpty) {
      _isLoading = false;
      return;
    }

    for (final rewardDoc in widget.rewardDocs) {
      final rewardData = rewardDoc.data();

      final double criteria =
          (rewardData['fuldfoertKriterie'] as num?)?.toDouble() ?? 50.0;

      _criteriaByRewardId[rewardDoc.id] = criteria;

      final subscription = rewardDoc.reference.collection('tasks').snapshots().listen(
        (taskSnapshot) {
          final myTasks = taskSnapshot.docs.where((taskDoc) {
            final taskData = taskDoc.data();
            return taskData['medlemId'] == widget.memberId;
          }).toList();

          _tasksByRewardId[rewardDoc.id] = myTasks;
          _loadedRewardIds.add(rewardDoc.id);

          _recalculateStats();
        },
        onError: (error) {
          _tasksByRewardId[rewardDoc.id] = [];
          _loadedRewardIds.add(rewardDoc.id);

          _recalculateStats();
        },
      );

      _taskSubscriptions.add(subscription);
    }
  }

  void _cancelTaskSubscriptions() {
    for (final subscription in _taskSubscriptions) {
      subscription.cancel();
    }

    _taskSubscriptions.clear();
  }

  void _recalculateStats() {
    int totalStars = 0;
    int completedRewards = 0;

    for (final rewardDoc in widget.rewardDocs) {
      final rewardTasks = _tasksByRewardId[rewardDoc.id] ?? [];

      if (rewardTasks.isEmpty) {
        continue;
      }

      int rewardTotalStars = 0;
      int rewardEarnedStars = 0;

      for (final task in rewardTasks) {
        final taskData = task.data();

        final int taskTotal =
            (taskData['antalGange'] as num?)?.toInt() ?? 1;

        final int taskDone =
            (taskData['udfoertGange'] as num?)?.toInt() ?? 0;

        rewardTotalStars += taskTotal;
        rewardEarnedStars += taskDone;

        totalStars += taskDone;
      }

      final double criteria = _criteriaByRewardId[rewardDoc.id] ?? 50.0;

      if (rewardTotalStars > 0) {
        final double progress = rewardEarnedStars / rewardTotalStars;

        if ((progress * 100) >= criteria) {
          completedRewards++;
        }
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _totalStars = totalStars;
      _completedRewards = completedRewards;
      _isLoading = _loadedRewardIds.length < widget.rewardDocs.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _buildStatBox(
              icon: const Icon(
                Icons.star_rounded,
                color: Color(0xFFFFD166),
                size: 28,
              ),
              accentColor: const Color(0xFFFFD166),
              value: _isLoading ? '...' : '$_totalStars',
              label: 'Opgaver udført',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatBox(
              icon: const TreasureChestIcon(
                size: 30,
                color: Color(0xFF008D3D),
              ),
              accentColor: const Color(0xFF008D3D),
              value: _isLoading ? '...' : '$_completedRewards',
              label: 'Belønninger opnået',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required Widget icon,
    required Color accentColor,
    required String value,
    required String label,
  }) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 8),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  height: 1,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// CHILD REWARD CARD
// ==========================================
class ChildRewardCard extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> rewardDoc;
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
  late Stream<QuerySnapshot<Map<String, dynamic>>> _taskStream;

  @override
  void initState() {
    super.initState();
    _taskStream = widget.rewardDoc.reference.collection('tasks').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final rewardData = widget.rewardDoc.data();

    final String title = rewardData['navn'] ?? 'Ingen titel';

    final double criteria =
        (rewardData['fuldfoertKriterie'] as num?)?.toDouble() ?? 50.0;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _taskStream,
      builder: (context, taskSnapshot) {
        if (taskSnapshot.hasError) {
          return const SizedBox.shrink();
        }

        if (!taskSnapshot.hasData) {
          return const SizedBox.shrink();
        }

        final allTasks = taskSnapshot.data!.docs;

        final filteredTasks = allTasks.where((task) {
          final taskData = task.data();
          return taskData['medlemId'] == widget.memberId;
        }).toList();

        if (filteredTasks.isEmpty) {
          return const SizedBox.shrink();
        }

        double totalStars = 0;
        double earnedStars = 0;

        for (final doc in filteredTasks) {
          final taskData = doc.data();

          totalStars += ((taskData['antalGange'] ?? 1) as num).toDouble();
          earnedStars += ((taskData['udfoertGange'] ?? 0) as num).toDouble();
        }

        double progress = 0.0;

        if (totalStars > 0) {
          progress = earnedStars / totalStars;
        }

        final bool isCompleted = (progress * 100) >= criteria;

        if (widget.currentTab == 0 && isCompleted) {
          return const SizedBox.shrink();
        }

        if (widget.currentTab == 1 && !isCompleted) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            border: Border.all(
              color: isCompleted
                  ? const Color(0xFF008D3D)
                  : const Color(0xFF3F3F46),
            ),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: TextStyle(
                            color: isCompleted
                                ? const Color(0xFF008D3D)
                                : Colors.white70,
                            fontWeight: isCompleted
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(width: 8),
                        CustomPaint(
                          size: const Size(20, 20),
                          painter: TriangleProgressPainter(
                            progress: progress,
                            fillColor: isCompleted
                                ? const Color(0xFF008D3D)
                                : const Color(0xFFFF6B35),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(
                color: Color(0xFF3F3F46),
                height: 1,
              ),
              Column(
                children: List.generate(filteredTasks.length, (index) {
                  return _buildTaskItem(
                    filteredTasks[index],
                    isLast: index == filteredTasks.length - 1,
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskItem(
    QueryDocumentSnapshot<Map<String, dynamic>> taskDoc, {
    required bool isLast,
  }) {
    final taskData = taskDoc.data();

    final String name = taskData['navn'] ?? 'Opgave';
    final String desc = taskData['beskrivelse'] ?? '';
    final int done = (taskData['udfoertGange'] as num?)?.toInt() ?? 0;
    final int total = (taskData['antalGange'] as num?)?.toInt() ?? 1;
    final String memberId = taskData['medlemId'] ?? '';

    final int pending =
        (taskData['pendingGodkendelser'] as num?)?.toInt() ?? 0;

    final int activeCount = done + pending;
    final bool isFullyActioned = activeCount >= total;

    // --- MATEMATIK VARIABLER ---
    final bool isMathTask = taskData['isMathTask'] == true;
    final String mathLevel = taskData['mathLevel'] ?? 'Let';
    final int mathProblemCount = taskData['mathProblemCount'] ?? 12;
    final double mathPassCriteria = (taskData['mathPassCriteria'] as num?)?.toDouble() ?? 80.0;
    final Map<String, dynamic> mathTypes = taskData['mathTypes'] ?? {'Plus': true};

    return Dismissible(
      key: Key(taskDoc.id),
      direction: isFullyActioned
          ? DismissDirection.endToStart
          : activeCount > 0
              ? DismissDirection.horizontal
              : DismissDirection.startToEnd,
      background: Container(
        color: const Color(0xFF008D3D),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(
          Icons.send_rounded,
          color: Colors.white,
        ),
      ),
      secondaryBackground: Container(
        color: Colors.redAccent,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.undo,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // SIKKERHED: Hvis det er en matematik-opgave, må den IKKE swipes til at være færdig!
          if (isMathTask && activeCount < total) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tryk på opgaven for at spille matematik-spillet!', style: TextStyle(color: Colors.white)),
                backgroundColor: Color(0xFFFF6B35),
                duration: Duration(seconds: 2),
              ),
            );
            return false; // Blokerer swipet
          }

          if (activeCount < total) {
            await taskDoc.reference.update({
              'pendingGodkendelser': pending + 1,
            });
          }
        } else if (direction == DismissDirection.endToStart) {
          if (pending > 0) {
            await taskDoc.reference.update({
              'pendingGodkendelser': pending - 1,
            });
          } else if (done > 0) {
            await taskDoc.reference.update({
              'udfoertGange': done - 1,
            });
          }
        }

        return false;
      },
      child: InkWell(
        // ÅBEN POPUP NÅR DER TRYKKE PÅ OPGAVEN
        onTap: () {
          if (isMathTask && !isFullyActioned) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => MatOpgPopup(
                taskRef: taskDoc.reference,
                level: mathLevel,
                problemCount: mathProblemCount,
                passCriteria: mathPassCriteria,
                activeTypes: mathTypes,
              ),
            );
          }
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  decoration:
                                      isFullyActioned ? TextDecoration.lineThrough : null,
                                  decorationColor: Colors.white54,
                                ),
                              ),
                            ),
                            // LILLE IKON SÅ BARNET KAN SE DET ER ET SPIL
                            if (isMathTask) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.calculate_rounded, color: Color(0xFF008D3D), size: 18),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          desc,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        if (pending > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.pending_actions_rounded,
                                color: Color(0xFFFFD166),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  pending == 1
                                      ? 'Anmodning sendt - afventer godkendelse'
                                      : '$pending anmodninger sendt',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD166),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
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
                        children: List.generate(total, (index) {
                          if (index < done) {
                            return const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Colors.amber,
                            );
                          } else if (index < done + pending) {
                            return const Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: Color(0xFFFFD166),
                            );
                          } else {
                            return const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Colors.white10,
                            );
                          }
                        }),
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future: FirebaseFirestore.instance
                            .collection('members')
                            .doc(memberId)
                            .get(),
                        builder: (context, memberSnap) {
                          final memberData = memberSnap.data?.data();

                          final memberName =
                              memberData?['navn']?.split(' ')[0] ?? '...';

                          final int colorVal =
                              (memberData?['ikonFarve'] as num?)?.toInt() ??
                                  Colors.grey.value;

                          return Column(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: Color(colorVal),
                                child: const Icon(
                                  Icons.person,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                memberName,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
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
            if (!isLast)
              const Divider(
                color: Color(0xFF3F3F46),
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// SKATTEKISTE-IKON TIL STATISTIKBOKSEN
// ==========================================
class TreasureChestIcon extends StatelessWidget {
  final double size;
  final Color color;

  const TreasureChestIcon({
    super.key,
    this.size = 30,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: TreasureChestPainter(color: color),
      ),
    );
  }
}

class TreasureChestPainter extends CustomPainter {
  final Color color;

  const TreasureChestPainter({
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    final Paint fillPaint = Paint()
      ..color = color.withOpacity(0.18)
      ..style = PaintingStyle.fill;

    final Paint outlinePaint = Paint()
      ..color = color
      ..strokeWidth = width * 0.07
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint goldStrokePaint = Paint()
      ..color = const Color(0xFFFFD166)
      ..strokeWidth = width * 0.07
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint goldFillPaint = Paint()
      ..color = const Color(0xFFFFD166)
      ..style = PaintingStyle.fill;

    final RRect lid = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        width * 0.12,
        height * 0.18,
        width * 0.76,
        height * 0.32,
      ),
      Radius.circular(width * 0.12),
    );

    final RRect body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        width * 0.10,
        height * 0.42,
        width * 0.80,
        height * 0.42,
      ),
      Radius.circular(width * 0.09),
    );

    canvas.drawRRect(lid, fillPaint);
    canvas.drawRRect(body, fillPaint);

    canvas.drawRRect(lid, outlinePaint);
    canvas.drawRRect(body, outlinePaint);

    canvas.drawLine(
      Offset(width * 0.12, height * 0.50),
      Offset(width * 0.88, height * 0.50),
      goldStrokePaint,
    );

    canvas.drawLine(
      Offset(width * 0.32, height * 0.44),
      Offset(width * 0.32, height * 0.82),
      goldStrokePaint,
    );

    canvas.drawLine(
      Offset(width * 0.68, height * 0.44),
      Offset(width * 0.68, height * 0.82),
      goldStrokePaint,
    );

    final RRect lock = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(width * 0.50, height * 0.57),
        width: width * 0.20,
        height: height * 0.18,
      ),
      Radius.circular(width * 0.03),
    );

    canvas.drawRRect(lock, goldFillPaint);
  }

  @override
  bool shouldRepaint(covariant TreasureChestPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

// ==========================================
// GRAFIK TIL PROCENTVISNING
// ==========================================
class TriangleProgressPainter extends CustomPainter {
  final double progress;
  final Color fillColor;

  TriangleProgressPainter({
    required this.progress,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintBase = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.fill;

    final paintFill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paintBase);

    canvas.save();

    canvas.clipRect(
      Rect.fromLTWH(
        0,
        size.height * (1.0 - progress),
        size.width,
        size.height * progress,
      ),
    );

    canvas.drawPath(path, paintFill);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
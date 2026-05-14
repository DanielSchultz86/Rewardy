import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/app_drawer.dart';
import 'opret_medlem_screen.dart'; // Husk at det evt. hedder opret_medlem_popup.dart hos dig
import 'rediger_medlem_popup.dart';

class MedlemmerScreen extends StatefulWidget {
  const MedlemmerScreen({super.key});

  @override
  State<MedlemmerScreen> createState() => _MedlemmerScreenState();
}

class _MedlemmerScreenState extends State<MedlemmerScreen> {

  // --- FUNKTION: Henter familienavne ud fra deres IDs ---
  Future<String> _getFamilyNames(List<dynamic> familyIds) async {
    if (familyIds.isEmpty) return 'Ingen familie';
    
    List<String> names = [];
    for (String id in familyIds) {
      try {
        final doc = await FirebaseFirestore.instance.collection('families').doc(id).get();
        if (doc.exists && doc.data() != null) {
          names.add(doc.data()!['name'] ?? 'Ukendt familie');
        }
      } catch (e) {
        debugPrint('Kunne ikke hente familie: $e');
      }
    }
    
    if (names.isEmpty) return 'Ingen familie';
    return 'Familie: ${names.join(' • ')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Dine medlemmer'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(Icons.add_circle, color: Color(0xFFFF6B35), size: 36),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true, 
                  backgroundColor: Colors.transparent, 
                  builder: (context) => const OpretMedlemPopup(),
                );
              },
            ),
          ),
        ],
      ),
      body: currentUserId == null 
        ? const Center(child: Text("Du er ikke logget ind.", style: TextStyle(color: Colors.white)))
        : StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('members')
                .where('oprettetAf', isEqualTo: currentUserId)
                .snapshots(),
            builder: (context, snapshot) {
              
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)));
              }

              if (snapshot.hasError) {
                return Center(child: Text('Noget gik galt: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
              }

              final docs = snapshot.data?.docs ?? [];
              
              if (docs.isEmpty) {
                return _buildEmptyState();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  
                  // LISTE MED MEDLEMMER (Filter fjernet)
                  Expanded(
                    child: ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (context, index) => const Divider(color: Color(0xFF3F3F46), height: 1, thickness: 1),
                      itemBuilder: (context, index) {
                        return _buildMemberTile(docs[index]);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  // --- HJÆLPE WIDGETS ---

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.family_restroom_rounded, size: 80, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 24),
            const Text(
              'Ingen medlemmer endnu',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text(
              'Opret dine familiemedlemmer her, så du kan tildele dem opgaver og belønninger senere.\n\nTryk på det orange + i toppen for at starte!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white54, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    final String name = data['navn'] ?? 'Ukendt navn';
    final List<dynamic> families = data['familier'] ?? [];
    final int colorValue = data['ikonFarve'] ?? Colors.grey.value;
    final Color iconColor = Color(colorValue);

    return InkWell(
      // NYT: Hele rækken åbner nu redigerings popuppen!
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => RedigerMedlemPopup(memberDoc: doc),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  
                  FutureBuilder<String>(
                    future: _getFamilyNames(families),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Text('Henter familie...', style: TextStyle(fontSize: 13, color: Colors.white54));
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return const Text('Ingen familie', style: TextStyle(fontSize: 13, color: Colors.white54));
                      }
                      return Text(
                        snapshot.data!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: Colors.white54),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: iconColor, width: 2),
              ),
              child: Icon(Icons.person_outline, color: iconColor, size: 24),
            ),
            const SizedBox(width: 8),
            // NYT: De tre prikker er fjernet herfra!
            const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }
}
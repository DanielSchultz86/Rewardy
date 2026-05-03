import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/app_drawer.dart';
import 'opret_medlem_screen.dart';
import 'rediger_medlem_popup.dart';

class MedlemmerScreen extends StatefulWidget {
  const MedlemmerScreen({super.key});

  @override
  State<MedlemmerScreen> createState() => _MedlemmerScreenState();
}

class _MedlemmerScreenState extends State<MedlemmerScreen> {
  // Holder styr på valgte filtre (Navne). Starter med "Alle".
  final List<String> _selectedFilters = ['Alle'];

  // Logik til at vælge/fravælge filtre
  void _toggleFilter(String filterName) {
    setState(() {
      if (filterName == 'Alle') {
        _selectedFilters.clear();
        _selectedFilters.add('Alle');
      } else {
        _selectedFilters.remove('Alle');
        if (_selectedFilters.contains(filterName)) {
          _selectedFilters.remove(filterName);
          if (_selectedFilters.isEmpty) {
            _selectedFilters.add('Alle'); 
          }
        } else {
          _selectedFilters.add(filterName);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Hent den aktuelle brugers ID for kun at hente deres medlemmer
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
                  isScrollControlled: true, // VIGTIG: Tillader at popuppen fylder næsten hele skærmen
                  backgroundColor: Colors.transparent, // Gør toppen af popuppen gennemsigtig så runderne virker
                  builder: (context) => const OpretMedlemPopup(), // Bemærk at vi nu kalder "Popup" widgetten
                );
              },
            ),
          ),
        ],
      ),
      body: currentUserId == null 
        ? const Center(child: Text("Du er ikke logget ind.", style: TextStyle(color: Colors.white)))
        : StreamBuilder<QuerySnapshot>(
            // Vi lytter KUN til medlemmer, som denne admin har oprettet
            stream: FirebaseFirestore.instance
                .collection('members')
                .where('oprettetAf', isEqualTo: currentUserId)
                .snapshots(),
            builder: (context, snapshot) {
              
              // 1. Venter på data (Loading)
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)));
              }

              // 2. Fejlhåndtering
              if (snapshot.hasError) {
                return Center(child: Text('Noget gik galt: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
              }

              // 3. Konverter dokumenter til en liste af Map
              final docs = snapshot.data?.docs ?? [];
              
              if (docs.isEmpty) {
                return _buildEmptyState();
              }

              // 4. Filtreringslogik
              final filteredDocs = _selectedFilters.contains('Alle')
                  ? docs
                  : docs.where((doc) {
                      final name = doc['navn'] as String;
                      return _selectedFilters.any((filter) => name.startsWith(filter));
                    }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  
                  // FILTER SEKTION
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildFilterChip('Alle'),
                        ...docs.map((doc) {
                          String shortName = (doc['navn'] as String).split(' ')[0];
                          if (shortName.length > 8) {
                            shortName = '${shortName.substring(0, 8)}..';
                          }
                          return _buildFilterChip(shortName);
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF3F3F46), height: 1, thickness: 1),

                  // LISTE MED MEDLEMMER
                  Expanded(
                    child: filteredDocs.isEmpty
                      ? const Center(child: Text("Ingen medlemmer matcher filtret.", style: TextStyle(color: Colors.white54)))
                      : ListView.separated(
                          itemCount: filteredDocs.length,
                          separatorBuilder: (context, index) => const Divider(color: Color(0xFF3F3F46), height: 1, thickness: 1),
                          itemBuilder: (context, index) {
                            // Byg en række for hvert dokument
                            return _buildMemberTile(filteredDocs[index]);
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

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilters.contains(label);
    return GestureDetector(
      onTap: () => _toggleFilter(label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6B35) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF6B35) : const Color(0xFF3F3F46),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // Nu tager denne widget et QueryDocumentSnapshot i stedet for DummyMember
  Widget _buildMemberTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Udpak data sikkert
    final String name = data['navn'] ?? 'Ukendt navn';
    final List<dynamic> families = data['familier'] ?? [];
    final int colorValue = data['ikonFarve'] ?? Colors.grey.value;
    final Color iconColor = Color(colorValue);

    String familyText = families.isEmpty 
        ? 'Ingen familie' 
        : 'Familie: ${families.join(' • ')}';

    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Åbner profil for $name')));
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
                  Text(
                    familyText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Colors.white54),
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

            Theme(
              data: Theme.of(context).copyWith(
                popupMenuTheme: PopupMenuThemeData(
                  color: const Color(0xFF2A2A30),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white70),
                onSelected: (value) async {
                  if (value == 'Slet medlem') {
                    // Sletter medlemmet direkte i Firebase!
                    await FirebaseFirestore.instance.collection('members').doc(doc.id).delete();
                    if(mounted){
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Medlemmet blev slettet.')));
                    }
                  } else if (value == 'Rediger medlem') {
                    // Åbn redigerings-popup
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => RedigerMedlemPopup(memberDoc: doc),
                    );
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem(
                    value: 'Rediger medlem',
                    child: Text('Rediger medlem', style: TextStyle(color: Colors.white)),
                  ),
                  const PopupMenuDivider(height: 1),
                  const PopupMenuItem(
                    value: 'Slet medlem',
                    child: Text('Slet medlem', style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
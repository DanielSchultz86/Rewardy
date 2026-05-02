import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart'; // 1. Husk at importere menuen her i toppen

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(), // 2. Indsæt menuen her! Flutter tegner selv ikonet.
      appBar: AppBar(
        title: const Text('Familien Jensen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Color(0xFFFF6B35), size: 28),
            onPressed: () {
              // TODO: Opret opgave
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Gruppe-indstillinger
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Her kommer familiens rigtige dashboard med opgaver!'),
      ),
    );
  }
}
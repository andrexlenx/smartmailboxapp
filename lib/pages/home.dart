import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';

class ViewPage extends StatelessWidget {
  const ViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            // Usa il Navigator standard di Flutter
            Navigator.pushNamed(context, '/settings');
          },
        ),
        title: const Text('CAIoTTA'),
        actions: const [
          ServerAppBar(),
        ],
      ),
      body: Container(
        decoration: AppTheme.primaryContainerRange(),
        child: appState.events.isEmpty
            ? const Center(child: Text("Nessun evento registrato", style: TextStyle(color: Colors.white)))
            : ListView.builder(
          itemCount: appState.events.length,
          itemBuilder: (context, index) {
            final FirebaseEvent event = appState.events[index];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.shadedWhite(),
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                leading: const Icon(Icons.mark_email_unread, color: Colors.blueAccent),
                title: Text(event.type, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Data: ${event.date}"),
                trailing: Text("Peso: ${event.weight}g", style: const TextStyle(fontSize: 16)),
              ),
            );
          },
        ),
      ),
    );
  }
}
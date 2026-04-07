import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _endpointController;

  @override
  void initState() {
    super.initState();
    // Inizializza il controller con il valore attuale prelevato dal Provider
    final appState = Provider.of<MyAppState>(context, listen: false);
    _endpointController = TextEditingController(text: appState.firebaseendpoint);
  }

  @override
  void dispose() {
    _endpointController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // Torna alla pagina precedente
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              'Configurazione Firebase',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _endpointController,
                    decoration: const InputDecoration(
                      labelText: 'Collection Endpoint (es. mailbox_events)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final fbend = _endpointController.text.trim();
                    if (fbend.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('L\'endpoint non può essere vuoto')),
                      );
                    } else {
                      // Chiama la funzione di aggiornamento nello State
                      await appState.updateEndpoint(fbend);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Endpoint salvato e in connessione...')),
                        );
                        // Opzionale: torna indietro automaticamente dopo il salvataggio
                        // Navigator.pop(context);
                      }
                    }
                  },
                  child: const Text('Salva'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            ListTile(
              title: const Text("Stato Permessi Notifiche"),
              trailing: Icon(
                appState.permsgranted ? Icons.check_circle : Icons.cancel,
                color: appState.permsgranted ? Colors.green : Colors.red,
              ),
            )
          ],
        ),
      ),
    );
  }
}
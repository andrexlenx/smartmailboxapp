import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _macController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _macController.dispose();
    _passwordController.dispose();
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
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              'Gestione Gateway',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                TextField(
                  controller: _macController,
                  decoration: const InputDecoration(
                    labelText: 'MAC Address Gateway',
                    hintText: 'es. AA:BB:CC:DD:EE:FF',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password Decrittazione',
                    hintText: 'Inserisci la password del gateway',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final mac = _macController.text.trim();
                      final password = _passwordController.text.trim();
                      if (mac.isEmpty || password.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Inserisci MAC address e Password')),
                        );
                      } else {
                        await appState.addGateway(mac, password);
                        _macController.clear();
                        _passwordController.clear();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Gateway aggiunto')),
                          );
                        }
                      }
                    },
                    child: const Text('Aggiungi Gateway'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Gateway Associati',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            if (appState.gateways.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Nessun gateway configurato.'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: appState.gateways.length,
                itemBuilder: (context, index) {
                  final mac = appState.gateways[index];
                  return ListTile(
                    title: Text(mac),
                    subtitle: const Text('Configurato con password'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        appState.removeGateway(mac);
                      },
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),
            const Divider(),
            ListTile(
              title: const Text("Permessi Notifiche"),
              trailing: Icon(
                appState.permsgranted ? Icons.check_circle : Icons.cancel,
                color: appState.permsgranted ? Colors.green : Colors.red,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Gestione Dati',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ListTile(
              title: const Text("Cancella tutti gli eventi"),
              subtitle: const Text("Rimuove permanentemente tutti i record dal database"),
              trailing: const Icon(Icons.delete_forever, color: Colors.red),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text("Conferma eliminazione"),
                      content: const Text("Sei sicuro di voler cancellare tutti gli eventi? Questa azione non è reversibile."),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text("Annulla"),
                        ),
                        TextButton(
                          onPressed: () async {
                            await appState.clearEvents();
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Eventi cancellati con successo')),
                              );
                            }
                          },
                          child: const Text("Elimina", style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';

class ViewPage extends StatefulWidget {
  const ViewPage({super.key});

  @override
  State<ViewPage> createState() => _ViewPageState();
}

class _ViewPageState extends State<ViewPage> {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    // Flatten the data to a list of mailboxes for display
    List<MailboxInfo> allMailboxes = [];
    appState.mailboxData.forEach((mac, mailboxes) {
      allMailboxes.addAll(mailboxes.values);
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
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
        child: allMailboxes.isEmpty
            ? const Center(
                child: Text(
                  "Nessuna mailbox configurata.\nAggiungi un gateway per iniziare.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              )
            : ListView.builder(
                itemCount: allMailboxes.length,
                itemBuilder: (context, index) {
                  final mailbox = allMailboxes[index];
                  return MailboxTile(mailbox: mailbox);
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGatewayDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddGatewayDialog(BuildContext context) {
    final TextEditingController macController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Aggiungi Gateway"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: macController,
              decoration: const InputDecoration(
                hintText: "es. AA:BB:CC:DD:EE:FF",
                labelText: "MAC Address",
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: "Password di decrittazione",
                labelText: "Password",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annulla"),
          ),
          ElevatedButton(
            onPressed: () {
              final mac = macController.text.trim();
              final password = passwordController.text.trim();
              if (mac.isNotEmpty && password.isNotEmpty) {
                Provider.of<MyAppState>(context, listen: false).addGateway(mac, password);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Inserisci MAC address e Password')),
                );
              }
            },
            child: const Text("Aggiungi"),
          ),
        ],
      ),
    );
  }
}

class MailboxTile extends StatelessWidget {
  final MailboxInfo mailbox;

  const MailboxTile({super.key, required this.mailbox});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.shadedWhite(),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Stack(
          children: [
            const Icon(Icons.markunread_mailbox, size: 40, color: Colors.blueAccent),
            if (mailbox.hasUnread)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                ),
              ),
          ],
        ),
        title: Text(mailbox.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Gateway: ${mailbox.gatewayMac}"),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // Mark as read when tapping the card
          Provider.of<MyAppState>(context, listen: false).markAsRead(mailbox.gatewayMac, mailbox.name);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventsPage(mailbox: mailbox),
            ),
          );
        },
      ),
    );
  }
}

class EventsPage extends StatelessWidget {
  final MailboxInfo mailbox;

  const EventsPage({super.key, required this.mailbox});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Eventi: ${mailbox.name}"),
      ),
      body: Container(
        decoration: AppTheme.primaryContainerRange(),
        child: mailbox.events.isEmpty
            ? const Center(child: Text("Nessun evento registrato", style: TextStyle(color: Colors.white)))
            : ListView.builder(
                itemCount: mailbox.events.length,
                itemBuilder: (context, index) {
                  final event = mailbox.events[index];
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

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'firebase_options.dart';

import 'pages/home.dart';
import 'pages/settings.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e) {}
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CAIoTTA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const ViewPage(),
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}

class MailboxInfo {
  final String gatewayMac;
  final String name;
  final List<FirebaseEvent> events;
  bool hasUnread;

  MailboxInfo({
    required this.gatewayMac,
    required this.name,
    required this.events,
    this.hasUnread = false,
  });
}

class MyAppState extends ChangeNotifier {
  String firebaseendpoint = "events";
  String network = "Offline";
  Color statuscolor = Colors.red;
  IconData statusicon = Icons.cloud_off;

  bool permsgranted = false;
  List<String> gateways = [];
  Map<String, String> gatewayPasswords = {}; // mac -> password
  Map<String, int> lastReadTimestamps = {}; // mac-mailboxName -> timestamp

  // gatewayMac -> { mailboxName -> MailboxInfo }
  Map<String, Map<String, MailboxInfo>> mailboxData = {};
  
  final Map<String, StreamSubscription> _subscriptions = {};
  final Storage storage = Storage();

  MyAppState() {
    initApp();
  }

  Future<void> initApp() async {
    await readSettings();
    await setupPushNotifications();
    connectToDatabase();
  }

  Future<void> setupPushNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    permsgranted = settings.authorizationStatus == AuthorizationStatus.authorized;
    if (permsgranted) {
      await FirebaseMessaging.instance.subscribeToTopic('new_mail');
      print("Subscribed to new_mail topic");
    }
    String? token = await messaging.getToken();
    print("Token FCM: $token");
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Ricevuto messaggio in foreground: ${message.notification?.title}');
    });
  }

  void connectToDatabase() {
    for (var sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    mailboxData.clear();

    if (gateways.isEmpty) {
      network = "No Gateways";
      statuscolor = Colors.orange;
      statusicon = Icons.warning;
      notifyListeners();
      return;
    }

    network = "Connecting";
    statuscolor = Colors.yellow;
    statusicon = Icons.cloud_sync;
    notifyListeners();

    for (String mac in gateways) {
      final String? password = gatewayPasswords[mac];
      if (password == null) continue;

      _subscriptions[mac] = FirebaseDatabase.instance
          .ref("$firebaseendpoint/$mac")
          .onValue
          .listen((DatabaseEvent event) {
        
        final dynamic val = event.snapshot.value;
        print("debug data for $mac: $val");
        Map<String, MailboxInfo> mailboxes = {};

        if (val != null) {
           _processDatabaseValue(mac, password, val, mailboxes);
        }
        
        mailboxData[mac] = mailboxes;
        network = "Online";
        statuscolor = Colors.green;
        statusicon = Icons.cloud_done;
        notifyListeners();
      }, onError: (e) {
        print("Error for $mac: $e");
      });
    }
  }

  void _processDatabaseValue(String mac, String password, dynamic val, Map<String, MailboxInfo> mailboxes) {
    List<String> encryptedRecords = [];

    if (val is Map) {
      val.forEach((key, subVal) {
        if (subVal is Map) {
          if (subVal.containsKey('payload') && subVal['payload'] is String) {
            encryptedRecords.add(subVal['payload']);
          } else {
            subVal.forEach((k2, v2) {
              if (v2 is String) {
                encryptedRecords.add(v2);
              }
            });
          }
        } else if (subVal is String) {
          encryptedRecords.add(subVal);
        } else if (subVal is List) {
           encryptedRecords.addAll(subVal.whereType<String>());
        }
      });
    } else if (val is List) {
      encryptedRecords = val.whereType<String>().toList();
    }

    if (encryptedRecords.isEmpty) return;

    final keyBytes = sha256.convert(utf8.encode(password)).bytes;
    final key = encrypt.Key(Uint8List.fromList(keyBytes));

    Map<String, List<FirebaseEvent>> tempMailboxes = {};

    for (String base64Data in encryptedRecords) {
      try {
        final decoded = base64.decode(base64Data);
        if (decoded.length < 16) continue;

        final iv = encrypt.IV(decoded.sublist(0, 16));
        final payload = decoded.sublist(16);

        final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
        final decrypted = encrypter.decrypt(encrypt.Encrypted(payload), iv: iv);

        final Map<String, dynamic> data = json.decode(decrypted);
        final event = FirebaseEvent.fromJson(data);
        final mailboxName = event.mailboxName;
        if (!tempMailboxes.containsKey(mailboxName)) {
          tempMailboxes[mailboxName] = [];
        }
        tempMailboxes[mailboxName]!.add(event);
      } catch (e) {
        print("Decryption error: $e");
      }
    }

    tempMailboxes.forEach((name, eventsList) {
      eventsList.sort((a, b) => b.rawTimestamp.compareTo(a.rawTimestamp));
      
      // Logic changed: hasUnread if latest event is newer than lastReadTimestamp
      int lastRead = lastReadTimestamps["$mac-$name"] ?? 0;
      bool unread = eventsList.isNotEmpty && eventsList.first.rawTimestamp > lastRead;

      mailboxes[name] = MailboxInfo(
        gatewayMac: mac,
        name: name,
        events: eventsList,
        hasUnread: unread,
      );
    });
  }

  Future<void> markAsRead(String mac, String mailboxName) async {
    final key = "$mac-$mailboxName";
    final mailbox = mailboxData[mac]?[mailboxName];
    if (mailbox != null && mailbox.events.isNotEmpty) {
      lastReadTimestamps[key] = mailbox.events.first.rawTimestamp;
      mailbox.hasUnread = false;
      await _saveSettings();
      notifyListeners();
    }
  }

  Future<void> readSettings() async {
    gateways = await storage.readList("gateways");
    final List<String> passwords = await storage.readList("passwords");
    final String? timestampsJson = await storage.readString("lastReadTimestamps");

    gatewayPasswords.clear();
    for (int i = 0; i < gateways.length && i < passwords.length; i++) {
      gatewayPasswords[gateways[i]] = passwords[i];
    }

    if (timestampsJson != null) {
      try {
        Map<String, dynamic> decoded = json.decode(timestampsJson);
        lastReadTimestamps = decoded.map((key, value) => MapEntry(key, value as int));
      } catch (e) {
        print("Error loading timestamps: $e");
      }
    }

    notifyListeners();
  }

  Future<void> clearEvents() async {
    for (String mac in gateways) {
      await FirebaseDatabase.instance.ref("$firebaseendpoint/$mac").remove();
    }
  }

  Future<void> addGateway(String mac, String password) async {
    if (!gateways.contains(mac)) {
      gateways.add(mac);
      gatewayPasswords[mac] = password;
      await _saveSettings();
      connectToDatabase();
    }
  }

  Future<void> removeGateway(String mac) async {
    gateways.remove(mac);
    gatewayPasswords.remove(mac);
    mailboxData.remove(mac);
    // Optional: remove related lastReadTimestamps keys here if desired
    await _saveSettings();
    connectToDatabase();
  }

  Future<void> _saveSettings() async {
    await storage.writeList("gateways", gateways);
    List<String> passwords = gateways.map((mac) => gatewayPasswords[mac] ?? "").toList();
    await storage.writeList("passwords", passwords);
    await storage.writeString("lastReadTimestamps", json.encode(lastReadTimestamps));
  }

  @override
  void dispose() {
    for (var sub in _subscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }
}

class Storage {
  Future<List<String>> readList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key) ?? [];
  }
  Future<void> writeList(String key, List<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, value);
  }
  Future<String?> readString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }
  Future<void> writeString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}

class ServerAppBar extends StatelessWidget {
  const ServerAppBar({super.key});
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Text(appState.network, style: TextStyle(color: appState.statuscolor, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Icon(appState.statusicon, color: appState.statuscolor),
        ],
      ),
    );
  }
}

class AppTheme {
  AppTheme._();
  static BoxDecoration primaryContainerRange() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF97BDF8), Color(0xFF61A4F1), Color(0xFF478DE0), Color(0xFF1B76E4)],
        stops: [0.5, 0.75, 0.875, 0.9],
      ),
    );
  }
  static Color shadedWhite() => const Color(0xE6FFFFFF);
}

class FirebaseEvent {
  final String date;
  final String type;
  final int weight;
  final int rawTimestamp;
  final String mailboxName;

  FirebaseEvent({
    required this.date,
    required this.type,
    required this.weight,
    required this.rawTimestamp,
    required this.mailboxName,
  });

  factory FirebaseEvent.fromJson(Map<String, dynamic> data) {
    int timestamp = data['time'] is num ? (data['time'] as num).toInt() : int.tryParse(data['time']?.toString() ?? '0') ?? 0;
    String formattedDate = timestamp.toString();
    if (timestamp != 0) {
      final DateTime dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      formattedDate = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }
    return FirebaseEvent(
      date: formattedDate,
      rawTimestamp: timestamp,
      type: data['classification']?.toString() ?? 'Sconosciuto',
      weight: data['weight'] is num ? (data['weight'] as num).toInt() : int.tryParse(data['weight']?.toString() ?? '0') ?? 0,
      mailboxName: data['mailbox']?.toString() ?? 'Principale',
    );
  }
}

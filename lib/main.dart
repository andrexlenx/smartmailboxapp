import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

import 'pages/home.dart';
import 'pages/settings.dart';

// Gestore delle notifiche in background
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) {
      rethrow;
    }
  }
  print("Gestendo un messaggio in background: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) {
      rethrow;
    }
  }
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
      title: 'SmartMailbox',
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

class MyAppState extends ChangeNotifier {
  String firebaseendpoint = "events";
  String network = "Offline";
  Color statuscolor = Colors.red;
  IconData statusicon = Icons.cloud_off;

  bool permsgranted = false;
  List<FirebaseEvent> events = [];
  StreamSubscription? _dbSubscription;
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
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Ricevuto messaggio in foreground: ${message.notification?.title}');
    });
  }

  void connectToDatabase() {
    network = "Connecting";
    statuscolor = Colors.yellow;
    statusicon = Icons.cloud_sync;
    notifyListeners();

    _dbSubscription?.cancel();

    if (firebaseendpoint.isNotEmpty) {
      try {
        _dbSubscription = FirebaseDatabase.instance
            .ref(firebaseendpoint)
            .onValue
            .listen((DatabaseEvent event) {
          
          final data = event.snapshot.value;
          List<FirebaseEvent> loadedEvents = [];
          print("debug data snapshot: $data");
          
          if (data != null && data is Map) {
            data.forEach((key, value) {
              if (value is Map) {

                final int? timestamp = int.tryParse(key.toString());
                if (timestamp != null) {
                  loadedEvents.add(FirebaseEvent.fromMap(key.toString(), Map<String, dynamic>.from(value)));
                }
              }
            });
            // Ordina per timestamp decrescente
            loadedEvents.sort((a, b) => b.rawTimestamp.compareTo(a.rawTimestamp));
          }

          events = loadedEvents;
          network = "Online";
          statuscolor = Colors.green;
          statusicon = Icons.cloud_done;
          notifyListeners();

        }, onError: (error) {
          network = "Connection Failed";
          statuscolor = Colors.orange;
          statusicon = Icons.error;
          notifyListeners();
          print("Errore durante la connessione al database: $error");
        });
      } catch (e) {
        network = "Offline";
        statuscolor = Colors.red;
        statusicon = Icons.cloud_off;
        notifyListeners();
      }
    }
  }

  Future<void> readSettings() async {
    String savedEndpoint = await storage.readString("FBendpoint");
    if (savedEndpoint.isNotEmpty) {
      firebaseendpoint = savedEndpoint;
    }
  }

  Future<void> updateEndpoint(String newEndpoint) async {
    firebaseendpoint = newEndpoint;
    await storage.writeString("FBendpoint", newEndpoint);
    connectToDatabase();
  }

  @override
  void dispose() {
    _dbSubscription?.cancel();
    super.dispose();
  }
}

class Storage {
  Future<String> readString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key) ?? '';
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

  FirebaseEvent({required this.date, required this.type, required this.weight, required this.rawTimestamp});

  factory FirebaseEvent.fromMap(String key, Map<String, dynamic> data) {
    int timestamp = int.tryParse(key) ?? 0;
    String formattedDate = key;
    
    if (timestamp != 0) {
      final DateTime dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      formattedDate = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }
    
    // filter data if wrapped
    Map<dynamic, dynamic> innerData = data;
    if (data.isNotEmpty && data.values.first is Map) {
      innerData = data.values.first as Map<dynamic, dynamic>;
    }

    return FirebaseEvent(
      date: formattedDate,
      rawTimestamp: timestamp,
      type: innerData['classification']?.toString() ?? 'Sconosciuto',
      weight: innerData['weight'] is num ? (innerData['weight'] as num).toInt() : int.tryParse(innerData['weight']?.toString() ?? '0') ?? 0,
    );
  }
}

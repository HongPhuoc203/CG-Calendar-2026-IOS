import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'firebase_options.dart';
import 'providers/theme_provider.dart';
import 'presentation/auth/auth_wrapper.dart';
import 'data/services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize timezone database
  tz.initializeTimeZones();
  
  // Setup FCM background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    
    return MaterialApp(
      title: 'CG Calendar',
      theme: theme,
      debugShowCheckedModeBanner: false,
      
      // Real auth flow with role-based routing
      home: const AuthWrapper(),
    );
  }
}


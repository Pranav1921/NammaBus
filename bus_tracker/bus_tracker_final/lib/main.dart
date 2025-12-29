import 'package:bus_tracker_final/screens/wrapper.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:bus_tracker_final/firebase_options.dart';
import 'package:bus_tracker_final/services/auth_service.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamProvider.value(
      initialData: null,
      value: AuthService().user,
      child: MaterialApp(
        debugShowCheckedModeBanner: false, // This line removes the debug banner
        title: 'Bus Tracker',
        theme: ThemeData(
          primarySwatch: Colors.orange,
        ),
        home: const Wrapper(),
      ),
    );
  }
}

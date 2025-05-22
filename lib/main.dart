import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:invent_app_redesign/providers/theme_provider.dart';
import 'package:invent_app_redesign/providers/locale_provider.dart';
import 'package:invent_app_redesign/screens/home_screen.dart';
import 'package:invent_app_redesign/screens/login_screen.dart';
import 'package:invent_app_redesign/screens/pin_login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// RestartWidget for app reload
class RestartWidget extends StatefulWidget {
  final Widget child;

  const RestartWidget({Key? key, required this.child}) : super(key: key);

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>()?.restartApp();
  }

  @override
  _RestartWidgetState createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key key = UniqueKey();

  void restartApp() {
    setState(() {
      key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: key,
      child: widget.child,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('products');
  await Hive.openBox('history');
  await Hive.openBox('drafts');
  await Hive.openBox('settings');
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyB8sJChHQrTY4P34RXizeAmkC5Ck_CQGxo",
      authDomain: "invent-423e7.firebaseapp.com",
      projectId: "invent-423e7",
      storageBucket: "invent-423e7.appspot.com",
      messagingSenderId: "561252289076",
      appId: "1:561252289076:web:958bbdde521c65934d1861",
      measurementId: "G-LR76SNLKZN",
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  final isGuest = prefs.getBool('isGuest') ?? false;
  final storage = const FlutterSecureStorage();
  final isPinSet = await storage.read(key: 'user_pin') != null;

  final user = FirebaseAuth.instance.currentUser;

  Widget initialScreen;
  if ((isGuest || user != null) && isPinSet) {
    initialScreen = const PinLoginScreen();
  } else if (isGuest || user != null) {
    initialScreen = const HomeScreen();
  } else {
    initialScreen = const LoginScreen();
  }

  runApp(MyApp(initialScreen: initialScreen));
}

class DefaultFirebaseOptions {
  static var currentPlatform;
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;

  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (context, themeProvider, localeProvider, _) {
          return RestartWidget(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Inventory App',
              theme: themeProvider.currentTheme,
              locale: localeProvider.locale,
              supportedLocales: const [
                Locale('en'),
                Locale('ru'),
                Locale('kk'),
              ],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: initialScreen,
            ),
          );
        },
      ),
    );
  }
}
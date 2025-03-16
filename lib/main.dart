import 'package:flutter/material.dart';
import 'package:project/services/api_service.dart';
import 'package:project/screens/auth/login_screen.dart';
import 'package:project/screens/home/home_screen.dart';
import 'package:project/screens/search/search_screen.dart';
import 'package:project/screens/friends/friend_requests_screen.dart';
import 'package:project/screens/friends/friends_list_screen.dart';
import 'package:project/screens/chat/new_chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => ApiService(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/search': (context) => const SearchScreen(),
        '/friend_requests': (context) => const FriendRequestsScreen(),
        '/friends': (context) => const FriendsListScreen(),
        '/new_chat': (context) => const NewChatScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token != null) {
      final apiService = Provider.of<ApiService>(context, listen: false);
      apiService.setToken(token);
      
      final isAuthenticated = await apiService.checkAuth();
      
      setState(() {
        _isAuthenticated = isAuthenticated;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _isAuthenticated ? const HomeScreen() : const LoginScreen();
  }
}

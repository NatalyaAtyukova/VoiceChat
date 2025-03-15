import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;
  bool _isCheckingUsername = false;
  bool _mounted = true;

  @override
  void dispose() {
    _mounted = false;
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      
      if (_isLogin) {
        // Вход в систему
        await firebaseService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
        
        // Добавляем сообщение об успешном входе
        if (_mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login successful!')),
          );
          
          // Явно перенаправляем на домашний экран после входа
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        }
      } else {
        // Проверяем доступность логина
        final isUsernameAvailable = await firebaseService.isUsernameAvailable(_usernameController.text);
        if (!isUsernameAvailable) {
          if (_mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Username is already taken. Please choose another one.')),
            );
            setState(() => _isLoading = false);
          }
          return;
        }

        // Создаем пользователя
        final userCredential = await firebaseService.createUserWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
        
        // Создаем профиль пользователя
        await firebaseService.createUserProfile(
          userCredential.user!.uid,
          _usernameController.text,
          _emailController.text.trim(),
          displayName: _displayNameController.text.isNotEmpty 
              ? _displayNameController.text 
              : _usernameController.text,
        );
        
        // Добавляем сообщение об успешной регистрации
        if (_mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful!')),
          );
          
          // Явно перенаправляем на домашний экран после регистрации
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        }
      }
    } catch (e) {
      if (_mounted) {
        // Показываем более понятное сообщение об ошибке
        String errorMessage = 'An error occurred: ${e.toString()}';
        if (e.toString().contains('email-already-in-use')) {
          errorMessage = 'This email is already registered. Please login or use another email.';
        } else if (e.toString().contains('invalid-email')) {
          errorMessage = 'Invalid email format. Please check your email address.';
        } else if (e.toString().contains('weak-password')) {
          errorMessage = 'Password is too weak. Please use a stronger password.';
        } else if (e.toString().contains('user-not-found') || e.toString().contains('wrong-password')) {
          errorMessage = 'Invalid email or password. Please check your credentials.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      if (_mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkUsername(String username) async {
    if (username.isEmpty) return;
    
    setState(() => _isCheckingUsername = true);
    
    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      final isAvailable = await firebaseService.isUsernameAvailable(username);
      
      if (!isAvailable && _mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username is already taken. Please choose another one.')),
        );
      }
    } catch (e) {
      // Игнорируем ошибки при проверке
    } finally {
      if (_mounted) {
        setState(() => _isCheckingUsername = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLogin ? 'Welcome Back' : 'Create Account',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      // Используем регулярное выражение для проверки email
                      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                      if (!emailRegex.hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  if (!_isLogin) ...[
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        border: const OutlineInputBorder(),
                        suffixIcon: _isCheckingUsername 
                            ? const SizedBox(
                                width: 20, 
                                height: 20, 
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        if (value.length > 3) {
                          _checkUsername(value);
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a username';
                        }
                        if (value.length < 3) {
                          return 'Username must be at least 3 characters';
                        }
                        if (value.contains(' ')) {
                          return 'Username cannot contain spaces';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _displayNameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Name (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : Text(_isLogin ? 'Login' : 'Sign Up'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      setState(() => _isLogin = !_isLogin);
                    },
                    child: Text(
                      _isLogin
                          ? 'Don\'t have an account? Sign Up'
                          : 'Already have an account? Login',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 
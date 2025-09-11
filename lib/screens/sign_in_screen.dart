import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmailAndPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isSignUp) {
        // Sign up
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );

        if (mounted && credential.user != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Sign in
        final credential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );

        // If we reach here, sign in was successful
        if (mounted && credential.user != null) {
          debugPrint('Sign in successful for user: ${credential.user!.email}');
        }
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found for that email.';
          break;
        case 'wrong-password':
          message = 'Wrong password provided.';
          break;
        case 'email-already-in-use':
          message = 'The account already exists for that email.';
          break;
        case 'weak-password':
          message = 'The password provided is too weak.';
          break;
        case 'invalid-email':
          message = 'The email address is not valid.';
          break;
        default:
          message = e.message ?? 'An error occurred. Please try again.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        // Log the actual error for debugging
        debugPrint('Unexpected error during authentication: $e');

        // Check for the specific Firebase Auth pigeon type casting issue
        final errorString = e.toString();
        final isPigeonTypeError =
            errorString.contains('PigeonUserDetails') ||
            errorString.contains('type cast') ||
            errorString.contains('List<Object?>');

        // Check if user is actually signed in despite the error
        final currentUser = FirebaseAuth.instance.currentUser;

        if (currentUser != null) {
          // Authentication succeeded despite the error
          debugPrint('Authentication succeeded despite error: $e');
          if (isPigeonTypeError) {
            // This is a known Firebase Auth pigeon issue, show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Sign in successful!'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            // Other non-critical error, just log it
            debugPrint('Non-critical authentication error: $e');
          }
        } else {
          // Authentication actually failed, show error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Authentication failed: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _devLogin(String email, String password) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (mounted && credential.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dev login successful: $email'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'Dev account not found. Please create the account first.';
          break;
        case 'wrong-password':
          message = 'Wrong password for dev account.';
          break;
        case 'invalid-email':
          message = 'The email address is not valid.';
          break;
        default:
          message = e.message ?? 'Dev login failed. Please try again.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Unexpected error during dev login: $e');

        // Check for the specific Firebase Auth pigeon type casting issue
        final errorString = e.toString();
        final isPigeonTypeError =
            errorString.contains('PigeonUserDetails') ||
            errorString.contains('type cast') ||
            errorString.contains('List<Object?>');

        // Check if user is actually signed in despite the error
        final currentUser = FirebaseAuth.instance.currentUser;

        if (currentUser != null) {
          // Authentication succeeded despite the error
          debugPrint('Dev login succeeded despite error: $e');
          if (isPigeonTypeError) {
            // This is a known Firebase Auth pigeon issue, show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Dev login successful!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          // Authentication actually failed, show error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Dev login error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSignUp ? 'Sign Up' : 'Sign In'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 80, color: Colors.blue),
              const SizedBox(height: 32),
              Text(
                'Safety App',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
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
                  onPressed: _isLoading ? null : _signInWithEmailAndPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_isSignUp ? 'Sign Up' : 'Sign In'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isSignUp = !_isSignUp;
                  });
                },
                child: Text(
                  _isSignUp
                      ? 'Already have an account? Sign In'
                      : "Don't have an account? Sign Up",
                ),
              ),
              const SizedBox(height: 32),
              // const Divider(),
              // const SizedBox(height: 16),
              // Text(
              //   'Development Login',
              //   style: Theme.of(context).textTheme.titleMedium?.copyWith(
              //     fontWeight: FontWeight.bold,
              //     color: Colors.grey[600],
              //   ),
              // ),
              // const SizedBox(height: 16),
              // SizedBox(
              //   width: double.infinity,
              //   height: 48,
              //   child: ElevatedButton(
              //     onPressed: _isLoading
              //         ? null
              //         : () => _devLogin('a@gmail.com', '12345678'),
              //     style: ElevatedButton.styleFrom(
              //       backgroundColor: Colors.orange,
              //       foregroundColor: Colors.white,
              //     ),
              //     child: const Text('Dev Login: a@gmail.com'),
              //   ),
              // ),
              // const SizedBox(height: 12),
              // SizedBox(
              //   width: double.infinity,
              //   height: 48,
              //   child: ElevatedButton(
              //     onPressed: _isLoading
              //         ? null
              //         : () => _devLogin(
              //             'my3palasirisena2384@gmail.com',
              //             '12345678',
              //           ),
              //     style: ElevatedButton.styleFrom(
              //       backgroundColor: Colors.purple,
              //       foregroundColor: Colors.white,
              //     ),
              //     child: const Text('Dev Login: my3palasirisena2384@gmail.com'),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}

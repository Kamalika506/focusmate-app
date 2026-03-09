import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'main_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = false;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Firebase Auth Error: ${e.code} - ${e.message}')),
        );
      }
    } on PlatformException catch (e) {
      debugPrint('PlatformException: ${e.code} - ${e.message} - ${e.details}');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sign-In Failed'),
            content: SingleChildScrollView(
              child: Text('Platform Error: ${e.code}\n${e.message}\nDetail: ${e.details}'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('DISMISS')),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('General Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigo[900]!, Colors.indigo[500]!],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_graph_rounded, size: 100, color: Colors.white),
            const SizedBox(height: 24),
            const Text(
              'FocusMate',
              style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5),
            ),
            const Text(
              'Achieve Deep Focus with AI',
              style: TextStyle(fontSize: 18, color: Colors.white70),
            ),
            const SizedBox(height: 60),
            if (_isLoading)
              const CircularProgressIndicator(color: Colors.white)
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: ElevatedButton.icon(
                  onPressed: _signInWithGoogle,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Sign in with Google'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.indigo[900],
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const MainScreen())
              ),
              child: const Text('Continue without signing in', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'timer_screen.dart';

class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  @override
  NameScreenState createState() => NameScreenState();
}

class NameScreenState extends State<NameScreen> {
  final _nameController = TextEditingController();
  String? _errorMessage;

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorMessage = "Please enter your name";
      });
      return;
    }

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final response = await Supabase.instance.client
            .from('profiles')
            .upsert({
              'id': user.id,
              'name': name,
            })
            .select();

        if (response.isNotEmpty) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => TimerScreen()),
            );
          }
        } else {
          _showErrorDialog();
        }
      }
    } catch (e) {
      _showErrorDialog();
    }
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Failed to save the name"),
        content: const Text("Would you like to try again or continue without a name?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(), // Try Again → Closes dialog
            child: const Text("Try Again"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => TimerScreen()), // Continue without name
              );
            },
            child: const Text("Skip"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("How should we call you?"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveName,
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}
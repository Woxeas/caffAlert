import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'timer_screen.dart'; // Importujte hlavní obrazovku (TimerScreen nebo MainScreen)

class NameScreen extends StatefulWidget {
  @override
  _NameScreenState createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final _nameController = TextEditingController();
  String? _errorMessage;

  Future<void> _saveName() async {
    final name = _nameController.text.trim(); // Trim na odstranění bílých znaků
    if (name.isEmpty) {
      setState(() {
        _errorMessage = "Please enter your name";
      });
      return;
    }

    try {
      // Získání aktuálního uživatele
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Uložení jména do databáze
        final response = await Supabase.instance.client
            .from('profiles')
            .upsert({
              'id': user.id, // ID uživatele
              'name': name,  // Jméno uživatele
            })
            .select();

        if (response != null && response.isNotEmpty) {
          // Úspěšné uložení - přesměrování na hlavní obrazovku (TimerScreen)
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => TimerScreen()), // Změna na vaši hlavní obrazovku
            );
          }
        } else {
          setState(() {
            _errorMessage = "Failed to save the name. Please try again.";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "An error occurred. Please try again.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("How should we call you?"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Your Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red),
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveName,
              child: Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}

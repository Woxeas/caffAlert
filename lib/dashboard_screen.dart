import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'coffee_stats_provider.dart';

class DashboardScreen extends StatelessWidget {
  // Funkce pro načtení uživatelského jména ze Supabase
  Future<String> _getUserName() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final response = await Supabase.instance.client
          .from('profiles') // Název tabulky s profily
          .select('name')
          .eq('id', user.id)
          .maybeSingle();
      
      if (response != null && response['name'] != null) {
        return response['name'];
      }
    }
    return 'User';
  }

  // Funkce pro zobrazení dialogu a úpravu dnešních údajů
  void _showEditDialog(BuildContext context, CoffeeStatsProvider coffeeStats) {
    final TextEditingController _controller = TextEditingController(
      text: coffeeStats.dailyCoffees.toString(),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Update Today’s Coffee Count'),
          content: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Enter new count',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final int? newCount = int.tryParse(_controller.text);
                if (newCount != null) {
                  coffeeStats.setDailyCount(newCount); // Nastavení nového počtu káv
                }
                Navigator.of(context).pop();
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final coffeeStats = Provider.of<CoffeeStatsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<String>(
              future: _getUserName(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text("Error loading name");
                } else {
                  return Text(
                    'Welcome, ${snapshot.data}!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  );
                }
              },
            ),
            SizedBox(height: 20),
            Text(
              'Coffee Statistics',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text('Coffees Today: ${coffeeStats.dailyCoffees}', style: TextStyle(fontSize: 18)),
            Text('Coffees This Month: ${coffeeStats.monthlyCoffees}', style: TextStyle(fontSize: 18)),
            Text('Total Coffees: ${coffeeStats.totalCoffees}', style: TextStyle(fontSize: 18)),
            SizedBox(height: 40),
            Text(
              'Coffee Log:',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: coffeeStats.coffeeLog.length,
                itemBuilder: (context, index) {
                  String dateTime = coffeeStats.coffeeLog[index];
                  return ListTile(
                    title: Text('Coffee at ${DateTime.parse(dateTime)}'),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () => _showEditDialog(context, coffeeStats),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(300, 50),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  'Update Today’s Coffee Count',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

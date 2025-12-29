//Run "flutter pub get" in the TERMINAL to install all the dependencies
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

String firebaseUrl = "https://clipboard-5c0bc-default-rtdb.asia-southeast1.firebasedatabase.app/clipboard.json";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(CbSync());
}

class CbSync extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: CbSyncPage(),
    );
  }
}

class CbSyncPage extends StatefulWidget {
  @override
  State<CbSyncPage> createState() => CbSyncPageState();
}

class CbSyncPageState extends State<CbSyncPage> {
  List<Map<String, String>> cbHistory = [];
  List<Map<String, String>> pin = [];
  Timer? cbTimer;
  Timer? cloudTimer;
  String lastCbText = "";

  @override
  void initState() {
    super.initState();
    cbTimer = Timer.periodic(const Duration(seconds: 1), (timer) => checkLocal());
    cloudTimer = Timer.periodic(const Duration(seconds: 4), (timer) => fetchCloud());
  }

  Future<void> fetchCloud() async {
    try {
      final res = await http.get(Uri.parse(firebaseUrl));
      if (res.statusCode == 200 && res.body != "null") {
        final data = json.decode(res.body);
        String cloudText = data['text'] ?? "";
        if (cloudText.isNotEmpty && cloudText != lastCbText) {
          setState(() {
            lastCbText = cloudText;
            addCbEntry(cloudText);
          });
          Clipboard.setData(ClipboardData(text: cloudText));
        }
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
    }
  }

  Future<void> checkLocal() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      String currentText = data.text!.trim();
      if (currentText.isNotEmpty && currentText != lastCbText) {
        lastCbText = currentText;
        addCbEntry(currentText);
        try {
          await http.put(
            Uri.parse(firebaseUrl), 
            body: json.encode({"text": currentText})
          );
        } catch (e) {
          debugPrint("Push Error: $e");
        }
      }
    }
  }

  void addCbEntry(String text) {
    String timestamp = DateFormat('jm').format(DateTime.now());
    setState(() {
      cbHistory.insert(0, {"text": text, "time": timestamp});
      if (cbHistory.length > 50) cbHistory.removeLast(); 
    });
  }

  void delhist() async {
    Clipboard.setData(ClipboardData(text: ""));
    try {
      await http.put(
        Uri.parse(firebaseUrl), 
        body: json.encode({"text": ""})
      );
    } catch (e) {
      debugPrint("Clear Cloud Error: $e");
    }
    setState(() {
      cbHistory.clear();
      lastCbText = "";
    });
  }

  @override
  void dispose() {
    cbTimer?.cancel();
    cloudTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("CLIPBOARD APP"),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: () { 
              fetchCloud(); 
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("History (Max 50 Items):", 
                  style: TextStyle(color: Colors.blue[600], fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: delhist, 
                  child: Text("Delete All", style: TextStyle(color: Colors.red[600]))
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              flex: 2, 
              child: ListView.builder(
                itemCount: cbHistory.length, 
                itemBuilder: (context, index) => buildCbItem(index, true)
              )
            ),
            const Divider(color: Colors.white24, height: 30),
            const Text("Pinned:", 
              style: TextStyle(color: Colors.blue, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              flex: 1, 
              child: ListView.builder(
                itemCount: pin.length, 
                itemBuilder: (context, index) => buildCbItem(index, false)
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCbItem(int index, bool isHistory) {
    var item = isHistory ? cbHistory[index] : pin[index];
    return Card(
      color: Colors.grey[900],
      child: ListTile(
        title: Text(item["text"]!, style: const TextStyle(color: Colors.white)),
        subtitle: Text(item["time"]!, style: const TextStyle(color: Colors.blueGrey, fontSize: 11)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.copy, color: Colors.blue, size: 18), 
              onPressed: () => Clipboard.setData(ClipboardData(text: item["text"]!))
            ),
            IconButton(
              icon: Icon(isHistory ? Icons.push_pin_outlined : Icons.pin_drop, color: Colors.blue, size: 18),
              onPressed: () => setState(() { 
                if (isHistory) 
                {
                  pin.add(item);
                } 
                else 
                {
                  pin.removeAt(index);
                }
              }),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), 
              onPressed: () => setState(() => isHistory ? cbHistory.removeAt(index) : pin.removeAt(index))
            ),
          ],
        ),
      ),
    );
  }
}
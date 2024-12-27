import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
 	String dropdownValue = 'RANDOM';
	String colorOnValue = 'RED';
	String colorOffValue = 'OFF';
  final TextEditingController timeOnController = TextEditingController();
  final TextEditingController timeOffController = TextEditingController();

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

	void _stop() {
		final value1 = timeOnController.text;
		final value2 = timeOffController.text;
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text(
						'Dropdown: $dropdownValue, Value1: $value1, Value2: $value2'),
			),
		);
	}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Dropdown
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Mode:',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: dropdownValue,
                  onChanged: (String? newValue) {
                    setState(() {
                      dropdownValue = newValue!;
                    });
                  },
                  items: <String>['RANDOM', 'FREQUENTLY']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ],
            ),
						Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text(
												'Color On',
												style: TextStyle(fontSize: 16),
											),
											const SizedBox(height: 8),
											DropdownButton<String>(
												value: colorOnValue,
												onChanged: (String? newValue) {
													setState(() {
														colorOnValue = newValue!;
													});
												},
												items: <String>['RED', 'WHITE', 'YELLOW', 'BLUE']
														.map<DropdownMenuItem<String>>((String value) {
													return DropdownMenuItem<String>(
														value: value,
														child: Text(value),
													);
												}).toList(),
											),
										],
                  ),
                ),
                const SizedBox(width: 16), // Space between two fields
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text(
												'Color Off',
												style: TextStyle(fontSize: 16),
											),
											const SizedBox(height: 8),
											DropdownButton<String>(
												value: colorOffValue,
												onChanged: (String? newValue) {
													setState(() {
														colorOffValue = newValue!;
													});
												},
												items: <String>['RED', 'WHITE', 'YELLOW', 'BLUE', 'OFF']
														.map<DropdownMenuItem<String>>((String value) {
													return DropdownMenuItem<String>(
														value: value,
														child: Text(value),
													);
												}).toList(),
											),
										],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Row with Two Text Fields
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Time Off',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: timeOnController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '100ms',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16), // Space between two fields
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Time On',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: timeOffController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'ms',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
						Row(
							mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
									onPressed: _stop,
									child: const Text('Stop'),
								),
                const SizedBox(width: 26), // Space between two fields
                ElevatedButton(
									onPressed: () {
										final value1 = timeOnController.text;
										final value2 = timeOffController.text;
										ScaffoldMessenger.of(context).showSnackBar(
											SnackBar(
												content: Text(
														'Dropdown: $dropdownValue, Value1: $value1, Value2: $value2'),
											),
										);
									},
									child: const Text('Setup'),
								),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

enum OP { UP, DOWN, STOP, LOCK }
void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remote Controller',
      home: Controller(),
    );
  }
}

class Controller extends StatefulWidget {
  @override
  _ControllerState createState() => _ControllerState();
}

class _ControllerState extends State<Controller> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Remote Controller'),
        actions: [
          IconButton(
              icon: Icon(Icons.admin_panel_settings),
              onPressed: _enterAdminPage),
        ],
      ),
      body: Center(
        child: _buildGrid(),
      ),
    );
  }

  Widget _buildGrid() {
    return Expanded(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
          child: IntrinsicWidth(
              child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buttonBuilder(OP.UP, Icons.arrow_upward),
          _buttonBuilder(OP.DOWN, Icons.arrow_downward)
        ],
      ))),
      Expanded(
          child: IntrinsicWidth(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
            _buttonBuilder(OP.STOP, Icons.stop),
            _buttonBuilder(OP.LOCK, Icons.lock)
          ])))
    ]));
  }

  Widget _buttonBuilder(OP op, IconData icon) {
    return Expanded(
        child: IconButton(
      onPressed: () => onPressed(op),
      icon: Icon(icon),
      iconSize: 120,
    ));
  }

  void onPressed(OP op) {}

  void _enterAdminPage() {}
}

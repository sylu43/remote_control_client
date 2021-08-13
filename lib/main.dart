import 'dart:convert';
//import 'dart:html';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

//enum OP { UP, DOWN, STOP, LOCK }
void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Provider<KeyCheck>(
        create: (context) => KeyCheck(),
        child: MaterialApp(title: "controller", home: Controller()));
  }
}

class KeyCheck extends StatefulWidget {
  @override
  _KeyCheckState createState() => _KeyCheckState();
  //void dispose() {}
}

class _KeyCheckState extends State<KeyCheck> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Checking key...'),
      ),
    );
  }
}

class Controller extends StatefulWidget {
  @override
  _ControllerState createState() => _ControllerState();
}

class _ControllerState extends State<Controller> {
  final ip = '218.161.107.174';
  final port = '5000';
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
          _buttonBuilder('up', Icons.arrow_upward),
          _buttonBuilder('down', Icons.arrow_downward)
        ],
      ))),
      Expanded(
          child: IntrinsicWidth(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
            _buttonBuilder('stop', Icons.stop),
            _buttonBuilder('lock', Icons.lock)
          ])))
    ]));
  }

  Widget _buttonBuilder(String op, IconData icon) {
    return Expanded(
        child: IconButton(
      onPressed: () => onPressed(op),
      icon: Icon(icon),
      iconSize: 120,
    ));
  }

  void onPressed(String op) {
    sendGateOp(op);
  }

  void _enterAdminPage() {}

  Future<http.Response> sendGateOp(String op) {
    return http.post(
      Uri.http(ip + ':' + port, '/gate_op'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'op': op,
      }),
    );
  }
}

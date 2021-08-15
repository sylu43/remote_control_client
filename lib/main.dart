import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() => runApp(MaterialApp(home: Controller()));

class Controller extends StatefulWidget {
  @override
  _ControllerState createState() => _ControllerState();
}

class _ControllerState extends State<Controller> {
  final ip = '218.161.107.174';
  final port = '5000';
  final _storage = FlutterSecureStorage();
  var hasKey;
  var _username;
  var _otp;

  @override
  void initState() {
    super.initState();
    _hasKey();
  }

  Future<Null> _hasKey() async {
    final result = await _storage.containsKey(key: "token") &&
        await _storage.containsKey(key: "secret");
    setState(() {
      hasKey = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('Remote Controller'),
          actions: (hasKey)
              ? [
                  IconButton(
                      icon: Icon(Icons.admin_panel_settings),
                      onPressed: _enterAdminPage)
                ]
              : []),
      body: Center(
        child: (hasKey) ? _buildGrid() : _buildLogin(),
      ),
    );
  }

  Widget _buildLogin() {
    return Form(
      child: Column(
        children: [
          TextFormField(
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
                labelText: "Your username:", filled: true),
            onChanged: (value) {
              _username = value;
            },
          ),
          TextFormField(
            decoration: const InputDecoration(
                labelText: "OTP from admin:", filled: true),
            onChanged: (value) {
              _otp = value;
            },
          ),
          TextButton(onPressed: verify, child: const Text("Verify"))
        ],
      ),
    );
  }

  void verify() {}

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
      onPressed: () => gateAction(op),
      icon: Icon(icon),
      iconSize: 120,
    ));
  }

  void gateAction(String op) {
    sendHTTPRequest('/gate_op', jsonEncode(<String, String>{'op': op}));
  }

  void _enterAdminPage() {}

  Future<http.Response?> sendHTTPRequest(String path, String body) async {
    try {
      return await http.post(Uri.http(ip + ':' + port, path),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: body);
    } on SocketException {
      Fluttertoast.showToast(msg: "Connection Error");
      return null;
    }
  }
}

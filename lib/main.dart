import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';

void main() => runApp(MaterialApp(home: Controller()));

class Controller extends StatefulWidget {
  @override
  _ControllerState createState() => _ControllerState();
}

class _ControllerState extends State<Controller> {
  final ip = '218.161.107.174';
  final port = '5000';
  final _storage = FlutterSecureStorage();
  var _username;
  var _otp;
  var _token;
  var _secret;

  @override
  void initState() {
    super.initState();
  }

  Future<bool> _hasKey() async {
    //await _storage.deleteAll();
    return (await _storage.containsKey(key: "token") &&
        await _storage.containsKey(key: "secret"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Remote Controller'), actions: [
        FutureBuilder<bool>(
          future: _hasKey(),
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return (snapshot.data)
                  ? IconButton(
                      onPressed: _enterAdminPage,
                      icon: Icon(Icons.admin_panel_settings))
                  : Icon(Icons.admin_panel_settings);
            } else {
              return CircularProgressIndicator();
            }
          },
        )
      ]),
      body: Center(
        child: FutureBuilder<bool>(
          future: _hasKey(),
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return (snapshot.data) ? _buildGrid() : _buildLogin();
            } else {
              return CircularProgressIndicator();
            }
          },
        ),
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

  void verify() async {
    final r =
        await sendHTTPRequest("/checkin", jsonEncode({"name": _username}));
    try {
      //decode data with otp
      final checkinJWT =
          verifyJwtHS256Signature(jsonDecode(r!.body)['data'], _otp);
      _token = checkinJWT.toJson()['token'];
      _secret = checkinJWT.toJson()['secret'];

      //decode token
      final dataJWT = verifyJwtHS256Signature(_token, _secret);
      if (_username == dataJWT.toJson()['sub']) {
        _storage.write(key: "token", value: _token);
        _storage.write(key: "secret", value: _secret);
        setState(() {});
      }
    } on JwtException {
      Fluttertoast.showToast(msg: "invalid OTP");
    }
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

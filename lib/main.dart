import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:intl/intl.dart';
import 'package:datetime_picker_formfield/datetime_picker_formfield.dart';

void main() => runApp(MaterialApp(home: Controller()));

class Controller extends StatefulWidget {
  @override
  _ControllerState createState() => _ControllerState();
}

enum METHOD { GET, POST }

class _ControllerState extends State<Controller> {
  final ip = '218.161.107.174';
  final port = '5000';
  final _storage = FlutterSecureStorage();
  var _username;
  var _otp;
  var _token;
  var _secret;

  Future<bool> _hasKey() async {
    //await _storage.deleteAll();
    _token = await _storage.read(key: "token");
    _secret = await _storage.read(key: "secret");
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
    final r = await sendHTTPRequest(
        "/checkin", jsonEncode({"name": _username}), METHOD.POST);
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
        _storage.write(key: "username", value: _username);
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
    sendHTTPRequest(
        '/gate_op', jsonEncode(<String, String>{'op': op}), METHOD.POST);
  }

  void _enterAdminPage() async {
    _username = await _storage.read(key: "username");
    final response = await sendHTTPRequest(
        "/list", jsonEncode(<String, String>{}), METHOD.GET);
    if (response != null) {
      if (response.statusCode == 200) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => AdminPage(
                    username: _username,
                    token: _token,
                    secret: _secret,
                    data: response,
                    sendHTTPRequest: sendHTTPRequest)));
      } else {
        Fluttertoast.showToast(msg: "You shall not pass");
      }
    }
  }

  Future<http.Response?> sendHTTPRequest(
      String path, String body, METHOD method) async {
    final nonce = DateTime.now().microsecondsSinceEpoch.toString();
    var hs256 = (_secret != null) ? Hmac(sha256, hex.decode(_secret)) : null;
    final signature = (_secret != null)
        ? hs256!.convert(utf8.encode("$path$nonce$body"))
        : null; //hex string
    final header = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'nonce': nonce,
      'token': (_token != null) ? (_token) : '',
      'signature': (_secret != null) ? "$signature" : ''
    };
    try {
      if (method == METHOD.POST) {
        return await http.post(Uri.http(ip + ':' + port, path),
            headers: header, body: body);
      } else if (method == METHOD.GET) {
        return await http.get(Uri.http(ip + ':' + port, path), headers: header);
      }
    } on SocketException {
      Fluttertoast.showToast(msg: "Connection Error");
      return null;
    }
  }
}

class AdminPage extends StatefulWidget {
  final username;
  final token;
  final secret;
  final data;
  final Function sendHTTPRequest;
  const AdminPage(
      {Key? key,
      required this.username,
      required this.token,
      required this.secret,
      required this.data,
      required this.sendHTTPRequest})
      : super(key: key);
  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List<Widget> userList = [];
  var data;
  @override
  Widget build(BuildContext context) {
    if (data == null) {
      data = widget.data;
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Page"),
        actions: [IconButton(onPressed: addUser, icon: Icon(Icons.add))],
      ),
      body: _buildUserList(),
    );
  }

  void addUser() async {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => AddUserPage(
                sendHTTPRequest: widget.sendHTTPRequest,
                refreshList: refreshList)));
  }

  void refreshList() async {
    data = await widget.sendHTTPRequest(
        "/list", jsonEncode(<String, String>{}), METHOD.GET);
    userList = [];
    setState(() {});
  }

  Widget _buildUserList() {
    final body = json.decode(data.body);
    for (var user in body['users']) {
      userList.add(Card(
        child: ListTile(
          title: Text(user['name']),
          subtitle: Text(
            user['zone'] +
                "\n" +
                DateFormat.yMd().add_Hm().format(
                    DateTime.fromMillisecondsSinceEpoch(
                            (user['expireDate'].round() * 1000),
                            isUtc: true)
                        .toLocal()),
          ),
          trailing: (user['name'] == widget.username)
              ? null
              : IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => deleteUser(user['name'])),
        ),
      ));
    }
    return ListView(children: userList);
  }

  void deleteUser(String name) async {
    await widget.sendHTTPRequest(
        "/delete", jsonEncode({"name": name}), METHOD.POST);
    refreshList();
  }
}

class AddUserPage extends StatefulWidget {
  final Function sendHTTPRequest;
  final Function refreshList;
  const AddUserPage(
      {Key? key, required this.sendHTTPRequest, required this.refreshList})
      : super(key: key);

  @override
  _AddUserPageState createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  var name;
  var zone;
  var expDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("Add User")),
        body: Form(
          child: Column(
            children: [
              TextFormField(
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                    labelText: "Username to add:", filled: true),
                onChanged: (value) {
                  name = value;
                },
              ),
              TextFormField(
                decoration:
                    const InputDecoration(labelText: "Zone:", filled: true),
                onChanged: (value) {
                  zone = value;
                },
              ),
              DateTimeField(
                  format: DateFormat("yyyy/MM/dd"),
                  decoration: const InputDecoration(
                      labelText: "Expire Date", filled: true),
                  onShowPicker: (context, currentValue) {
                    return showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        initialDate: currentValue ?? DateTime.now(),
                        lastDate: DateTime(2100));
                  },
                  onChanged: (value) {
                    expDate = value!.microsecondsSinceEpoch / 1000000;
                  }),
              TextButton(onPressed: register, child: const Text("Register"))
            ],
          ),
        ));
  }

  void register() async {
    await widget.sendHTTPRequest(
        "/register",
        jsonEncode({
          "name": name,
          "zone": zone,
          "time": expDate + Duration.secondsPerDay - 1
        }),
        METHOD.POST);
    widget.refreshList();
    Navigator.pop(context);
  }
}

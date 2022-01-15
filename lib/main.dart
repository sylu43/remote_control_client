import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  var _token;

  Future<bool> _hasKey() async {
    //await _storage.deleteAll();
    _token = await _storage.read(key: "token");
    _username = await _storage.read(key: "username");
    return (await _storage.containsKey(key: "token") &&
        await _storage.containsKey(key: "username"));
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
              _username = value.replaceAll(' ', '');
            },
          ),
          TextButton(onPressed: apply, child: const Text("Apply"))
        ],
      ),
    );
  }

  void apply() async {
    final r = await sendHTTPRequest(
        "/register",
        jsonEncode({
          "name": _username,
          "zone": "test",
        }),
        METHOD.POST);
    //decode data with otp
    _token = json.decode(r!.body)['token'];

    //decode token
    await _storage.write(key: "username", value: _username);
    await _storage.write(key: "token", value: _token);
    Fluttertoast.showToast(msg: "$_token");
    setState(() {});
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
    sendHTTPRequest('/gate_op',
        jsonEncode(<String, String>{'name': _username, 'op': op}), METHOD.POST);
  }

  void _enterAdminPage() async {
    final response = await sendHTTPRequest(
        "/list", jsonEncode(<String, String>{'name': _username}), METHOD.POST);
    if (response != null) {
      if (response.statusCode == 200) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => AdminPage(
                    username: _username,
                    token: _token,
                    data: response,
                    sendHTTPRequest: sendHTTPRequest)));
      } else {
        Fluttertoast.showToast(msg: "You shall not pass");
      }
    }
  }

  Future<http.Response?> sendHTTPRequest(
      String path, String body, METHOD method) async {
    final nonce = (DateTime.now().microsecondsSinceEpoch / 1000000).toString();
    var signature = '';
    if (_token != null) {
      final _secret = _token;
      List<int> secretBytes = utf8.encode(_secret);
      List<int> sigBytes = utf8.encode("$path$nonce$body");
      var sha = new Hmac(sha256, secretBytes);
      signature = sha.convert(sigBytes).toString();
      Fluttertoast.showToast(msg: "token?");
    } else {
      Fluttertoast.showToast(msg: "no token");
    }
    final header = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'nonce': nonce,
      'signature': (_token != null) ? "$signature" : ''
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
  final data;
  final Function sendHTTPRequest;
  const AdminPage(
      {Key? key,
      required this.username,
      required this.token,
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
      appBar: AppBar(title: const Text("Admin Page")),
      body: _buildUserList(),
    );
  }

  void editUser(String name, String zone, int activated, double expDate) async {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => EditUserPage(
                username: widget.username,
                name: name,
                zone: zone,
                activated: activated,
                expDate: expDate,
                sendHTTPRequest: widget.sendHTTPRequest,
                refreshList: refreshList)));
    setState(() {});
  }

  void refreshList() async {
    data = await widget.sendHTTPRequest("/list",
        jsonEncode(<String, String>{"name": widget.username}), METHOD.POST);
    userList = [];
    setState(() {});
  }

  Widget _buildUserList() {
    setState(() {});
    final body = json.decode(data.body);
    for (var user in body['users']) {
      userList.add(GestureDetector(
          onTap: () => editUser(
              user['name'], user['zone'], user['activated'], user['expDate']),
          child: Card(
            child: ListTile(
              title: Text(user['name']),
              subtitle: Text(
                user['zone'] +
                    "\n" +
                    DateFormat.yMd().add_Hm().format(
                        DateTime.fromMicrosecondsSinceEpoch(
                                (user['expDate'].round() * 1000000),
                                isUtc: true)
                            .toLocal()),
              ),
              trailing: Icon((user['activated'] == -1)
                  ? Icons.priority_high
                  : (user['activated'] == 0)
                      ? Icons.close
                      : Icons.done),
            ),
          )));
    }
    return ListView(children: userList);
  }

  void deleteUser(String name) async {
    await widget.sendHTTPRequest("/delete",
        jsonEncode({"name": widget.username, "guest": name}), METHOD.POST);
    refreshList();
  }
}

class EditUserPage extends StatefulWidget {
  final username;
  final name;
  final zone;
  final activated;
  final expDate;
  final Function sendHTTPRequest;
  final Function refreshList;
  const EditUserPage(
      {Key? key,
      required this.username,
      required this.name,
      required this.zone,
      required this.activated,
      required this.expDate,
      required this.sendHTTPRequest,
      required this.refreshList})
      : super(key: key);

  @override
  _EditUserPageState createState() => _EditUserPageState();
}

class _EditUserPageState extends State<EditUserPage> {
  var zone;
  var activated;
  var expDate;

  @override
  Widget build(BuildContext context) {
    zone = (zone == null) ? widget.zone : zone;
    activated = (activated == null) ? widget.activated : activated;
    expDate = (expDate == null) ? widget.expDate : expDate;
    return Scaffold(
        appBar: AppBar(
          title: Text("Edit User"),
          actions: [
            Switch(
                value: (activated == 1) ? true : false,
                activeColor: Colors.red,
                onChanged: (value) {
                  setState(() {
                    activated = (value == true) ? 1 : 0;
                  });
                })
          ],
        ),
        body: Form(
          child: Column(
            children: [
              TextFormField(
                textInputAction: TextInputAction.next,
                decoration:
                    const InputDecoration(labelText: "Username:", filled: true),
                enabled: false,
                initialValue: widget.name,
              ),
              TextFormField(
                decoration:
                    const InputDecoration(labelText: "Zone:", filled: true),
                onChanged: (value) {
                  zone = value;
                },
                initialValue: widget.zone,
              ),
              DateTimeField(
                format: DateFormat("yyyy/MM/dd"),
                decoration: const InputDecoration(
                    labelText: "Expire Date:", filled: true),
                onShowPicker: (context, currentValue) {
                  return showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      initialDate: currentValue ?? DateTime.now(),
                      lastDate: DateTime(2100));
                },
                resetIcon: null,
                onChanged: (value) {
                  if (value != null) {
                    if (value.microsecondsSinceEpoch >
                        DateTime.now().microsecondsSinceEpoch) {
                      expDate = value.microsecondsSinceEpoch / 1000000;
                    }
                  }
                },
                initialValue: (DateTime.now().microsecondsSinceEpoch >
                        widget.expDate.round() * 1000000)
                    ? DateTime.now()
                    : DateTime.fromMicrosecondsSinceEpoch(
                        widget.expDate.round() * 1000000),
              ),
              TextButton(onPressed: save, child: const Text("Save changes"))
            ],
          ),
        ));
  }

  void save() async {
    await widget.sendHTTPRequest(
        "/update",
        jsonEncode({
          "name": widget.username,
          "guest": {
            "name": widget.name,
            "zone": zone,
            "activated": activated,
            "expDate": expDate
          }
        }),
        METHOD.POST);
    super.widget.refreshList();
    Navigator.pop(context);
  }
}

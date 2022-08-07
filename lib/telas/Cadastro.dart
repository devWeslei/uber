import 'package:flutter/material.dart';
import '../model/Usuario.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Cadastro extends StatefulWidget {
  const Cadastro({Key? key}) : super(key: key);

  @override
  State<Cadastro> createState() => _CadastroState();
}

class _CadastroState extends State<Cadastro> {
  TextEditingController _controllerNome = TextEditingController();
  TextEditingController _controllerEmail = TextEditingController();
  TextEditingController _controllerSenha = TextEditingController();
  bool _tipoUsuario = false;
  String _mensagemErro = "";

  _validarCampos() {
    //recuperar dados dos campos
    String nome = _controllerNome.text;
    String email = _controllerEmail.text;
    String senha = _controllerSenha.text;

    //validar campos
    if (nome.isNotEmpty) {
      if (email.isNotEmpty && email.contains("@")) {
        if (senha.isNotEmpty && senha.length > 6) {
          Usuario usuario = Usuario();
          usuario.nome = nome;
          usuario.email = email;
          usuario.senha = senha;
          usuario.tipoUsuario = usuario.verificaTipoUsuario(_tipoUsuario);

          _cadastrarUsuario(usuario);
        } else {
          setState(() {
            _mensagemErro = "Preencha senha! digite mais de 6 caracteres";
          });
        }
      } else {
        setState(() {
          _mensagemErro = "Preencha um Email válido";
        });
      }
    } else {
      setState(() {
        _mensagemErro = "Preencha o Nome";
      });
    }
  }

  _cadastrarUsuario(Usuario usuario) {
    FirebaseAuth auth = FirebaseAuth.instance;
    FirebaseFirestore db = FirebaseFirestore.instance;

    auth
        .createUserWithEmailAndPassword(
      email: usuario.email!,
      password: usuario.senha!,
    )
        .then((firebaseUser) {
      db
          .collection("usuarios")
          .doc(firebaseUser.user?.uid)
          .set(usuario.toMap());

      //redireciona para o painel, de acordo com o tipoUsuario
      switch (usuario.tipoUsuario) {
        case "motorista":
          Navigator.pushNamedAndRemoveUntil(
              context, "/painel-motorista", (_) => false);
          break;
        case "passageiro":
          Navigator.pushNamedAndRemoveUntil(
              context, "/painel-passageiro", (_) => false);
          break;
      }
    }).catchError((error) {
      _mensagemErro =
          "Erro ao autenticar o usuário, verifique os campos e tente novamente!";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Cadastro"),
      ),
      body: Container(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _controllerNome,
                  autofocus: true,
                  keyboardType: TextInputType.text,
                  style: TextStyle(fontSize: 20),
                  decoration: InputDecoration(
                      contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                      hintText: "Nome completo",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      )),
                ),
                TextField(
                  controller: _controllerEmail,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(fontSize: 20),
                  decoration: InputDecoration(
                      contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                      hintText: "e-mail",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      )),
                ),
                TextField(
                  controller: _controllerSenha,
                  obscureText: true,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(fontSize: 20),
                  decoration: InputDecoration(
                      contentPadding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                      hintText: "senha",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      )),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Text("Passageiro"),
                      Switch(
                          value: _tipoUsuario,
                          onChanged: (bool valor) {
                            setState(() {
                              _tipoUsuario = valor;
                            });
                          }),
                      Text("Motorista"),
                    ],
                  ),
                ),
                Padding(
                    padding: EdgeInsets.only(top: 16, bottom: 10),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          primary: Color(0xff1ebbd8),
                          padding: EdgeInsets.fromLTRB(32, 16, 32, 16)),
                      onPressed: () {
                        _validarCampos();
                      },
                      child: Text(
                        "Cadastrar",
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                    )),
                Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(
                    child: Text(
                      _mensagemErro,
                      style: TextStyle(color: Colors.red, fontSize: 20),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

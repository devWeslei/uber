import 'package:flutter/material.dart';
import '../model/Usuario.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  TextEditingController _controllerEmail = TextEditingController(text: "weslei@gmail.com");
  TextEditingController _controllerSenha = TextEditingController(text: "1234567");
  String _mensagemErro = "";
  bool _carregando = false;

  _validarCampos() {
    _mensagemErro = "";
    //recuperar dados dos campos
    String email = _controllerEmail.text;
    String senha = _controllerSenha.text;

    //validar campos
    if (email.isNotEmpty && email.contains("@")) {
      if (senha.isNotEmpty && senha.length > 6) {
        Usuario usuario = Usuario();
        usuario.email = email;
        usuario.senha = senha;

        _logarUsuario(usuario);
      } else {
        setState(() {
          _mensagemErro = "Preencha senha! digite mais que 6 caracteres";
        });
      }
    } else {
      setState(() {
        _mensagemErro = "Preencha um Email válido";
      });
    }
  }

  _logarUsuario(Usuario usuario) {

    setState(() {
      _carregando = true;
    });

    FirebaseAuth auth = FirebaseAuth.instance;

    auth
        .signInWithEmailAndPassword(
          email: usuario.email!,
          password: usuario.senha!
        )
        .then((firebaseUser) {
      _redirecionaPainelPorTipoUsuario( firebaseUser.user!.uid );
       })
        .catchError((error) {

          setState(() {
            _carregando = false;
            _mensagemErro =
            "Erro ao autenticar o usuário, verifique e-mail e senha e tente novamente!";
          });

    });
  }

  _redirecionaPainelPorTipoUsuario(String idUsuario) async {

    FirebaseFirestore db = FirebaseFirestore.instance;

    DocumentSnapshot snapshot = await db.collection("usuarios")
    .doc( idUsuario)
    .get();

    dynamic dados = snapshot.data();

    String tipoUsuario = dados["tipoUsuario"];
    print("$dados");

    setState(() {
      _carregando = false;
    });

    switch( tipoUsuario ){
      case "motorista":
        Navigator.pushReplacementNamed(context, "/painel-motorista");
        break;
      case "passageiro":
        Navigator.pushReplacementNamed(context, "/painel-passageiro");
        break;

    }
  }

  _verificaUsuarioLogado() async {
    FirebaseAuth auth = FirebaseAuth.instance;

    User? usuarioLogado = await auth.currentUser;
    if( usuarioLogado != null){
      String idUsuario = usuarioLogado.uid;
      _redirecionaPainelPorTipoUsuario(idUsuario);
    }
  }

  @override
  void initState() {
    super.initState();
    _verificaUsuarioLogado();

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
            image: DecorationImage(
                image: AssetImage("imagens/fundo.png"), fit: BoxFit.cover)),
        padding: EdgeInsets.all(16),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 32),
                  child: Image.asset(
                    "imagens/logo.png",
                    width: 200,
                    height: 150,
                  ),
                ),
                TextField(
                  controller: _controllerEmail,
                  autofocus: true,
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
                    padding: EdgeInsets.only(top: 16, bottom: 10),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          primary: Color(0xff1ebbd8),
                          padding: EdgeInsets.fromLTRB(32, 16, 32, 16)),
                      onPressed: () {
                        _validarCampos();
                      },
                      child: Text(
                        "Entrar",
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                    )),
                Center(
                  child: GestureDetector(
                    child: Text(
                      "Não tem conta? cadastre-se!",
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pushNamed(context, "/cadastro");
                    },
                  ),
                ),
                _carregando
                    ? Padding(
                    padding:EdgeInsets.only(top: 16),
                    child: Center(
                      child: CircularProgressIndicator(backgroundColor: Colors.white ,),))
                    : Container(),
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

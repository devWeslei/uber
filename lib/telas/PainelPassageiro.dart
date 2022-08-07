import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PainelPassageiro extends StatefulWidget {
  const PainelPassageiro({Key? key}) : super(key: key);

  @override
  State<PainelPassageiro> createState() => _PainelPassageiroState();
}

class _PainelPassageiroState extends State<PainelPassageiro> {

  List<String> itensMenu = [
    "Configurações", "Deslogar"
  ];

  _deslogarUsuario() async {

    FirebaseAuth auth = FirebaseAuth.instance;

    await auth.signOut();
    Navigator.pushReplacementNamed(context, "/");

  }

  _escolhaMenuItem( String escolha ){

    switch ( escolha ){
      case "Deslogar" :
        _deslogarUsuario();
        break;
      case "Configurações" :

        break;
    }

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("painel passageiro"),
        actions: [
          PopupMenuButton<String>(
            onSelected: _escolhaMenuItem,
              itemBuilder: (context){
              return itensMenu.map((String item) {

                return PopupMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList();

              }
          )
        ],
      ),
      body: Container(),
    );
  }
}

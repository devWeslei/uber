import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uber/util/StatusRequisicao.dart';
import 'package:uber/util/UsuarioFirebase.dart';
import 'dart:io';

import '../model/Usuario.dart';

class Corrida extends StatefulWidget {

  final String idRequisicao;
  const Corrida(this.idRequisicao, {Key? key}) : super(key: key);

  @override
  State<Corrida> createState() => _CorridaState();
}

class _CorridaState extends State<Corrida> {

  Completer<GoogleMapController> _controller = Completer();
  Set<Marker> _marcadores = {};
  Map<String, dynamic>? _dadosRequisicao;
  CameraPosition _posicaoCamera = CameraPosition(target: LatLng(-23.42087200129373, -51.93719096900213),
    zoom: 18,);
  Position? _localMotorista;

  //Controles para exibição na tela
  String _textoBotao = "Aceitar corrida";
  Color _corBotao = Color(0xff1ebbd8);
  Function? _funcaoBotao;

  _alterarBotaoPrincipal(String texto, Color cor, Function funcao){
    setState(() {
      _textoBotao = texto;
      _corBotao = cor;
      _funcaoBotao = funcao;
    });
  }

  _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  _recuperarUltimaLocalizacaoConhecida() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      if (position != null) {

        _exibirMarcadoresPassageiro( position );

        _posicaoCamera = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 18,
        );

        _movimentarCamera(_posicaoCamera);
        _localMotorista = position;
      }
    });
  }

  _movimentarCamera(CameraPosition cameraPosition) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  _adicionarListenerLocalizacao() async {
    LocationPermission permission;
    await Geolocator.checkPermission();
    permission = await Geolocator.requestPermission();

    var locationSetings =
    LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);

    var geolocator =
    Geolocator.getPositionStream(locationSettings: locationSetings)
        .listen((Position position) {

      _exibirMarcadoresPassageiro( position );

      setState(() {
        _posicaoCamera = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 18,
        );
      });
      _movimentarCamera(_posicaoCamera);
      setState(() {
        _localMotorista = position;
      });
    });
  }
  _exibirMarcadoresPassageiro(Position local) async {

    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        "imagens/motorista.png"
    ).then((BitmapDescriptor icone){

      Marker marcadorPassageiro = Marker(
          markerId: MarkerId("marcador-motorista"),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: InfoWindow(
              title: "Meu local"
          ),
          icon: icone
      );

      setState(() {
        _marcadores.add(marcadorPassageiro);
      });

    });

  }

  _recuperarRequisicao() async {

    String idRequisicao = widget.idRequisicao;

    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentSnapshot documentSnapshot = await db
        .collection("requisicoes")
        .doc( idRequisicao )
        .get();

    _dadosRequisicao = documentSnapshot.data() as Map<String,dynamic>;
    _adicionarListenerRequisicao();

  }

  _adicionarListenerRequisicao() async {

    FirebaseFirestore db = FirebaseFirestore.instance;
    String idRequisicao = _dadosRequisicao?["id"];
    await db.collection("requisicoes")
    .doc( idRequisicao ).snapshots().listen((snapshot) {

      if( snapshot.data() != null ){

        Map<String,dynamic> dados = snapshot.data() as Map<String,dynamic>;
        String status = dados["status"];

        switch( status ){
          case StatusRequisicao.AGUARDANDO :
            _statusAguardando();
            break;
          case StatusRequisicao.A_CAMINHO :
            _statusACaminho();
            break;
          case StatusRequisicao.VIAGEM :

            break;
          case StatusRequisicao.FINALIZADA :

            break;

        }

      }

    });

  }

  _statusAguardando(){
    _alterarBotaoPrincipal(
        "Aceitar corrida",
        Color(0xff1ebbd8),
            (){
          _aceitarCorrida();
        }
    );
  }

  _statusACaminho(){
    _alterarBotaoPrincipal(
        "A caminho do passageiro",
        Colors.grey,
        (){},
    );
  }

  _aceitarCorrida() async {
    //Recuperar dados do motorista
    Usuario motorista   = await UsuarioFirebase.getDadosUsuarioLogado();
    motorista.latitude  = _localMotorista?.latitude;
    motorista.longitude = _localMotorista?.longitude;

    FirebaseFirestore db = FirebaseFirestore.instance;
    String idRequisicao = _dadosRequisicao?["id"];
    
    db.collection("requisicoes")
    .doc( idRequisicao )
    .update({
      "motorista" : motorista.toMap(),
      "status" : StatusRequisicao.A_CAMINHO,
    }).then((_){

      //atualiza requisicao ativa
      String? idPassageiro = _dadosRequisicao?["passageiro"]["idUsuario"];
      db.collection("requisicao_ativa")
        .doc( idPassageiro ).update({
        "status" : StatusRequisicao.A_CAMINHO,
      });

      //Salvar requisicao ativa para motorista
      String? idMotorista = motorista.idUsuario;
      db.collection("requisicao_ativa_motorista")
          .doc( idMotorista )
          .set({
        "id_requisicao" : idRequisicao,
        "id_usuario" : idMotorista,
        "status" : StatusRequisicao.A_CAMINHO,
      });
    });
  }

  @override
  void initState() {
    _recuperarUltimaLocalizacaoConhecida();
    _adicionarListenerLocalizacao();

    //Recuperar requisicao e
    //adicionar listener para mudança de status
    _recuperarRequisicao();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("painel corrida"),
      ),
      body: Container(
        child: Stack(
          children: [
            GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: _posicaoCamera,
              onMapCreated: _onMapCreated,
              //myLocationEnabled: true,
              myLocationButtonEnabled: false,
              markers: _marcadores,
            ),
            Positioned(
              right: 0,
              left: 0,
              bottom: 0,
              child: Padding(
                padding: Platform.isIOS
                    ? EdgeInsets.fromLTRB(20, 10, 20, 25)
                    : EdgeInsets.all(10),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      primary: _corBotao,
                      padding: EdgeInsets.fromLTRB(32, 16, 32, 16)),
                  onPressed:(){
                    _funcaoBotao!();
                  },
                  child: Text(
                    _textoBotao,
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

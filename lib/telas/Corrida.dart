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

  String idRequisicao;

  Corrida(this.idRequisicao, {Key? key}) : super(key: key);

  @override
  State<Corrida> createState() => _CorridaState();
}

class _CorridaState extends State<Corrida> {

  Completer<GoogleMapController> _controller = Completer();
  Set<Marker> _marcadores = {};
  Map<String, dynamic>? _dadosRequisicao;
  CameraPosition _posicaoCamera = CameraPosition(target: LatLng(-23.42087200129373, -51.93719096900213),
    zoom: 18,);
  String? _idRequisicao;
  Position? _localMotorista;
  String _statusRequisicao = StatusRequisicao.AGUARDANDO;


  //Controles para exibição na tela
  String _textoBotao = "Aceitar corrida";
  Color _corBotao = Color(0xff1ebbd8);
  Function? _funcaoBotao;
  String _mensagemStatus = "";

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

    if (position != null) {
      //Atualizar localização em tempo real do motorista
    }
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
        .listen((Position? position) {

          if(position != null) {

            if (_idRequisicao != null && _idRequisicao!.isNotEmpty) {

              if (_statusRequisicao != StatusRequisicao.AGUARDANDO) {
                //Atualiza local do passageiro
                UsuarioFirebase.atualizarDadosLocalizacao(
                    _idRequisicao!,
                    position.latitude,
                    position.longitude,
                    "motorista"
                );

              }else{//aguardando
                setState(() {
                  _localMotorista = position;
                });
                _statusAguardando();
              }
            }
          }
    });
  }

  _exibirMarcador(Position local, String icone, String infoWindow) async {

    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        icone
    ).then((BitmapDescriptor bitmapDescriptor){

      Marker marcador = Marker(
          markerId: MarkerId(icone),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: InfoWindow(
              title: infoWindow
          ),
          icon: bitmapDescriptor
      );

      setState(() {
        _marcadores.add(marcador);
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

  }

  _adicionarListenerRequisicao(){

    FirebaseFirestore db = FirebaseFirestore.instance;

    db.collection("requisicoes")
    .doc( _idRequisicao ).snapshots().listen((snapshot) {

      if( snapshot.data() != null ){

        _dadosRequisicao = snapshot.data()!;

        Map<String, dynamic>? dados = snapshot.data();
        _statusRequisicao = dados?["status"];

        switch( _statusRequisicao ){
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

  _statusAguardando() async {
    _alterarBotaoPrincipal(
        "Aceitar corrida",
        Color(0xff1ebbd8),
            (){
          _aceitarCorrida();
        }
    );

    if(_localMotorista != null) {

      double? motoristaLat = _localMotorista?.latitude;
      double? motoristaLon = _localMotorista?.longitude;
      // Position position = Position(
      //   latitude: motoristaLat ,longitude: motoristaLon, timestamp: null, accuracy: null, altitude: null, speed: null, heading: null, speedAccuracy: null,
      // );
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      _exibirMarcador( position,
          "imagens/motorista.png",
          "motorista"
      );

      //setState(() {
      CameraPosition cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 18,
      );
      // });
      _movimentarCamera(cameraPosition);

    }

  }

  _statusACaminho(){

    _mensagemStatus = "A caminho do passageiro";
    _alterarBotaoPrincipal(
        "Iniciar corrida",
        Color(0xff1ebbd8),
        (){
          _iniciarCorrida();
        },
    );

    double latitudePassageiro = _dadosRequisicao!["passageiro"]["latitude"];
    double longitudePassageiro = _dadosRequisicao!["passageiro"]["longitude"];

    double latitudeMotorista = _dadosRequisicao!["motorista"]["latitude"];
    double longitudeMotorista = _dadosRequisicao!["motorista"]["longitude"];

    _exibirDoisMArcadores(
      LatLng(latitudeMotorista, longitudeMotorista),
      LatLng(latitudePassageiro, longitudePassageiro),
    );

    //'southwest.latitude <= northeast.latitude' : is not true
    double? nLat, nLon, sLat, sLon;

    if(latitudeMotorista <= latitudePassageiro){
      sLat = latitudeMotorista;
      nLat = latitudePassageiro;
    }else{
      sLat = latitudePassageiro;
      nLat = latitudeMotorista;
    }

    if(longitudeMotorista <= longitudePassageiro){
      sLon = longitudeMotorista;
      nLon = longitudePassageiro;
    }else{
      sLon = longitudePassageiro;
      nLon = longitudeMotorista;
    }

    _movimentarCameraBounds(

      LatLngBounds(
        northeast: LatLng(nLat,nLon),
        southwest: LatLng(sLat,sLon),
      )
      
    );
  }

  _iniciarCorrida(){

    FirebaseFirestore db = FirebaseFirestore.instance;
    db.collection("requisicoes")
    .doc( _idRequisicao )
    .update({
      "origem" : {
        "latitude" : _dadosRequisicao!["motorista"]["latitude"],
        "longitude" : _dadosRequisicao!["motorista"]["longitude"],
      },
      "status" : StatusRequisicao.VIAGEM
    });

    String idPassageiro = _dadosRequisicao!["passageiro"]["idUsuario"];
    db.collection("requisicao_ativa")
    .doc( idPassageiro)
    .update({"status" : StatusRequisicao.VIAGEM});

    String idMotorista = _dadosRequisicao!["motorista"]["idUsuario"];
    db.collection("requisicao_ativa_motorista")
        .doc( idMotorista)
        .update({"status" : StatusRequisicao.VIAGEM});

  }

  _movimentarCameraBounds(LatLngBounds latLngBounds) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(
      CameraUpdate.newLatLngBounds(
          latLngBounds,
          100
      )
    );
  }

  _exibirDoisMArcadores(LatLng latLngMotorista, LatLng latLngPassageiro ){

    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    Set<Marker> _listaMarcadores = {};
    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        "imagens/motorista.png"
    ).then((BitmapDescriptor icone){

      Marker marcador1 = Marker(
          markerId: MarkerId("marcador-motorista"),
          position: LatLng(latLngMotorista.latitude, latLngMotorista.longitude),
          infoWindow: InfoWindow(
              title: "Local motorista"
          ),
          icon: icone
      );
      _listaMarcadores.add(marcador1);
    });

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        "imagens/passageiro.png"
    ).then((BitmapDescriptor icone){

      Marker marcador2 = Marker(
          markerId: MarkerId("marcador-passageiro"),
          position: LatLng(latLngPassageiro.latitude, latLngPassageiro.longitude),
          infoWindow: InfoWindow(
              title: "Local passageiro"
          ),
          icon: icone
      );
      _listaMarcadores.add(marcador2);
    });

    setState(() {
      _marcadores = _listaMarcadores;
    });

  }

  _aceitarCorrida() async {
    //Recuperar dados do motorista
    Usuario motorista   = await UsuarioFirebase.getDadosUsuarioLogado();
    motorista.latitude  = _localMotorista?.latitude;
    motorista.longitude = _localMotorista?.longitude;

    FirebaseFirestore db = FirebaseFirestore.instance;
    String idRequisicao = _dadosRequisicao!["id"];
    
    db.collection("requisicoes")
    .doc( idRequisicao )
    .update({
      "motorista" : motorista.toMap(),
      "status" : StatusRequisicao.A_CAMINHO,
    }).then((_){

      //atualiza requisicao ativa
      String? idPassageiro = _dadosRequisicao!["passageiro"]["idUsuario"];
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
    super.initState();

    _idRequisicao = widget.idRequisicao;

    //adicionar listener para mudanças na requisição
    _adicionarListenerRequisicao();

    //_recuperarUltimaLocalizacaoConhecida();
    _adicionarListenerLocalizacao();

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("painel corrida - $_mensagemStatus"),
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

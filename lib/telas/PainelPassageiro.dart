import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uber/model/Requisicao.dart';
import 'package:uber/util/UsuarioFirebase.dart';
import 'dart:io';
import '../model/Destino.dart';
import '../model/Marcador.dart';
import '../model/Usuario.dart';
import '../util/StatusRequisicao.dart';

class PainelPassageiro extends StatefulWidget {
  const PainelPassageiro({Key? key}) : super(key: key);

  @override
  State<PainelPassageiro> createState() => _PainelPassageiroState();
}

class _PainelPassageiroState extends State<PainelPassageiro> {

  TextEditingController _controllerDestino = TextEditingController(text: "av. tiradentes, 380 - Maringa PR");
  Completer<GoogleMapController> _controller = Completer();
  Set<Marker> _marcadores = {};
  String? _idRequisicao;
  Position? _localPassageiro;
  Map<String, dynamic>? _dadosRequisicao;
  StreamSubscription<DocumentSnapshot>? _streamSubscriptionRequisicoes;

  //Controles para exibição na tela
  bool _exibirCaixaEnderecoDestino = true;
  String _textoBotao = "Chamar uber";
  Color _corBotao = Color(0xff1ebbd8);
  Function? _funcaoBotao;

  CameraPosition _posicaoCamera = CameraPosition(
    target: LatLng(-23.42087200129373, -51.93719096900213),
    zoom: 18,
  );

  _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  _recuperarUltimaLocalizacaoConhecida() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      if (position != null) {

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

          if(_idRequisicao != null ){

            //Atualiza local do passageiro
          UsuarioFirebase.atualizarDadosLocalizacao(
              _idRequisicao!,
              position.latitude,
              position.longitude,
              "passageiro"
          );

          }else{
            setState(() {
              _localPassageiro = position;
            });
            _statusUberNaoChamado();
          }



    });

  }

  List<String> itensMenu = ["Configurações", "Deslogar"];

  _deslogarUsuario() async {
    FirebaseAuth auth = FirebaseAuth.instance;

    await auth.signOut();
    Navigator.pushReplacementNamed(context, "/");
  }

  _escolhaMenuItem(String escolha) {
    switch (escolha) {
      case "Deslogar":
        _deslogarUsuario();
        break;
      case "Configurações":
        break;
    }
  }

  _chamarUber() async {

    String enderecoDestino = _controllerDestino.text;

    List <Location> listaLocalizacoes = await GeocodingPlatform.instance.locationFromAddress(enderecoDestino);

    if( listaLocalizacoes.isNotEmpty ){
      Location localizacao = listaLocalizacoes[0];
      List<Placemark> listaEnderecos = await GeocodingPlatform.instance.placemarkFromCoordinates(localizacao.latitude, localizacao.longitude);
      if(listaEnderecos.isNotEmpty){
        Placemark endereco = listaEnderecos[0];

        Destino destino = Destino();
        destino.cidade = endereco.subAdministrativeArea;
        destino.cep = endereco.postalCode;
        destino.bairro = endereco.subLocality;
        destino.rua = endereco.thoroughfare;
        destino.numero = endereco.subThoroughfare;

        destino.latitude = localizacao.latitude;
        destino.longitude = localizacao.longitude;

        String enderecoConfirmacao;
        enderecoConfirmacao = "\n Cidade: ${destino.cidade}";
        enderecoConfirmacao += "\n Rua: ${destino.rua}, ${destino.numero}";
        enderecoConfirmacao += "\n Bairro: ${destino.bairro}";
        enderecoConfirmacao += "\n Cep: ${destino.cep}";

        showDialog(
            context: context,
            builder: (context){
              return AlertDialog(
                title: Text("Confirmação do endereço"),
                content: Text(enderecoConfirmacao),
                contentPadding: EdgeInsets.all(16),
                actions: [
                  TextButton(
                    child: Text("Cancelar",style: TextStyle(color: Colors.red),),
                    onPressed: () => Navigator.pop(context),
                  ),
                  TextButton(
                    child: Text("Confirmar",style: TextStyle(color: Colors.green),),
                    onPressed: () {

                      //salvar requisicao
                      _salvarRequisicao( destino );

                      Navigator.pop(context);
                    },
                  ),
                ],
              );
            }
        );
      }
    }else{
      //algum controle/aviso para preencher todos os campos.
    }

  }

  _exibirMarcadoresPassageiro(Position local) async {

    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        "imagens/passageiro.png"
    ).then((BitmapDescriptor icone){

      Marker marcadorPassageiro = Marker(
          markerId: MarkerId("marcador-passageiro"),
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

  _salvarRequisicao( Destino destino) async {

    /*
    + requisicao
       + ID_REQUISICAO
          + destino (rua, endereço, latitude...)
          + passageiro (nome, email ...)
          + motorista (nome, email ...)
          + status (aguardando, a caminho...finalizada)
     */

    Usuario passageiro = await UsuarioFirebase.getDadosUsuarioLogado();
    passageiro.latitude = _localPassageiro?.latitude;
    passageiro.longitude = _localPassageiro?.longitude;

    Requisicao requisicao = Requisicao();
    requisicao.destino = destino;
    requisicao.passageiro = passageiro;
    requisicao.status = StatusRequisicao.AGUARDANDO;

    FirebaseFirestore db = FirebaseFirestore.instance;

    //Salvar requisição ativa
    db.collection("requisicoes")
    .doc( requisicao.id )
    .set(requisicao.toMap());

    //Salvar requisição ativa
    Map<String, dynamic> dadosRequisicaoAtiva = {};
    dadosRequisicaoAtiva["id_requisicao"] = requisicao.id;
    dadosRequisicaoAtiva["id_usuario"] = passageiro.idUsuario;
    dadosRequisicaoAtiva["status"] = StatusRequisicao.AGUARDANDO;
    
    db.collection("requisicao_ativa")
    .doc(passageiro.idUsuario )
    .set(dadosRequisicaoAtiva);

    //Adicionar listener requisicao
    if( _streamSubscriptionRequisicoes == null ){
      _adicionarListenerRequisicao(requisicao.id!);
    }

  }

  _alterarBotaoPrincipal(String texto, Color cor, Function funcao){

    setState(() {
      _textoBotao = texto;
      _corBotao = cor;
      _funcaoBotao = funcao;
    });

  }

  _statusUberNaoChamado() async {

    _exibirCaixaEnderecoDestino = true;
    _alterarBotaoPrincipal(
        "Chamar uber",
        Color(0xff1ebbd8),
        (){
          _chamarUber();
        });

    if(_localPassageiro != null ){

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      _exibirMarcadoresPassageiro( position );
      CameraPosition cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 18,
      );
      _movimentarCamera(cameraPosition);

    }


  }

  _statusAguardando() async {
    _exibirCaixaEnderecoDestino = false;
    _alterarBotaoPrincipal(
        "Cancelar",
        Colors.red,
            (){
          _cancelarUber();
        }
    );

    // double passageiroLat = _dadosRequisicao?["passageiro"]["latitude"];
    // double passageiroLon = _dadosRequisicao?["passageiro"]["longitude"];
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    _exibirMarcadoresPassageiro( position );
    CameraPosition cameraPosition = CameraPosition(
      target: LatLng(position.latitude, position.longitude),
      zoom: 18,
    );
    _movimentarCamera(cameraPosition);
  }

  _statusACaminho(){
    _exibirCaixaEnderecoDestino = false;
    _alterarBotaoPrincipal(
        "Motorista a caminho",
        Colors.grey,
            (){

        }
    );

    double latitudeDestino = _dadosRequisicao!["passageiro"]["latitude"];
    double longitudeDestino = _dadosRequisicao!["passageiro"]["longitude"];

    double latitudeOrigem = _dadosRequisicao!["motorista"]["latitude"];
    double longitudeOrigem = _dadosRequisicao!["motorista"]["longitude"];

    Marcador marcadorOrigem = Marcador(
        LatLng(latitudeOrigem, longitudeOrigem),
        "imagens/motorista.png",
        "local motorista"
    );

    Marcador marcadorDestino = Marcador(
        LatLng(latitudeDestino, longitudeDestino),
        "imagens/passageiro.png",
        "local destino"
    );

    _exibirCentralizarDoisMarcadores(marcadorOrigem, marcadorDestino);

  }

  _statusEmViagem(){
    _exibirCaixaEnderecoDestino = false;

    _alterarBotaoPrincipal(
      "Em viagem",
      Colors.grey,
      (){},
    );

    double latitudeDestino = _dadosRequisicao!["destino"]["latitude"];
    double longitudeDestino = _dadosRequisicao!["destino"]["longitude"];

    double latitudeOrigem = _dadosRequisicao!["motorista"]["latitude"];
    double longitudeOrigem = _dadosRequisicao!["motorista"]["longitude"];

    Marcador marcadorOrigem = Marcador(
        LatLng(latitudeOrigem, longitudeOrigem),
        "imagens/motorista.png",
        "local motorista"
    );

    Marcador marcadorDestino = Marcador(
        LatLng(latitudeDestino, longitudeDestino),
        "imagens/destino.png",
        "local destino"
    );

    _exibirCentralizarDoisMarcadores(marcadorOrigem, marcadorDestino);

  }

  _statusFinalizada() async {

    //Calcula valor da corrida
    double latitudeDestino = _dadosRequisicao!["destino"]["latitude"];
    double longitudeDestino = _dadosRequisicao!["destino"]["longitude"];

    double latitudeOrigem = _dadosRequisicao!["origem"]["latitude"];
    double longitudeOrigem = _dadosRequisicao!["origem"]["longitude"];

    //para calcular um valor mais exato basta consumir uma API do google
    // que calcula a distanciaconsiderando as ruas do percurso.
    double distanciaEmMetros = Geolocator.distanceBetween(
        latitudeOrigem,
        longitudeOrigem,
        latitudeDestino,
        longitudeDestino
    );

    //converte para KM
    double distanciaKM = distanciaEmMetros / 1000;
    double valorViagem = distanciaKM * 8;

    //8 é o valor cobrado por KM
    var f = NumberFormat('#,##0.00', 'pt_BR');
    var valorViagemFormatado = f.format( valorViagem );

    _alterarBotaoPrincipal(
      "Total - R\$ $valorViagemFormatado",
      Colors.green,
          (){},
    );



    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    _exibirMarcador( position,
        "imagens/destino.png",
        "Destino"
    );

    //setState(() {
    CameraPosition cameraPosition = CameraPosition(
      target: LatLng(position.latitude, position.longitude),
      zoom: 18,
    );
    // });
    _movimentarCamera(cameraPosition);

  }

  _statusConfirmada() async {

    if(_streamSubscriptionRequisicoes != null){
      _streamSubscriptionRequisicoes!.cancel();
      _streamSubscriptionRequisicoes = null;
    }

    _exibirCaixaEnderecoDestino = true;

    _alterarBotaoPrincipal(
        "Chamar uber",
        Color(0xff1ebbd8),
            (){
          _chamarUber();
        });

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    _exibirMarcadoresPassageiro( position );
    CameraPosition cameraPosition = CameraPosition(
      target: LatLng(position.latitude, position.longitude),
      zoom: 18,
    );
    _movimentarCamera(cameraPosition);

    _dadosRequisicao = {};

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

  _exibirDoisMArcadores( Marcador marcadorOrigem, Marcador marcadorDestino ){

    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    LatLng latLngOrigem = marcadorOrigem.local;
    LatLng latLngDestino = marcadorDestino.local;

    Set<Marker> _listaMarcadores = {};
    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        marcadorOrigem.caminhoImagem
    ).then((BitmapDescriptor icone){

      Marker mOrigem = Marker(
          markerId: MarkerId(marcadorOrigem.caminhoImagem),
          position: LatLng(latLngOrigem.latitude, latLngOrigem.longitude),
          infoWindow: InfoWindow(title: marcadorOrigem.titulo),
          icon: icone
      );
      _listaMarcadores.add(mOrigem);
    });

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        marcadorDestino.caminhoImagem
    ).then((BitmapDescriptor icone){

      Marker mDestino = Marker(
          markerId: MarkerId(marcadorDestino.caminhoImagem),
          position: LatLng(latLngDestino.latitude, latLngDestino.longitude),
          infoWindow: InfoWindow(title: marcadorDestino.titulo),
          icon: icone
      );
      _listaMarcadores.add(mDestino);
    });

    setState(() {
      _marcadores = _listaMarcadores;
    });

  }

  _exibirCentralizarDoisMarcadores( Marcador marcadorOrigem, Marcador marcadorDestino){

    double latitudeOrigem = marcadorOrigem.local.latitude;
    double longitudeOrigem = marcadorOrigem.local.longitude;

    double latitudeDestino = marcadorDestino.local.latitude;
    double longitudeDestino = marcadorDestino.local.longitude;

    _exibirDoisMArcadores(
      marcadorOrigem,
      marcadorDestino,
    );

    //'southwest.latitude <= northeast.latitude' : is not true
    double? nLat, nLon, sLat, sLon;

    if(latitudeOrigem <= latitudeDestino){
      sLat = latitudeOrigem;
      nLat = latitudeDestino;
    }else{
      sLat = latitudeDestino;
      nLat = latitudeOrigem;
    }

    if(longitudeOrigem <= longitudeDestino){
      sLon = longitudeOrigem;
      nLon = longitudeDestino;
    }else{
      sLon = longitudeDestino;
      nLon = longitudeOrigem;
    }

    _movimentarCameraBounds(

        LatLngBounds(
          northeast: LatLng(nLat,nLon),
          southwest: LatLng(sLat,sLon),
        )

    );

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

  _cancelarUber() async{

    User firebaseUser = await UsuarioFirebase.getUsuarioAtual();
    FirebaseFirestore db = FirebaseFirestore.instance;
    db.collection("requisicoes")
    .doc(_idRequisicao)
    .update({
      "status" : StatusRequisicao.CANCELADA
    }).then((_) {
      
      db.collection("requisicao_ativa")
          .doc( firebaseUser.uid)
          .delete();

      _statusUberNaoChamado();

      if(_streamSubscriptionRequisicoes != null){
        _streamSubscriptionRequisicoes!.cancel();
        _streamSubscriptionRequisicoes = null;
      }

    });

  }

  _recuperarRequisicaoAtiva() async{

    User firebaseUser = await UsuarioFirebase.getUsuarioAtual();

    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentSnapshot documentSnapshot = await db.collection("requisicao_ativa")
            .doc(firebaseUser.uid)
            .get();

    if(documentSnapshot.data() != null){

      Map<String, dynamic> dados = documentSnapshot.data() as Map<String, dynamic>;
      _idRequisicao = dados["id_requisicao"];

      _adicionarListenerRequisicao(_idRequisicao!);

    }else{

      _statusUberNaoChamado();

    }

  }

  _adicionarListenerRequisicao( String idRequisicao ) async {

    FirebaseFirestore db = FirebaseFirestore.instance;
    _streamSubscriptionRequisicoes = await db.collection("requisicoes")
        .doc( idRequisicao ).snapshots().listen((snapshot) {

      if( snapshot.data() != null ){

        Map<String, dynamic>? dados = snapshot.data() as Map<String, dynamic>?;
        _dadosRequisicao = dados;
        String status = dados?["status"];
        _idRequisicao = dados?["id"];

        switch( status ){
          case StatusRequisicao.AGUARDANDO :
            _statusAguardando();
            break;
          case StatusRequisicao.A_CAMINHO :
            _statusACaminho();
            break;
          case StatusRequisicao.VIAGEM :
            _statusEmViagem();
            break;
          case StatusRequisicao.FINALIZADA :
            _statusFinalizada();
            break;
          case StatusRequisicao.CONFIRMADA :
            _statusConfirmada();
            break;

        }

      }

    });

  }

  @override
  void initState() {
    super.initState();
    //adicionar listener para requisicao ativa
    _recuperarRequisicaoAtiva();

    //_recuperarUltimaLocalizacaoConhecida();
    _adicionarListenerLocalizacao();

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("painel passageiro"),
        actions: [
          PopupMenuButton<String>(
              onSelected: _escolhaMenuItem,
              itemBuilder: (context) {
                return itensMenu.map((String item) {
                  return PopupMenuItem<String>(
                    value: item,
                    child: Text(item),
                  );
                }).toList();
              })
        ],
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
            Visibility(
                visible: _exibirCaixaEnderecoDestino,
                child: Stack(
                  children: [
                    Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Container(
                            height: 50,
                            width: double.infinity,
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(3),
                                color: Colors.white),
                            child: TextField(
                              readOnly: true,
                              decoration: InputDecoration(
                                  icon: Container(
                                    margin: EdgeInsets.only(
                                      left: 20,
                                    ),
                                    width: 10,
                                    height: 40,
                                    child: Icon(
                                      Icons.location_on,
                                      color: Colors.green,
                                    ),
                                  ),
                                  hintText: "Meu local",
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.only(left: 15)),
                            ),
                          ),
                        )),
                    Positioned(
                        top: 55,
                        left: 0,
                        right: 0,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Container(
                            height: 50,
                            width: double.infinity,
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(3),
                                color: Colors.white),
                            child: TextField(
                              controller: _controllerDestino,
                              decoration: InputDecoration(
                                  icon: Container(
                                    margin: EdgeInsets.only(left: 20,),
                                    width: 10,
                                    height: 40,
                                    child: Icon(Icons.local_taxi, color: Colors.black,),
                                  ),
                                  hintText: "Digite o destino",
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.only(left: 15)),
                            ),
                          ),
                        ))
                  ],
                )
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

  @override
  void dispose() {
    super.dispose();
    _streamSubscriptionRequisicoes?.cancel();
    _streamSubscriptionRequisicoes = null;
  }

}

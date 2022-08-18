import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uber/model/Requisicao.dart';
import 'package:uber/util/UsuarioFirebase.dart';
import 'dart:io';
import '../model/Destino.dart';
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
  String _idRequisicao = "";

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

        _exibirMarcadoresPassageiro( position );

        _posicaoCamera = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 18,
        );

        _movimentarCamera(_posicaoCamera);
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
          + motorista (aguardando, a caminho...finalizada)
     */

    Usuario passageiro = await UsuarioFirebase.getDadosUsuarioLogado();

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

  }

  _alterarBotaoPrincipal(String texto, Color cor, Function funcao){

    setState(() {
      _textoBotao = texto;
      _corBotao = cor;
      _funcaoBotao = funcao;
    });

  }

  _statusUberNaoChamado(){

    _exibirCaixaEnderecoDestino = true;
    _alterarBotaoPrincipal(
        "Chamar uber",
        Color(0xff1ebbd8),
        (){
          _chamarUber();
        }
    );
  }

  _statusAguardando(){
    _exibirCaixaEnderecoDestino = false;
    _alterarBotaoPrincipal(
        "Cancelar",
        Colors.red,
            (){
          _cancelarUber();
        }
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
    });

  }

  _adicionarListenerRequisicaoAtiva() async{

    User firebaseUser = await UsuarioFirebase.getUsuarioAtual();

    FirebaseFirestore db = FirebaseFirestore.instance;
    await db.collection("requisicao_ativa")
            .doc(firebaseUser.uid)
            .snapshots()
            .listen((snapshot) {

              //print("dados recuperados: ${snapshot.data().toString()}");
            /*
                Caso tenha uma requisicao ativa
                  -> altera interface de acordo com status
                Caso nao tenha
                  -> Exibe interface padrao para chamar uber
             */
      if( snapshot.data() != null ){

        Map<String, dynamic> dados = snapshot.data()!;
        String status = dados["status"];
        _idRequisicao = dados["id_requisicao"];

        switch( status ){
          case StatusRequisicao.AGUARDANDO :
            _statusAguardando();
            break;
          case StatusRequisicao.A_CAMINHO :

            break;
          case StatusRequisicao.VIAGEM :

            break;
          case StatusRequisicao.FINALIZADA :

            break;

        }

      }else{

        _statusUberNaoChamado();

      }

    });
  }

  @override
  void initState() {
    super.initState();
    _recuperarUltimaLocalizacaoConhecida();
    _adicionarListenerLocalizacao();

    //adicionar listener para requisicao ativa
    _adicionarListenerRequisicaoAtiva();
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
}

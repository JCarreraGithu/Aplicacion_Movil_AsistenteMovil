import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:systema_riego_app/pages/asistente_page.dart';

class InventarioPage extends StatefulWidget {
  final String token;

  const InventarioPage({
    super.key,
    required this.token,
  });

  @override
  State<InventarioPage> createState() => _InventarioPageState();
}

class _InventarioPageState extends State<InventarioPage> {
  final ImagePicker _picker = ImagePicker();

  // ============================================================
  // CONTROLADORES
  // ============================================================

  final TextEditingController nombrePersonalizadoController =
  TextEditingController();

  // ============================================================
  // ESTADOS
  // ============================================================

  bool identificando = false;
  bool cargandoInventario = false;
  bool plantaRegistrada = false;

  // ============================================================
  // DATOS
  // ============================================================

  List<dynamic> jardines = [];
  List<dynamic> sectores = [];
  List<dynamic> plantas = [];

  int? jardinSeleccionado;
  int? sectorSeleccionado;

  // ============================================================
  // RESULTADO DE PLANTNET
  // ============================================================

  String? plantaIdentificada;
  String? nombreCientifico;
  double confianza = 0;

  // ============================================================
  // IMAGEN ACTUAL
  // ============================================================

  XFile? imagenPlanta;

  // ============================================================
  // FILTRO
  // ============================================================

  String filtroSeleccionado = 'Todas';

  // ============================================================
  // URL API
  // ============================================================

  final String baseUrl = 'http://10.0.2.2:3000/api';

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    cargarInventario();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    nombrePersonalizadoController.dispose();
    super.dispose();
  }

  // ============================================================
  // CARGAR JARDINES
  // ============================================================

  Future<void> cargarJardines() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/jardines'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      debugPrint('Jardines status: ${response.statusCode}');
      debugPrint('Jardines response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is List) {
          jardines = data;
        } else {
          jardines = [];
        }

        debugPrint(
          'Jardines encontrados: ${jardines.length}',
        );
      }
    } catch (e) {
      debugPrint(
        'Error cargando jardines: $e',
      );
    }
  }

  // ============================================================
  // CARGAR SECTORES
  // ============================================================

  Future<void> cargarSectores(int idJardin) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/jardines/$idJardin/sectores',
        ),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      debugPrint(
        'Sectores status: ${response.statusCode}',
      );

      debugPrint(
        'Sectores response: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (!mounted) return;

        setState(() {
          sectores = data is List ? data : [];
        });
      }
    } catch (e) {
      debugPrint(
        'Error cargando sectores: $e',
      );
    }
  }

  // ============================================================
  // CARGAR TODO EL INVENTARIO
  // ============================================================

  Future<void> cargarInventario() async {
    if (mounted) {
      setState(() {
        cargandoInventario = true;
      });
    }

    try {
      await cargarJardines();

      final List<dynamic> todasLasPlantas = [];

      for (final jardin in jardines) {
        final int idJardin = int.parse(
          jardin['id_jardin'].toString(),
        );

        final response = await http.get(
          Uri.parse(
            '$baseUrl/jardines/$idJardin/sectores',
          ),
          headers: {
            'Authorization': 'Bearer ${widget.token}',
          },
        );

        if (response.statusCode != 200) {
          continue;
        }

        final data = jsonDecode(
          response.body,
        );

        if (data is! List) {
          continue;
        }

        for (final sector in data) {
          final int idSector = int.parse(
            sector['id_sector'].toString(),
          );

          final plantasResponse = await http.get(
            Uri.parse(
              '$baseUrl/plantas/$idSector/plantas',
            ),
            headers: {
              'Authorization': 'Bearer ${widget.token}',
            },
          );

          if (plantasResponse.statusCode != 200) {
            continue;
          }

          final plantasData = jsonDecode(
            plantasResponse.body,
          );

          if (plantasData is! List) {
            continue;
          }

          for (final planta in plantasData) {
            todasLasPlantas.add({
              ...Map<String, dynamic>.from(planta),
              'nombre_jardin':
              jardin['nombre'] ?? '',
              'nombre_sector':
              sector['nombre'] ?? '',
            });
          }
        }
      }

      if (!mounted) return;

      setState(() {
        plantas = todasLasPlantas;
      });

      debugPrint(
        '====================================',
      );
      debugPrint(
        'INVENTARIO CARGADO',
      );
      debugPrint(
        'Total plantas: ${plantas.length}',
      );
      debugPrint(
        '====================================',
      );
    } catch (e) {
      debugPrint(
        'Error cargando inventario: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          cargandoInventario = false;
        });
      }
    }
  }

  // ============================================================
  // IDENTIFICAR PLANTA
  //
  // IMPORTANTE:
  // Identificar NO registra la planta.
  // ============================================================

  Future<void> identificarPlanta() async {
    final XFile? imagen = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (imagen == null) {
      return;
    }

    if (!mounted) return;

    setState(() {
      imagenPlanta = imagen;
      identificando = true;
      plantaRegistrada = false;
    });

    try {
      final Uint8List bytes =
      await imagen.readAsBytes();

      debugPrint(
        '====================================',
      );
      debugPrint(
        'IMAGEN SELECCIONADA',
      );
      debugPrint(
        'Nombre: ${imagen.name}',
      );
      debugPrint(
        'Tamaño: ${bytes.length} bytes',
      );
      debugPrint(
        '====================================',
      );

      final uri = Uri.parse(
        '$baseUrl/identificacion/identificar',
      );

      final request =
      http.MultipartRequest(
        'POST',
        uri,
      );

      request.headers['Authorization'] =
      'Bearer ${widget.token}';

      request.files.add(
        http.MultipartFile.fromBytes(
          'imagen',
          bytes,
          filename: imagen.name,
        ),
      );

      final streamedResponse =
      await request.send();

      final response =
      await http.Response.fromStream(
        streamedResponse,
      );

      debugPrint(
        'STATUS: ${response.statusCode}',
      );

      debugPrint(
        'RESPUESTA: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data =
        jsonDecode(response.body);

        if (!mounted) return;

        final valor =
            data['porcentajeConfianza'] ?? 0;

        setState(() {
          plantaIdentificada =
              data['nombreIdentificado'] ??
                  'Desconocido';

          nombreCientifico =
              data['nombreCientifico'] ??
                  'No disponible';

          confianza =
              double.tryParse(
                valor.toString(),
              ) ??
                  0;

          plantaRegistrada = false;
        });

        mostrarResultado();
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'Error ${response.statusCode}: '
                  '${response.body}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      debugPrint(
        'ERROR IDENTIFICANDO: $e',
      );

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Error al identificar: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          identificando = false;
        });
      }
    }
  }

  // ============================================================
  // MOSTRAR RESULTADO DE IDENTIFICACIÓN
  // ============================================================

  void mostrarResultado() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (
              modalContext,
              setModalState,
              ) {
            return Container(
              constraints: BoxConstraints(
                maxHeight:
                MediaQuery.of(
                  modalContext,
                ).size.height *
                    0.92,
              ),
              padding:
              const EdgeInsets.fromLTRB(
                25,
                15,
                25,
                25,
              ),
              decoration:
              const BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                child:
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      // ==================================================
                      // CABECERA
                      // ==================================================

                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,
                        children: [
                          Container(
                            width: 45,
                            height: 5,
                            decoration:
                            BoxDecoration(
                              color: Colors
                                  .grey
                                  .shade300,
                              borderRadius:
                              BorderRadius
                                  .circular(
                                10,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.pop(
                                modalContext,
                              );
                            },
                            icon: const Icon(
                              Icons.close,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      const Text(
                        'Planta identificada',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 20,
                      ),

                      // ==================================================
                      // FOTO
                      // ==================================================

                      if (imagenPlanta != null)
                        _imagenIdentificada(),

                      const SizedBox(
                        height: 20,
                      ),

                      // ==================================================
                      // INFORMACIÓN
                      // ==================================================

                      Container(
                        width:
                        double.infinity,
                        padding:
                        const EdgeInsets.all(
                          20,
                        ),
                        decoration:
                        BoxDecoration(
                          color:
                          const Color(
                            0xFFE8F5E9,
                          ),
                          borderRadius:
                          BorderRadius
                              .circular(
                            18,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                          children: [
                            const Icon(
                              Icons.eco,
                              color: Color(
                                0xFF2E7D32,
                              ),
                              size: 45,
                            ),

                            const SizedBox(
                              height: 15,
                            ),

                            Text(
                              plantaIdentificada ??
                                  'Desconocido',
                              style:
                              const TextStyle(
                                fontSize: 21,
                                fontWeight:
                                FontWeight
                                    .bold,
                              ),
                            ),

                            const SizedBox(
                              height: 5,
                            ),

                            Text(
                              nombreCientifico ??
                                  'No disponible',
                              style: TextStyle(
                                color: Colors
                                    .grey
                                    .shade600,
                                fontStyle:
                                FontStyle
                                    .italic,
                              ),
                            ),

                            const SizedBox(
                              height: 15,
                            ),

                            Text(
                              'Confianza: '
                                  '${confianza.toStringAsFixed(1)}%',
                              style:
                              const TextStyle(
                                color: Color(
                                  0xFF2E7D32,
                                ),
                                fontWeight:
                                FontWeight
                                    .bold,
                              ),
                            ),

                            if (plantaRegistrada)
                              const Padding(
                                padding:
                                EdgeInsets.only(
                                  top: 12,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons
                                          .check_circle,
                                      color: Color(
                                        0xFF2E7D32,
                                      ),
                                      size: 20,
                                    ),
                                    SizedBox(
                                      width: 8,
                                    ),
                                    Text(
                                      'Planta registrada',
                                      style:
                                      TextStyle(
                                        color:
                                        Color(
                                          0xFF2E7D32,
                                        ),
                                        fontWeight:
                                        FontWeight
                                            .bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(
                        height: 20,
                      ),

                      // ==================================================
                      // REGISTRAR
                      // ==================================================

                      if (!plantaRegistrada)
                        SizedBox(
                          width:
                          double.infinity,
                          height: 52,
                          child:
                          ElevatedButton
                              .icon(
                            onPressed: () async {
                              await mostrarRegistro();

                              if (mounted) {
                                setModalState(
                                      () {},
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.add,
                            ),
                            label: const Text(
                              'Registrar en mi jardín',
                            ),
                            style:
                            ElevatedButton
                                .styleFrom(
                              backgroundColor:
                              const Color(
                                0xFF2E7D32,
                              ),
                              foregroundColor:
                              Colors.white,
                              shape:
                              RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius
                                    .circular(
                                  15,
                                ),
                              ),
                            ),
                          ),
                        ),

                      if (!plantaRegistrada)
                        const SizedBox(
                          height: 10,
                        ),

                      // ==================================================
                      // CONSULTAR CON IA
                      // ==================================================

                      SizedBox(
                        width:
                        double.infinity,
                        height: 52,
                        child:
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(
                              modalContext,
                            );

                            abrirAsistente(
                              nombrePlanta:
                              plantaIdentificada ??
                                  'esta planta',
                              nombreCientifico:
                              nombreCientifico,
                            );
                          },
                          icon: const Icon(
                            Icons.smart_toy,
                          ),
                          label: const Text(
                            'Consultar con asistente',
                          ),
                          style:
                          ElevatedButton
                              .styleFrom(
                            backgroundColor:
                            const Color(
                              0xFF1565C0,
                            ),
                            foregroundColor:
                            Colors.white,
                            shape:
                            RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius
                                  .circular(
                                15,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      // ==================================================
                      // CERRAR
                      // ==================================================

                      SizedBox(
                        width:
                        double.infinity,
                        height: 50,
                        child:
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pop(
                              modalContext,
                            );
                          },
                          child: const Text(
                            'Cerrar',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // IMAGEN DE IDENTIFICACIÓN
  // ============================================================

  Widget _imagenIdentificada() {
    return FutureBuilder<List<int>>(
      future: imagenPlanta!.readAsBytes(),
      builder: (
          context,
          snapshot,
          ) {
        if (!snapshot.hasData) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius:
              BorderRadius.circular(18),
            ),
            child: const Center(
              child:
              CircularProgressIndicator(),
            ),
          );
        }

        final Uint8List bytes =
        Uint8List.fromList(
          snapshot.data!,
        );

        return ClipRRect(
          borderRadius:
          BorderRadius.circular(18),
          child: Image.memory(
            bytes,
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }

  // ============================================================
  // MOSTRAR REGISTRO
  // ============================================================

  Future<void> mostrarRegistro() async {
    await cargarJardines();

    if (!mounted) return;

    jardinSeleccionado = null;
    sectorSeleccionado = null;
    sectores = [];

    nombrePersonalizadoController.text =
        plantaIdentificada ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (registroContext) {
        return StatefulBuilder(
          builder: (
              registroContext,
              setModalState,
              ) {
            return Container(
              constraints: BoxConstraints(
                maxHeight:
                MediaQuery.of(
                  registroContext,
                ).size.height *
                    0.90,
              ),
              padding:
              const EdgeInsets.all(25),
              decoration:
              const BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                child:
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      // ==================================================
                      // CABECERA
                      // ==================================================

                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,
                        children: [
                          const Text(
                            'Registrar planta',
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.pop(
                                registroContext,
                              );
                            },
                            icon: const Icon(
                              Icons.close,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      Text(
                        plantaIdentificada ??
                            'Planta',
                        style:
                        const TextStyle(
                          fontSize: 17,
                          color: Color(
                            0xFF2E7D32,
                          ),
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 20,
                      ),

                      // ==================================================
                      // NOMBRE
                      // ==================================================

                      const Text(
                        'Nombre de la planta',
                        style: TextStyle(
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      TextField(
                        controller:
                        nombrePersonalizadoController,
                        decoration:
                        InputDecoration(
                          hintText:
                          'Ej. Mi Begonia',
                          border:
                          OutlineInputBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                              12,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 20,
                      ),

                      // ==================================================
                      // JARDÍN
                      // ==================================================

                      const Text(
                        'Jardín',
                        style: TextStyle(
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      DropdownButtonFormField<int>(
                        value:
                        jardinSeleccionado,
                        decoration:
                        InputDecoration(
                          border:
                          OutlineInputBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                              12,
                            ),
                          ),
                        ),
                        hint: const Text(
                          'Selecciona un jardín',
                        ),
                        items: jardines
                            .map<
                            DropdownMenuItem<
                                int>>(
                              (jardin) {
                            final int id =
                            int.parse(
                              jardin[
                              'id_jardin']
                                  .toString(),
                            );

                            return DropdownMenuItem<
                                int>(
                              value: id,
                              child: Text(
                                jardin[
                                'nombre']
                                    .toString(),
                              ),
                            );
                          },
                        )
                            .toList(),
                        onChanged:
                            (value) async {
                          setModalState(() {
                            jardinSeleccionado =
                                value;

                            sectorSeleccionado =
                            null;

                            sectores = [];
                          });

                          if (value != null) {
                            await cargarSectores(
                              value,
                            );

                            if (mounted) {
                              setModalState(
                                    () {},
                              );
                            }
                          }
                        },
                      ),

                      const SizedBox(
                        height: 20,
                      ),

                      // ==================================================
                      // SECTOR
                      // ==================================================

                      const Text(
                        'Sector',
                        style: TextStyle(
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      DropdownButtonFormField<int>(
                        value:
                        sectorSeleccionado,
                        decoration:
                        InputDecoration(
                          border:
                          OutlineInputBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                              12,
                            ),
                          ),
                        ),
                        hint: Text(
                          jardinSeleccionado ==
                              null
                              ? 'Primero selecciona un jardín'
                              : sectores.isEmpty
                              ? 'No hay sectores'
                              : 'Selecciona un sector',
                        ),
                        items: sectores
                            .map<
                            DropdownMenuItem<
                                int>>(
                              (sector) {
                            final int id =
                            int.parse(
                              sector[
                              'id_sector']
                                  .toString(),
                            );

                            return DropdownMenuItem<
                                int>(
                              value: id,
                              child: Text(
                                sector[
                                'nombre']
                                    .toString(),
                              ),
                            );
                          },
                        )
                            .toList(),
                        onChanged:
                        jardinSeleccionado ==
                            null
                            ? null
                            : (value) {
                          setModalState(
                                () {
                              sectorSeleccionado =
                                  value;
                            },
                          );
                        },
                      ),

                      const SizedBox(
                        height: 25,
                      ),

                      // ==================================================
                      // REGISTRAR
                      // ==================================================

                      SizedBox(
                        width:
                        double.infinity,
                        height: 52,
                        child:
                        ElevatedButton(
                          onPressed:
                          sectorSeleccionado ==
                              null
                              ? null
                              : () async {
                            final exito =
                            await registrarPlanta();

                            if (exito &&
                                mounted) {
                              Navigator.pop(
                                registroContext,
                              );
                            }
                          },
                          style:
                          ElevatedButton
                              .styleFrom(
                            backgroundColor:
                            const Color(
                              0xFF2E7D32,
                            ),
                            foregroundColor:
                            Colors.white,
                            shape:
                            RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius
                                  .circular(
                                15,
                              ),
                            ),
                          ),
                          child: const Text(
                            'Registrar planta',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // REGISTRAR PLANTA
  // ============================================================

  Future<bool> registrarPlanta() async {
    if (sectorSeleccionado == null) {
      return false;
    }

    if (imagenPlanta == null) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'No se encontró la fotografía de la planta.',
          ),
        ),
      );

      return false;
    }

    String nombreFinal =
    nombrePersonalizadoController.text
        .trim();

    if (nombreFinal.isEmpty) {
      nombreFinal =
          plantaIdentificada ?? 'Planta';
    }

    try {
      final uri = Uri.parse(
        '$baseUrl/identificacion/registrar',
      );

      final request =
      http.MultipartRequest(
        'POST',
        uri,
      );

      request.headers['Authorization'] =
      'Bearer ${widget.token}';

      request.fields['idSector'] =
          sectorSeleccionado.toString();

      request.fields['nombre'] =
          nombreFinal;

      request.fields['nombreCientifico'] =
          nombreCientifico ?? '';

      request.fields['descripcion'] =
      'Planta identificada mediante PlantNet';

      request.fields['fechaRegistro'] =
          DateTime.now()
              .toIso8601String();

      final Uint8List bytes =
      await imagenPlanta!.readAsBytes();

      request.files.add(
        http.MultipartFile.fromBytes(
          'imagen',
          bytes,
          filename: imagenPlanta!.name,
        ),
      );

      final streamedResponse =
      await request.send();

      final response =
      await http.Response.fromStream(
        streamedResponse,
      );

      debugPrint(
        'Registro status: '
            '${response.statusCode}',
      );

      debugPrint(
        'Registro response: '
            '${response.body}',
      );

      if (!mounted) return false;

      if (response.statusCode == 201 ||
          response.statusCode == 200) {
        setState(() {
          plantaRegistrada = true;
        });

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            backgroundColor:
            Color(0xFF2E7D32),
            content: Text(
              'Planta registrada correctamente',
            ),
          ),
        );

        await cargarInventario();

        return true;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Error al registrar: '
                '${response.body}',
          ),
        ),
      );

      return false;
    } catch (e) {
      if (!mounted) return false;

      debugPrint(
        'ERROR REGISTRANDO PLANTA: $e',
      );

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Error al registrar planta: $e',
          ),
        ),
      );

      return false;
    }
  }

  // ============================================================
  // ASISTENTE
  //
  // Puede abrirse:
  //
  // 1. Después de identificar una planta.
  // 2. Desde una planta registrada.
  //
  // ============================================================

  void abrirAsistente({
    required String nombrePlanta,
    String? nombreCientifico,
  }) {
    final TextEditingController consultaController =
    TextEditingController();

    String preguntaSeleccionada = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (
              modalContext,
              setModalState,
              ) {
            return Container(
              constraints: BoxConstraints(
                maxHeight:
                MediaQuery.of(
                  modalContext,
                ).size.height *
                    0.75,
              ),
              padding:
              const EdgeInsets.fromLTRB(
                20,
                15,
                20,
                20,
              ),
              decoration:
              const BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                child:
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      // ============================================
                      // CABECERA
                      // ============================================

                      Row(
                        children: [
                          Container(
                            padding:
                            const EdgeInsets
                                .all(10),
                            decoration:
                            BoxDecoration(
                              color:
                              const Color(
                                0xFFE3F2FD,
                              ),
                              borderRadius:
                              BorderRadius
                                  .circular(
                                12,
                              ),
                            ),
                            child: const Icon(
                              Icons.smart_toy,
                              color: Color(
                                0xFF1565C0,
                              ),
                            ),
                          ),

                          const SizedBox(
                            width: 12,
                          ),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                              children: [
                                const Text(
                                  'Consultar con IA',
                                  style:
                                  TextStyle(
                                    fontSize: 20,
                                    fontWeight:
                                    FontWeight
                                        .bold,
                                  ),
                                ),
                                Text(
                                  nombrePlanta,
                                  style: TextStyle(
                                    color: Colors
                                        .grey
                                        .shade600,
                                    fontStyle:
                                    FontStyle
                                        .italic,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          IconButton(
                            onPressed: () {
                              Navigator.pop(
                                modalContext,
                              );
                            },
                            icon: const Icon(
                              Icons.close,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 20,
                      ),

                      // ============================================
                      // TEXTO
                      // ============================================

                      const Text(
                        '¿Qué quieres saber?',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      Text(
                        'Selecciona una pregunta o escribe la tuya.',
                        style: TextStyle(
                          color: Colors
                              .grey
                              .shade600,
                        ),
                      ),

                      const SizedBox(
                        height: 18,
                      ),

                      // ============================================
                      // PREGUNTAS PREDETERMINADAS
                      // ============================================

                      const Text(
                        'Preguntas sugeridas',
                        style: TextStyle(
                          fontWeight:
                          FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      _opcionConsulta(
                        texto:
                        '¿Cómo debo cuidar esta planta?',
                        seleccionada:
                        preguntaSeleccionada ==
                            '¿Cómo debo cuidar esta planta?',
                        onTap: () {
                          setModalState(() {
                            preguntaSeleccionada =
                            '¿Cómo debo cuidar esta planta?';

                            consultaController
                                .text =
                                preguntaSeleccionada;
                          });
                        },
                      ),

                      _opcionConsulta(
                        texto:
                        '¿Cuánta agua necesita?',
                        seleccionada:
                        preguntaSeleccionada ==
                            '¿Cuánta agua necesita?',
                        onTap: () {
                          setModalState(() {
                            preguntaSeleccionada =
                            '¿Cuánta agua necesita?';

                            consultaController
                                .text =
                                preguntaSeleccionada;
                          });
                        },
                      ),

                      _opcionConsulta(
                        texto:
                        '¿Cuánta luz necesita?',
                        seleccionada:
                        preguntaSeleccionada ==
                            '¿Cuánta luz necesita?',
                        onTap: () {
                          setModalState(() {
                            preguntaSeleccionada =
                            '¿Cuánta luz necesita?';

                            consultaController
                                .text =
                                preguntaSeleccionada;
                          });
                        },
                      ),

                      _opcionConsulta(
                        texto:
                        '¿Por qué sus hojas están amarillas?',
                        seleccionada:
                        preguntaSeleccionada ==
                            '¿Por qué sus hojas están amarillas?',
                        onTap: () {
                          setModalState(() {
                            preguntaSeleccionada =
                            '¿Por qué sus hojas están amarillas?';

                            consultaController
                                .text =
                                preguntaSeleccionada;
                          });
                        },
                      ),

                      const SizedBox(
                        height: 18,
                      ),

                      // ============================================
                      // PREGUNTA PERSONALIZADA
                      // ============================================

                      const Text(
                        'O escribe tu pregunta',
                        style: TextStyle(
                          fontWeight:
                          FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      TextField(
                        controller:
                        consultaController,
                        maxLines: 4,
                        onChanged: (value) {
                          setModalState(() {
                            preguntaSeleccionada =
                            '';
                          });
                        },
                        decoration:
                        InputDecoration(
                          hintText:
                          'Ej. ¿Por qué las hojas de mi planta están caídas?',
                          filled: true,
                          fillColor:
                          const Color(
                            0xFFF5F7F5,
                          ),
                          border:
                          OutlineInputBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                              15,
                            ),
                            borderSide:
                            BorderSide.none,
                          ),
                          contentPadding:
                          const EdgeInsets
                              .all(15),
                        ),
                      ),

                      const SizedBox(
                        height: 18,
                      ),

                      // ============================================
                      // CONSULTAR
                      // ============================================

                      SizedBox(
                        width:
                        double.infinity,
                        height: 52,
                        child:
                        ElevatedButton.icon(
                          onPressed: () {
                            final pregunta =
                            consultaController
                                .text
                                .trim();

                            if (pregunta.isEmpty) {
                              ScaffoldMessenger
                                  .of(
                                context,
                              ).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Escribe o selecciona una pregunta.',
                                  ),
                                ),
                              );

                              return;
                            }

                            Navigator.pop(
                              modalContext,
                            );

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AsistentePage(
                                      token:
                                      widget.token,
                                      preguntaInicial:
                                      'Mira, acabo de identificar esta planta: '
                                          '$nombrePlanta.\n\n'
                                          '$pregunta',
                                    ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.smart_toy,
                          ),
                          label: const Text(
                            'Consultar al asistente',
                          ),
                          style:
                          ElevatedButton
                              .styleFrom(
                            backgroundColor:
                            const Color(
                              0xFF1565C0,
                            ),
                            foregroundColor:
                            Colors.white,
                            shape:
                            RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius
                                  .circular(
                                15,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 5,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      consultaController.dispose();
    });
  }

  // ============================================================
  // OPCIÓN DE CONSULTA
  // ============================================================

  Widget _opcionConsulta({
    required String texto,
    required bool seleccionada,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin:
        const EdgeInsets.only(
          bottom: 8,
        ),
        padding:
        const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 13,
        ),
        decoration:
        BoxDecoration(
          color: seleccionada
              ? const Color(0xFFE3F2FD)
              : const Color(0xFFF5F7F5),
          borderRadius:
          BorderRadius.circular(
            12,
          ),
          border: Border.all(
            color: seleccionada
                ? const Color(0xFF1565C0)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              seleccionada
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 20,
              color: seleccionada
                  ? const Color(0xFF1565C0)
                  : Colors.grey.shade500,
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: Text(
                texto,
                style: TextStyle(
                  fontSize: 13,
                  color: seleccionada
                      ? const Color(0xFF1565C0)
                      : Colors.grey.shade800,
                  fontWeight: seleccionada
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PLANTAS FILTRADAS
  // ============================================================

  List<dynamic> get plantasFiltradas {
    if (filtroSeleccionado ==
        'Todas') {
      return plantas;
    }

    return plantas.where((planta) {
      final estado =
      (planta['estado'] ??
          planta['estado_salud'] ??
          '')
          .toString()
          .toLowerCase();

      return estado ==
          filtroSeleccionado
              .toLowerCase();
    }).toList();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF5F7F5),

      // ==========================================================
      // APP BAR
      // ==========================================================

      appBar: AppBar(
        title: const Text(
          'Inventario',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor:
        Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding:
            const EdgeInsets.only(
              right: 12,
            ),
            child: ElevatedButton.icon(
              onPressed:
              identificando
                  ? null
                  : identificarPlanta,
              icon:
              identificando
                  ? const SizedBox(
                width: 18,
                height: 18,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                  color:
                  Colors.white,
                ),
              )
                  : const Icon(
                Icons.camera_alt,
                size: 18,
              ),
              label: Text(
                identificando
                    ? 'Identificando...'
                    : 'Identificar',
              ),
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                const Color(
                  0xFF2E7D32,
                ),
                foregroundColor:
                Colors.white,
                disabledBackgroundColor:
                Colors.grey.shade400,
                disabledForegroundColor:
                Colors.white,
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // ==========================================================
      // BODY
      // ==========================================================

      body: Column(
        children: [
          // ========================================================
          // FILTROS
          // ========================================================

          SingleChildScrollView(
            scrollDirection:
            Axis.horizontal,
            padding:
            const EdgeInsets.symmetric(
              horizontal: 20,
            ),
            child: Row(
              children: [
                _filterChip(
                  'Todas',
                  filtroSeleccionado ==
                      'Todas',
                ),
                const SizedBox(
                  width: 10,
                ),
                _filterChip(
                  'Óptimo',
                  filtroSeleccionado ==
                      'Óptimo',
                  color: Colors.green,
                ),
                const SizedBox(
                  width: 10,
                ),
                _filterChip(
                  'Atención',
                  filtroSeleccionado ==
                      'Atención',
                  color: Colors.orange,
                ),
                const SizedBox(
                  width: 10,
                ),
                _filterChip(
                  'Crítico',
                  filtroSeleccionado ==
                      'Crítico',
                  color: Colors.red,
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          // ========================================================
          // INVENTARIO
          // ========================================================

          Expanded(
            child:
            cargandoInventario
                ? const Center(
              child:
              CircularProgressIndicator(
                color:
                Color(
                  0xFF2E7D32,
                ),
              ),
            )
                : RefreshIndicator(
              color:
              const Color(
                0xFF2E7D32,
              ),
              onRefresh:
              cargarInventario,
              child:
              plantasFiltradas
                  .isEmpty
                  ? ListView(
                physics:
                const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height:
                    MediaQuery.of(context)
                        .size
                        .height *
                        0.55,
                    child:
                    _inventarioVacio(),
                  ),
                ],
              )
                  : GridView.builder(
                padding:
                const EdgeInsets
                    .fromLTRB(
                  20,
                  0,
                  20,
                  30,
                ),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:
                  2,
                  crossAxisSpacing:
                  14,
                  mainAxisSpacing:
                  14,
                  childAspectRatio:
                  0.64,
                ),
                itemCount:
                plantasFiltradas
                    .length,
                itemBuilder:
                    (
                    context,
                    index,
                    ) {
                  final planta =
                  plantasFiltradas[
                  index];

                  return _plantCard(
                    planta,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INVENTARIO VACÍO
  // ============================================================

  Widget _inventarioVacio() {
    final bool tienePlantas =
        plantas.isNotEmpty;

    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(
              tienePlantas
                  ? Icons.filter_alt_off
                  : Icons.eco_outlined,
              size: 70,
              color:
              Colors.grey.shade400,
            ),
            const SizedBox(
              height: 15,
            ),
            Text(
              tienePlantas
                  ? 'No hay plantas en este filtro'
                  : 'No tienes plantas registradas',
              textAlign:
              TextAlign.center,
              style:
              const TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              tienePlantas
                  ? 'Prueba seleccionando otro estado.'
                  : 'Identifica una planta para agregarla a tu inventario.',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color:
                Colors.grey.shade600,
              ),
            ),
            if (!tienePlantas) ...[
              const SizedBox(
                height: 20,
              ),
              ElevatedButton.icon(
                onPressed:
                identificando
                    ? null
                    : identificarPlanta,
                icon: const Icon(
                  Icons.camera_alt,
                ),
                label: const Text(
                  'Identificar planta',
                ),
                style:
                ElevatedButton.styleFrom(
                  backgroundColor:
                  const Color(
                    0xFF2E7D32,
                  ),
                  foregroundColor:
                  Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FILTRO
  // ============================================================

  Widget _filterChip(
      String texto,
      bool seleccionado, {
        Color? color,
      }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          filtroSeleccionado =
              texto;
        });
      },
      child: Container(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 9,
        ),
        decoration:
        BoxDecoration(
          color:
          seleccionado
              ? const Color(
            0xFF2E7D32,
          )
              : Colors.white,
          borderRadius:
          BorderRadius.circular(
            20,
          ),
          border:
          Border.all(
            color:
            seleccionado
                ? const Color(
              0xFF2E7D32,
            )
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            if (color != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration:
                BoxDecoration(
                  color: color,
                  shape:
                  BoxShape.circle,
                ),
              ),
              const SizedBox(
                width: 6,
              ),
            ],
            Text(
              texto,
              style:
              TextStyle(
                color:
                seleccionado
                    ? Colors.white
                    : Colors.grey
                    .shade700,
                fontWeight:
                FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TARJETA DE PLANTA
  // ============================================================

  Widget _plantCard(
      dynamic planta,
      ) {
    final nombre =
        planta['nombre'] ??
            planta['nombre_comun'] ??
            'Sin nombre';

    final cientifico =
        planta['nombre_cientifico'] ??
            planta['nombreCientifico'] ??
            '';

    final jardin =
        planta['nombre_jardin'] ??
            '';

    final sector =
        planta['nombre_sector'] ??
            '';

    final fotoUrl =
    planta['foto_url'];

    final estado =
    (planta['estado'] ??
        planta['estado_salud'] ??
        '')
        .toString();

    String? imagenUrl;

    if (fotoUrl != null &&
        fotoUrl
            .toString()
            .trim()
            .isNotEmpty) {
      final foto =
      fotoUrl.toString().trim();

      if (foto.startsWith(
        'http://',
      ) ||
          foto.startsWith(
            'https://',
          )) {
        imagenUrl = foto;
      } else {
        imagenUrl =
        'http://10.0.2.2:3000$foto';
      }
    }

    return Container(
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        boxShadow: [
          BoxShadow(
            color:
            Colors.grey.withOpacity(
              0.08,
            ),
            blurRadius: 10,
            offset:
            const Offset(
              0,
              4,
            ),
          ),
        ],
      ),
      child: Padding(
        padding:
        const EdgeInsets.all(
          12,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            // ==================================================
            // FOTO
            // ==================================================

            Expanded(
              child: Container(
                width:
                double.infinity,
                decoration:
                BoxDecoration(
                  color:
                  Colors.grey.shade100,
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                ),
                clipBehavior:
                Clip.antiAlias,
                child:
                imagenUrl == null
                    ? const Center(
                  child: Icon(
                    Icons.eco,
                    size: 40,
                    color:
                    Color(
                      0xFF2E7D32,
                    ),
                  ),
                )
                    : Image.network(
                  imagenUrl,
                  width:
                  double.infinity,
                  height:
                  double.infinity,
                  fit:
                  BoxFit.cover,
                  loadingBuilder:
                      (
                      context,
                      child,
                      loadingProgress,
                      ) {
                    if (loadingProgress ==
                        null) {
                      return child;
                    }

                    return const Center(
                      child:
                      CircularProgressIndicator(
                        color:
                        Color(
                          0xFF2E7D32,
                        ),
                      ),
                    );
                  },
                  errorBuilder:
                      (
                      context,
                      error,
                      stackTrace,
                      ) {
                    return Container(
                      color:
                      Colors.grey.shade100,
                      child:
                      Column(
                        mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                        children: [
                          Icon(
                            Icons
                                .broken_image_outlined,
                            size: 40,
                            color: Colors
                                .grey
                                .shade500,
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                          Text(
                            'No se pudo cargar',
                            textAlign:
                            TextAlign
                                .center,
                            style:
                            TextStyle(
                              fontSize:
                              11,
                              color: Colors
                                  .grey
                                  .shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            // ==================================================
            // NOMBRE
            // ==================================================

            Text(
              nombre.toString(),
              style:
              const TextStyle(
                fontWeight:
                FontWeight.bold,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow:
              TextOverflow.ellipsis,
            ),

            const SizedBox(
              height: 2,
            ),

            // ==================================================
            // CIENTÍFICO
            // ==================================================

            if (cientifico
                .toString()
                .isNotEmpty)
              Text(
                cientifico.toString(),
                style:
                TextStyle(
                  color:
                  Colors.grey.shade600,
                  fontSize: 12,
                  fontStyle:
                  FontStyle.italic,
                ),
                maxLines: 1,
                overflow:
                TextOverflow.ellipsis,
              ),

            const SizedBox(
              height: 5,
            ),

            // ==================================================
            // UBICACIÓN
            // ==================================================

            Text(
              '$jardin - $sector',
              style:
              TextStyle(
                color:
                Colors.grey.shade500,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow:
              TextOverflow.ellipsis,
            ),

            // ==================================================
            // ESTADO
            // ==================================================

            if (estado.isNotEmpty) ...[
              const SizedBox(
                height: 6,
              ),
              _estadoBadge(estado),
            ],

            const SizedBox(
              height: 8,
            ),

            // ==================================================
            // BOTÓN CONSULTAR IA
            // ==================================================

            SizedBox(
              width:
              double.infinity,
              height: 38,
              child:
              OutlinedButton.icon(
                onPressed: () {
                  abrirAsistente(
                    nombrePlanta:
                    nombre.toString(),
                    nombreCientifico:
                    cientifico
                        .toString()
                        .isEmpty
                        ? null
                        : cientifico
                        .toString(),
                  );
                },
                icon: const Icon(
                  Icons.smart_toy,
                  size: 16,
                ),
                label: const Text(
                  'Consultar IA',
                  style: TextStyle(
                    fontSize: 12,
                  ),
                ),
                style:
                OutlinedButton.styleFrom(
                  foregroundColor:
                  const Color(
                    0xFF1565C0,
                  ),
                  side:
                  const BorderSide(
                    color: Color(
                      0xFF1565C0,
                    ),
                  ),
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius
                        .circular(
                      10,
                    ),
                  ),
                  padding:
                  EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BADGE DE ESTADO
  // ============================================================

  Widget _estadoBadge(
      String estado,
      ) {
    final estadoLower =
    estado.toLowerCase();

    Color color;
    Color fondo;
    IconData icono;

    if (estadoLower ==
        'óptimo' ||
        estadoLower == 'optimo' ||
        estadoLower == 'saludable') {
      color =
      const Color(0xFF2E7D32);
      fondo =
      const Color(0xFFE8F5E9);
      icono =
          Icons.check_circle;
    } else if (estadoLower ==
        'atención' ||
        estadoLower == 'atencion') {
      color =
      const Color(0xFFE65100);
      fondo =
      const Color(0xFFFFF3E0);
      icono =
          Icons.warning_amber_rounded;
    } else if (estadoLower ==
        'crítico' ||
        estadoLower == 'critico') {
      color =
      const Color(0xFFC62828);
      fondo =
      const Color(0xFFFFEBEE);
      icono =
          Icons.error;
    } else {
      color =
          Colors.grey.shade700;
      fondo =
          Colors.grey.shade100;
      icono =
          Icons.info_outline;
    }

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration:
      BoxDecoration(
        color: fondo,
        borderRadius:
        BorderRadius.circular(
          20,
        ),
      ),
      child: Row(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Icon(
            icono,
            size: 13,
            color: color,
          ),
          const SizedBox(
            width: 4,
          ),
          Text(
            estado,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}


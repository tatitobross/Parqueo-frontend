import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

class EntryScreen extends StatefulWidget {
  final AuthService auth;

  const EntryScreen({super.key, required this.auth});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  bool _busy = true;
  bool _saving = false;
  List<dynamic> _vehicles = [];
  List<dynamic> _spaces = [];
  List<dynamic> _rates = [];
  dynamic _vehicle;
  dynamic _space;
  dynamic _rate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final responses = await Future.wait([
        widget.auth.api.get('/vehiculos?por_pagina=100'),
        widget.auth.api.get('/espacios?estado=disponible&por_pagina=100'),
        widget.auth.api.get('/tarifas?por_pagina=100'),
        widget.auth.api.get('/entradas?activas=true&por_pagina=100'),
      ]);
      if (!mounted) return;
      setState(() {
        final occupiedVehicleIds = _items(responses[3]).map((item) => item['vehiculo_id']).toSet();
        _vehicles = _items(responses[0]).where((item) => !occupiedVehicleIds.contains(item['id'])).toList();
        _spaces = _items(responses[1]);
        _rates = _items(responses[2]);
      });
    } on ApiException catch (error) {
      if (mounted) _message(error.message);
    } catch (error) {
      if (mounted) _message('No fue posible cargar los datos: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<dynamic> _items(dynamic response) {
    final data = response is Map ? response['data'] : response;
    return data is Map && data['data'] is List
        ? List<dynamic>.from(data['data'])
        : data is List
            ? List<dynamic>.from(data)
            : [];
  }

  Future<void> _save() async {
    if (_vehicle == null || _space == null || _rate == null) {
      _message('Selecciona vehículo, espacio y tarifa.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.auth.api.post('/entradas', {
        'vehiculo_id': _vehicle['id'],
        'parqueo_id': _space['id'],
        'tarifa_id': _rate['id'],
      });
      if (!mounted) return;
      _message('Entrada registrada correctamente.');
      setState(() {
        _vehicle = null;
        _space = null;
        _rate = null;
      });
      _load();
    } on ApiException catch (error) {
      _message(error.message);
    } catch (error) {
      _message('No se pudo registrar la entrada: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (_busy && _vehicles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Registrar entrada', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('El sistema valida vehículos y espacios disponibles.'),
        const SizedBox(height: 24),
        DropdownButtonFormField<dynamic>(
          value: _vehicle,
          decoration: const InputDecoration(labelText: 'Vehículo'),
          items: _vehicles
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text('${item['placa']} · ${item['marca'] ?? ''}'),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _vehicle = value),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<dynamic>(
          value: _space,
          decoration: const InputDecoration(labelText: 'Espacio disponible'),
          items: _spaces
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item['codigo'].toString()),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _space = value),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<dynamic>(
          value: _rate,
          decoration: const InputDecoration(labelText: 'Tarifa'),
          items: _rates
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item['nombre'].toString()),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _rate = value),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login),
          label: const Text('Registrar entrada'),
        ),
      ],
    );
  }
}

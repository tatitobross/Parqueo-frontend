import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

class VehicleScreen extends StatefulWidget {
  final AuthService auth;
  final bool readOnly;

  const VehicleScreen({super.key, required this.auth, this.readOnly = false});

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  final _search = TextEditingController();
  List<dynamic> _vehicles = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final query = _search.text.trim();
      final suffix = query.isEmpty ? '' : '&buscar=${Uri.encodeQueryComponent(query)}';
      final result = await widget.auth.api.get('/vehiculos?por_pagina=100$suffix');
      if (!mounted) return;
      setState(() {
        _vehicles = List<dynamic>.from(result['data'] as List);
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([Map<String, dynamic>? vehicle]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => VehicleFormDialog(auth: widget.auth, vehicle: vehicle),
    );
    if (saved == true) _load();
  }

  Future<void> _openDetails(Map<String, dynamic> vehicle) async {
    Map<String, dynamic> detail = vehicle;
    try {
      final result = await widget.auth.api.get('/vehiculos/${vehicle['id']}');
      detail = Map<String, dynamic>.from(result['data'] as Map);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    }
    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      builder: (_) => VehicleDetailsDialog(vehicle: detail, canEdit: !widget.readOnly, canDelete: widget.auth.user!.isAdmin),
    );
    if (action == 'edit') {
      await _openForm(detail);
    }
    if (action == 'delete') {
      await _delete(detail);
    }
  }

  Future<void> _delete(Map<String, dynamic> vehicle) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar vehículo'),
        content: Text('¿Eliminar el vehículo ${vehicle['placa']}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      await widget.auth.api.delete('/vehiculos/${vehicle['id']}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vehículo eliminado.')));
      _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onSubmitted: (_) => _load(),
                  decoration: InputDecoration(
                    labelText: 'Buscar por placa, marca o modelo',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _load,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (!widget.readOnly) FilledButton.icon(onPressed: () => _openForm(), icon: const Icon(Icons.add), label: const Text('Nuevo')),
            ],
          ),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_loading && _vehicles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_vehicles.isEmpty) {
      return const Center(child: Text('No hay vehículos registrados.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _vehicles.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, index) {
          final vehicle = Map<String, dynamic>.from(_vehicles[index] as Map);
          final client = vehicle['cliente'] is Map
              ? Map<String, dynamic>.from(vehicle['cliente'] as Map)
              : <String, dynamic>{};
          final clientName = '${client['nombre'] ?? ''} ${client['apellido'] ?? ''}'.trim();
          return ListTile(
            leading: CircleAvatar(child: Text(vehicle['placa'].toString().substring(0, 1))),
            title: Text('${vehicle['placa']} · ${vehicle['marca']} ${vehicle['modelo']}'),
            subtitle: Text('$clientName · ${vehicle['tipo'] ?? 'automovil'}'),
            trailing: Icon(
              vehicle['activo'] == true ? Icons.check_circle : Icons.cancel,
              color: vehicle['activo'] == true ? Colors.green : Colors.grey,
            ),
            onTap: () => _openDetails(vehicle),
          );
        },
      ),
    );
  }
}

class VehicleDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> vehicle;
  final bool canEdit;
  final bool canDelete;

  const VehicleDetailsDialog({super.key, required this.vehicle, required this.canEdit, required this.canDelete});

  @override
  Widget build(BuildContext context) {
    final client = vehicle['cliente'] is Map
        ? Map<String, dynamic>.from(vehicle['cliente'] as Map)
        : <String, dynamic>{};
    final rows = <MapEntry<String, String>>[
      MapEntry('Placa', vehicle['placa']?.toString() ?? '-'),
      MapEntry('Marca', vehicle['marca']?.toString() ?? '-'),
      MapEntry('Modelo', vehicle['modelo']?.toString() ?? '-'),
      MapEntry('Año', vehicle['anio']?.toString() ?? '-'),
      MapEntry('Color', vehicle['color']?.toString() ?? '-'),
      MapEntry('Tipo', vehicle['tipo']?.toString() ?? '-'),
      MapEntry('Cliente', '${client['nombre'] ?? ''} ${client['apellido'] ?? ''}'.trim()),
      MapEntry('Estado', vehicle['activo'] == true ? 'Activo' : 'Inactivo'),
    ];
    return AlertDialog(
      title: const Text('Detalle del vehículo'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: rows
              .map((row) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(row.key),
                    trailing: Text(row.value),
                  ))
              .toList(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        if (canDelete) TextButton(onPressed: () => Navigator.pop(context, 'delete'), child: const Text('Eliminar')),
        if (canEdit) FilledButton(onPressed: () => Navigator.pop(context, 'edit'), child: const Text('Editar')),
      ],
    );
  }
}

class VehicleFormDialog extends StatefulWidget {
  final AuthService auth;
  final Map<String, dynamic>? vehicle;

  const VehicleFormDialog({super.key, required this.auth, this.vehicle});

  @override
  State<VehicleFormDialog> createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends State<VehicleFormDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _plate;
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _year;
  late final TextEditingController _color;
  List<dynamic> _clients = [];
  int? _clientId;
  String _type = 'automovil';
  bool _active = true;
  bool _loadingClients = true;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    final vehicle = widget.vehicle;
    _plate = TextEditingController(text: vehicle?['placa']?.toString() ?? '');
    _brand = TextEditingController(text: vehicle?['marca']?.toString() ?? '');
    _model = TextEditingController(text: vehicle?['modelo']?.toString() ?? '');
    _year = TextEditingController(text: vehicle?['anio']?.toString() ?? '');
    _color = TextEditingController(text: vehicle?['color']?.toString() ?? '');
    _clientId = vehicle?['cliente_id'] as int?;
    _type = vehicle?['tipo']?.toString() ?? 'automovil';
    _active = vehicle?['activo'] != false;
    _loadClients();
  }

  @override
  void dispose() {
    _plate.dispose();
    _brand.dispose();
    _model.dispose();
    _year.dispose();
    _color.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    try {
      final result = await widget.auth.api.get('/clientes?por_pagina=100');
      if (mounted) setState(() => _clients = List<dynamic>.from(result['data'] as List));
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loadingClients = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _clientId == null) {
      setState(() => _error = _clientId == null ? 'Selecciona un cliente.' : null);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final payload = <String, dynamic>{
      'cliente_id': _clientId,
      'placa': _plate.text.trim(),
      'marca': _brand.text.trim(),
      'modelo': _model.text.trim(),
      'anio': _year.text.trim().isEmpty ? null : int.tryParse(_year.text.trim()),
      'color': _color.text.trim().isEmpty ? null : _color.text.trim(),
      'tipo': _type,
      'activo': _active,
    };
    try {
      if (_editing) {
        await widget.auth.api.put('/vehiculos/${widget.vehicle!['id']}', payload);
      } else {
        await widget.auth.api.post('/vehiculos', payload);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editing ? 'Actualizar vehículo' : 'Registrar vehículo'),
      content: SizedBox(
        width: 460,
        child: _loadingClients
            ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        value: _clientId,
                        decoration: const InputDecoration(labelText: 'Cliente'),
                        items: _clients.map((item) {
                          final client = Map<String, dynamic>.from(item as Map);
                          return DropdownMenuItem(
                            value: client['id'] as int,
                            child: Text('${client['nombre']} ${client['apellido']}'),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _clientId = value),
                      ),
                      TextFormField(
                        controller: _plate,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'Placa'),
                        validator: (value) => value == null || value.trim().isEmpty ? 'La placa es obligatoria.' : null,
                      ),
                      TextFormField(
                        controller: _brand,
                        decoration: const InputDecoration(labelText: 'Marca'),
                        validator: (value) => value == null || value.trim().isEmpty ? 'La marca es obligatoria.' : null,
                      ),
                      TextFormField(
                        controller: _model,
                        decoration: const InputDecoration(labelText: 'Modelo'),
                        validator: (value) => value == null || value.trim().isEmpty ? 'El modelo es obligatorio.' : null,
                      ),
                      TextFormField(
                        controller: _year,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Año (opcional)'),
                        validator: (value) => value != null && value.isNotEmpty && int.tryParse(value) == null ? 'Escribe un año válido.' : null,
                      ),
                      TextFormField(
                        controller: _color,
                        decoration: const InputDecoration(labelText: 'Color (opcional)'),
                      ),
                      DropdownButtonFormField<String>(
                        value: _type,
                        decoration: const InputDecoration(labelText: 'Tipo'),
                        items: const [
                          DropdownMenuItem(value: 'automovil', child: Text('Automóvil')),
                          DropdownMenuItem(value: 'motocicleta', child: Text('Motocicleta')),
                          DropdownMenuItem(value: 'camioneta', child: Text('Camioneta')),
                          DropdownMenuItem(value: 'otro', child: Text('Otro')),
                        ],
                        onChanged: (value) => setState(() => _type = value!),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Vehículo activo'),
                        value: _active,
                        onChanged: (value) => setState(() => _active = value),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _saving || _loadingClients ? null : _save,
          child: Text(_saving ? 'Guardando...' : (_editing ? 'Actualizar' : 'Guardar')),
        ),
      ],
    );
  }
}

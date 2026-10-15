import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

enum FormFieldType { text, number, email, date, password, select, toggle }

class CrudField {
  final String key;
  final String label;
  final FormFieldType type;
  final bool required;
  final List<MapEntry<String, String>> options;
  final String? optionsEndpoint;
  final String Function(Map<String, dynamic>)? optionLabel;

  const CrudField({
    required this.key,
    required this.label,
    this.type = FormFieldType.text,
    this.required = false,
    this.options = const [],
    this.optionsEndpoint,
    this.optionLabel,
  });
}

class CrudModuleScreen extends StatefulWidget {
  final AuthService auth;
  final String endpoint;
  final String title;
  final String Function(Map<String, dynamic>) itemTitle;
  final String Function(Map<String, dynamic>) itemSubtitle;
  final List<CrudField> fields;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;

  const CrudModuleScreen({
    super.key,
    required this.auth,
    required this.endpoint,
    required this.title,
    required this.itemTitle,
    required this.itemSubtitle,
    required this.fields,
    this.canCreate = true,
    this.canEdit = true,
    this.canDelete = true,
  });

  @override
  State<CrudModuleScreen> createState() => _CrudModuleScreenState();
}

class _CrudModuleScreenState extends State<CrudModuleScreen> {
  final _search = TextEditingController();
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CrudModuleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endpoint != widget.endpoint) {
      _items = [];
      _error = null;
      _load();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final search = _search.text.trim();
      final suffix = search.isEmpty ? '' : '&buscar=${Uri.encodeQueryComponent(search)}';
      final result = await widget.auth.api.get('/${widget.endpoint}?por_pagina=100$suffix');
      if (!mounted) return;
      setState(() {
        _items = _records(result);
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> _records(dynamic payload) {
    if (payload is List) return List<dynamic>.from(payload);
    if (payload is Map) {
      final data = payload['data'];
      if (data is List) return List<dynamic>.from(data);
      if (data is Map) return _records(data);
    }
    return [];
  }

  Future<void> _form([Map<String, dynamic>? item]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => CrudFormDialog(
        auth: widget.auth,
        endpoint: widget.endpoint,
        title: widget.title,
        fields: widget.fields,
        item: item,
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _show(Map<String, dynamic> listItem) async {
    Map<String, dynamic> item = listItem;
    try {
      final result = await widget.auth.api.get('/${widget.endpoint}/${listItem['id']}');
      item = Map<String, dynamic>.from(result['data'] as Map);
    } on ApiException catch (error) {
      // El listado ya contiene los campos del espacio, tarifa o cliente.
      // Mostrarlo permite consultar el detalle aun si el servidor se reinició.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mostrando datos cargados: ${error.message}')),
        );
      }
    }
    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      builder: (_) => CrudDetailsDialog(title: widget.title, fields: widget.fields, item: item, canEdit: widget.canEdit, canDelete: widget.canDelete),
    );
    if (action == 'edit' && widget.canEdit) await _form(item);
    if (action == 'delete' && widget.canDelete) await _delete(item);
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Eliminar ${widget.title.toLowerCase()}'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton.tonal(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (delete != true) return;
    try {
      await widget.auth.api.delete('/${widget.endpoint}/${item['id']}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registro eliminado.')));
      _load();
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _search,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  labelText: 'Buscar ${widget.title.toLowerCase()}',
                  suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _load),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (widget.canCreate) FilledButton.icon(onPressed: () => _form(), icon: const Icon(Icons.add), label: const Text('Nuevo')),
          ]),
        ),
        Expanded(child: _content()),
      ],
    );
  }

  Widget _content() {
    if (_loading && _items.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    if (_items.isEmpty) return Center(child: Text('No hay ${widget.title.toLowerCase()} registrados.'));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, index) {
          final item = Map<String, dynamic>.from(_items[index] as Map);
          return ListTile(
            title: Text(widget.itemTitle(item)),
            subtitle: Text(widget.itemSubtitle(item)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _show(item),
          );
        },
      ),
    );
  }
}

class CrudDetailsDialog extends StatelessWidget {
  final String title;
  final List<CrudField> fields;
  final Map<String, dynamic> item;
  final bool canEdit;
  final bool canDelete;

  const CrudDetailsDialog({super.key, required this.title, required this.fields, required this.item, required this.canEdit, required this.canDelete});

  String _value(CrudField field) {
    final raw = item[field.key];
    if (field.type == FormFieldType.toggle) return raw == true ? 'Sí' : 'No';
    if (field.key == 'role_id' && item['role'] != null) return item['role'].toString();
    return raw?.toString().isNotEmpty == true ? raw.toString() : '-';
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Detalle de $title'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: fields
                  .where((field) => field.type != FormFieldType.password)
                  .map((field) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(field.label),
                        trailing: Text(_value(field)),
                      ))
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
          if (canDelete) TextButton(onPressed: () => Navigator.pop(context, 'delete'), child: const Text('Eliminar')),
          if (canEdit) FilledButton(onPressed: () => Navigator.pop(context, 'edit'), child: const Text('Editar')),
        ],
      );
}

class CrudFormDialog extends StatefulWidget {
  final AuthService auth;
  final String endpoint;
  final String title;
  final List<CrudField> fields;
  final Map<String, dynamic>? item;

  const CrudFormDialog({super.key, required this.auth, required this.endpoint, required this.title, required this.fields, this.item});

  @override
  State<CrudFormDialog> createState() => _CrudFormDialogState();
}

class _CrudFormDialogState extends State<CrudFormDialog> {
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _values = {};
  final Map<String, List<Map<String, dynamic>>> _remoteOptions = {};
  bool _loadingOptions = true;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.item != null;

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      final value = widget.item?[field.key];
      if (field.type == FormFieldType.toggle) {
        _values[field.key] = value != false;
      } else if (field.type == FormFieldType.select) {
        _values[field.key] = value?.toString();
      } else {
        _controllers[field.key] = TextEditingController(text: value?.toString() ?? '');
      }
    }
    _loadOptions();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      for (final field in widget.fields.where((field) => field.optionsEndpoint != null)) {
        final result = await widget.auth.api.get('${field.optionsEndpoint}?por_pagina=100');
        final data = result['data'];
        _remoteOptions[field.key] = data is Map
            ? List<Map<String, dynamic>>.from((data['data'] as List).map((item) => Map<String, dynamic>.from(item as Map)))
            : List<Map<String, dynamic>>.from((data as List).map((item) => Map<String, dynamic>.from(item as Map)));
      }
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  dynamic _payloadValue(CrudField field) {
    if (field.type == FormFieldType.toggle) return _values[field.key] == true;
    if (field.type == FormFieldType.select) {
      final value = _values[field.key];
      return field.optionsEndpoint == null ? value : int.tryParse(value?.toString() ?? '');
    }
    final value = _controllers[field.key]!.text.trim();
    if (field.type == FormFieldType.number) return value.isEmpty ? null : num.tryParse(value);
    return value.isEmpty ? null : value;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final data = <String, dynamic>{};
    for (final field in widget.fields) {
      final value = _payloadValue(field);
      if (_editing && field.type == FormFieldType.password && value == null) continue;
      if (value == null && !field.required) continue;
      data[field.key] = value;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_editing) {
        await widget.auth.api.put('/${widget.endpoint}/${widget.item!['id']}', data);
      } else {
        await widget.auth.api.post('/${widget.endpoint}', data);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<DropdownMenuItem<String>> _selectItems(CrudField field) {
    if (field.optionsEndpoint == null) {
      return field.options.map((option) => DropdownMenuItem(value: option.key, child: Text(option.value))).toList();
    }
    return (_remoteOptions[field.key] ?? []).map((option) {
      return DropdownMenuItem(value: option['id'].toString(), child: Text(field.optionLabel!(option)));
    }).toList();
  }

  Widget _field(CrudField field) {
    if (field.type == FormFieldType.toggle) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(field.label),
        value: _values[field.key] == true,
        onChanged: (value) => setState(() => _values[field.key] = value),
      );
    }
    if (field.type == FormFieldType.select) {
      return DropdownButtonFormField<String>(
        value: _values[field.key],
        isExpanded: true,
        decoration: InputDecoration(labelText: field.label),
        items: _selectItems(field),
        onChanged: (value) => setState(() => _values[field.key] = value),
        validator: field.required ? (value) => value == null ? '${field.label} es obligatorio.' : null : null,
      );
    }
    return TextFormField(
      controller: _controllers[field.key],
      obscureText: field.type == FormFieldType.password,
      keyboardType: field.type == FormFieldType.number ? TextInputType.number : field.type == FormFieldType.email ? TextInputType.emailAddress : field.type == FormFieldType.date ? TextInputType.datetime : TextInputType.text,
      decoration: InputDecoration(labelText: '${field.label}${field.type == FormFieldType.password && _editing ? ' (dejar vacío para conservar)' : ''}'),
      validator: (value) {
        if (field.required && !(_editing && field.type == FormFieldType.password) && (value == null || value.trim().isEmpty)) return '${field.label} es obligatorio.';
        if (field.type == FormFieldType.email && value != null && value.isNotEmpty && !value.contains('@')) return 'Correo inválido.';
        if (field.type == FormFieldType.number && value != null && value.isNotEmpty && num.tryParse(value) == null) return 'Número inválido.';
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(_editing ? 'Actualizar ${widget.title}' : 'Nuevo ${widget.title}'),
        content: SizedBox(
          width: 460,
          child: _loadingOptions
              ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))
              : SingleChildScrollView(
                  child: Form(
                    key: _form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...widget.fields.map((field) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _field(field))),
                        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ],
                    ),
                  ),
                ),
        ),
        actions: [
          TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: _saving || _loadingOptions ? null : _save, child: Text(_saving ? 'Guardando...' : 'Guardar')),
        ],
      );
}

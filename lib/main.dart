import 'package:flutter/material.dart';
import 'models/auth_user.dart';
import 'screens/dashboard_screen.dart';
import 'screens/crud_module_screen.dart';
import 'screens/entry_screen.dart';
import 'screens/exit_screen.dart';
import 'screens/login_screen.dart';
import 'screens/list_screen.dart';
import 'screens/vehicle_screen.dart';
import 'services/auth_service.dart';

void main() => runApp(const ParkingApp());

class ParkingApp extends StatefulWidget {
  const ParkingApp({super.key});
  @override
  State<ParkingApp> createState() => _ParkingAppState();
}

class _ParkingAppState extends State<ParkingApp> {
  final _auth = AuthService();
  @override
  void dispose() { _auth.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Parqueo Jasmyn',
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff0b5d8b)), useMaterial3: true),
    home: ListenableBuilder(listenable: _auth, builder: (_, __) => _auth.isAuthenticated ? Shell(auth: _auth) : LoginScreen(auth: _auth)),
  );
}

class Shell extends StatefulWidget {
  final AuthService auth;
  const Shell({super.key, required this.auth});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  String _title = 'Dashboard';
  Widget? _content;
  @override
  void initState() { super.initState(); _content = DashboardScreen(auth: widget.auth); }
  void _open(String title, Widget screen) { setState(() { _title = title; _content = screen; }); Navigator.pop(context); }
  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user!;
    return Scaffold(appBar: AppBar(title: Text(_title)), drawer: _Drawer(user: user, onOpen: _open, onLogout: widget.auth.logout, auth: widget.auth), body: _content);
  }
}

class _Drawer extends StatelessWidget {
  final AuthUser user;
  final AuthService auth;
  final void Function(String, Widget) onOpen;
  final Future<void> Function() onLogout;
  const _Drawer({required this.user, required this.auth, required this.onOpen, required this.onLogout});
  Widget _item(BuildContext context, IconData icon, String title, Widget screen) => ListTile(leading: Icon(icon), title: Text(title), onTap: () => onOpen(title, screen));
  @override
  Widget build(BuildContext context) => Drawer(child: SafeArea(child: ListView(children: [
    UserAccountsDrawerHeader(accountName: Text(user.greeting), accountEmail: Text('${user.email}\n${user.role ?? "Sin rol"}'), currentAccountPicture: const CircleAvatar(child: Icon(Icons.person))),
    _item(context, Icons.dashboard_outlined, 'Dashboard', DashboardScreen(auth: auth)),
    const Divider(),
    _item(context, Icons.people_outline, 'Clientes', _clientes(auth, user.isReadOnly)),
    _item(context, Icons.directions_car_outlined, 'Vehículos', VehicleScreen(auth: auth, readOnly: user.isReadOnly)),
    _item(context, Icons.login, 'Entradas', ListScreen(auth: auth, endpoint: 'entradas?activas=true', title: 'Entradas')),
    _item(context, Icons.logout, 'Salidas', ListScreen(auth: auth, endpoint: 'salidas', title: 'Salidas')),
    if (!user.isReadOnly) ...[
      const Divider(),
      _item(context, Icons.add_road, 'Registrar entrada', EntryScreen(auth: auth)),
      _item(context, Icons.exit_to_app, 'Registrar salida', ExitScreen(auth: auth)),
    ],
    if (user.isAdmin || user.isReadOnly || user.role == 'Operador') ...[
      const Divider(),
      _item(context, Icons.local_parking_outlined, 'Espacios', _espacios(auth, !user.isAdmin)),
      _item(context, Icons.sell_outlined, 'Tarifas', _tarifas(auth, !user.isAdmin)),
    ],
    if (user.isAdmin) ...[
      const Divider(),
      _item(context, Icons.manage_accounts_outlined, 'Usuarios', _usuarios(auth)),
    ],
    const Divider(),
    ListTile(leading: const Icon(Icons.logout), title: const Text('Cerrar sesión'), onTap: () async { Navigator.pop(context); await onLogout(); }),
  ])));

  static CrudModuleScreen _clientes(AuthService auth, bool readOnly) => CrudModuleScreen(
    auth: auth, endpoint: 'clientes', title: 'Clientes',
    itemTitle: (x) => '${x['nombre']} ${x['apellido']}',
    itemSubtitle: (x) => '${x['documento']} · ${x['telefono']}',
    canDelete: auth.user!.isAdmin,
    canCreate: !readOnly,
    canEdit: !readOnly,
    fields: const [
      CrudField(key: 'nombre', label: 'Nombre', required: true),
      CrudField(key: 'apellido', label: 'Apellido', required: true),
      CrudField(key: 'documento', label: 'Documento', required: true),
      CrudField(key: 'telefono', label: 'Teléfono', required: true),
      CrudField(key: 'correo', label: 'Correo', type: FormFieldType.email),
      CrudField(key: 'activo', label: 'Cliente activo', type: FormFieldType.toggle),
    ],
  );

  static CrudModuleScreen _espacios(AuthService auth, bool readOnly) => CrudModuleScreen(
    auth: auth, endpoint: 'espacios', title: 'Espacios',
    itemTitle: (x) => x['codigo'].toString(),
    itemSubtitle: (x) => '${x['zona']} · ${x['estado']}',
    canCreate: !readOnly,
    canEdit: !readOnly,
    canDelete: !readOnly,
    fields: const [
      CrudField(key: 'codigo', label: 'Código', required: true),
      CrudField(key: 'zona', label: 'Zona', required: true),
      CrudField(key: 'tipo', label: 'Tipo', type: FormFieldType.select, options: [
        MapEntry('automovil', 'Automóvil'), MapEntry('motocicleta', 'Motocicleta'), MapEntry('discapacitado', 'Discapacitado'), MapEntry('carga', 'Carga'), MapEntry('otro', 'Otro'),
      ]),
      CrudField(key: 'estado', label: 'Estado', type: FormFieldType.select, options: [
        MapEntry('disponible', 'Disponible'), MapEntry('ocupado', 'Ocupado'), MapEntry('reservado', 'Reservado'), MapEntry('mantenimiento', 'Mantenimiento'),
      ]),
      CrudField(key: 'tarifa_hora', label: 'Tarifa por hora', type: FormFieldType.number),
      CrudField(key: 'activo', label: 'Espacio activo', type: FormFieldType.toggle),
    ],
  );

  static CrudModuleScreen _tarifas(AuthService auth, bool readOnly) => CrudModuleScreen(
    auth: auth, endpoint: 'tarifas', title: 'Tarifas',
    itemTitle: (x) => x['nombre'].toString(),
    itemSubtitle: (x) => 'L ${x['precio_hora']} por hora',
    canCreate: !readOnly,
    canEdit: !readOnly,
    canDelete: !readOnly,
    fields: const [
      CrudField(key: 'nombre', label: 'Nombre', required: true),
      CrudField(key: 'precio_hora', label: 'Precio por hora', type: FormFieldType.number, required: true),
      CrudField(key: 'cobro_minimo', label: 'Cobro mínimo', type: FormFieldType.number),
      CrudField(key: 'minutos_cortesia', label: 'Minutos de cortesía', type: FormFieldType.number),
      CrudField(key: 'activa', label: 'Tarifa activa', type: FormFieldType.toggle),
    ],
  );

  static CrudModuleScreen _usuarios(AuthService auth) => CrudModuleScreen(
    auth: auth, endpoint: 'usuarios', title: 'Usuarios',
    itemTitle: (x) => '${x['name'] ?? 'Usuario'} (${x['username'] ?? x['id']})',
    itemSubtitle: (x) => '${x['role'] ?? 'Sin rol'} · ${x['status'] ?? 'Sin estado'}',
    fields: [
      CrudField(key: 'username', label: 'Usuario', required: true),
      CrudField(key: 'name', label: 'Nombre completo', required: true),
      CrudField(key: 'email', label: 'Correo', type: FormFieldType.email, required: true),
      CrudField(key: 'gender', label: 'Género', required: true),
      CrudField(key: 'birth', label: 'Fecha de nacimiento', type: FormFieldType.date, required: true),
      CrudField(key: 'role_id', label: 'Rol', type: FormFieldType.select, required: true, optionsEndpoint: '/roles', optionLabel: _roleName),
      CrudField(key: 'status', label: 'Estado', type: FormFieldType.select, required: true, options: [MapEntry('active', 'Activo'), MapEntry('inactive', 'Inactivo')]),
      CrudField(key: 'password', label: 'Contraseña', type: FormFieldType.password, required: true),
    ],
  );

  static String _roleName(Map<String, dynamic> role) => role['role'].toString();
}

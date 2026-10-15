import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class DashboardScreen extends StatefulWidget { final AuthService auth; const DashboardScreen({super.key, required this.auth}); @override State<DashboardScreen> createState() => _DashboardScreenState(); }
class _DashboardScreenState extends State<DashboardScreen> { Map<String, dynamic>? _data; String? _error; @override void initState() { super.initState(); _load(); }
 Future<void> _load() async { try { final result = await widget.auth.api.get('/dashboard'); if (mounted) setState(() { _data = Map<String, dynamic>.from(result['data'] as Map); _error = null; }); } on ApiException catch (e) { if (mounted) setState(() => _error = e.message); } }
 @override Widget build(BuildContext context) { if (_data == null && _error == null) return const Center(child: CircularProgressIndicator()); if (_error != null) return Center(child: FilledButton(onPressed: _load, child: Text(_error!))); final d = _data!; return RefreshIndicator(onRefresh: _load, child: GridView.count(padding: const EdgeInsets.all(16), crossAxisCount: MediaQuery.of(context).size.width > 650 ? 3 : 2, crossAxisSpacing: 12, mainAxisSpacing: 12, children: [_card(Icons.payments, 'Ingresos hoy', 'L ${d['ingresos_hoy']}'), _card(Icons.directions_car, 'Entradas activas', '${d['entradas_activas']}'), _card(Icons.local_parking, 'Disponibles', '${d['espacios_disponibles']}'), _card(Icons.no_transfer_outlined, 'Ocupados', '${d['espacios_ocupados']}'), _card(Icons.logout, 'Salidas hoy', '${d['salidas_hoy']}')])); }
 Widget _card(IconData icon, String title, String value) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon), Text(title), Text(value, style: Theme.of(context).textTheme.headlineSmall)])));
}

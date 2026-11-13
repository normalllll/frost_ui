// Dedicated native validation entrypoint. Never installed in a consuming App.
// The harness owns launch/capture and supplies saved values over arguments;
// this app does not read or write any persistence.
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:material_ui/material_ui.dart';
import 'package:frost_ui/frost_ui.dart';

final _window = FrostWindowController(minimumSize: const Size(640, 480));
final _marker = GlobalKey();
final _model = ValueNotifier<(int, String)>((1, 'Prepared while hidden'));
late FrostWindowPlacementResult _prepared;

Future<void> main(List<String> arguments) async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Test-only: initial route focus can ask Flutter's native view to activate.
  // Background geometry/capture needs no keyboard focus or focus simulation.
  FocusManager.instance.rootScope.canRequestFocus = false;
  FrostWindowPlacement? saved;
  for (final arg in arguments) {
    if (arg.startsWith('--placement=')) {
      saved = FrostWindowPlacement.fromMap(jsonDecode(utf8.decode(base64Url.decode(arg.substring(12)))) as Map<String, dynamic>);
    }
  }
  _prepared = await _window.prepare(saved: saved);
  developer.registerExtension('ext.frostWindowPlacementProbe', (_, args) async {
    try {
      final command = args['command'];
      if (command == 'show') await _window.show();
      if (command == 'minimize') await _window.minimize();
      if (command == 'move') {
        final environment = await _window.queryEnvironment();
        final next = validateFrostWindow(FrostWindowPlacement(displayId: environment.target().id, rect: const Rect.fromLTWH(70, 65, 840, 540)), environment);
        await _window.applyPlacement(next.placement);
      }
      if (command == 'close') {
        await _window.close();
        return developer.ServiceExtensionResponse.result('{}');
      }
      _model.value = (
        _model.value.$1 + 1,
        command == 'show'
            ? 'First visible frame'
            : command == 'move'
            ? 'App supplied placement applied'
            : 'Native geometry queried',
      );
      binding.scheduleFrame();
      await binding.endOfFrame;
      final geometry = await _window.queryGeometry();
      final environment = await _window.queryEnvironment();
      final box = _marker.currentContext!.findRenderObject()! as RenderBox;
      final origin = box.localToGlobal(Offset.zero);
      return developer.ServiceExtensionResponse.result(
        jsonEncode({
          'placement': geometry.placement.toMap(),
          'frame': [geometry.frame.left, geometry.frame.top, geometry.frame.right, geometry.frame.bottom],
          'positionSupport': geometry.positionSupport.name,
          'minimized': geometry.minimized,
          'maximized': _window.state.maximized,
          'adjustments': _prepared.adjustments.map((a) => a.name).toList(),
          'expected': _prepared.placement.toMap(),
          'displays': environment.displays
              .map(
                (d) => {
                  'id': d.id,
                  'scale': d.scale,
                  'coordinateScale': d.coordinateScale,
                  'workArea': [d.workArea.left, d.workArea.top, d.workArea.right, d.workArea.bottom],
                },
              )
              .toList(),
          'probe': {
            'token': _model.value.$1,
            'rect': {'x': origin.dx, 'y': origin.dy, 'width': box.size.width, 'height': box.size.height},
            'pixelRatio': View.of(_marker.currentContext!).devicePixelRatio,
          },
        }),
      );
    } catch (error, stack) {
      developer.log('Placement probe failed', error: error, stackTrace: stack);
      return developer.ServiceExtensionResponse.error(developer.ServiceExtensionResponse.extensionError, '$error');
    }
  });
  runApp(const _ProbeApp());
  await binding.waitUntilFirstFrameRasterized;
  // Deliberately wait for the owned harness to establish background Z-order
  // before it calls show. No native or framework input is injected.
  developer.log('F5C_PLACEMENT_PROBE_READY');
}

class _ProbeApp extends StatelessWidget {
  const _ProbeApp();
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    home: Scaffold(
      backgroundColor: const Color(0xff1b1c20),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ValueListenableBuilder(
          valueListenable: _model,
          builder: (context, phase, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomPaint(key: _marker, size: const Size(192, 12), painter: _Marker(phase.$1)),
              const SizedBox(height: 24),
              const Text('Frost Window · F5c native placement', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Text(phase.$2, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 16),
              Text('Startup adjustments: ${_prepared.adjustments.map((a) => a.name).join(', ')}'),
              const SizedBox(height: 16),
              ValueListenableBuilder(
                valueListenable: _window.geometry,
                builder: (_, geometry, _) => Text(
                  'Normal placement: ${geometry?.placement.rect}\nMaximized: ${geometry?.placement.maximized}\nDisplay: ${geometry?.placement.displayId}\nPosition: ${geometry?.positionSupport.name}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 24),
              const Text('App-owned values in, native state out. No library persistence.'),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Marker extends CustomPainter {
  _Marker(this.token);
  final int token;
  @override
  void paint(Canvas canvas, Size size) {
    final word = (0xa << 28) | (token << 4) | 5;
    for (var bit = 0; bit < 32; bit++) {
      final one = ((word >> (31 - bit)) & 1) != 0;
      canvas.drawRect(
        Rect.fromLTWH(bit * size.width / 32, 0, size.width / 32, size.height),
        Paint()..color = one ? const Color(0xfff0b429) : const Color(0xff16324f),
      );
    }
  }

  @override
  bool shouldRepaint(_Marker oldDelegate) => oldDelegate.token != token;
}

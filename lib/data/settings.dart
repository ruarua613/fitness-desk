import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 轻量设置存储：一个 JSON 文件，不引入额外插件。
class Settings {
  Map<String, dynamic> _data = {};

  int get activePlanId => (_data['activePlanId'] as num?)?.toInt() ?? 0;

  set activePlanId(int v) {
    _data['activePlanId'] = v;
    _flush();
  }

  double get incrementKg =>
      ((_data['incrementKg'] as num?)?.toDouble() ?? 2.5).clamp(0.25, 50);

  set incrementKg(double v) {
    _data['incrementKg'] = v;
    _flush();
  }

  Future<void> load() async {
    try {
      final file = await _file;
      if (await file.exists()) {
        _data = Map<String, dynamic>.from(jsonDecode(await file.readAsString()));
      }
    } catch (_) {
      _data = {};
    }
  }

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'settings.json'));
  }

  Future<void> _flush() async {
    try {
      final file = await _file;
      await file.writeAsString(jsonEncode(_data));
    } catch (_) {
      // 设置写不进去不影响主流程
    }
  }
}

/// 日期与数值的小工具。不依赖任何第三方包。

String dateKey(DateTime d) =>
    '${d.year}-${_pad(d.month)}-${_pad(d.day)}';

String _pad(int v) => v.toString().padLeft(2, '0');

String todayKey() => dateKey(DateTime.now());

/// 1 = 周一 … 7 = 周日（Dart 的 DateTime.weekday 就是这个口径）
int weekdayIndex(DateTime d) => d.weekday;

const kWeekdayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

String weekdayLabel(int index) =>
    (index >= 1 && index <= 7) ? kWeekdayLabels[index - 1] : '—';

/// 本周周一（日期键）
String weekStartKey([DateTime? d]) {
  final x = d ?? DateTime.now();
  return dateKey(x.subtract(Duration(days: x.weekday - 1)));
}

DateTime? parseDateKey(String key) {
  final p = key.split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

String shortDate(String key) {
  final d = parseDateKey(key);
  if (d == null) return key;
  return '${d.month}/${d.day}';
}

/// 今天 / 昨天 / 前天 / M/D
String friendlyDate(String key) {
  final d = parseDateKey(key);
  if (d == null) return key;
  final now = DateTime.now();
  final diff = DateTime(now.year, now.month, now.day)
      .difference(DateTime(d.year, d.month, d.day))
      .inDays;
  if (diff == 0) return '今天';
  if (diff == 1) return '昨天';
  if (diff == 2) return '前天';
  if (diff > 2 && diff < 7) return '$diff 天前';
  return shortDate(key);
}

String fmtWeight(double? v) {
  if (v == null || v <= 0) return '—';
  final r = (v * 10).round() / 10;
  return r == r.roundToDouble() ? '${r.toInt()}' : '$r';
}

String fmtQty(double? v) {
  if (v == null) return '—';
  final r = (v * 100).round() / 100;
  return r == r.roundToDouble() ? '${r.toInt()}' : '$r';
}

String fmtInt(int? v) => v == null ? '—' : '$v';

double? parseDouble(String? s) {
  if (s == null) return null;
  final t = s.trim();
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

int? parseInt(String? s) {
  final v = parseDouble(s);
  return v?.round();
}

/// 日程表里排在今天之后的下一个训练日（用于「下次练什么」）
int nextTrainingIndex(List<int> dayIndexes, int today) {
  if (dayIndexes.isEmpty) return today;
  final sorted = [...dayIndexes]..sort();
  for (final i in sorted) {
    if (i > today) return i;
  }
  return sorted.first;
}

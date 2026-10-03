import '../data/models.dart';
import '../data/repository.dart';

/*
 * 渐进建议引擎 —— 规则来自 Lzheng-fitness knowledge/03
 *  推进：所有工作组达到次数上限 且 末组 RPE ≤ 7 → 加一个最小重量单位
 *  止损：连续两次同重量掉次数，或同组次 RPE 上升约一级 → 维持，先查恢复与技术
 *  单次异常不改周期结构
 */

enum SuggestionLevel { increase, hold, calibrate }

class Suggestion {
  final SuggestionLevel level;
  final String tag;
  final double? weight;
  final int reps;
  final String reason;

  const Suggestion({
    required this.level,
    required this.tag,
    this.weight,
    required this.reps,
    required this.reason,
  });
}

List<SetLog> _workSets(List<SetLog> sets) =>
    sets.where((s) => !s.isWarmup && (s.reps ?? 0) > 0).toList(growable: false);

double _maxWeight(Iterable<SetLog> sets) =>
    sets.fold(0.0, (m, s) => s.weight != null && s.weight! > m ? s.weight! : m);

int _topReps(Iterable<SetLog> sets) =>
    sets.fold(0, (m, s) => (s.reps ?? 0) > m ? (s.reps ?? 0) : m);

double? _lastRpe(List<SetLog> sets) {
  for (var i = sets.length - 1; i >= 0; i--) {
    final v = sets[i].rpe;
    if (v != null && v > 0) return v;
  }
  return null;
}

double? _avgRpe(List<SetLog> sets) {
  final xs = sets.map((s) => s.rpe).where((v) => v != null && v! > 0).cast<double>().toList();
  if (xs.isEmpty) return null;
  return xs.reduce((a, b) => a + b) / xs.length;
}

Suggestion suggestNext(
  List<ExerciseHistory> history,
  Prescription prescription, {
  double increment = 2.5,
}) {
  final setCount = prescription.setCount;
  final repsMax = prescription.repsMax;
  final repsMin = prescription.repsMin;

  final played = history
      .map((h) => MapEntry(h.date, _workSets(h.sets)))
      .where((e) => e.value.isNotEmpty)
      .toList();

  if (played.isEmpty) {
    return Suggestion(
      level: SuggestionLevel.calibrate,
      tag: '首次校准',
      weight: null,
      reps: repsMin,
      reason: '还没有记录。先按最低次数做一组轻重量试组，动作稳定后逐档加重，找到今天的工作重量。',
    );
  }

  final last = played.last;
  final wLast = _maxWeight(last.value);
  final rLast = _topReps(last.value);
  final rpeLast = _lastRpe(last.value);
  final enoughSets = last.value.length >= setCount;
  final allHitCeiling =
      last.value.isNotEmpty && last.value.every((s) => (s.reps ?? 0) >= repsMax);

  if (allHitCeiling && enoughSets && (rpeLast == null || rpeLast <= 7)) {
    return Suggestion(
      level: SuggestionLevel.increase,
      tag: '可以加重',
      weight: _round(wLast + increment),
      reps: repsMin,
      reason: '上次 ${last.value.length} 组全部达到 $repsMax 次上限'
          '${rpeLast != null ? '，末组 RPE ${_fmt(rpeLast)}' : ''}。'
          '下次加一个最小单位，先从 $repsMin 次重新往上补。',
    );
  }

  if (played.length > 1) {
    final prev = played[played.length - 2];
    final wPrev = _maxWeight(prev.value);
    final rPrev = _topReps(prev.value);
    final rpePrev = _avgRpe(prev.value);
    final sameLoadBand = (wLast - wPrev).abs() <= increment * 0.6 && wLast > 0;
    final repsDropped = rPrev - rLast >= 2;
    final rpeCreep = rpePrev != null &&
        _avgRpe(last.value) != null &&
        _avgRpe(last.value)! - rpePrev >= 1;

    if (sameLoadBand && (repsDropped || rpeCreep)) {
      return Suggestion(
        level: SuggestionLevel.hold,
        tag: '先维持',
        weight: wLast,
        reps: rLast < repsMin ? repsMin : rLast,
        reason: (repsDropped
                ? '连续两次在同一重量上次数下降（$rPrev → $rLast）。'
                : '同样重量下 RPE 抬了约一级。') +
            '先维持这个载荷，核对睡眠、压力和动作质量；单次异常不必改计划。',
      );
    }
  }

  var nextReps = (rLast == 0 ? repsMin : rLast) + 1;
  if (nextReps > repsMax) nextReps = repsMax;
  if (nextReps < repsMin) nextReps = repsMin;

  return Suggestion(
    level: SuggestionLevel.hold,
    tag: '继续补次数',
    weight: wLast > 0 ? wLast : null,
    reps: nextReps,
    reason: '上次 ${wLast > 0 ? '${_fmt(wLast)}kg × $rLast 次' : '$rLast 次'}，'
        '还没到 $repsMax 次上限。保持重量，先把次数往上补一格。',
  );
}

/// 每次训练的峰值重量，用于画曲线
class ProgressPoint {
  final String date;
  final double weight;
  final double volume;
  final double? rpe;

  const ProgressPoint({
    required this.date,
    required this.weight,
    required this.volume,
    this.rpe,
  });
}

List<ProgressPoint> progressionSeries(List<ExerciseHistory> history) {
  final out = <ProgressPoint>[];
  for (final h in history) {
    final sets = _workSets(h.sets);
    if (sets.isEmpty) continue;
    final w = _maxWeight(sets);
    final reps = sets.fold<int>(0, (a, s) => a + (s.reps ?? 0));
    out.add(ProgressPoint(
      date: h.date,
      weight: w,
      volume: w * reps,
      rpe: _lastRpe(sets),
    ));
  }
  return out;
}

double _round(double v) => (v * 100).round() / 100;

String _fmt(double v) {
  final r = (v * 10).round() / 10;
  return r == r.roundToDouble() ? '${r.toInt()}' : '$r';
}

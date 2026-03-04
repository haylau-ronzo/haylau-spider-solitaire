enum DailyDealStatus { notStarted, inProgress, completed }

class DailyCompletionMetrics {
  const DailyCompletionMetrics({
    required this.score,
    required this.timeSeconds,
    required this.moves,
    required this.undos,
    required this.hints,
  });

  final int score;
  final int timeSeconds;
  final int moves;
  final int undos;
  final int hints;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'score': score,
      'timeSeconds': timeSeconds,
      'moves': moves,
      'undos': undos,
      'hints': hints,
    };
  }

  static DailyCompletionMetrics fromJson(Map<String, dynamic> json) {
    return DailyCompletionMetrics(
      score: (json['score'] as num?)?.toInt() ?? 0,
      timeSeconds: (json['timeSeconds'] as num?)?.toInt() ?? 0,
      moves: (json['moves'] as num?)?.toInt() ?? 0,
      undos: (json['undos'] as num?)?.toInt() ?? 0,
      hints: (json['hints'] as num?)?.toInt() ?? 0,
    );
  }
}

class DailyDealRecord {
  const DailyDealRecord({
    required this.dateKeyLocal,
    required this.status,
    this.completedAt,
    this.metrics,
  });

  final String dateKeyLocal;
  final DailyDealStatus status;
  final DateTime? completedAt;
  final DailyCompletionMetrics? metrics;

  DailyDealRecord copyWith({
    String? dateKeyLocal,
    DailyDealStatus? status,
    DateTime? completedAt,
    DailyCompletionMetrics? metrics,
    bool clearCompletedAt = false,
    bool clearMetrics = false,
  }) {
    return DailyDealRecord(
      dateKeyLocal: dateKeyLocal ?? this.dateKeyLocal,
      status: status ?? this.status,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      metrics: clearMetrics ? null : (metrics ?? this.metrics),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'dateKeyLocal': dateKeyLocal,
      'status': status.name,
      'completedAt': completedAt?.toIso8601String(),
      'metrics': metrics?.toJson(),
    };
  }

  static DailyDealRecord fromJson(Map<String, dynamic> json) {
    final statusName =
        (json['status'] as String?) ?? DailyDealStatus.notStarted.name;
    final status = DailyDealStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => DailyDealStatus.notStarted,
    );
    final completedAtRaw = json['completedAt'] as String?;
    return DailyDealRecord(
      dateKeyLocal: (json['dateKeyLocal'] as String?) ?? '',
      status: status,
      completedAt: completedAtRaw == null
          ? null
          : DateTime.tryParse(completedAtRaw),
      metrics: (json['metrics'] as Map<String, dynamic>?) == null
          ? null
          : DailyCompletionMetrics.fromJson(
              json['metrics'] as Map<String, dynamic>,
            ),
    );
  }
}

class DailyDealsModel {
  const DailyDealsModel({required this.recordsByDateKey});

  final Map<String, DailyDealRecord> recordsByDateKey;

  static const empty = DailyDealsModel(
    recordsByDateKey: <String, DailyDealRecord>{},
  );

  DailyDealsModel copyWith({Map<String, DailyDealRecord>? recordsByDateKey}) {
    return DailyDealsModel(
      recordsByDateKey: recordsByDateKey ?? this.recordsByDateKey,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'recordsByDateKey': recordsByDateKey.map(
        (key, value) => MapEntry<String, dynamic>(key, value.toJson()),
      ),
    };
  }

  static DailyDealsModel fromJson(Map<String, dynamic> json) {
    final rawMap = json['recordsByDateKey'] as Map<String, dynamic>?;
    if (rawMap == null) {
      return empty;
    }

    final mapped = <String, DailyDealRecord>{};
    rawMap.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        mapped[key] = DailyDealRecord.fromJson(value);
      } else if (value is Map) {
        mapped[key] = DailyDealRecord.fromJson(
          Map<String, dynamic>.from(value),
        );
      }
    });
    return DailyDealsModel(recordsByDateKey: mapped);
  }
}

enum AmlCaseKind { sanctionsHit, velocity, limitBreach }

class AmlCase {
  final String id;
  final DateTime createdAt;
  final AmlCaseKind kind;
  final String subject;
  final String details;
  final String status; // Open, Cleared

  const AmlCase({
    required this.id,
    required this.createdAt,
    required this.kind,
    required this.subject,
    required this.details,
    this.status = 'Open',
  });

  String get kindLabel {
    switch (kind) {
      case AmlCaseKind.sanctionsHit:
        return 'Sanctions hit';
      case AmlCaseKind.velocity:
        return 'Velocity flag';
      case AmlCaseKind.limitBreach:
        return 'Limit breach';
    }
  }

  AmlCase copyWith({String? status}) => AmlCase(
    id: id,
    createdAt: createdAt,
    kind: kind,
    subject: subject,
    details: details,
    status: status ?? this.status,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'kind': kind.index,
    'subject': subject,
    'details': details,
    'status': status,
  };

  factory AmlCase.fromJson(Map<String, dynamic> json) => AmlCase(
    id: json['id'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    kind: AmlCaseKind.values[json['kind'] as int],
    subject: json['subject'] as String,
    details: json['details'] as String,
    status: json['status'] as String,
  );
}

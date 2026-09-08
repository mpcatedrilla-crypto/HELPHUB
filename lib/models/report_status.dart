enum ReportStatus {
  submitted('submitted', 'SUBMITTED'),
  acknowledged('acknowledged', 'ACKNOWLEDGED'),
  inProgress('in_progress', 'IN PROGRESS'),
  resolved('resolved', 'RESOLVED'),
  referred('referred', 'REFERRED'),
  falseAlarm('false_alarm', 'FALSE ALARM'),
  closed('closed', 'CLOSED'),
  archived('archived', 'ARCHIVED');

  const ReportStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static ReportStatus fromDatabase(Object? value) {
    final raw = value?.toString().trim().toLowerCase();
    return switch (raw) {
      'acknowledged' || 'under_review' => ReportStatus.acknowledged,
      'in_progress' || 'responding' => ReportStatus.inProgress,
      'resolved' || 'pending_confirmation' => ReportStatus.resolved,
      'referred' => ReportStatus.referred,
      'false_alarm' => ReportStatus.falseAlarm,
      'closed' || 'rejected' => ReportStatus.closed,
      'archived' => ReportStatus.archived,
      _ => ReportStatus.submitted,
    };
  }

  bool get isActive => switch (this) {
    submitted || acknowledged || inProgress => true,
    _ => false,
  };

  bool get isCompleted => switch (this) {
    resolved || referred || falseAlarm || closed => true,
    _ => false,
  };

  bool get isTerminal => switch (this) {
    referred || falseAlarm || closed || archived => true,
    _ => false,
  };

  Set<ReportStatus> get validNextStatuses => switch (this) {
    submitted => const {ReportStatus.acknowledged},
    acknowledged => const {ReportStatus.inProgress},
    inProgress => const {
      ReportStatus.resolved,
      ReportStatus.referred,
      ReportStatus.falseAlarm,
    },
    resolved || referred || falseAlarm => const {ReportStatus.closed},
    closed => const {ReportStatus.archived},
    archived => const {},
  };

  bool canTransitionTo(ReportStatus next) => validNextStatuses.contains(next);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:helphub/models/report_status.dart';

void main() {
  group('ReportStatus', () {
    test('normalizes legacy database values', () {
      expect(ReportStatus.fromDatabase('responding'), ReportStatus.inProgress);
      expect(
        ReportStatus.fromDatabase('under_review'),
        ReportStatus.acknowledged,
      );
      expect(
        ReportStatus.fromDatabase('pending_confirmation'),
        ReportStatus.resolved,
      );
    });

    test('classifies queue buckets consistently', () {
      expect(ReportStatus.submitted.isActive, isTrue);
      expect(ReportStatus.inProgress.isActive, isTrue);
      expect(ReportStatus.referred.isActive, isFalse);
      expect(ReportStatus.referred.isCompleted, isTrue);
      expect(ReportStatus.archived.isCompleted, isFalse);
      expect(ReportStatus.archived.isTerminal, isTrue);
    });

    test('exposes canonical resident-facing labels', () {
      expect(ReportStatus.submitted.label, 'SUBMITTED');
      expect(ReportStatus.acknowledged.label, 'ACKNOWLEDGED');
      expect(ReportStatus.inProgress.label, 'IN PROGRESS');
      expect(ReportStatus.falseAlarm.label, 'FALSE ALARM');
    });

    test('allows only canonical lifecycle transitions', () {
      expect(ReportStatus.submitted.validNextStatuses, {
        ReportStatus.acknowledged,
      });
      expect(ReportStatus.inProgress.validNextStatuses, {
        ReportStatus.resolved,
        ReportStatus.referred,
        ReportStatus.falseAlarm,
      });
      expect(
        ReportStatus.referred.canTransitionTo(ReportStatus.closed),
        isTrue,
      );
      expect(
        ReportStatus.closed.canTransitionTo(ReportStatus.archived),
        isTrue,
      );
      expect(
        ReportStatus.submitted.canTransitionTo(ReportStatus.resolved),
        isFalse,
      );
      expect(ReportStatus.archived.validNextStatuses, isEmpty);
    });
  });
}

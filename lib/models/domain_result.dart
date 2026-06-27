enum DomainResultStatus { pending, success, skipped, failed }

class DomainResult {
  const DomainResult({
    required this.domain,
    this.status = DomainResultStatus.pending,
    this.message,
    this.zoneId,
  });

  final String domain;
  final DomainResultStatus status;
  final String? message;
  final String? zoneId;

  DomainResult copyWith({
    DomainResultStatus? status,
    String? message,
    String? zoneId,
  }) {
    return DomainResult(
      domain: domain,
      status: status ?? this.status,
      message: message ?? this.message,
      zoneId: zoneId ?? this.zoneId,
    );
  }
}

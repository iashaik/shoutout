/// Document status enum representing Frappe's docstatus field
///
/// Frappe documents follow a state machine:
/// - Draft (0): Editable, not yet finalized
/// - Submitted (1): Locked, creates GL entries, audit trail enabled
/// - Cancelled (2): Reversed, can be amended to create new version
enum DocStatus {
  /// Draft document - editable, no accounting impact
  draft(0),

  /// Submitted document - locked, accounting entries created
  submitted(1),

  /// Cancelled document - reversed, can be amended
  cancelled(2);

  /// The integer value used by Frappe API
  final int value;

  const DocStatus(this.value);

  /// Create DocStatus from integer value
  factory DocStatus.fromValue(int value) {
    return DocStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => throw ArgumentError('Invalid docstatus value: $value'),
    );
  }

  /// Check if document can be submitted
  bool get canSubmit => this == DocStatus.draft;

  /// Check if document can be cancelled
  bool get canCancel => this == DocStatus.submitted;

  /// Check if document can be amended
  bool get canAmend => this == DocStatus.cancelled;

  /// Check if document is editable
  bool get isEditable => this == DocStatus.draft;

  /// Human-readable label
  String get label {
    switch (this) {
      case DocStatus.draft:
        return 'Draft';
      case DocStatus.submitted:
        return 'Submitted';
      case DocStatus.cancelled:
        return 'Cancelled';
    }
  }

  @override
  String toString() => 'DocStatus.$name($value)';
}

/// Extension to parse docstatus from dynamic values
extension DocStatusParser on dynamic {
  /// Parse docstatus from API response (can be int or String)
  DocStatus toDocStatus() {
    if (this == null) return DocStatus.draft;
    if (this is int) return DocStatus.fromValue(this as int);
    if (this is String) {
      final intValue = int.tryParse(this as String);
      if (intValue != null) return DocStatus.fromValue(intValue);
    }
    return DocStatus.draft;
  }
}

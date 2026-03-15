/// MOT test history from the UKVD MotHistoryDetails data block.
class MotHistory {
  final String? motDueDate;
  final String? latestTestDate;
  final int? daysSinceLastMot;
  final List<MotTest> tests;

  MotHistory({
    this.motDueDate,
    this.latestTestDate,
    this.daysSinceLastMot,
    this.tests = const [],
  });

  bool get isOverdue {
    if (motDueDate == null) return false;
    final due = DateTime.tryParse(motDueDate!);
    if (due == null) return false;
    return DateTime.now().isAfter(due);
  }

  int get totalPasses => tests.where((t) => t.passed).length;
  int get totalFailures => tests.where((t) => !t.passed).length;

  factory MotHistory.fromApiJson(Map<String, dynamic> json) {
    final testList = json['MotTestDetailsList'] as List<dynamic>? ?? [];
    return MotHistory(
      motDueDate: json['MotDueDate']?.toString(),
      latestTestDate: json['LatestTestDate']?.toString(),
      daysSinceLastMot: json['DaysSinceLastMot'] as int?,
      tests: testList.map((t) => MotTest.fromApiJson(t as Map<String, dynamic>)).toList(),
    );
  }

  factory MotHistory.fromStoredJson(Map<String, dynamic> json) {
    final testList = json['tests'] as List<dynamic>? ?? [];
    return MotHistory(
      motDueDate: json['mot_due_date'],
      latestTestDate: json['latest_test_date'],
      daysSinceLastMot: json['days_since_last_mot'] as int?,
      tests: testList.map((t) => MotTest.fromStoredJson(t as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'mot_due_date': motDueDate,
    'latest_test_date': latestTestDate,
    'days_since_last_mot': daysSinceLastMot,
    'tests': tests.map((t) => t.toJson()).toList(),
  };
}

class MotTest {
  final String? testDate;
  final bool passed;
  final String? expiryDate;
  final String? odometerReading;
  final String? odometerUnit;
  final String? testNumber;
  final bool isRetest;
  final List<MotDefect> defects;

  MotTest({
    this.testDate,
    this.passed = false,
    this.expiryDate,
    this.odometerReading,
    this.odometerUnit,
    this.testNumber,
    this.isRetest = false,
    this.defects = const [],
  });

  String get mileageDisplay {
    if (odometerReading == null || odometerReading!.isEmpty) return 'N/A';
    return '$odometerReading ${odometerUnit ?? 'mi'}';
  }

  factory MotTest.fromApiJson(Map<String, dynamic> json) {
    final annotations = json['AnnotationList'] as List<dynamic>? ?? [];
    return MotTest(
      testDate: json['TestDate']?.toString(),
      passed: json['TestPassed'] as bool? ?? false,
      expiryDate: json['ExpiryDate']?.toString(),
      odometerReading: json['OdometerReading']?.toString(),
      odometerUnit: json['OdometerUnit']?.toString(),
      testNumber: json['TestNumber']?.toString(),
      isRetest: json['IsRetest'] as bool? ?? false,
      defects: annotations.map((a) => MotDefect.fromApiJson(a as Map<String, dynamic>)).toList(),
    );
  }

  factory MotTest.fromStoredJson(Map<String, dynamic> json) {
    final defectList = json['defects'] as List<dynamic>? ?? [];
    return MotTest(
      testDate: json['test_date'],
      passed: json['passed'] as bool? ?? false,
      expiryDate: json['expiry_date'],
      odometerReading: json['odometer_reading'],
      odometerUnit: json['odometer_unit'],
      testNumber: json['test_number'],
      isRetest: json['is_retest'] as bool? ?? false,
      defects: defectList.map((d) => MotDefect.fromStoredJson(d as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'test_date': testDate,
    'passed': passed,
    'expiry_date': expiryDate,
    'odometer_reading': odometerReading,
    'odometer_unit': odometerUnit,
    'test_number': testNumber,
    'is_retest': isRetest,
    'defects': defects.map((d) => d.toJson()).toList(),
  };
}

class MotDefect {
  final String? type;
  final String? text;
  final bool isDangerous;

  MotDefect({this.type, this.text, this.isDangerous = false});

  bool get isFailure => type == 'Major' || type == 'Dangerous' || type == 'FAIL';
  bool get isAdvisory => type == 'Advisory' || type == 'ADVISORY';

  factory MotDefect.fromApiJson(Map<String, dynamic> json) => MotDefect(
    type: json['Type']?.toString(),
    text: json['Text']?.toString(),
    isDangerous: json['IsDangerous'] as bool? ?? false,
  );

  factory MotDefect.fromStoredJson(Map<String, dynamic> json) => MotDefect(
    type: json['type'],
    text: json['text'],
    isDangerous: json['is_dangerous'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'type': type,
    'text': text,
    'is_dangerous': isDangerous,
  };
}

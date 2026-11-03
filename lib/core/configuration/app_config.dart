/// DEV/PROD settings for the app.
///
/// None of these values are secrets. Never put a client secret, password
/// or token in this file.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.tenantId,
    required this.clientId,
    required this.siteId,
    required this.employeesListId,
    required this.pocTestListId,
    required this.tasksListId,
  });

  final String environment;
  final String tenantId;
  final String clientId;
  final String siteId;
  final String employeesListId;
  final String pocTestListId;

  /// IT_Tasks list id. Empty until the admin creates the list (AdminSetup-DEV.md, Part H).
  final String tasksListId;

  /// ITDMP-DEV. Values come from docs/Authentication.md.
  static const dev = AppConfig(
    environment: 'DEV',
    tenantId: 'de1751f9-e541-4dca-9fff-9366ccd7a998',
    clientId: 'ed45bfb6-e005-40ba-8522-a53359e2a8dc',
    siteId:
        'sqlacc.sharepoint.com,626945d6-16e9-4fdd-8ad3-993720800677,f601c7c7-e0ff-4907-b2b3-05941f3acecf',
    employeesListId: '1b0bf4f3-5ef8-4907-9b99-66231cd23e4b',
    pocTestListId: '93137a60-b271-41d6-b84c-8666faae6be4',
    tasksListId: '7d068025-e4b7-4641-a171-537ff03a440f',
  );

  /// Delegated scopes requested at sign-in. Keep this list minimal.
  /// Do not add tenant-wide scopes such as Sites.ReadWrite.All.
  static const scopes = <String>[
    'openid',
    'profile',
    'offline_access',
    'User.Read',
    'Sites.Selected',
  ];

  static const graphBaseUrl = 'https://graph.microsoft.com/v1.0';

  /// Tenant-specific sign-in address (single tenant app).
  String get authority => 'https://login.microsoftonline.com/$tenantId';
}

/// SharePoint internal field names.
/// Keep in sync with docs/SharePointSchema.md. Do not scatter these strings.
class SpFields {
  const SpFields._();

  // IT_Employees
  static const employeeId = 'EmployeeID';
  static const email = 'Email';
  static const entraObjectId = 'EntraObjectID';
  static const appRole = 'AppRole';
  static const isActive = 'IsActive';
  static const jobTitle = 'JobTitle';
  static const department = 'Department';
  static const joinDate = 'JoinDate';
  static const managerEmployeeId = 'ManagerEmployeeID';
  static const createdAtUtc = 'CreatedAtUTC';

  // IT_Tasks
  static const taskCode = 'TaskCode';
  static const description = 'Description';
  static const taskType = 'TaskType';
  static const assignedEmployeeId = 'AssignedEmployeeID';
  static const createdByEmployeeId = 'CreatedByEmployeeID';
  static const projectCode = 'ProjectCode';
  static const priority = 'Priority';
  static const status = 'Status';
  static const estimatedHours = 'EstimatedHours';
  static const revisedEstimatedHours = 'RevisedEstimatedHours';
  static const plannedStart = 'PlannedStart';
  static const expectedCompletion = 'ExpectedCompletion';
  static const actualStart = 'ActualStart';
  static const actualCompletion = 'ActualCompletion';
  static const progress = 'Progress';
  static const blockerRemarks = 'BlockerRemarks';
  static const completionRemarks = 'CompletionRemarks';
  static const documentationRequired = 'DocumentationRequired';
  static const documentationStatus = 'DocumentationStatus';
  static const reviewedByEmployeeId = 'ReviewedByEmployeeID';
  static const lastProgressUpdateUtc = 'LastProgressUpdateUTC';
  static const estimateRevisionReason = 'EstimateRevisionReason';
  static const estimateApprovedBy = 'EstimateApprovedBy';
  static const estimateApprovedAtUtc = 'EstimateApprovedAtUTC';
  static const proposedEstimatedHours = 'ProposedEstimatedHours';
  static const documentationRemarks = 'DocumentationRemarks';

  // Shared
  static const title = 'Title';

  // IT_PoC_Test
  static const testNote = 'TestNote';
  static const testStatus = 'TestStatus';
}

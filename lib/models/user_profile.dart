/// Identity of the signed-in Microsoft account, from Graph `/me`.
class UserProfile {
  const UserProfile({
    required this.objectId,
    required this.displayName,
    required this.userPrincipalName,
  });

  /// Entra Object ID. This is the key stored in IT_Employees.EntraObjectID.
  final String objectId;
  final String displayName;
  final String userPrincipalName;

  factory UserProfile.fromGraph(Map<String, dynamic> json) => UserProfile(
        objectId: json['id'] as String,
        displayName: (json['displayName'] ?? '').toString(),
        userPrincipalName: (json['userPrincipalName'] ?? '').toString(),
      );
}

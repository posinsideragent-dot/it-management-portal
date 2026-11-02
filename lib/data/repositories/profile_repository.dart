import '../../models/user_profile.dart';
import '../api/graph_client.dart';

/// Reads who the signed-in user is.
abstract interface class ProfileSource {
  Future<UserProfile> fetchMe();
}

class ProfileRepository implements ProfileSource {
  ProfileRepository(this._graph);

  final GraphClient _graph;

  @override
  Future<UserProfile> fetchMe() async {
    final json = await _graph.get(
      '/me',
      query: {r'$select': 'id,displayName,userPrincipalName'},
    );
    return UserProfile.fromGraph(json);
  }
}

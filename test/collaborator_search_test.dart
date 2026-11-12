import 'package:brainy/collaborator_search.dart';
import 'package:brainy/collaborators_api.dart';
import 'package:flutter_test/flutter_test.dart';

// Search among collaborators: name or e-mail, case and accents ignored, every word must match.
void main() {
  BrainyCollaborator person(String name, String email) => BrainyCollaborator(userId: email, name: name, email: email, since: DateTime(2026), hasPhoto: false);
  final people = [person('Éric Ndiaye', 'eric@example.test'), person('Awa Diallo', 'awa@example.test'), person('Bruno Kamga', 'bruno.k@example.test')];

  test('filters as you type', () {
    expect(filterCollaborators(people, 'ERIC').map((item) => item.name), ['Éric Ndiaye']);
    expect(filterCollaborators(people, 'bruno.k').map((item) => item.name), ['Bruno Kamga']);
    expect(filterCollaborators(people, 'awa diallo').length, 1);
    expect(filterCollaborators(people, 'awa kamga'), isEmpty);
    expect(filterCollaborators(people, '  ').length, 3);
  });
}

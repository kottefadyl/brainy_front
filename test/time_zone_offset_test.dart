import 'package:brainy/task_agenda_view.dart';
import 'package:flutter_test/flutter_test.dart';

// T49/2: a device zone Dart only knows by its offset still maps to an IANA zone the API accepts.
void main() {
  test('named zones are kept, whole hours use Etc/GMT, part hours use a matching zone', () {
    expect(zoneForOffset('Africa/Douala', const Duration(hours: 1)), 'Africa/Douala');
    expect(zoneForOffset('WAT', const Duration(hours: 1)), 'Etc/GMT-1');
    expect(zoneForOffset('EST', const Duration(hours: -5)), 'Etc/GMT+5');
    expect(zoneForOffset('GMT', Duration.zero), 'UTC');
    expect(zoneForOffset('India Standard Time', const Duration(hours: 5, minutes: 30)), 'Asia/Kolkata');
    expect(zoneForOffset('Nepal Standard Time', const Duration(hours: 5, minutes: 45)), 'Asia/Kathmandu');
    expect(zoneForOffset('NST', const Duration(hours: -3, minutes: -30)), 'America/St_Johns');
    expect(zoneForOffset('?', const Duration(hours: 2, minutes: 20)), 'UTC');
  });
}

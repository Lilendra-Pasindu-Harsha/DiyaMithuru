import 'package:diyamithuru/services/voice_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('voice commands are recognised', () {
    expect(VoiceService.parse('stop'), 'STOP');
    expect(VoiceService.parse('Turn it off please'), 'STOP');
    expect(VoiceService.parse('turn on'), 'ON');
    expect(VoiceService.parse('start'), 'ON');
    expect(VoiceService.parse('fill it up'), 'FILL');
    expect(VoiceService.parse("don't start, stop!"), 'STOP');
    expect(VoiceService.parse('hello there'), isNull);
    expect(VoiceService.parse('one'), isNull); // "one" is not "on"
  });
}

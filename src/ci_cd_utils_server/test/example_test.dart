
import 'package:ci_cd_utils_server/main.dart';
import 'package:test/test.dart';

Future main() async {
  test("diffs", () async {
    // A === Server
    // B === Client
    expect(calculateDifferenceBetweenNumbers(10, 5), -5);
    expect(calculateDifferenceBetweenNumbers(5, 10), 5);
    expect(calculateDifferenceBetweenNumbers(-10, -5), 5);
    expect(calculateDifferenceBetweenNumbers(-5, -10), -5);
    expect(calculateDifferenceBetweenNumbers(-10, 5), 15);
    expect(calculateDifferenceBetweenNumbers(5, -10), -15);
    expect(calculateDifferenceBetweenNumbers(10, -5), -15);
    expect(calculateDifferenceBetweenNumbers(-5, 10), 15);
  });
}

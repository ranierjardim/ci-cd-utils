import 'dart:convert';

import 'package:ci_cd_cmd_utils/ci_cd_cmd_utils.dart' as ci_cd_cmd_utils;

Future<void> main(List<String> arguments) async {
  ci_cd_cmd_utils.parse(arguments);
}

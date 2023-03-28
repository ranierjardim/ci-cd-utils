import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:dio/dio.dart';
import 'package:dolumns/dolumns.dart';
import 'package:eosdart_ecc/eosdart_ecc.dart';
import 'package:yaml/yaml.dart';

Future<void> parse(List<String> arguments) async {
  final parser = ArgParser();
  final googleOauth2TokenCommandParser = ArgParser();
  googleOauth2TokenCommandParser.addOption('serverAddress', abbr: 'a');
  googleOauth2TokenCommandParser.addOption('base64', abbr: 'b');
  googleOauth2TokenCommandParser.addOption('name', abbr: 'n', defaultsTo: 'default');
  parser.addCommand('google-oauth2-token', googleOauth2TokenCommandParser);
  final versionListCommandParser = ArgParser();
  versionListCommandParser.addOption('serverAddress', abbr: 'a');
  versionListCommandParser.addOption('base64', abbr: 'b');
  versionListCommandParser.addOption('app-id', abbr: 'i', defaultsTo: 'default');
  parser.addCommand('version-list', versionListCommandParser);
  final versionBuildNumberCommandParser = ArgParser();
  versionBuildNumberCommandParser.addOption('serverAddress', abbr: 'a');
  versionBuildNumberCommandParser.addOption('base64', abbr: 'b');
  versionBuildNumberCommandParser.addOption('version', abbr: 'v', mandatory: true);
  versionBuildNumberCommandParser.addOption('app-id', abbr: 'i', defaultsTo: 'default');
  parser.addCommand('version-build-number', versionBuildNumberCommandParser);
  final createKeysCommandParser = ArgParser();
  parser.addCommand('create-keys', createKeysCommandParser);
  final args = parser.parse(arguments);
  if (args.command == null) {
    print('You need to specify a command: google-oauth2-token, version-build-number, version-list or create-keys');
    exit(1);
  }
  final command = args.command!;
  if (command.name == 'create-keys') {
    final privateKey = EOSPrivateKey.fromRandom();
    final publicKey = privateKey.toEOSPublicKey();
    final columns = dolumnify([
      ['Type', 'Key'],
      ['Public', publicKey.toString()],
      ['Private', privateKey.toString()],
    ], columnSplitter: ' | ', headerIncluded: true, headerSeparator: '=');
    print('\n\nYour keys has been created, copy the public key into your server config file and the private key into the client config file: \n\n $columns');
  } else if ((command.name == 'google-oauth2-token') || (command.name == 'version-list') || (command.name == 'version-build-number')){
    if (command.name == 'version-build-number' && !command.options.contains('version')) {
      print('You need to specify the tag version using \'--version\'');
      exit(1);
    }
    String base64;
    final envvars = Platform.environment;
    if (command.options.contains('base64')) {
      base64 = command['base64'];
    } else if (envvars.containsKey('CI_CD_UTILS_CLIENT_CREDENTIALS_BASE64')) {
      base64 = envvars['CI_CD_UTILS_CLIENT_CREDENTIALS_BASE64']!;
    } else {
      print('You need to specify a credential type using \'--base64\' param or use CI_CD_UTILS_CLIENT_CREDENTIALS_BASE64 environment variable');
      exit(1);
    }
    final configDocument = loadYaml(utf8.decode(base64Decode(base64)));
    String serverAddress = configDocument['server']['address'];
    if(command.options.contains('serverAddress')) {
      serverAddress = command['serverAddress'];
    }
    final key = EOSPrivateKey.fromString(configDocument['server']['credentials']['key']);
    final requestTime = (DateTime.now().millisecondsSinceEpoch + configDocument['server']['credentials']['timeDiff'] as int).toString();
    final signature = key.signString('$requestTime.${configDocument['server']['credentials']['salt']}');
    final headers = {
      'Username': configDocument['server']['credentials']['user'],
      'Signature': signature.toString(),
      'RequestTime': requestTime,
    };
    final instance = Dio();
    if (command.name == 'google-oauth2-token') {
      final name = command['name'];
      final resposta = await instance.get(
        '$serverAddress/google/oauth2/token/fetch/$name',
        options: Options(
          headers: headers,
        ),
      );
      print(resposta.data['access_token']);
      exit(0);
    } else if (command.name == 'version-list') {
      final appId = command['app-id'];
      final resposta = await instance.get(
        '$serverAddress/version/$appId/list',
        options: Options(
          headers: headers,
        ),
      );
      final colunas = [
        ['Tag', 'Build Number'],
      ];
      print('resposta.data: ${resposta.data}');
      final List<dynamic> versoes = resposta.data["content"];
      for (final versao in versoes) {
        colunas.add([versao['tag'], versao['buildNumber'].toString()]);
      }
      final columns = dolumnify(colunas, columnSplitter: ' | ', headerIncluded: true, headerSeparator: '=');
      print('\n\nVersions and build numbers: \n\n $columns');
      exit(0);
    } else if (command.name == 'version-build-number') {
      final appId = command['app-id'];
      final version = command['version'];
      final resposta = await instance.get(
        '$serverAddress/version/$appId/$version',
        options: Options(
          headers: headers,
        ),
      );
      print(resposta.data['buildNumber']);
      exit(0);
    }
    exit(0);
  } else {
    print('You need to specify a command: google-oauth2-token, version-build-number, version-list or create-keys');
    exit(1);
  }
}

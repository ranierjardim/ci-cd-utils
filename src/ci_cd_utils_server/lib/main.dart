import 'dart:convert';
import 'dart:io';

import 'package:alfred/alfred.dart';
import 'package:args/args.dart';
import 'package:dio/dio.dart';
import 'package:eosdart_ecc/eosdart_ecc.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:yaml/yaml.dart';

late Db mongoDb;

late dynamic configDocument;

int calculateDifferenceBetweenNumbers(int a, int b) {
  if (a > b) {
    return (a - b) * -1;
  } else {
    return b - a;
  }
}

Future main(List<String> arguments) async {
  print('Starting...');
  final parser = ArgParser();
  final serveCommandParser = ArgParser();
  serveCommandParser.addOption('base64', abbr: 'b');
  parser.addCommand('serve', serveCommandParser);
  final args = parser.parse(arguments);
  if (args.command == null) {
    print('You need to specify a command: serve');
    exit(1);
  }
  final command = args.command!;
  String base64;
  final envvars = Platform.environment;
  if (command.options.contains('base64')) {
    base64 = command['base64'];
  } else if (envvars.containsKey('CI_CD_UTILS_SERVER_CREDENTIALS_BASE64')) {
    base64 = envvars['CI_CD_UTILS_SERVER_CREDENTIALS_BASE64']!;
  } else {
    print('You need to specify a credential type using \'--base64\' param or use CI_CD_UTILS_SERVER_CREDENTIALS_BASE64 environment variable');
    exit(1);
  }
  configDocument = loadYaml(utf8.decode(base64Decode(base64)));
  print('Connecting to database...');
  mongoDb = await Db.create(configDocument['mongodb']);
  await mongoDb.open();
  await mongoDb.createCollection('version_list');
  await mongoDb.createCollection('google_oauth_tokens');
  await mongoDb.createCollection('references');
  final app = Alfred();
  app.all('*', permissionHandler);
  app.get('/google/oauth2/token/fetch/:name', googleOauth2TokenFetchHandler);
  app.get('/version/:appId/list', getVersionListHandler);
  app.get('/version/:appId/:versionTag', getVersionBuildNumberHandler);
  print("Initializing server...");
  await app.listen(configDocument['port'] as int, '0.0.0.0', true, 0);
  print("Application started on port: ${app.server?.port}.");
  print("Use Ctrl-C (SIGINT) to stop running the application.");
}


Future<void> permissionHandler(HttpRequest request, HttpResponse response) async {
  final username = request.headers.value('Username');
  final signature = request.headers.value('Signature');
  final requestTime = request.headers.value('RequestTime');
  print('Username: $username');
  print('Signature: $signature');
  print('RequestTime: $requestTime');
  if (username == null || signature == null || requestTime == null) {
    print('Someone requested server without credentials');
    response.statusCode = 401;
    await response.send('Unauthorized');
    await response.close();
    return;
  }
  final List<dynamic> googleAuthList = configDocument['clients_credentials'];
  final userCredentials = await googleAuthList.firstWhere((element) => element['user'] == username, orElse: () => null);
  if (userCredentials == null) {
    print('User: $username not registered');
    response.statusCode = 401;
    await response.send('Unauthorized');
    await response.close();
    return;
  }
  final publicKey = userCredentials['public_key'];
  final singnatureObject = EOSSignature.fromString(signature);
  if (!singnatureObject.verify('$requestTime.${userCredentials['salt']}', EOSPublicKey.fromString(publicKey))) {
    print('User: $username invalid signature');
    response.statusCode = 401;
    await response.send('Unauthorized');
    await response.close();
    return;
  }
  final clientTime = int.parse(requestTime);
  print('clientTime: ${DateTime.now().millisecondsSinceEpoch}');
  final currentTime = DateTime.now().millisecondsSinceEpoch + userCredentials['timeDiff'] as int;
  print('server currentTime: ${DateTime.now().millisecondsSinceEpoch}');
  final difference = calculateDifferenceBetweenNumbers(clientTime, currentTime);
  print('difference: $difference');
  final signatureTimeout = int.parse(configDocument['signature_timeout'].toString());
  print('signatureTimeout: $signatureTimeout');
  if (difference > signatureTimeout || difference < signatureTimeout * -1) {
    print('User: $username token was expired');
    response.statusCode = 401;
    await response.send('Unauthorized');
    await response.close();
    return;
  }
  print('User: $username successfuly authenticated');
}


Future<void> googleOauth2TokenFetchHandler(HttpRequest request, HttpResponse response) async {
  final name = request.params['name'];
  final instance = Dio();
  final List<dynamic> googleAuthList = configDocument['credentials']['google-oauth'];
  final selectedCredential = await googleAuthList.firstWhere((element) => element['name'] == name, orElse: () => null);
  if (selectedCredential == null) {
    response.statusCode = 404;
    await response.send('Credentials not found');
    await response.close();
    return;
  }
  final googleOauthTokenCollection = mongoDb.collection('google_oauth_tokens');
  final storedAccessToken = await googleOauthTokenCollection.findOne({
    'name': name,
  });
  if (storedAccessToken != null) {
    final accessToken = storedAccessToken['access_token'];
    try {
      print('checking if the stored access_token still valid: $accessToken');
      final tokenValidResponse = await instance.get('https://oauth2.googleapis.com/tokeninfo?access_token=$accessToken', options: Options(validateStatus: (value) => true));
      // {
      //   "error": "invalid_token",
      //   "error_description": "Invalid Value"
      // }
      // -------
      // {
      //   "azp": "",
      //   "aud": "",
      //   "scope": "https://www.googleapis.com/auth/chromewebstore",
      //   "exp": "1679875401",
      //   "expires_in": "3560",
      //   "access_type": "offline"
      // }
      final requestResponse = tokenValidResponse.data as Map<String, dynamic>;
      print('Response from tokeninfo: ${jsonEncode(requestResponse)}');
      if (!requestResponse.containsKey('error') && int.parse(requestResponse['expires_in']) >= 600) {
        print('The last access_token still valid, sending it');
        await response.json({"access_token": accessToken});
      }
    } on DioError catch (_) {}
  }
  final resposta = await instance.post(
    'https://oauth2.googleapis.com/token',
    options: Options(
      headers: {
        "Authorization": selectedCredential['authorization'],
        "x-goog-api-version": "2",
      },
    ),
    data: {
      'client_id': selectedCredential['client_id'],
      'client_secret': selectedCredential['client_secret'],
      'refresh_token': selectedCredential['refresh_token'],
      'grant_type': 'refresh_token',
    },
  );
  final newDocument = {
    'name': name,
    'access_token': resposta.data['access_token'],
  };
  if (storedAccessToken != null) {
    await googleOauthTokenCollection.replaceOne(
      {
        'name': name,
      },
      newDocument,
    );
  } else {
    await googleOauthTokenCollection.insert(newDocument);
  }
  print('Retrieved the new access_token, sending it');
  await response.json({"access_token": resposta.data['access_token']});
}


Future<void> getVersionBuildNumberHandler(HttpRequest request, HttpResponse response) async {
  final appId = request.params['appId'];
  final versionTag = request.params['versionTag'];
  final versionListCollection = mongoDb.collection('version_list');
  final tagDb = await versionListCollection.findOne({
    'tag': versionTag,
    'app_id': appId,
  });
  int buildNumber;
  if (tagDb == null) {
    final referencesCollection = mongoDb.collection('references');
    final buildNumberReference = await referencesCollection.findOne({
      'type': 'build_number_reference',
      'app_id': appId,
    });
    if (buildNumberReference != null) {
      buildNumberReference['counter'] += 1;
      await referencesCollection.update(
        {
          'type': 'build_number_reference',
          'app_id': appId,
        },
        buildNumberReference,
      );
      buildNumber = buildNumberReference['counter'] as int;
    } else {
      await referencesCollection.insert(
        {
          'type': 'build_number_reference',
          'app_id': appId,
          'counter': 1,
        },
      );
      buildNumber = 1;
    }
    await versionListCollection.insert({
      'tag': versionTag,
      'app_id': appId,
      'buildNumber': buildNumber,
    });
  } else {
    buildNumber = tagDb['buildNumber'];
  }
  await response.json({"buildNumber": buildNumber});
}


Future<void> getVersionListHandler(HttpRequest request, HttpResponse response) async {
  final appId = request.params['appId'];
  final versionListCollection = mongoDb.collection('version_list');
  final lista = await versionListCollection.find({
    'app_id': appId,
  }).toList();
  await response.json({"content": lista});
}


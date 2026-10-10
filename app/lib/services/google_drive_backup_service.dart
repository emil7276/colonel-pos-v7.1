import 'dart:convert';
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class GoogleDriveBackupService {
  static const _backupFolderName = 'Colonel POS Backup';

  static const List<String> _scopes = <String>[
    drive.DriveApi.driveFileScope,
  ];

  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  static Future<void>? _initialized;

  static Future<void> _ensureInitialized() {
    return _initialized ??= _googleSignIn.initialize(serverClientId: '661221438084-dfuspmpaqm8tp56bsgmm5aifck9fbck5.apps.googleusercontent.com');
  }

  static Future<GoogleSignInAccount> _getAccount() async {
    await _ensureInitialized();

    if (!_googleSignIn.supportsAuthenticate()) {
      throw Exception(
        'Google Sign-In tidak didukung pada perangkat ini.',
      );
    }

    return _googleSignIn.authenticate();
  }

  static Future<List<drive.File>> listBackups() async {
    final account = await _getAccount();
    final authorization =
        await account.authorizationClient.authorizationForScopes(_scopes) ??
        await account.authorizationClient.authorizeScopes(_scopes);
    if (authorization.accessToken.isEmpty) {
      throw Exception('Token Google Drive tidak tersedia.');
    }
    final client = _GoogleAuthClient(authorization.accessToken);
    final api = drive.DriveApi(client);
    try {
      final folderId = await _findExistingBackupFolder(api);
      if (folderId == null) return <drive.File>[];
      final result = await api.files.list(
        q: "'$folderId' in parents and trashed = false",
        orderBy: 'createdTime desc',
        pageSize: 100,
        $fields: 'files(id,name,mimeType,createdTime,size)',
        spaces: 'drive',
      );
      return (result.files ?? <drive.File>[])
          .where((f) => f.id != null && (f.name ?? '').toLowerCase().endsWith('.json'))
          .toList();
    } finally {
      client.close();
    }
  }

  static Future<Uint8List> downloadBackup(String fileId) async {
    final account = await _getAccount();
    final authorization =
        await account.authorizationClient.authorizationForScopes(_scopes) ??
        await account.authorizationClient.authorizeScopes(_scopes);
    if (authorization.accessToken.isEmpty) {
      throw Exception('Token Google Drive tidak tersedia.');
    }
    final client = _GoogleAuthClient(authorization.accessToken);
    try {
      final response = await client.get(
        Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId?alt=media'),
      );
      if (response.statusCode != 200) {
        throw Exception('Unduh backup dari Google Drive gagal (HTTP ${response.statusCode}).');
      }
      return response.bodyBytes;
    } finally {
      client.close();
    }
  }

  static Future<String?> _findExistingBackupFolder(drive.DriveApi api) async {
    final result = await api.files.list(
      q: "name = '$_backupFolderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id,name)',
    );
    final files = result.files;
    if (files == null || files.isEmpty) return null;
    return files.first.id;
  }

  static Future<String> uploadBackup({
    required Map<String, dynamic> data,
  }) async {
    final account = await _getAccount();

    final authorization =
        await account.authorizationClient.authorizationForScopes(_scopes) ??
        await account.authorizationClient.authorizeScopes(_scopes);

    final accessToken = authorization.accessToken;

    if (accessToken.isEmpty) {
      throw Exception('Token Google Drive tidak tersedia.');
    }

    final client = _GoogleAuthClient(accessToken);
    final api = drive.DriveApi(client);

    try {
      final folderId = await _findOrCreateBackupFolder(api);

      final json = const JsonEncoder.withIndent('  ').convert(data);
      final bytes = Uint8List.fromList(utf8.encode(json));

      final fileName =
          'colonel_pos_backup_${DateTime.now().millisecondsSinceEpoch}.json';

      final metadata = drive.File()
        ..name = fileName
        ..mimeType = 'application/json'
        ..parents = [folderId];

      final media = drive.Media(
        Stream<List<int>>.value(bytes),
        bytes.length,
      );

      final uploaded = await api.files.create(
        metadata,
        uploadMedia: media,
        $fields: 'id,name',
      );

      if (uploaded.id == null) {
        throw Exception('Google Drive tidak mengembalikan ID file.');
      }

      return uploaded.name ?? fileName;
    } finally {
      client.close();
    }
  }

  static Future<String> _findOrCreateBackupFolder(
    drive.DriveApi api,
  ) async {
    final result = await api.files.list(
      q: "name = '$_backupFolderName' "
          "and mimeType = 'application/vnd.google-apps.folder' "
          "and trashed = false",
      spaces: 'drive',
      $fields: 'files(id,name)',
    );

    final files = result.files;

    if (files != null && files.isNotEmpty) {
      final id = files.first.id;
      if (id != null) return id;
    }

    final folder = drive.File()
      ..name = _backupFolderName
      ..mimeType = 'application/vnd.google-apps.folder';

    final created = await api.files.create(
      folder,
      $fields: 'id',
    );

    if (created.id == null) {
      throw Exception('Folder backup gagal dibuat.');
    }

    return created.id!;
  }

  static Future<void> signOut() async {
    await _ensureInitialized();
    await _googleSignIn.signOut();
  }
}

class _GoogleAuthClient extends http.BaseClient {
  final String accessToken;
  final http.Client _inner = http.Client();

  _GoogleAuthClient(this.accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $accessToken';
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}

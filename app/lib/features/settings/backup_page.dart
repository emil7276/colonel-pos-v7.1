import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../../core/app_localizations.dart';
import '../../core/widgets.dart';
import '../../data/database.dart';
import '../../services/google_drive_backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool working=false;

  Future<File> makeBackup() async {
    final data=await DB.backup();
    final dir=await getApplicationDocumentsDirectory();
    final file=File(path.join(dir.path,'colonel_pos_v65_backup_${DateTime.now().millisecondsSinceEpoch}.json'));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return file;
  }

  Future<void> backup() async {
    if(working) return;
    setState(()=>working=true);

    try {
      final data = await DB.backup();
      final bytes = utf8.encode(
        const JsonEncoder.withIndent('  ').convert(data),
      );

      final fileName =
          'colonel_pos_v65_backup_${DateTime.now().millisecondsSinceEpoch}.json';

      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: AppLocalizations.t(
          'Simpan Backup CP Colonel POS',
          'Save CP Colonel POS Backup',
        ),
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );

      if (!mounted) return;

      if (savedPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
          content: Text(
            AppLocalizations.t(
              'Backup dibatalkan.',
              'Backup cancelled.',
            ),
          ),
        ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
          content: Text(
            AppLocalizations.t(
              'Backup berhasil disimpan.',
              'Backup saved successfully.',
            ),
          ),
        ),
        );
      }
    } catch(e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
          content: Text(
            AppLocalizations.t(
              'Backup gagal: $e',
              'Backup failed: $e',
            ),
          ),
        ),
        );
      }
    } finally {
      if(mounted) setState(()=>working=false);
    }
  }

  Future<void> backupToGoogleDrive() async {
    if (working) return;

    setState(() => working = true);

    try {
      final data = await DB.backup();

      final fileName =
          await GoogleDriveBackupService.uploadBackup(data: data);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              AppLocalizations.t(
                'Backup Google Drive berhasil: $fileName',
                'Google Drive backup successful: $fileName',
              ),
            ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.t(
                'Backup Google Drive gagal: $e',
                'Google Drive backup failed: $e',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> restore() async {
    if(working) return;
    final ok=await showDialog<bool>(
      context:context,
      builder:(_)=>AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        title: Text(
          AppLocalizations.t(
            'Restore database?',
            'Restore database?',
          ),
        ),
        content: Text(
          AppLocalizations.t(
            'Data saat ini akan diganti dengan isi file backup. Pastikan file berasal dari CP POS.',
            'Current data will be replaced with the contents of the backup file. Make sure the file comes from CP POS.',
          ),
        ),
        actions:[
          TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            AppLocalizations.t('Batal', 'Cancel'),
          ),
        ),
          FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            AppLocalizations.t('Restore', 'Restore'),
          ),
        ),
        ],
      ),
    );
    if(ok!=true) return;
    final result=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['json'],withData:true);
    if(result==null) return;
    setState(()=>working=true);
    try {
      final f=result.files.single;
      final raw=f.bytes!=null ? utf8.decode(f.bytes!) : await File(f.path!).readAsString();
      final decoded=jsonDecode(raw);
      if(decoded is! Map<String,dynamic>) throw Exception(AppLocalizations.t('File backup tidak valid.', 'Invalid backup file.'));
      await DB.restoreBackup(decoded);
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            AppLocalizations.t(
              'Restore berhasil.',
              'Restore completed successfully.',
            ),
          ),
        ));
        Navigator.pop(context);
      }
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            AppLocalizations.t(
              'Restore gagal: $e',
              'Restore failed: $e',
            ),
          ),
        ));
    } finally {
      if(mounted) setState(()=>working=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.t(
            'Backup & Restore',
            'Backup & Restore',
          ),
        ),
      ),
      body:ListView(
        padding:const EdgeInsets.all(16),
        children:[
          Card(
            child:Padding(
              padding:const EdgeInsets.all(18),
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  Text(
              AppLocalizations.t(
                'Backup & Restore Database',
                'Backup & Restore Database',
              ),
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
                  const SizedBox(height:8),
                  Text(
              AppLocalizations.t(
                'Backup menyimpan menu, pengguna, transaksi, detail transaksi dan stok. Restore mengganti seluruh data dengan file backup.',
                'Backup saves menus, users, transactions, transaction details, and inventory. Restore replaces all data with the backup file.',
              ),
            ),
                  const SizedBox(height:16),
                  Row(children:[
                    Expanded(child:FilledButton.icon(onPressed:working?null:backup,icon:const Icon(Icons.backup_rounded),label: Text(
                      AppLocalizations.t('BACKUP', 'BACKUP'),
                    ))),
                    const SizedBox(width:10),
                    Expanded(child:OutlinedButton.icon(onPressed:working?null:restore,icon:const Icon(Icons.restore_rounded),label: Text(
                      AppLocalizations.t('RESTORE', 'RESTORE'),
                    ))),
                  ]),
                  const SizedBox(height:10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: working ? null : backupToGoogleDrive,
                      icon: const Icon(Icons.cloud_upload_rounded),
                      label: Text(
                          AppLocalizations.t(
                            'BACKUP KE GOOGLE DRIVE',
                            'BACKUP TO GOOGLE DRIVE',
                          ),
                        ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height:10),
          Text(
          AppLocalizations.t(
            'Simpan file backup di lokasi aman sebelum melakukan restore.',
            'Save the backup file in a secure location before performing a restore.',
          ),
          style: const TextStyle(
            color: Color(0xFF6F7177),
            fontSize: 12,
          ),
        ),
          const CopyrightFooter(),
        ],
      ),
    );
  }
}

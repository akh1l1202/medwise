// ignore_for_file: avoid_print
import 'dart:io';
import 'package:path/path.dart' as p;

void main() async {
  print('=== MedWise Indian Medicines Database Generator ===');
  final pythonScript = p.join(Directory.current.path, 'tool', 'build_full_database.py');
  
  if (File(pythonScript).existsSync()) {
    print('Executing Python full database builder from Kaggle A-Z dataset...');
    final result = await Process.run('python', [pythonScript]);
    print(result.stdout);
    if (result.stderr.toString().isNotEmpty) {
      print('Errors / Notes: ${result.stderr}');
    }
  } else {
    print('build_full_database.py not found at $pythonScript');
  }
}

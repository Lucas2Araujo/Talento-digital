import 'package:flutter/material.dart';
import 'database/app_database.dart';
import 'database/talentos_repository.dart';
import 'screens/alunos_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppDatabase.setupPlatformDriver();

  final appDatabase = AppDatabase();
  try {
    await appDatabase.database;
  } catch (e, stack) {
    debugPrint('Erro ao inicializar banco de dados: $e\n$stack');
  }

  final repository = TalentosRepository(appDatabase);

  runApp(TalentoApp(repository: repository));
}

class TalentoApp extends StatelessWidget {
  final TalentosRepository repository;

  const TalentoApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Talento Digital - IASD Recanto',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: const CardThemeData(
          elevation: 2,
          color: Color(0xFF1E1E1E),
        ),
      ),
      home: AlunosScreen(repository: repository),
    );
  }
}

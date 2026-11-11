import 'package:flutter/material.dart';
import 'database/app_database.dart';
import 'database/talentos_repository.dart';
import 'screens/alunos_screen.dart';
import 'theme/adventure_theme.dart';

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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AdventureTheme.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Talento Digital - Exploradores',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: AdventureTheme.lightTheme,
          darkTheme: AdventureTheme.darkTheme,
          home: AlunosScreen(repository: repository),
        );
      },
    );
  }
}

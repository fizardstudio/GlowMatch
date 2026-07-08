import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/network/database_service.dart';
import 'features/catalog/data/repositories/shade_matcher_repository_impl.dart';
import 'features/scanner/presentation/bloc/scanner_bloc.dart';
import 'features/scanner/presentation/pages/scanner_page.dart';

void main() async {
  // Pastikan binding Flutter terinisialisasi sebelum pengerjaan asinkron
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Database Isar lokal dan lakukan seeding data
  final dbService = DatabaseService();
  await dbService.init();

  runApp(MyApp(dbService: dbService));
}

class MyApp extends StatelessWidget {
  final DatabaseService dbService;

  const MyApp({
    super.key,
    required this.dbService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ScannerBloc>(
          create: (context) => ScannerBloc(
            shadeMatcherRepository: ShadeMatcherRepositoryImpl(dbService),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'GlowMatch',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0F0F1A),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFE5A93B),
            brightness: Brightness.dark,
            surface: const Color(0xFF0F0F1A),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF16162A),
            elevation: 0,
          ),
        ),
        home: const ScannerPage(),
      ),
    );
  }
}

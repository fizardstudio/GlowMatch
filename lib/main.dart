import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/network/database_service.dart';
import 'features/catalog/data/repositories/shade_matcher_repository_impl.dart';
import 'features/scanner/presentation/bloc/scanner_bloc.dart';
import 'features/home/presentation/pages/home_page.dart';

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
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFFCF9F6),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFE5A99E),
            brightness: Brightness.light,
            surface: const Color(0xFFFCF9F6),
            primary: const Color(0xFFE5A99E),
            secondary: const Color(0xFFC89E88),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFFCF9F6),
            elevation: 0,
            iconTheme: IconThemeData(color: Color(0xFF3E3635)),
            titleTextStyle: TextStyle(
              color: Color(0xFF3E3635),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        home: const HomePage(),
      ),
    );
  }
}

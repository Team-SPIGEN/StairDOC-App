import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'providers/auth/auth_bloc.dart';
import 'routes/app_router.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const StairDocApp());
}

class StairDocApp extends StatefulWidget {
  const StairDocApp({super.key});

  @override
  State<StairDocApp> createState() => _StairDocAppState();
}

class _StairDocAppState extends State<StairDocApp> {
  late final AuthService _authService;
  late final StorageService _storageService;
  late final AuthBloc _authBloc;
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _storageService = StorageService();
    _authBloc = AuthBloc(
      authService: _authService,
      storageService: _storageService,
    );
    _appRouter = AppRouter(_authBloc);
  }

  @override
  void dispose() {
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>.value(
      value: _authBloc,
      child: MaterialApp.router(
        title: 'Delivery Robot Control',
        themeMode: ThemeMode.system,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        debugShowCheckedModeBanner: false,
        routerConfig: _appRouter.router,
      ),
    );
  }
}

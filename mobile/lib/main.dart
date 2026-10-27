import 'package:flutter/material.dart';

import 'app.dart';
import 'app_services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AgriScanApp(services: AppServices.production()));
}

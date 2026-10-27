import 'package:flutter/material.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'data/prediction_api.dart';
import 'logic/analysis_controller.dart';
import 'logic/image_source_service.dart';
import 'logic/locale_controller.dart';

void main() {
  final controller = AnalysisController(
    api: HttpPredictionApi(baseUrl: AppConfig.apiBaseUrl, timeout: AppConfig.requestTimeout),
    imageSource: DeviceImageSourceService(),
  );
  runApp(AgriScanApp(controller: controller, localeController: LocaleController()));
}

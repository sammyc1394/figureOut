import 'logger_service.dart';

void appLog(
    String tag,
    String message, {
      LogLevel level = LogLevel.debug,
    }) {
  LoggerService.instance.appLog(
    tag,
    message,
    level: level,
  );
}
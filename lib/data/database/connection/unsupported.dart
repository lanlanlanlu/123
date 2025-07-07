// lib/data/database/connection/unsupported.dart
import 'package:record_app/data/database/database.dart';

AppDatabase connect() {
  throw 'Platform not supported';
}
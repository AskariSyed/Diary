import 'package:intl/intl.dart';

String formatDate(DateTime? date) {
  if (date == null) {
    return 'Unknown Date';
  }
  return DateFormat('MMMM dd, yyyy').format(date);
}

String formatDateWithDay(DateTime? date) {
  if (date == null) {
    return 'Unknown Date';
  }
  return DateFormat('EEEE, MMMM dd, yyyy').format(date);
}

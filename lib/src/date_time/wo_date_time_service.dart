import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wo_form_service/src/date_time/pick_date_page.dart';

class DateTimeService {
  const DateTimeService();

  Future<DateTime?> pickDate({
    required BuildContext context,
    DateTime? initialDate,
    DateTime? maxBound,
    DateTime? minBound,
    DatePickerEntryMode? initialEntryMode,
    String? dateFormat,
  }) {
    if (initialEntryMode == DatePickerEntryMode.input ||
        initialEntryMode == DatePickerEntryMode.inputOnly) {
      throw UnimplementedError(
        "WoDateTimeService doesn't support DatePickerEntryMode.input",
      );
    }

    if (minBound != null && maxBound != null && minBound.isAfter(maxBound)) {
      throw AssertionError('minBound must be before maxBound');
    }

    return Navigator.push(
      context,
      MaterialPageRoute<DateTime>(
        builder: (_) => PickDatePage(
          woFormStatusCubit: context.read(),
          initialDate: initialDate,
          maxBound: maxBound,
          minBound: minBound,
          dateFormat: dateFormat,
        ),
      ),
    );
  }
}

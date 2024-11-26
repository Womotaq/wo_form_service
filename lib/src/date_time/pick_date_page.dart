import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:wo_form/wo_form.dart';

class PickDatePage extends StatefulWidget {
  const PickDatePage({
    required this.woFormStatusCubit,
    this.initialDate,
    this.maxBound,
    this.minBound,
    super.key,
  });

  final WoFormStatusCubit woFormStatusCubit;
  final DateTime? initialDate;
  final DateTime? maxBound;
  final DateTime? minBound;

  @override
  State<PickDatePage> createState() => _PickDatePageState();
}

class _PickDatePageState extends State<PickDatePage> {
  late final AutoScrollController yearScrollController;
  late final AutoScrollController monthScrollController;
  late final AutoScrollController dayScrollController;

  @override
  void initState() {
    super.initState();

    yearScrollController = AutoScrollController(axis: Axis.horizontal);
    monthScrollController = AutoScrollController(axis: Axis.horizontal);
    dayScrollController = AutoScrollController(axis: Axis.horizontal);
  }

  @override
  Widget build(BuildContext context) {
    final initialDate = (widget.initialDate ?? DateTime.now()).date;
    final minBound = widget.minBound?.date;
    final maxBound = widget.maxBound?.date;

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => _YearDeltaCubit()),
        BlocProvider(
          create: (context) => _FullMonthCubit(
            initialDate.fullMonth,
            yearScrollController: yearScrollController,
            monthScrollController: monthScrollController,
            yearDeltaCubit: context.read(),
            minBound: minBound?.fullMonth,
            maxBound: maxBound?.fullMonth,
          ),
        ),
        BlocProvider(
          create: (context) => _SelectedDateCubit(
            initialDate,
            fullMonthCubit: context.read(),
            maxBound: maxBound,
            minBound: minBound,
          ),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(),
        body: ListView(
          children: [
            SizedBox(
              height: 64,
              child: InfiniteListView(
                scrollController: yearScrollController,
                scrollDirection: Axis.horizontal,
                initialIndex: initialDate.year,
                itemBuilder: (index, scrollController) {
                  if (minBound != null && index < minBound.year) {
                    return null;
                  }
                  if (maxBound != null && index > maxBound.year) {
                    return null;
                  }

                  return _YearWidget(
                    year: index,
                    scrollController: scrollController,
                  );
                },
              ),
            ),
            SizedBox(
              height: 64,
              child: InfiniteListView(
                scrollController: monthScrollController,
                scrollDirection: Axis.horizontal,
                initialIndex: initialDate.fullMonth,
                itemBuilder: (index, scrollController) {
                  if (minBound != null && index < minBound.fullMonth) {
                    return null;
                  }
                  if (maxBound != null && index > maxBound.fullMonth) {
                    return null;
                  }

                  return _MonthWidget(
                    fullMonth: index,
                    scrollController: scrollController,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: _DateWidget.cellWidth * 7,
                height: _DateWidget.cellWidth * 6,
                child: _DateWidget(
                  scrollController: dayScrollController,
                ),
              ),
            ),
            RepositoryProvider.value(
              value: widget.woFormStatusCubit,
              child: BlocBuilder<_SelectedDateCubit, DateTime?>(
                builder: (context, date) {
                  return SubmitButton(
                    SubmitButtonData(
                      // TODO : empty localizations
                      text: date == null
                          ? 'Empty'
                          : DateFormat.yMMMMEEEEd().format(date),
                      // MaterialLocalizations.of(context).keyboardKeySelect,
                      onPressed: () => Navigator.of(context)
                          .pop(context.read<_SelectedDateCubit>().state),
                      position: SubmitButtonPosition.body,
                      pageIndex: 0,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    yearScrollController.dispose();
    monthScrollController.dispose();
    dayScrollController.dispose();
    super.dispose();
  }
}

class _SelectedDateCubit extends Cubit<DateTime?> {
  _SelectedDateCubit(
    super.initialState, {
    required this.fullMonthCubit,
    required this.minBound,
    required this.maxBound,
  });

  final _FullMonthCubit fullMonthCubit;
  final DateTime? minBound;
  final DateTime? maxBound;

  DateTime _clamp(DateTime date) {
    if (minBound != null && date.isBefore(minBound!)) return minBound!;
    if (maxBound != null && date.isAfter(maxBound!)) return maxBound!;
    return date;
  }

  void setDay(int day) {
    final (year, month) = fullMonthCubit.state.yearAndMonth;
    final newDate = DateTime(year, month, day);
    if (_clamp(newDate) == newDate) emit(newDate);
  }
}

class _FullMonthCubit extends Cubit<int> {
  _FullMonthCubit(
    super.initialState, {
    required this.yearScrollController,
    required this.monthScrollController,
    required this.yearDeltaCubit,
    required this.minBound,
    required this.maxBound,
  });

  final AutoScrollController yearScrollController;
  final AutoScrollController monthScrollController;
  final _YearDeltaCubit yearDeltaCubit;
  final int? minBound;
  final int? maxBound;

  int _clamp(int fullMonth) {
    if (minBound != null && fullMonth < minBound!) return minBound!;
    if (maxBound != null && fullMonth > maxBound!) return maxBound!;
    return fullMonth;
  }

  // void setDay(int day) => emit(_clamp(state.copyWith(day: day)));

  void setFullMonth(int fullMonth) {
    final (year, month) = fullMonth.yearAndMonth;
    final scrollYear = year != state.year;

    emit(_clamp(fullMonth));
    // Let the widgets update their sizes before srolling to their hitbox
    SchedulerBinding.instance.addPostFrameCallback((_) {
      monthScrollController.scrollToIndex(
        fullMonth,
        preferPosition: AutoScrollPosition.middle,
      );
      if (scrollYear) {
        yearScrollController.scrollToIndex(
          year,
          preferPosition: AutoScrollPosition.middle,
        );
      }
    });
  }

  void setYear(int year) {
    final newDate = _clamp(_FullMonth.build(year: year, month: state.month));
    final yearDelta =
        newDate.month == state.month ? newDate.year - state.year : null;
    emit(newDate);
    // Let the widgets update their sizes before srolling to their hitbox
    SchedulerBinding.instance.addPostFrameCallback((_) {
      yearScrollController.scrollToIndex(
        state.year,
        preferPosition: AutoScrollPosition.middle,
      );

      if (yearDelta != null) {
        yearDeltaCubit.increment(yearDelta);

        // Let the _MonthWidgets apply year delta before srolling to their index
        SchedulerBinding.instance.addPostFrameCallback((_) {
          monthScrollController.scrollToIndex(
            state,
            preferPosition: AutoScrollPosition.middle,
          );
        });
      }
    });
  }
}

/// This cubit stores a very special value that allows the _MonthWidget to stay
/// coherent when changing the year
class _YearDeltaCubit extends Cubit<int> {
  _YearDeltaCubit() : super(0);

  void increment(int delta) => emit(state + delta);
}

extension on DateTime {
  int get fullMonth => year * 12 + month;
  DateTime get date => DateTime(year, month, day);
}

extension _FullMonth on int {
  static int build({required int year, required int month}) =>
      year * 12 + month;

  (int, int) get yearAndMonth {
    var month = this % 12;
    var year = this ~/ 12;
    if (month == 0) {
      month = 12;
      year -= 1;
    }

    return (year, month);
  }

  int get year => yearAndMonth.$1;
  int get month => yearAndMonth.$2;
}

class InfiniteListView extends StatefulWidget {
  const InfiniteListView({
    required this.scrollController,
    required this.itemBuilder,
    this.scrollDirection = Axis.vertical,
    this.initialIndex,
    super.key,
  });

  final AutoScrollController scrollController;
  final Widget? Function(int index, AutoScrollController scrollController)
      itemBuilder;
  final Axis scrollDirection;
  final int? initialIndex;

  @override
  State<InfiniteListView> createState() => _InfiniteListViewState();
}

class _InfiniteListViewState extends State<InfiniteListView> {
  @override
  void initState() {
    super.initState();
    if (widget.initialIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.scrollController.scrollToIndex(
          widget.initialIndex!,
          preferPosition: AutoScrollPosition.middle,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.scrollDirection != Axis.horizontal) throw UnimplementedError();

    final Key forwardListKey = UniqueKey();
    return Scrollable(
      axisDirection: AxisDirection.right,
      controller: widget.scrollController,
      viewportBuilder: (BuildContext context, ViewportOffset offset) {
        return Viewport(
          axisDirection: AxisDirection.right,
          offset: offset,
          center: forwardListKey,
          slivers: [
            // reverse
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, int index) => widget.itemBuilder(
                  (widget.initialIndex ?? 0) - index - 1,
                  widget.scrollController,
                ),
              ),
            ),
            // forward
            SliverList(
              key: forwardListKey,
              delegate: SliverChildBuilderDelegate(
                (_, int index) => widget.itemBuilder(
                  (widget.initialIndex ?? 0) + index,
                  widget.scrollController,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _YearWidget extends StatelessWidget {
  const _YearWidget({
    required this.year,
    required this.scrollController,
  });

  final int year;
  final AutoScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<_FullMonthCubit, int, int>(
      selector: (date) => date.year,
      builder: (context, selectedYear) {
        return _SelectableIndex(
          index: year,
          selectedIndex: selectedYear,
          scrollController: scrollController,
          child: Text(year.toString()),
          onSelect: () => context.read<_FullMonthCubit>().setYear(year),
        );
      },
    );
  }
}

class _MonthWidget extends StatelessWidget {
  const _MonthWidget({
    required this.fullMonth,
    required this.scrollController,
  });

  final int fullMonth;
  final AutoScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final fullMonth = this.fullMonth +
        context.select<_YearDeltaCubit, int>((c) => c.state * 12);
    final month = fullMonth % 12;
    return BlocBuilder<_FullMonthCubit, int>(
      builder: (context, currentFullMonth) {
        return _SelectableIndex(
          index: fullMonth,
          selectedIndex: currentFullMonth,
          scrollController: scrollController,
          child: Text(DateFormat.MMMM().format(DateTime(1, month))),
          onSelect: () =>
              context.read<_FullMonthCubit>().setFullMonth(fullMonth),
        );
      },
    );
  }
}

class _SelectableIndex extends StatelessWidget {
  const _SelectableIndex({
    required this.index,
    required this.selectedIndex,
    required this.scrollController,
    required this.child,
    required this.onSelect,
  });

  final int index;
  final int selectedIndex;
  final AutoScrollController scrollController;
  final Widget child;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final yearWidget = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      child: child,
    );

    return AutoScrollTag(
      key: ValueKey(index),
      controller: scrollController,
      index: index,
      child: TweenAnimationBuilder<Color?>(
        duration: Durations.medium1,
        tween: ColorTween(
          begin: index == selectedIndex
              ? theme.disabledColor
              : theme.colorScheme.onPrimary,
          end: index == selectedIndex
              ? theme.colorScheme.onPrimary
              : theme.disabledColor,
        ),
        builder: (context, color, child) => DefaultTextStyle(
          style: index == selectedIndex
              ? theme.textTheme.bodyLarge!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                )
              : TextStyle(color: color),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onSelect,
                child: index == selectedIndex
                    ? Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: yearWidget,
                      )
                    : yearWidget,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateWidget extends StatelessWidget {
  const _DateWidget({required this.scrollController});

  final AutoScrollController scrollController;

  static const cellWidth = 48;

  @override
  Widget build(BuildContext context) {
    final fullMonthCubit = context.watch<_FullMonthCubit>();
    final selectedDateCubit = context.watch<_SelectedDateCubit>();

    final isSelectedMonth =
        fullMonthCubit.state == selectedDateCubit.state?.fullMonth;

    return InfiniteListView(
      scrollController: scrollController,
      scrollDirection: Axis.horizontal,
      itemBuilder: (index, scrollController) {
        return SizedBox(
          width: cellWidth * 7,
          height: cellWidth * 6,
          child: MonthlyCalendar(
            year: fullMonthCubit.state.year,
            month: fullMonthCubit.state.month,
            selectedDay: isSelectedMonth ? selectedDateCubit.state?.day : null,
            onSelect: selectedDateCubit.setDay,
            minDay: isSelectedMonth && selectedDateCubit.minBound != null
                ? selectedDateCubit.minBound!.day
                : null,
            maxDay: isSelectedMonth && selectedDateCubit.maxBound != null
                ? selectedDateCubit.maxBound!.day
                : null,
          ),
        );
      },
    );
  }
}

class MonthlyCalendar extends StatelessWidget {
  const MonthlyCalendar({
    required this.onSelect,
    required this.year,
    required this.month,
    this.selectedDay,
    this.minDay,
    this.maxDay,
    super.key,
  });

  final void Function(int day) onSelect;
  final int year;
  final int month;
  final int? selectedDay;
  final int? minDay;
  final int? maxDay;

  @override
  Widget build(BuildContext context) {
    // Generate the calendar grid for the given month
    final days = _generateCalendar(year, month);

    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7, // 7 days in a week
      ),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final selectable = day != null &&
            !((minDay != null && day < minDay!) ||
                (maxDay != null && day > maxDay!));

        return Center(
          child: SizedBox(
            width: 40,
            height: 40,
            child: day != null
                ? selectedDay == day
                    ? Container(
                        decoration: selectedDay == day
                            ? BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              )
                            : null,
                        child: Center(
                          child: Text(
                            day.toString(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      )
                    : InkWell(
                        borderRadius: BorderRadius.circular(40),
                        onTap: selectable ? () => onSelect(day) : null,
                        child: Center(
                          child: Text(
                            day.toString(),
                            style: selectable
                                ? null
                                : TextStyle(
                                    color: Theme.of(context).disabledColor,
                                  ),
                          ),
                        ),
                      )
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  List<int?> _generateCalendar(int year, int month) {
    final days = <int?>[];
    final firstDayOfMonth = DateTime(year, month);
    final daysInMonth = DateTime(year, month + 1, 0).day; // Last day of month

    // Calculate the starting weekday (1 = Monday, 7 = Sunday)
    final startWeekday = firstDayOfMonth.weekday;

    // Add blank cells for days of the previous month
    for (var i = 1; i < startWeekday; i++) {
      days.add(null);
    }

    // Add days of the current month
    for (var i = 1; i <= daysInMonth; i++) {
      days.add(i);
    }

    // Add blank cells for days of the next month to fill the grid
    // while (days.length % 7 != 0) {
    //   days.add(null);
    // }

    return days;
  }
}

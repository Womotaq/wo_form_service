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
    var initialDate = widget.initialDate?.date;
    final minBound = widget.minBound?.date;
    final maxBound = widget.maxBound?.date;

    if (initialDate != null &&
        minBound != null &&
        initialDate.isBefore(minBound)) {
      initialDate = null;
    }
    if (initialDate != null &&
        maxBound != null &&
        initialDate.isAfter(maxBound)) {
      initialDate = null;
    }

    final initialDateSafe = initialDate ?? DateTime.now();
    // if (minBound != null && initialDateSafe.isBefore(minBound)) {
    //   initialDateSafe = minBound;
    // }
    // if (maxBound != null && initialDateSafe.isAfter(maxBound)) {
    //   initialDateSafe = maxBound;
    // }

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => _YearDeltaCubit()),
        BlocProvider(
          create: (context) => _FullMonthCubit(
            initialDateSafe.fullMonth,
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
                initialIndex: initialDateSafe.year,
                minIndex: minBound?.year,
                maxIndex: maxBound?.year,
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
              child: BlocSelector<_YearDeltaCubit, int, int>(
                selector: (yearDelta) => yearDelta * 12,
                builder: (context, monthDelta) {
                  return InfiniteListView(
                    scrollController: monthScrollController,
                    scrollDirection: Axis.horizontal,
                    initialIndex: initialDateSafe.fullMonth + monthDelta,
                    minIndex: minBound?.fullMonth,
                    maxIndex: maxBound?.fullMonth,
                    // minIndex: minBound == null
                    //     ? null
                    //     : minBound.fullMonth + monthDelta,
                    // maxIndex: maxBound == null
                    //     ? null
                    //     : maxBound.fullMonth + monthDelta,
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
                  if (date == null) return const SizedBox.shrink();

                  return BlocBuilder<_FullMonthCubit, int>(
                    builder: (context, fullMonth) {
                      if (fullMonth != date.fullMonth) {
                        return const SizedBox.shrink();
                      }

                      return SubmitButton(
                        SubmitButtonData(
                          text:
                              // DateFormat.yMMMMEEEEd().format(date),
                              MaterialLocalizations.of(context)
                                  .keyboardKeySelect,
                          onPressed: () => Navigator.of(context)
                              .pop(context.read<_SelectedDateCubit>().state),
                          position: SubmitButtonPosition.body,
                          pageIndex: 0,
                        ),
                      );
                    },
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

  void setFullMonth(int fullMonth) {
    final newFullMonth = _clamp(fullMonth);
    final scrollYear = newFullMonth.year != state.year;

    emit(newFullMonth);

    // Let the widgets update their sizes before srolling to their hitbox
    SchedulerBinding.instance.addPostFrameCallback((_) {
      monthScrollController.scrollToIndex(
        state,
        preferPosition: AutoScrollPosition.middle,
      );

      if (scrollYear) {
        yearScrollController.scrollToIndex(
          state.year,
          preferPosition: AutoScrollPosition.middle,
        );
      }
    });
  }

  void setYear(int year) {
    final fullMonth = _clamp(_FullMonth.build(year: year, month: state.month));
    final yearDelta = fullMonth.year - state.year;

    emit(fullMonth);

    // Let the widgets update their sizes before srolling to their hitbox
    SchedulerBinding.instance.addPostFrameCallback((_) {
      yearScrollController.scrollToIndex(
        state.year,
        preferPosition: AutoScrollPosition.middle,
      );

      yearDeltaCubit.increment(yearDelta);

      // Let the _MonthWidgets apply year delta before srolling to their index
      SchedulerBinding.instance.addPostFrameCallback((_) {
        monthScrollController.scrollToIndex(
          state,
          preferPosition: AutoScrollPosition.middle,
        );
      });
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
    this.minIndex,
    this.maxIndex,
    super.key,
  });

  final AutoScrollController scrollController;
  final Widget? Function(int index, AutoScrollController scrollController)
      itemBuilder;
  final Axis scrollDirection;
  final int? initialIndex;
  final int? minIndex;
  final int? maxIndex;

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
                // (_, int index) =>  widget.itemBuilder(
                //   (widget.initialIndex ?? 0) - index - 1,
                //   widget.scrollController,
                // ),
                (_, int index) {
                  final movedIndex = (widget.initialIndex ?? 0) - index - 1;
                  final child = widget.itemBuilder(
                    movedIndex,
                    widget.scrollController,
                  );
                  if (child == null) {
                    if (widget.minIndex != null &&
                        movedIndex > widget.minIndex!) {
                      return Container(
                        width: 30,
                        height: 30,
                        color: Colors.red,
                      );
                    }
                  }
                  return child;
                },
              ),
            ),
            // forward
            SliverList(
              key: forwardListKey,
              delegate: SliverChildBuilderDelegate(
                (_, int index) {
                  final movedIndex = (widget.initialIndex ?? 0) + index;
                  final child = widget.itemBuilder(
                    movedIndex,
                    widget.scrollController,
                  );
                  if (child == null) {
                    print(movedIndex);
                    if (widget.maxIndex != null &&
                        movedIndex < widget.maxIndex!) {
                      return Container(
                        width: 30,
                        height: 30,
                        color: Colors.blue,
                      );
                      // return const SizedBox.shrink();
                    }
                  }
                  return child;
                },
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
    final fullMonth = context.watch<_FullMonthCubit>().state;
    final selectedDateCubit = context.watch<_SelectedDateCubit>();

    final isSelectedMonth = fullMonth == selectedDateCubit.state?.fullMonth;
    final minBound = selectedDateCubit.minBound;
    final maxBound = selectedDateCubit.maxBound;

    return InfiniteListView(
      scrollController: scrollController,
      scrollDirection: Axis.horizontal,
      itemBuilder: (index, scrollController) {
        return SizedBox(
          width: cellWidth * 7,
          height: cellWidth * 6,
          child: MonthlyCalendar(
            year: fullMonth.year,
            month: fullMonth.month,
            selectedDay: isSelectedMonth ? selectedDateCubit.state?.day : null,
            onSelect: selectedDateCubit.setDay,
            minDay: minBound != null
                ? minBound.fullMonth == fullMonth
                    ? minBound.day
                    : minBound.fullMonth > fullMonth
                        ? 32
                        : null
                : null,
            maxDay: maxBound != null
                ? maxBound.fullMonth == fullMonth
                    ? maxBound.day
                    : maxBound.fullMonth < fullMonth
                        ? -1
                        : null
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
                              fontWeight: FontWeight.bold,
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

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
    final initialDate = widget.initialDate ?? DateTime.now();
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => _YearDeltaCubit()),
        BlocProvider(
          create: (context) => _DateCubit(
            initialDate,
            yearScrollController: yearScrollController,
            monthScrollController: monthScrollController,
            dayScrollController: dayScrollController,
            yearDeltaCubit: context.read(),
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
                itemBuilder: (index, scrollController) => _YearWidget(
                  year: index,
                  scrollController: scrollController,
                ),
              ),
            ),
            SizedBox(
              height: 64,
              child: InfiniteListView(
                scrollController: monthScrollController,
                scrollDirection: Axis.horizontal,
                initialIndex: initialDate.fullMonth,
                itemBuilder: (index, scrollController) => _MonthWidget(
                  fullMonth: index,
                  scrollController: scrollController,
                ),
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
              child: Builder(
                builder: (context) {
                  return SubmitButton(
                    SubmitButtonData(
                      text: MaterialLocalizations.of(context).keyboardKeySelect,
                      onPressed: () => Navigator.of(context)
                          .pop(context.read<_DateCubit>().state),
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

class _DateCubit extends Cubit<DateTime> {
  _DateCubit(
    super.initialState, {
    required this.yearScrollController,
    required this.monthScrollController,
    required this.dayScrollController,
    required this.yearDeltaCubit,
  });

  final AutoScrollController yearScrollController;
  final AutoScrollController monthScrollController;
  final AutoScrollController dayScrollController;
  final _YearDeltaCubit yearDeltaCubit;

  void setDay(int day) => emit(state.copyWith(day: day));

  void setFullMonth(int fullMonth) {
    var month = fullMonth % 12;
    var year = fullMonth ~/ 12;
    if (month == 0) {
      month = 12;
      year -= 1;
    }
    final scrollYear = year != state.year;

    emit(state.copyWith(year: year, month: month));
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
    final yearDelta = year - state.year;
    emit(state.copyWith(year: year));
    // Let the widgets update their sizes before srolling to their hitbox
    SchedulerBinding.instance.addPostFrameCallback((_) {
      yearScrollController.scrollToIndex(
        year,
        preferPosition: AutoScrollPosition.middle,
      );
      yearDeltaCubit.increment(yearDelta);

      // Let the _MonthWidgets apply year delta before srolling to their index
      SchedulerBinding.instance.addPostFrameCallback((_) {
        monthScrollController.scrollToIndex(
          state.fullMonth,
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
  final Widget Function(int index, AutoScrollController scrollController)
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
    return BlocSelector<_DateCubit, DateTime, int>(
      selector: (date) => date.year,
      builder: (context, selectedYear) {
        return _SelectableIndex(
          index: year,
          selectedIndex: selectedYear,
          scrollController: scrollController,
          child: Text(year.toString()),
          onSelect: () => context.read<_DateCubit>().setYear(year),
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
    return BlocSelector<_DateCubit, DateTime, int>(
      selector: (date) => date.fullMonth,
      builder: (context, selectedFullMonth) {
        return _SelectableIndex(
          index: fullMonth,
          selectedIndex: selectedFullMonth,
          scrollController: scrollController,
          child: Text(DateFormat.MMMM().format(DateTime(1, month))),
          onSelect: () => context.read<_DateCubit>().setFullMonth(fullMonth),
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

    return AutoScrollTag(
      key: ValueKey(index),
      controller: scrollController,
      index: index,
      child: BlocSelector<_DateCubit, DateTime, int>(
        selector: (date) => date.year,
        builder: (context, selectedYear) {
          final yearWidget = Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            child: child,
          );

          return TweenAnimationBuilder<Color?>(
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
          );
        },
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
    final dateCubit = context.watch<_DateCubit>();

    return InfiniteListView(
      scrollController: scrollController,
      scrollDirection: Axis.horizontal,
      itemBuilder: (index, scrollController) {
        return SizedBox(
          width: cellWidth * 7,
          height: cellWidth * 6,
          child: MonthlyCalendar(
            year: dateCubit.state.year,
            month: dateCubit.state.month,
            selectedDay: dateCubit.state.day,
            onSelect: dateCubit.setDay,
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
    super.key,
  });

  final void Function(int day) onSelect;
  final int year;
  final int month;
  final int? selectedDay;

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
                        onTap: () => onSelect(day),
                        child: Center(
                          child: Text(day.toString()),
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

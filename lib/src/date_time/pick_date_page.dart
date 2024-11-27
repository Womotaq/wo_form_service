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
    this.dateFormat,
    super.key,
  });

  final WoFormStatusCubit woFormStatusCubit;
  final DateTime? initialDate;
  final DateTime? maxBound;
  final DateTime? minBound;
  final String? dateFormat;

  @override
  State<PickDatePage> createState() => _PickDatePageState();
}

class _PickDatePageState extends State<PickDatePage> {
  late final AutoScrollController yearScrollController;
  late final AutoScrollController monthScrollController;
  late final InfiniteCarouselController dayScrollController;

  @override
  void initState() {
    super.initState();

    yearScrollController = AutoScrollController(axis: Axis.horizontal);
    monthScrollController = AutoScrollController(axis: Axis.horizontal);
    dayScrollController = InfiniteCarouselController();
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

    DateTime? initialDateSafe = initialDate ?? DateTime.now();
    if (minBound != null && initialDateSafe.isBefore(minBound)) {
      initialDateSafe = null;
    } else if (maxBound != null && initialDateSafe.isAfter(maxBound)) {
      initialDateSafe = null;
    }

    final yearMonthCenter =
        initialDateSafe ?? minBound ?? maxBound ?? DateTime.now();

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => _YearDeltaCubit()),
        BlocProvider(
          create: (context) => _FullMonthCubit(
            initialDateSafe?.fullMonth ?? DateTime.now().fullMonth,
            yearScrollController: yearScrollController,
            monthScrollController: monthScrollController,
            dayCarouselController: dayScrollController,
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
                centerIndex: yearMonthCenter.year,
                minIndex: minBound?.year,
                maxIndex: maxBound?.year,
                itemBuilder: (index, scrollController) => _YearWidget(
                  year: index,
                  scrollController: scrollController,
                ),
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
                    centerIndex: (yearMonthCenter.fullMonth + monthDelta)
                        ._clamp(minBound?.fullMonth, maxBound?.fullMonth),
                    minIndex: minBound?.fullMonth,
                    maxIndex: maxBound?.fullMonth,
                    itemBuilder: (index, scrollController) => _MonthWidget(
                      fullMonth: index,
                      scrollController: scrollController,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: _DateWidget.cellWidth * 7,
                height: _DateWidget.cellWidth * 6,
                child: _DateWidget(controller: dayScrollController),
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
                          text: DateFormat(widget.dateFormat ?? 'yMMMMd')
                              // DateFormat('EEEE d MMMM y')
                              .format(date),
                          // MaterialLocalizations.of(context)
                          //     .keyboardKeySelect,
                          onPressed: () => Navigator.of(context).pop(
                            context.read<_SelectedDateCubit>().state,
                          ),
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
    required this.dayCarouselController,
    required this.yearDeltaCubit,
    required this.minBound,
    required this.maxBound,
  });

  final AutoScrollController yearScrollController;
  final AutoScrollController monthScrollController;
  final InfiniteCarouselController dayCarouselController;
  final _YearDeltaCubit yearDeltaCubit;
  final int? minBound;
  final int? maxBound;

  void setFullMonth(int fullMonth) {
    final newFullMonth = fullMonth._clamp(minBound, maxBound);
    final scrollYear = newFullMonth.year != state.year;

    emit(newFullMonth);

    dayCarouselController.animateToIndex(fullMonth);

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
    final fullMonth = _FullMonth.build(year: year, month: state.month)
        ._clamp(minBound, maxBound);
    final yearDelta = fullMonth.year - state.year;

    emit(fullMonth);

    dayCarouselController.animateToIndex(fullMonth);

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

  int _clamp(int? min, int? max) {
    if (min != null && this < min) return min;
    if (max != null && this > max) return max;
    return this;
  }
}

class InfiniteListView extends StatefulWidget {
  const InfiniteListView({
    required this.scrollController,
    required this.itemBuilder,
    this.scrollDirection = Axis.vertical,
    this.centerIndex = 0,
    this.minIndex,
    this.maxIndex,
    super.key,
  });

  final AutoScrollController scrollController;
  final Widget? Function(int index, AutoScrollController scrollController)
      itemBuilder;
  final Axis scrollDirection;

  /// If provided, will auto-scroll to this index
  final int centerIndex;
  final int? minIndex;
  final int? maxIndex;

  @override
  State<InfiniteListView> createState() => _InfiniteListViewState();
}

class _InfiniteListViewState extends State<InfiniteListView> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.scrollController.scrollToIndex(
        widget.centerIndex,
        preferPosition: AutoScrollPosition.middle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.scrollDirection != Axis.horizontal) throw UnimplementedError();

    final minIndex = widget.minIndex;
    final maxIndex = widget.maxIndex;
    final centerIndex = widget.centerIndex;
    if (maxIndex != null && centerIndex > maxIndex) {
      throw AssertionError(
        'centerIndex ($centerIndex) must be lower or equal to '
        'maxIndex ($maxIndex)',
      );
    }
    if (minIndex != null && centerIndex < minIndex) {
      throw AssertionError(
        'centerIndex ($centerIndex) must be higher or equal to '
        'minIndex ($minIndex)',
      );
    }

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
                childCount: minIndex == null ? null : centerIndex - minIndex,
                (_, int index) {
                  final movedIndex = centerIndex - index - 1;
                  final child = widget.itemBuilder(
                    movedIndex,
                    widget.scrollController,
                  );
                  if (child == null) {
                    if (minIndex != null && movedIndex > minIndex) {
                      return const SizedBox.shrink();
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
                childCount:
                    maxIndex == null ? null : maxIndex - centerIndex + 1,
                (_, int index) {
                  final movedIndex = centerIndex + index;
                  final child = widget.itemBuilder(
                    movedIndex,
                    widget.scrollController,
                  );
                  if (child == null) {
                    if (maxIndex != null && movedIndex < maxIndex) {
                      return const SizedBox.shrink();
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
  const _DateWidget({required this.controller});

  final InfiniteCarouselController controller;

  static const cellWidth = 48;

  @override
  Widget build(BuildContext context) {
    final fullMonth = context.watch<_FullMonthCubit>().state;
    final selectedDateCubit = context.watch<_SelectedDateCubit>();

    final isSelectedMonth = fullMonth == selectedDateCubit.state?.fullMonth;
    final minBound = selectedDateCubit.minBound;
    final maxBound = selectedDateCubit.maxBound;

    return InfiniteCarouselView(
      controller: controller,
      initialIndex: fullMonth,
      maxIndex: maxBound?.fullMonth,
      minIndex: minBound?.fullMonth,
      swipeFullLength: 120,
      swipeTriggerLength: 30,
      onIndexChanged: context.read<_FullMonthCubit>().setFullMonth,
      itemBuilder: (context, index) {
        return SizedBox(
          width: cellWidth * 7,
          height: cellWidth * 6,
          child: MonthlyCalendar(
            year: index.year,
            month: index.month,
            selectedDay: isSelectedMonth ? selectedDateCubit.state?.day : null,
            onSelect: selectedDateCubit.setDay,
            minDay: minBound != null
                ? minBound.fullMonth == index
                    ? minBound.day
                    : minBound.fullMonth > index
                        ? 32
                        : null
                : null,
            maxDay: maxBound != null
                ? maxBound.fullMonth == index
                    ? maxBound.day
                    : maxBound.fullMonth < index
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
      itemCount: days.length + 7,
      itemBuilder: (context, index) {
        if (index < 7) {
          return Center(
            child: Text(
              DateFormat(DateFormat.ABBR_WEEKDAY)
                  .format(DateTime(1, 1, index))[0],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        }
        index -= 7;

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

    return days;
  }
}

class InfiniteCarouselController {
  InfiniteCarouselController();

  late void Function(int index) jumpToIndex;
  late Future<void> Function(int index, {Duration duration}) animateToIndex;
}

class InfiniteCarouselView extends StatefulWidget {
  const InfiniteCarouselView({
    required this.itemBuilder,
    this.onIndexChanged,
    this.controller,
    this.initialIndex,
    this.minIndex,
    this.maxIndex,
    this.clipBehavior = Clip.none,
    this.swipeTriggerLength = 32,
    this.swipeFullLength = 96,
    super.key,
  });

  final Widget Function(BuildContext context, int index) itemBuilder;
  final void Function(int index)? onIndexChanged;
  final InfiniteCarouselController? controller;
  final int? initialIndex;
  final int? minIndex;
  final int? maxIndex;
  final Clip clipBehavior;
  final int swipeTriggerLength;
  final int swipeFullLength;

  @override
  State<InfiniteCarouselView> createState() => _InfiniteCarouselViewState();
}

class _InfiniteCarouselViewState extends State<InfiniteCarouselView>
    with SingleTickerProviderStateMixin {
  // The following index only changes when the drag ends.
  // The ui's currentIndex can be accessed through onIndexChanged.
  int _currentIndex = 0;
  int _nextIndex = 0;
  double _swipeOffset = 0;
  late AnimationController _animationController;
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialIndex ?? 0;

    _animationController = AnimationController(vsync: this)
      ..addListener(() {
        if (_animation != null) _onSwipeUpdate(_animation!.value);
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _handleSwipeEnd(DragEndDetails());
        }
      });

    if (widget.controller != null) {
      widget.controller!
        ..jumpToIndex = (index) {
          setState(() {
            _currentIndex = index;
            _nextIndex = index;
            _swipeOffset = 0;
          });
        }
        ..animateToIndex = (index, {duration = Durations.medium1}) async {
          await _animateToIndex(index, duration);
        };
    }
  }

  Future<void> _animateToIndex(int targetIndex, Duration duration) async {
    if (targetIndex == _currentIndex) return;
    if (targetIndex == _nextIndex && _swipeOffset != 0) return;
    if ((widget.minIndex != null && targetIndex < widget.minIndex!) ||
        (widget.maxIndex != null && targetIndex > widget.maxIndex!)) {
      return; // Prevent moving out of bounds
    }

    _nextIndex = targetIndex;

    final direction = targetIndex > _currentIndex ? -1 : 1;

    _animation = Tween<double>(
      begin: 0,
      end: direction * widget.swipeFullLength.toDouble(),
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.duration = duration;

    await _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleSwipeUpdate(DragUpdateDetails details) {
    final newSwipeOffset = _swipeOffset + details.delta.dx;

    // Should be in setState, but since there is another one later,
    // it doesn't matter
    if (newSwipeOffset > 0) {
      _nextIndex = _currentIndex - 1;
    } else {
      _nextIndex = _currentIndex + 1;
    }

    _onSwipeUpdate(newSwipeOffset);
  }

  void _onSwipeUpdate(double newSwipeOffset) {
    if (newSwipeOffset > 0) {
      if (widget.minIndex != null && _currentIndex <= widget.minIndex!) {
        return;
      }
    } else {
      if (widget.maxIndex != null && _currentIndex >= widget.maxIndex!) {
        return;
      }
    }

    if (_swipeOffset.abs() > widget.swipeTriggerLength !=
        newSwipeOffset.abs() > widget.swipeTriggerLength) {
      final currentUiIndex = newSwipeOffset.abs() > widget.swipeTriggerLength
          ? _nextIndex
          : _currentIndex;
      widget.onIndexChanged?.call(currentUiIndex);
    }

    setState(() => _swipeOffset = newSwipeOffset);
  }

  void _handleSwipeEnd(DragEndDetails details) {
    setState(() {
      if (_swipeOffset.abs() > widget.swipeTriggerLength) {
        _currentIndex = _nextIndex;
      } else {
        _nextIndex = _currentIndex;
      }

      _swipeOffset = 0.0;
    });

    // Reset the controller after the animation completes
    _animationController.reset();
  }

  @override
  Widget build(BuildContext context) {
    final dragIndex =
        (_swipeOffset.abs() / widget.swipeFullLength).clamp(0.0, 1.0);

    return GestureDetector(
      onHorizontalDragUpdate: _handleSwipeUpdate,
      onHorizontalDragEnd: _handleSwipeEnd,
      child: Stack(
        clipBehavior: widget.clipBehavior,
        children: [
          // Current child with swipe transformation
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(_swipeOffset, 0),
              child: Opacity(
                opacity: 1.0 - dragIndex,
                child: widget.itemBuilder(context, _currentIndex),
              ),
            ),
          ),

          // Next child fades in during the swipe
          if (_swipeOffset != 0)
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(
                  (_swipeOffset < 0 ? -1 : 1) *
                      (dragIndex * widget.swipeFullLength -
                          widget.swipeFullLength),
                  0,
                ),
                child: Opacity(
                  opacity: dragIndex,
                  child: widget.itemBuilder(context, _nextIndex),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

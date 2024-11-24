import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:wo_form/wo_form.dart';

class PickDatePage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final initialDate = this.initialDate ?? DateTime.now();
    return BlocProvider(
      create: (context) => DateCubit(initialDate),
      child: Scaffold(
        appBar: AppBar(),
        body: ListView(
          children: [
            SizedBox(
              height: 64,
              child: InfiniteListView(
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
                scrollDirection: Axis.horizontal,
                initialIndex: initialDate.month,
                itemBuilder: (index, scrollController) => _MonthWidget(
                  month: index,
                  scrollController: scrollController,
                ),
              ),
            ),
            RepositoryProvider.value(
              value: woFormStatusCubit,
              child: Builder(
                builder: (context) {
                  return SubmitButton(
                    SubmitButtonData(
                      text: MaterialLocalizations.of(context).keyboardKeySelect,
                      onPressed: () => Navigator.of(context)
                          .pop(context.read<DateCubit>().state),
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
}

class DateCubit extends Cubit<DateTime> {
  DateCubit(super.initialState);

  void setMonth(int month) => emit(state.copyWith(month: month));
  void setYear(int year) => emit(state.copyWith(year: year));
}

class InfiniteListView extends StatefulWidget {
  const InfiniteListView({
    required this.itemBuilder,
    this.scrollDirection = Axis.vertical,
    this.initialIndex,
    super.key,
  });

  final Widget Function(int index, AutoScrollController scrollController)
      itemBuilder;
  final Axis scrollDirection;
  final int? initialIndex;

  @override
  State<InfiniteListView> createState() => _InfiniteListViewState();
}

class _InfiniteListViewState extends State<InfiniteListView> {
  late AutoScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = AutoScrollController();
    if (widget.initialIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollController.scrollToIndex(
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
      controller: _scrollController,
      viewportBuilder: (BuildContext context, ViewportOffset offset) {
        return Viewport(
          axisDirection: AxisDirection.right,
          offset: offset,
          center: forwardListKey,
          // anchor: .5,
          slivers: [
            // reverse
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, int index) => widget.itemBuilder(
                  (widget.initialIndex ?? 0) - index - 1,
                  _scrollController,
                ),
              ),
            ),
            // forward
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, int index) => widget.itemBuilder(
                  (widget.initialIndex ?? 0) + index,
                  _scrollController,
                ),
              ),
              key: forwardListKey,
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    return BlocSelector<DateCubit, DateTime, int>(
      selector: (date) => date.year,
      builder: (context, selectedYear) {
        return _SelectableIndex(
          index: year,
          selectedIndex: selectedYear,
          scrollController: scrollController,
          child: Text(year.toString()),
          onSelect: () => context.read<DateCubit>().setYear(year),
        );
      },
    );
  }
}

class _MonthWidget extends StatelessWidget {
  const _MonthWidget({
    required this.month,
    required this.scrollController,
  });

  final int month;
  final AutoScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    var month = this.month % 12;
    if (month == 0) month = 12;

    return BlocSelector<DateCubit, DateTime, int>(
      selector: (date) => date.month,
      builder: (context, selectedMonth) {
        return _SelectableIndex(
          index: month,
          selectedIndex: selectedMonth,
          scrollController: scrollController,
          child: Text(DateFormat.MMMM().format(DateTime(1, month))),
          onSelect: () => context.read<DateCubit>().setMonth(month),
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
    return AutoScrollTag(
      key: ValueKey(index),
      controller: scrollController,
      index: index,
      child: BlocSelector<DateCubit, DateTime, int>(
        selector: (date) => date.year,
        builder: (context, selectedYear) {
          final yearWidget = Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            child: child,
          );

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  onSelect();
                  scrollController.scrollToIndex(
                    index,
                    preferPosition: AutoScrollPosition.middle,
                  );
                },
                child: index == selectedIndex
                    ? Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DefaultTextStyle(
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                          child: yearWidget,
                        ),
                      )
                    : yearWidget,
              ),
            ),
          );
        },
      ),
    );
  }
}

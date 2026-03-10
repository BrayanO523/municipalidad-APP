import 'package:flutter/material.dart';

class ScrollableTable extends StatefulWidget {
  final Widget child;
  final ScrollController? verticalController;
  final ScrollController? horizontalController;

  const ScrollableTable({
    super.key,
    required this.child,
    this.verticalController,
    this.horizontalController,
  });

  @override
  State<ScrollableTable> createState() => _ScrollableTableState();
}

class _ScrollableTableState extends State<ScrollableTable> {
  late final ScrollController _horizontalController;
  late final ScrollController _verticalController;

  @override
  void initState() {
    super.initState();
    _horizontalController = widget.horizontalController ?? ScrollController();
    _verticalController = widget.verticalController ?? ScrollController();
  }

  @override
  void dispose() {
    if (widget.horizontalController == null) _horizontalController.dispose();
    if (widget.verticalController == null) _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _verticalController,
      thumbVisibility: true,
      trackVisibility: true,
      child: Scrollbar(
        controller: _horizontalController,
        thumbVisibility: true,
        trackVisibility: true,
        notificationPredicate: (notification) => notification.depth == 1,
        child: SingleChildScrollView(
          controller: _verticalController,
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

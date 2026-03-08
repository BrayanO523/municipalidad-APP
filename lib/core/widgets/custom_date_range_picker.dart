import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/date_formatter.dart';
import 'package:intl/intl.dart';

class CustomDateRangePicker extends StatefulWidget {
  final DateTimeRange initialRange;

  const CustomDateRangePicker({super.key, required this.initialRange});

  @override
  State<CustomDateRangePicker> createState() => _CustomDateRangePickerState();
}

class _CustomDateRangePickerState extends State<CustomDateRangePicker> {
  late DateTime _startDate;
  late DateTime _endDate;
  late DateTime _viewDate;

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialRange.start;
    _endDate = widget.initialRange.end;
    _viewDate = _startDate;
    _startController.text = DateFormatter.formatDate(_startDate);
    _endController.text = DateFormatter.formatDate(_endDate);
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      if (date.isBefore(_startDate) || _startDate != _endDate) {
        _startDate = date;
        _endDate = date;
        _startController.text = DateFormatter.formatDate(date);
        _endController.text = DateFormatter.formatDate(date);
      } else {
        _endDate = date;
        _endController.text = DateFormatter.formatDate(date);
      }
    });
  }

  void _parseDate(String value, bool isStart) {
    if (value.length != 10) return;
    try {
      final date = DateFormat('dd/MM/yyyy').parseStrict(value);
      setState(() {
        if (isStart) {
          _startDate = date;
          _viewDate = date;
        } else {
          _endDate = date;
        }
      });
    } catch (_) {
      // Formato inválido, no hacer nada
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        width: 350,
        decoration: BoxDecoration(
          color: Color(0xFF1E1E2D),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF252535),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seleccionar Rango',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _DateInputField(
                          label: 'Desde',
                          controller: _startController,
                          onChanged: (v) => _parseDate(v, true),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: const Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: Colors.white10,
                        ),
                      ),
                      Expanded(
                        child: _DateInputField(
                          label: 'Hasta',
                          controller: _endController,
                          onChanged: (v) => _parseDate(v, false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Calendar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _CalendarHeader(
                    viewDate: _viewDate,
                    onPrevious: () => setState(() {
                      _viewDate = DateTime(_viewDate.year, _viewDate.month - 1);
                    }),
                    onNext: () => setState(() {
                      _viewDate = DateTime(_viewDate.year, _viewDate.month + 1);
                    }),
                  ),
                  const SizedBox(height: 16),
                  _CalendarGrid(
                    viewDate: _viewDate,
                    startDate: _startDate,
                    endDate: _endDate,
                    onDateSelected: _onDateSelected,
                  ),
                ],
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white54,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                          DateTimeRange(start: _startDate, end: _endDate),
                        );
                      },
                      style:
                          ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF00D9A6),
                            foregroundColor: Colors.black,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ).copyWith(
                            overlayColor: WidgetStateProperty.all(
                              Colors.black.withOpacity(0.1),
                            ),
                          ),
                      child: const Text(
                        'Confirmar',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Function(String) onChanged;

  const _DateInputField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white30,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: TextInputType.datetime,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
            _DateInputFormatter(),
          ],
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00D9A6),
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
            border: InputBorder.none,
            hintText: 'dd/mm/yyyy',
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.1),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    if (newValue.selection.baseOffset < oldValue.selection.baseOffset) {
      return newValue;
    }

    if (text.length == 2 || text.length == 5) {
      if (!text.endsWith('/')) {
        text += '/';
      }
    }

    if (text.length > 10) {
      text = text.substring(0, 10);
    }

    return newValue.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  final DateTime viewDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _CalendarHeader({
    required this.viewDate,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left, color: Colors.white54),
          iconSize: 20,
        ),
        Text(
          '${DateFormatter.getMonthName(viewDate).toUpperCase()} ${viewDate.year}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            fontSize: 13,
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right, color: Colors.white54),
          iconSize: 20,
        ),
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime viewDate;
  final DateTime startDate;
  final DateTime endDate;
  final Function(DateTime) onDateSelected;

  const _CalendarGrid({
    required this.viewDate,
    required this.startDate,
    required this.endDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(viewDate.year, viewDate.month + 1, 0).day;
    final firstDayOffset =
        DateTime(viewDate.year, viewDate.month, 1).weekday % 7;

    final labels = ['D', 'L', 'M', 'M', 'J', 'V', 'S'];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: labels
              .map(
                (l) => Text(
                  l,
                  style: const TextStyle(
                    color: Colors.white24,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 42,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemBuilder: (context, index) {
            final day = index - firstDayOffset + 1;
            if (day < 1 || day > daysInMonth) return SizedBox.shrink();

            final date = DateTime(viewDate.year, viewDate.month, day);
            final isSelected =
                date.isAtSameMomentAs(startDate) ||
                date.isAtSameMomentAs(endDate);
            final isInRange = date.isAfter(startDate) && date.isBefore(endDate);

            return InkWell(
              onTap: () => onDateSelected(date),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Color(0xFF00D9A6)
                      : isInRange
                      ? Color(0xFF00D9A6).withOpacity(0.1)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  day.toString(),
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
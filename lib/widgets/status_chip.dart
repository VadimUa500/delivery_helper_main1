import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  Color _color() {
    switch (status) {
      case 'new':
        return Colors.blueAccent;
      case 'in_progress':
        return Colors.orangeAccent;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _label() {
    switch (status) {
      case 'new':
        return 'Новe';
      case 'in_progress':
        return 'У процесі';
      case 'delivered':
        return 'Доставлено';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: _color().withOpacity(0.2),
      label: Text(
        _label(),
        style: TextStyle(
          color: _color(),
          fontWeight: FontWeight.w600,
        ),
      ),
      shape: StadiumBorder(side: BorderSide(color: _color(), width: 1)),
    );
  }
}

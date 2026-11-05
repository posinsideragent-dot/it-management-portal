import 'package:fluent_ui/fluent_ui.dart';

/// Space inside every table cell. It stops neighbouring columns touching.
const EdgeInsets kCellPadding = EdgeInsets.symmetric(horizontal: 8);

/// Width below which tables switch to stacked cards.
const double kWideTableMinWidth = 1000;

/// A table cell with padding and a flex width.
class TableCell2 extends StatelessWidget {
  const TableCell2({super.key, required this.flex, required this.child});

  final int flex;
  final Widget child;

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Padding(padding: kCellPadding, child: child),
      );
}

/// Heading text for a table column. Never wraps.
class HeaderText extends StatelessWidget {
  const HeaderText(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.typography.bodyStrong?.copyWith(
        color: theme.resources.textFillColorSecondary,
      ),
    );
  }
}

/// A rounded surface for one table row or one stacked card.
class RowCard extends StatelessWidget {
  const RowCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: padding ?? const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.resources.cardStrokeColorDefault),
      ),
      child: child,
    );
  }
}

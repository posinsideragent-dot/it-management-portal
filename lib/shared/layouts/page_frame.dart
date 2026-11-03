import 'package:fluent_ui/fluent_ui.dart';

/// Standard heading and padding for every page.
class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(title: Text(title)),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: child,
      ),
    );
  }
}

/// Curated font choices for Settings.
///
/// These reference well-known cross-platform system font family names
/// rather than font files bundled as app assets. Embedding real distinct
/// .ttf/.otf files would need actual font binaries added to the project
/// (which nobody has supplied yet), and the alternative — the `google_fonts`
/// package — fetches each family over the network on first use, which is
/// exactly the startup-latency tradeoff this project is trying to avoid.
/// System font names give real visual variety today with zero network
/// dependency; swapping in real bundled font files later only touches this
/// file (add the family here, add the asset + pubspec.yaml `fonts:` entry).
enum AppFont {
  systemDefault(label: 'System Default', description: 'Platform default', fontFamily: null),
  serif(label: 'Serif', description: 'Georgia — editorial, classic', fontFamily: 'Georgia'),
  roundedSans(
    label: 'Rounded Sans',
    description: 'Trebuchet MS — friendly, humanist',
    fontFamily: 'Trebuchet MS',
  ),
  wideSans(label: 'Wide Sans', description: 'Verdana — clean, highly legible', fontFamily: 'Verdana'),
  mono(label: 'Monospace', description: 'Courier New — technical, tabular', fontFamily: 'Courier New');

  const AppFont({required this.label, required this.description, required this.fontFamily});

  final String label;
  final String description;
  final String? fontFamily;

  static AppFont fromName(String? name) {
    return AppFont.values.firstWhere((f) => f.name == name, orElse: () => AppFont.systemDefault);
  }
}

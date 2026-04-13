/// A single entry in the linguistic glossary.
class GlossaryEntry {
  final String term;
  final String category;
  final String definition;
  final String example;
  final List<String> seeAlso;

  const GlossaryEntry({
    required this.term,
    required this.category,
    required this.definition,
    required this.example,
    this.seeAlso = const [],
  });

  factory GlossaryEntry.fromJson(Map<String, dynamic> json) => GlossaryEntry(
        term: json['term'] as String,
        category: json['category'] as String,
        definition: json['definition'] as String,
        example: json['example'] as String? ?? '',
        seeAlso: (json['seeAlso'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
      );
}

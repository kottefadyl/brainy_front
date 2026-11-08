/// Tree and search over a code list. Same rules as the web client (lib/code-tree.ts).
const maxCodeLevels = 8;

/// Asking for the deepest level groups every entry by its exact code.
const exactCodeDepth = maxCodeLevels - 1;

class CodeNode {
  CodeNode({
    required this.code,
    required this.label,
    required this.path,
    required this.active,
    this.parent,
  });

  final String code;
  final String label;
  final List<String> path;
  final bool active;
  final String? parent;
  final List<String> children = [];

  int get level => path.length + 1;
}

class CodeTree {
  CodeTree._(this.nodes, this.roots);

  factory CodeTree.build(List<Map<String, dynamic>> codes, bool french) {
    final usable = codes.where((item) => (item['code'] as String? ?? '').isNotEmpty).toList();
    final byCode = {for (final item in usable) item['code'] as String: item};
    String label(Map<String, dynamic> item) {
      final text = item[french ? 'labelFr' : 'labelEn'] as String? ?? '';
      return text.isEmpty ? item['code'] as String : text;
    }

    Map<String, dynamic>? parentOf(Map<String, dynamic> item) => byCode[item['parentCode']];

    final nodes = <String, CodeNode>{};
    for (final item in usable) {
      final code = item['code'] as String;
      final path = <String>[];
      // A draft being edited may contain a cycle: the walk must still end.
      final seen = {code};
      var parent = parentOf(item);
      while (parent != null && seen.add(parent['code'] as String)) {
        path.insert(0, label(parent));
        parent = parentOf(parent);
      }
      nodes[code] = CodeNode(
        code: code,
        label: label(item),
        path: path,
        active: item['active'] != false,
        parent: parentOf(item)?['code'] as String?,
      );
    }
    final roots = <String>[];
    for (final node in nodes.values) {
      if (node.parent != null) {
        nodes[node.parent]!.children.add(node.code);
      } else {
        roots.add(node.code);
      }
    }
    return CodeTree._(nodes, roots);
  }

  final Map<String, CodeNode> nodes;
  final List<String> roots;

  int get deepestLevel => nodes.values.fold(1, (deepest, node) => node.level > deepest ? node.level : deepest);

  Set<String> descendantsOf(String code) {
    final found = <String>{};
    final pending = [...?nodes[code]?.children];
    while (pending.isNotEmpty) {
      final next = pending.removeLast();
      if (found.add(next)) pending.addAll(nodes[next]?.children ?? const []);
    }
    return found;
  }

  /// The codes whose ancestors must stay visible so that accepted codes can be reached.
  Set<String> reachable(bool Function(CodeNode) accept) {
    final result = <String>{};
    for (final node in nodes.values.where(accept)) {
      CodeNode? cursor = node;
      while (cursor != null && result.add(cursor.code)) {
        cursor = nodes[cursor.parent];
      }
    }
    return result;
  }

  /// Best matches first: code prefix, label prefix, word start, then anywhere.
  ({List<CodeNode> results, int total}) search(String query, bool Function(CodeNode) accept, {int limit = 60}) {
    final needle = foldText(query.trim());
    if (needle.isEmpty) return (results: const [], total: 0);
    final ranked = <(CodeNode, int, int)>[];
    var order = 0;
    for (final node in nodes.values) {
      order += 1;
      if (!accept(node)) continue;
      final code = foldText(node.code);
      final label = foldText(node.label);
      final at = label.indexOf(needle);
      final rank = code.startsWith(needle)
          ? 0
          : at == 0
          ? 1
          : at > 0 && !_wordCharacter.hasMatch(label[at - 1])
          ? 2
          : at > 0 || code.contains(needle)
          ? 3
          : -1;
      if (rank >= 0) ranked.add((node, rank, order));
    }
    ranked.sort((a, b) => a.$2 != b.$2 ? a.$2.compareTo(b.$2) : a.$3.compareTo(b.$3));
    return (results: [for (final item in ranked.take(limit)) item.$1], total: ranked.length);
  }
}

final _wordCharacter = RegExp(r'[\p{L}\p{N}]', unicode: true);

const _accents = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', 'æ': 'ae',
  'ç': 'c', 'č': 'c', 'ć': 'c', 'ď': 'd',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ě': 'e', 'ę': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i',
  'ł': 'l', 'ñ': 'n', 'ń': 'n', 'ň': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o', 'œ': 'oe',
  'ř': 'r', 'š': 's', 'ś': 's', 'ß': 'ss', 'ť': 't',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u',
  'ý': 'y', 'ÿ': 'y', 'ž': 'z', 'ź': 'z', 'ż': 'z',
};

/// Lower case without accents, so that "epice" finds "Épicerie".
String foldText(String text) {
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    if (rune >= 0x300 && rune <= 0x36F) continue;
    final character = String.fromCharCode(rune);
    buffer.write(_accents[character] ?? character);
  }
  return buffer.toString();
}

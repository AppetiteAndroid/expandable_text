import 'package:expandable_text/expandable_text.dart';

class TextSegment {
  String text;

  final String? name;
  final bool isHashtag;
  final bool isMention;
  final bool isUrl;

  bool get isText => !isHashtag && !isMention && !isUrl;

  TextSegment(this.text, [this.name, this.isHashtag = false, this.isMention = false, this.isUrl = false]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextSegment && runtimeType == other.runtimeType && text == other.text && name == other.name && isHashtag == other.isHashtag && isMention == other.isMention && isUrl == other.isUrl;

  @override
  int get hashCode => text.hashCode ^ name.hashCode ^ isHashtag.hashCode ^ isMention.hashCode ^ isUrl.hashCode;
}

/// Split the string into multiple instances of [TextSegment] for mentions, hashtags, URLs and regular text.
///
/// Mentions are all words that start with @, e.g. @mention.
/// Hashtags are all words that start with #, e.g. #hashtag.
List<TextSegment> parseText(String? text, {List<Mention>? customMention}) {
  final segments = <TextSegment>[];

  if (text == null || text.isEmpty) {
    return segments;
  }

  // parse urls and words starting with @ (mention) or # (hashtag)
  var pattern =
      r'(?<keyword>([id:\d+\])|(#|@)([\p{Alphabetic}\p{Mark}\p{Decimal_Number}\p{Connector_Punctuation}\p{Join_Control}]+)|(?<url>(?:(?:https?|ftp):\/\/)?[-a-z0-9@:%._\+~#=]{1,256}\.[a-z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?))';
  RegExp exp = RegExp(pattern, unicode: true);
  final matches = exp.allMatches(text);

  var start = 0;
  matches.forEach((match) {
    // text before the keyword
    if (match.start > start) {
      if (segments.isNotEmpty && segments.last.isText) {
        segments.last.text += text.substring(start, match.start);
      } else {
        segments.add(TextSegment(text.substring(start, match.start)));
      }
      start = match.start;
    }

    final url = match.namedGroup('url');
    final keyword = match.namedGroup('keyword');

    if (url != null) {
      segments.add(TextSegment(url, url, false, false, true));
    } else if (keyword != null) {
      final isWord = match.start == 0 || [' ', '\n'].contains(text.substring(match.start - 1, start));
      if (!isWord) {
        return;
      }

      final isHashtag = keyword.startsWith('#');
      var reg = RegExp(r"\[id:\d+\]");
      bool isMention = customMention != null ? keyword.contains(reg) : keyword.startsWith('@');
      final matched = reg.firstMatch(keyword);
      String id = keyword.substring(1);
      if (matched != null && customMention != null && isMention) {
        if (matched.end != keyword.length) {
          id = keyword.substring(0, matched.end).replaceAll(RegExp(r'\[|\]'), "").split(':').last;
        } else {
          id = keyword.replaceAll(RegExp(r'\[|\]'), '').split(':').last;
        }
        String name = keyword;
        final index = customMention.indexWhere((element) => element.id.toString() == id);
        if (index >= 0) {
          name = customMention.firstWhere((element) => element.id.toString() == id).name;
        } else {
          name = 'User';
          id = "-1";
          isMention = false;
        }
        segments.add(TextSegment(name, id, isHashtag, isMention));
        if (matched.end != keyword.length) {
          segments.add(TextSegment(keyword.substring(matched.end), '', false, false));
        }
      } else {
        segments.add(TextSegment(keyword, id, isHashtag, isMention));
      }
    }

    start = match.end;
  });

  // text after the last keyword or the whole text if it does not contain any keywords
  if (start < text.length) {
    if (segments.isNotEmpty && segments.last.isText) {
      segments.last.text += text.substring(start);
    } else {
      segments.add(TextSegment(text.substring(start)));
    }
  }

  return segments;
}

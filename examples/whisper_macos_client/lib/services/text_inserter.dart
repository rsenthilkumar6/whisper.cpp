import 'dart:convert';
import 'dart:io';

/// Result of an insertion attempt.
enum InsertResult {
  /// Text was typed at the cursor via System Events.
  typed,

  /// Typing failed; text was copied to the clipboard instead.
  copiedToClipboard,
}

/// Inserts text at the current cursor position of the frontmost app.
///
/// Primary mechanism is AppleScript `System Events` keystroke, which requires
/// the app to be trusted under *System Settings → Privacy & Security →
/// Accessibility*. If that is unavailable (or denied) we fall back to copying
/// the text to the clipboard so the user can paste manually.
class TextInserter {
  const TextInserter();

  /// Type [text] at the cursor. Returns what actually happened.
  Future<InsertResult> insert(String text) async {
    final clean = _normalize(text);
    if (clean.isEmpty) return InsertResult.typed;

    final script = 'tell application "System Events"\n'
        'keystroke "$clean"\n'
        'end tell';

    try {
      final result = await Process.run(
        'osascript',
        ['-e', script],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (result.exitCode == 0) return InsertResult.typed;
    } catch (_) {
      // Fall through to clipboard.
    }
    return _copyToClipboard(clean);
  }

  Future<InsertResult> _copyToClipboard(String text) async {
    try {
      final process = await Process.start('pbcopy', []);
      process.stdin.add(utf8.encode(text));
      await process.stdin.close();
      await process.exitCode;
    } catch (_) {
      // Best-effort only.
    }
    return InsertResult.copiedToClipboard;
  }

  /// Open the Accessibility pane so the user can grant the required permission.
  Future<void> openAccessibilitySettings() async {
    try {
      await Process.run(
        'open',
        const [
          'x-apple.systempreferences:com.apple.preference.security'
              '?Privacy_Accessibility',
        ],
      );
    } catch (_) {
      // Best-effort only.
    }
  }

  /// Escape AppleScript string metacharacters and flatten newlines so the
  /// `keystroke` command receives a single-line literal.
  static String _normalize(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .trim();
  }
}

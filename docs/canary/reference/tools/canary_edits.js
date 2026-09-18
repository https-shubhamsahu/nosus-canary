// Applies the NO SUS Canary edits to EXISTING app files. Run from app/:
//   node <path>/canary_edits.js
// Each anchor must be found exactly once; the script stops on the first miss.
// Files in app/ mostly use CRLF line endings (some lines use LF), so every
// anchor is tried as written and again with CRLF line endings.
const fs = require('fs');

function edit(file, pairs) {
  let s = fs.readFileSync(file, 'utf8');
  for (const [from, to] of pairs) {
    if (s.includes(from)) {
      s = s.replace(from, to);
      continue;
    }
    const fromCrlf = from.split('\n').join('\r\n');
    if (s.includes(fromCrlf)) {
      s = s.replace(fromCrlf, to.split('\n').join('\r\n'));
      continue;
    }
    console.error('ANCHOR NOT FOUND in ' + file + ':\n' + from);
    process.exit(1);
  }
  fs.writeFileSync(file, s);
  console.log('edited ' + file);
}

// 1. main.dart — imports, token extractor, web reader branch, title, route,
//    native link routing.
edit('lib/main.dart', [
  [
    "import 'features/monad/presentation/monad_screen.dart';\n",
    "import 'features/monad/presentation/monad_screen.dart';\n" +
      "import 'features/canary/domain/canary_link.dart';\n" +
      "import 'features/canary/presentation/canary_home_screen.dart';\n" +
      "import 'features/canary/presentation/canary_reader_screen.dart';\n",
  ],
  [
    '/// Extracts the opaque token carried by a two-digit redemption pairing link.',
    '/// NO SUS Canary reader link: `#/canary/<uuid>?k=<64 hex key>`. Public so the\n' +
      '/// URL contract has regression tests (test/unit/canary_link_test.dart).\n' +
      'CanaryLinkToken? extractCanaryToken(Uri uri) {\n' +
      '  final fullUrl = kIsWeb ? html.window.location.href : uri.toString();\n' +
      '  return parseCanaryReaderLink(fullUrl);\n' +
      '}\n\n' +
      '/// Extracts the opaque token carried by a two-digit redemption pairing link.',
  ],
  [
    '      final redemptionToken = extractRedemptionToken(Uri.base);\n' +
      '      if (redemptionToken != null) {\n' +
      '        runApp(',
    '      // NO SUS Canary reader path: anonymous and standalone, like Burn links.\n' +
      '      final canaryToken = extractCanaryToken(Uri.base);\n' +
      '      if (canaryToken != null) {\n' +
      '        runApp(\n' +
      '          ProviderScope(\n' +
      '            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],\n' +
      '            child: CanaryReaderApp(\n' +
      '              noteId: canaryToken.noteId,\n' +
      '              keyHex: canaryToken.keyHex,\n' +
      '            ),\n' +
      '          ),\n' +
      '        );\n' +
      '        return;\n' +
      '      }\n\n' +
      '      final redemptionToken = extractRedemptionToken(Uri.base);\n' +
      '      if (redemptionToken != null) {\n' +
      '        runApp(',
  ],
  ["      title: 'NO SUS — Monad Experiment',", "      title: 'NO SUS',"],
  [
    "        if (route == '/monad' || route.startsWith('/monad/')) {",
    "        if (route == '/canary') {\n" +
      '          return MaterialPageRoute<void>(\n' +
      '            settings: settings,\n' +
      '            builder: (_) => const CanaryHomeScreen(),\n' +
      '          );\n' +
      '        }\n' +
      "        if (route == '/monad' || route.startsWith('/monad/')) {",
  ],
  [
    '  final redemptionToken = extractRedemptionToken(uri);\n' +
      '  if (redemptionToken != null) {\n' +
      '    Navigator.push(',
    '  final canary = extractCanaryToken(uri);\n' +
      '  if (canary != null) {\n' +
      '    Navigator.push(\n' +
      '      context,\n' +
      '      MaterialPageRoute(\n' +
      '        builder: (_) => CanaryReaderScreen(\n' +
      '          noteId: canary.noteId,\n' +
      '          keyHex: canary.keyHex,\n' +
      '        ),\n' +
      '      ),\n' +
      '    );\n' +
      '    return true;\n' +
      '  }\n\n' +
      '  final redemptionToken = extractRedemptionToken(uri);\n' +
      '  if (redemptionToken != null) {\n' +
      '    Navigator.push(',
  ],
]);

// 2. Top banner text (owner decision: brand is "NO SUS").
edit('lib/features/monad/presentation/experiment_frame.dart', [
  [
    "'NO SUS — Monad Experiment · Test data only'",
    "'NO SUS · Monad testnet · use harmless test notes only'",
  ],
]);

// 3. Links minted on Android must point at the deployed web app.
edit('lib/core/utils/web_links.dart', [
  [
    "const String kWebAppOrigin = 'https://monad.nosus.foo';",
    '/// Override at build time for the APK, e.g.\n' +
      '/// --dart-define=WEB_APP_ORIGIN=https://https-shubhamsahu.github.io\n' +
      'const String kWebAppOrigin = String.fromEnvironment(\n' +
      "  'WEB_APP_ORIGIN',\n" +
      "  defaultValue: 'https://monad.nosus.foo',\n" +
      ');',
  ],
  [
    "const String kWebAppBasePath = '';",
    '/// Override at build time, e.g. --dart-define=WEB_APP_BASE_PATH=/nosus-canary\n' +
      '/// (leading slash, no trailing slash).\n' +
      "const String kWebAppBasePath = String.fromEnvironment('WEB_APP_BASE_PATH');",
  ],
]);

// 4. Demo builds may allow screen capture so the phone can be mirrored.
edit('lib/services/screenshot_guard.dart', [
  [
    '    try {\n' +
      "      await _channel.invokeMethod('enableSecure');\n" +
      '    } catch (_) {}\n',
    '    // Demo builds pass --dart-define=NOSUS_ALLOW_SCREEN_CAPTURE=true so the\n' +
      '    // phone can be mirrored to a projector. MainActivity sets FLAG_SECURE in\n' +
      '    // onCreate, so this must actively clear it, and skip the popups.\n' +
      "    const allowCapture = bool.fromEnvironment('NOSUS_ALLOW_SCREEN_CAPTURE');\n" +
      '    if (allowCapture) {\n' +
      '      try {\n' +
      "        await _channel.invokeMethod('disableSecure');\n" +
      '      } catch (_) {}\n' +
      '      return;\n' +
      '    }\n\n' +
      '    try {\n' +
      "      await _channel.invokeMethod('enableSecure');\n" +
      '    } catch (_) {}\n',
  ],
]);

// 5. Entry cards: Canary replaces the (disabled) Monad receipts card.
for (const f of [
  'lib/features/onboarding/presentation/screens/welcome_screen.dart',
  'lib/features/workspace/presentation/pages/workspace_tab.dart',
]) {
  edit(f, [
    [
      "import '../../../monad/presentation/monad_entry_card.dart';",
      "import '../../../canary/presentation/canary_entry_card.dart';",
    ],
    ['const MonadEntryCard(),', 'const CanaryEntryCard(),'],
  ]);
}

// 6. Web branding.
edit('web/index.html', [['<title>NO SUS — Monad Experiment</title>', '<title>NO SUS</title>']]);
edit('web/manifest.json', [
  ['"name": "NO SUS — Monad Experiment",', '"name": "NO SUS",'],
  ['"short_name": "NO SUS Monad",', '"short_name": "NO SUS",'],
]);

// 7. Android identity: separate application id; namespace stays because the
//    Kotlin sources live in package foo.nosus.app.
edit('android/app/build.gradle.kts', [
  [
    '        applicationId = "foo.nosus.app"',
    '        // Separate app id so this build installs next to the production\n' +
      '        // NO SUS app and never uses its Play identity. namespace stays\n' +
      '        // foo.nosus.app because the Kotlin sources live in that package.\n' +
      '        applicationId = "foo.nosus.canary"',
  ],
]);
// Stop this APK from claiming production app.nosus.foo links.
edit('android/app/src/main/AndroidManifest.xml', [
  [
    '            <intent-filter android:autoVerify="true">\n' +
      '                <action android:name="android.intent.action.VIEW" />\n' +
      '                <category android:name="android.intent.category.DEFAULT" />\n' +
      '                <category android:name="android.intent.category.BROWSABLE" />\n' +
      '                <data android:scheme="https" android:host="app.nosus.foo" />\n' +
      '            </intent-filter>\n',
    '',
  ],
]);
// The comment that described the removed filter is now wrong: replace it.
{
  const f = 'android/app/src/main/AndroidManifest.xml';
  let s = fs.readFileSync(f, 'utf8');
  const startMarker = "            <!-- Android App Links for the web app's own origin.";
  const endMarker = 'with no browser fallback. -->';
  const start = s.indexOf(startMarker);
  const end = start === -1 ? -1 : s.indexOf(endMarker, start);
  if (start === -1 || end === -1) {
    console.error('ANCHOR NOT FOUND: App Links comment');
    process.exit(1);
  }
  const eol = s.indexOf(String.fromCharCode(13, 10)) !== -1 ? String.fromCharCode(13, 10) : String.fromCharCode(10);
  const replacement =
    '            <!-- NO SUS Canary build: no App Links filter. Canary links open' + eol +
    '                 in the browser (web reader), and this APK never intercepts' + eol +
    '                 production app.nosus.foo links. -->';
  s = s.slice(0, start) + replacement + s.slice(end + endMarker.length);
  fs.writeFileSync(f, s);
  console.log('edited ' + f + ' (comment)');
}

// 8. R8 (release minification) fails without these: google_mlkit_text_recognition
//    references the optional Chinese/Devanagari/Japanese/Korean recognizers,
//    which this app does not bundle (it uses the Latin model only).
{
  const f = 'android/app/proguard-rules.pro';
  let s = fs.readFileSync(f, 'utf8');
  if (s.includes('com.google.mlkit.vision.text.chinese')) {
    console.error('ANCHOR NOT FOUND: proguard-rules.pro already has the ML Kit rules (did this script run before?)');
    process.exit(1);
  }
  const eol = s.indexOf(String.fromCharCode(13, 10)) !== -1 ? String.fromCharCode(13, 10) : String.fromCharCode(10);
  const block = [
    '',
    '# --- NO SUS Canary: ML Kit text recognition (Latin model only) ---',
    '# The plugin references optional script recognizers that are not bundled.',
    '-dontwarn com.google.mlkit.vision.text.chinese.**',
    '-dontwarn com.google.mlkit.vision.text.devanagari.**',
    '-dontwarn com.google.mlkit.vision.text.japanese.**',
    '-dontwarn com.google.mlkit.vision.text.korean.**',
    '',
  ].join(eol);
  fs.writeFileSync(f, s + block);
  console.log('edited ' + f);
}
console.log('ALL EDITS APPLIED');

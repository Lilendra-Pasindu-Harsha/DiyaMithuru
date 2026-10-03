"""Adds the permissions DiyaMithuru needs to the Flutter-generated Android manifest.
Run from the app/ folder after `flutter create .` (the GitHub workflow does this)."""
import re
from pathlib import Path

m = Path("android/app/src/main/AndroidManifest.xml")
xml = m.read_text()

perms = [
    '<uses-permission android:name="android.permission.INTERNET"/>',
    '<uses-permission android:name="android.permission.RECORD_AUDIO"/>',
]
missing = [p for p in perms if p.split('"')[1] not in xml]
if missing:
    xml = xml.replace("<application", "\n    ".join(missing) + "\n    <application", 1)

speech_intent = '<intent><action android:name="android.speech.RecognitionService"/></intent>'
if "android.speech.RecognitionService" not in xml:
    if "<queries>" in xml:
        xml = xml.replace("<queries>", "<queries>\n        " + speech_intent, 1)
    else:
        xml = xml.replace("</manifest>", "    <queries>\n        " + speech_intent + "\n    </queries>\n</manifest>", 1)

# Nice app name on the phone
xml = re.sub(r'android:label="[^"]*"', 'android:label="DiyaMithuru"', xml, count=1)

m.write_text(xml)
print("Android manifest patched:\n" + xml)

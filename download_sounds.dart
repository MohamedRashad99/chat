import 'dart:io';

void main() async {
  final dir = Directory('assets/sounds');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  
  final client = HttpClient();
  print('Downloading walkie-talkie static sound...');
  
  try {
    var req = await client.getUrl(Uri.parse('https://www.soundjay.com/communication/sounds/walkie-talkie-1.mp3'));
    var res = await req.close();
    await res.pipe(File('assets/sounds/static.mp3').openWrite());
    
    print('Downloading beep sound...');
    req = await client.getUrl(Uri.parse('https://www.soundjay.com/buttons/sounds/button-09.mp3'));
    res = await req.close();
    await res.pipe(File('assets/sounds/beep.mp3').openWrite());
    
    print('Downloading mic release click...');
    req = await client.getUrl(Uri.parse('https://www.soundjay.com/communication/sounds/walkie-talkie-2.mp3'));
    res = await req.close();
    await res.pipe(File('assets/sounds/click.mp3').openWrite());
    
    print('\n✅ DONE! All 3 Walkie-Talkie Sounds downloaded perfectly directly into your assets folder!');
  } catch (e) {
    print('\n❌ Error downloading sounds. You might need to manually download MP3 files and place them into assets/sounds/');
  } finally {
    client.close();
  }
}

class EncodingConfig {
  final int bitrate;
  final bool removeSilence;
  final int? silenceDb;
  final bool removeHiss;
  final String author;
  final String title;
  final String year;
  
  const EncodingConfig({
    this.bitrate = 16,
    this.removeSilence = false,
    this.silenceDb,
    this.removeHiss = false,
    required this.author,
    required this.title,
    required this.year,
  });
  
  String get opusApplication => bitrate == 16 ? 'voip' : 'audio';
  
  String buildFilterString() {
    final filters = <String>[];
    
    if (removeSilence && silenceDb != null) {
      filters.add(
        'silenceremove=start_periods=0:stop_periods=-1:'
        'start_threshold=-${silenceDb}dB:stop_threshold=-${silenceDb}dB:'
        'start_silence=1:start_duration=0:stop_duration=1:detection=rms'
      );
    }
    
    if (removeHiss) {
      filters.addAll([
        'highpass=200',
        'lowpass=3000',
        'afftdn=nf=-25',
      ]);
    }
    
    filters.add('dynaudnorm=f=250:g=31:p=0.5:m=5:r=0.9:b=1');
    
    return filters.join(',');
  }
}
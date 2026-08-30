// lib/tafsir_index/varint.dart

class ByteWriter {
  final List<int> _bytes = [];
  List<int> get bytes => _bytes;

  void writeVarint(int value) {
    while (value >= 0x80) {
      _bytes.add((value & 0x7F) | 0x80);
      value >>= 7;
    }
    _bytes.add(value);
  }

  void writeBytes(List<int> b) => _bytes.addAll(b);
}

class ByteReader {
  final List<int> bytes;
  int pos = 0;
  ByteReader(this.bytes);

  int readVarint() {
    int result = 0, shift = 0;
    while (true) {
      final b = bytes[pos++];
      result |= (b & 0x7F) << shift;
      if (b < 0x80) break;
      shift += 7;
    }
    return result;
  }

  List<int> readBytes(int len) {
    final slice = bytes.sublist(pos, pos + len);
    pos += len;
    return slice;
  }
}

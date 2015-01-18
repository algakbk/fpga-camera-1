package comport_gui;

/**
 * The class for converting byte and to its string representation and back.
 * 
 * @author Yixing Lao
 * @author Zhixin Xu
 * 
 */
public class ByteStrConverter {
  public static String regex = "[0-1]+";

  /**
   * Convert byte to string
   * 
   * @param b
   *          The byte to be converted
   * @return
   */
  public static String byte2str(byte b) {
    String s = String.format("%8s", Integer.toBinaryString(b & 0xFF)).replace(
        ' ', '0');
    return s;
  }

  /**
   * Convert string to byte
   * 
   * @param s
   *          The string to be converted
   * @return
   */
  public static byte str2byte(String s) {
    byte b = (byte) 0;
    int i;
    if (s.length() == 8 && s.matches(regex)) {
      i = Integer.parseInt(s, 2);
      if (i >= 0 && i <= 255) {
        b = (byte) i;
      } else {
        System.out.println("string out of range");
      }
    }
    return b;
  }
}

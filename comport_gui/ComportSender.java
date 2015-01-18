package comport_gui;

import java.io.IOException;
import java.io.OutputStream;

/**
 * The class for sending a byte of message through commport.
 * 
 * @author Yixing Lao
 * @author Zhixin Xu
 * 
 */
public class ComportSender {
  static OutputStream out;

  /**
   * Set the data Stream to be written to
   * 
   * @param out
   */
  public static void setWriterStream(OutputStream out) {
    ComportSender.out = out;
  }

  /**
   * Send the byte via comport.
   * 
   * @param b
   *          The byte to be sent.
   */
  public static void send(byte b) {
    try {
      System.out.println("Sending: " + ByteStrConverter.byte2str(b));
      // sending through serial port is simply writing into OutputStream
      out.write(b);
      out.flush();
    } catch (IOException e) {
      e.printStackTrace();
    }
  }
}
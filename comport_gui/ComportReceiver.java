package comport_gui;

import java.io.IOException;
import java.io.InputStream;

/**
 * The comport receiver class. This class listens to the incoming message from
 * the comport and save the image if the incoming message have a valid
 * start_byte and end_byte according to our protocol. The receiver is robust to
 * disconnections during the transferring of the image from the FPGA board to
 * the PC, if the image sent back is not complete, the successfully sent part
 * will still be saved as a partial image.
 * 
 * @author Yixing Lao
 * @author Zhixin Xu
 * 
 */
public class ComportReceiver extends Thread {
  // states
  private static final int STATE_IDLE = 1;
  private static final int STATE_DATA = 2;
  private static final int STATE_END_BYTE = 3;
  private static final String START_BYTE = "11110101";
  private static final String END_BYTE = "11111010";
  // private static final long TIME_LIMIT = 15000000000;
  // attributes
  private byte receivedByte;
  private boolean isActive = true;
  private final InputStream in;
  private final byte[] rawImage;
  private int count;
  private int state;
  private final DisplayPanel displayPanel;
  private final ComportGui comportGui;

  /**
   * Constructor for the ComportREceiver
   * 
   * @param in
   * @param rawImiage
   * @param displayPanel
   * @param comportGui
   */
  public ComportReceiver(InputStream in, byte[] rawImiage,
      DisplayPanel displayPanel, ComportGui comportGui) {
    this.in = in;
    this.receivedByte = (byte) 0;
    this.count = 0;
    this.isActive = true;
    this.state = STATE_IDLE;
    this.rawImage = rawImiage;
    this.displayPanel = displayPanel;
    this.comportGui = comportGui; // changed
  }

  /**
   * Stop the ComportReceiver class elegantly.
   */
  public void myStop() {
    this.isActive = false;
    System.out.println("receiver closed");
  }

  /**
   * The receiver has several states: STATE_IDLE: listen the start byte in the
   * incoming message; STATE_DATA: listen for the image data and store the
   * image; STATE_END_BYTE: listen for the end byte of the incoming image and
   * check whether it is valid
   */
  /*
   * (non-Javadoc)
   * 
   * @see java.lang.Thread#run()
   */
  @Override
  public void run() {
    try {
      int b;
      String s;
      long expectEndTime = 0;

      while (true && this.isActive == true) {
        // if stream is not bound in.read() method returns -1
        while ((b = in.read()) != -1) {
          // convert to byte and string
          this.receivedByte = (byte) b;
          s = ByteStrConverter.byte2str(this.receivedByte);
          // state transition
          switch (state) {
          case STATE_IDLE:
            this.count = 0;
            if (s.equals(START_BYTE)) {
              System.out.println("Start byte success: " + s);
              this.count = 0;
              this.state = STATE_DATA;
            }
            break;
          case STATE_DATA:
            this.rawImage[count] = this.receivedByte;
            System.out.println("S" + Integer.toString(state) + ": rawImge["
                + Integer.toString(count) + "] = "
                + ByteStrConverter.byte2str(this.receivedByte));
            this.count = this.count + 1;
            comportGui.setStateLabel("State: received "
                + Integer.toString(count) + " of " + Integer.toString(76800));
            if (count >= 76800) {
              this.state = STATE_END_BYTE;
              this.count = 0;
            }
            break;
          case STATE_END_BYTE:
            if (s.equals(END_BYTE)) {
              System.out.println("End byte success: " + s);
            }
            this.displayPanel
                .setImage(RawImageConverter.raw2rgb(this.rawImage));
            comportGui.setStateLabel("IDLE");
            this.state = STATE_IDLE;
            break;
          default:
            System.out.println("Error state!");
            comportGui.setStateLabel("IDLE");
            this.state = STATE_IDLE;
            break;
          }
          // check state determine timing
          if (state == STATE_DATA && count == 1) {
            expectEndTime = System.currentTimeMillis() + 15000;
            System.out
                .println("expectEndTime: " + Long.toString(expectEndTime));
          }
        }
        if (state == STATE_DATA && System.currentTimeMillis() > expectEndTime) {
          System.out.println("currentTime: "
              + Long.toString(System.currentTimeMillis()));
          System.out.println("Time exceed!");
          this.state = STATE_IDLE;
          this.count = 0;
          this.displayPanel.setImage(RawImageConverter.raw2rgb(this.rawImage));
          // this.saveImage(this.rawImage);
        }
        // wait 10ms when stream is broken and check again
        sleep(10);
      }
    } catch (IOException e) {
      e.printStackTrace();
    } catch (InterruptedException e) {
      e.printStackTrace();
    }
  }
}
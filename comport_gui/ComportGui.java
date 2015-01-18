package comport_gui;

import gnu.io.CommPortIdentifier;
import gnu.io.SerialPort;

import java.awt.*;
import java.awt.event.*;
import java.awt.image.BufferedImage;
import java.io.File;
//import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.Hashtable;

import javax.imageio.ImageIO;
import javax.swing.*;
import javax.swing.event.ChangeEvent;
import javax.swing.event.ChangeListener;

/**
 * This is the main class for the ComportCamera for the ELEC2818 integrated
 * project.
 * 
 * @author Yixing Lao
 * @author Zhixin Xu
 */
public class ComportGui {
  // main object
  static ComportGui comportGui;

  // constants
  private static final String CAPTURE_COMMAND = "10101010";
  private static final String RETRIEVE_COMMAND = "10100101";
  private static final String RESET_COMMAND = "01010101";
  // private static final String UP_COMMAND = "00010000";
  // private static final String DOWN_COMMAND = "00010001";
  // private static final String LEFT_COMMAND = "00010010";
  // private static final String RIGHT_COMMAND = "00010011";

  // related to comport
  public static String regex = "[0-1]+";
  public static SerialPort mainPort;
  public static ComportReceiver receiver;

  // related to Gui
  private JFrame mainFrame;
  private JPanel leftPanel;
  private JPanel rightPanel;
  private DisplayPanel imagePanel;
  private JPanel statusPanel;
  private JLabel stateLabel; // display current state
  private JLabel logLabel; // display previous log
  private JPanel controlPanel;
  private JPanel sliderPanel;
  private JPanel motorPanel;
  private JSlider vSlider;
  private JSlider hSlider;

  // image data
  private final byte[] rawImage;

  public ComportGui() {
    this.rawImage = new byte[76800];
    for (int i = 0; i < 76800; i++) {
      this.rawImage[i] = (byte) 0;
    }
  }

  public static void main(String[] args) throws Exception {
    // gui control
    comportGui = new ComportGui();
    comportGui.prepareGui();

    // connect to comport
    comportGui.connect("COM1");
    System.out.println("Welcome to ComportCamera");

    // terminal control
    // Scanner reader = new Scanner(System.in);
    // while (true) {
    // System.out.printf("Byte to send: ");
    // String byteString = reader.nextLine();
    // if (byteString.equals("exit")) {
    // break;
    // } else {
    // CommportSender.send(ByteStrConverter.str2byte(byteString));
    // }
    // }
    // reader.close();
    // receiver.myStop();
    // mainPort.close();
  }

  /**
   * Connect to the port and start a receiver thread to listen to the incoming
   * message.
   * 
   * @param portName
   *          The name of the port to be connected to, such as "COM1"
   * @throws Exception
   */
  public void connect(String portName) throws Exception {
    CommPortIdentifier portIdentifier = CommPortIdentifier
        .getPortIdentifier(portName);
    if (portIdentifier.isCurrentlyOwned()) {
      System.out.println("Port in use!");
    } else {
      // port owner and connection timeout
      mainPort = (SerialPort) portIdentifier.open("RS232Example", 2000);
      // connection parameters
      mainPort.setSerialPortParams(115200, SerialPort.DATABITS_8,
          SerialPort.STOPBITS_1, SerialPort.PARITY_NONE);
      // setup serial port writer
      ComportSender.setWriterStream(mainPort.getOutputStream());
      // setup serial port reader
      receiver = new ComportReceiver(mainPort.getInputStream(), rawImage,
          imagePanel, comportGui);
      receiver.start();
    }
  }

  /**
   * Set label for the state
   * 
   * @param label
   */
  void setStateLabel(String label) {
    stateLabel.setText(label);
  }

  /**
   * Initiate the GUI components and display them
   */
  private void prepareGui() {
    // main frame
    mainFrame = new JFrame("ComportCamera");
    mainFrame.getContentPane().setLayout(new BorderLayout());

    // panels
    leftPanel = new JPanel();
    leftPanel.setLayout(new BorderLayout());
    rightPanel = new JPanel();
    rightPanel.setLayout(new BorderLayout());
    imagePanel = new DisplayPanel();
    statusPanel = new JPanel();
    statusPanel.setLayout(new BorderLayout());
    controlPanel = new JPanel();
    controlPanel.setLayout(new GridLayout(4, 1));
    sliderPanel = new JPanel();
    sliderPanel.setLayout(new GridLayout(1, 2));
    motorPanel = new JPanel();
    motorPanel.setLayout(new GridLayout(4, 1));

    // labels
    stateLabel = new JLabel("State: IDLE");
    logLabel = new JLabel("");

    // buttons
    JButton captureButton = new JButton("Capture");
    JButton retrieveButton = new JButton("Retrieve");
    JButton saveButton = new JButton("Save");
    JButton resetButton = new JButton("Reset");
    JButton upButton = new JButton("Up");
    JButton downButton = new JButton("Down");
    JButton leftButton = new JButton("Left");
    JButton rightButton = new JButton("Right");
    captureButton.setActionCommand("Capture");
    retrieveButton.setActionCommand("Retrieve");
    saveButton.setActionCommand("Save");
    resetButton.setActionCommand("Reset");
    upButton.setActionCommand("Up");
    downButton.setActionCommand("Down");
    leftButton.setActionCommand("Left");
    rightButton.setActionCommand("Right");
    captureButton.addActionListener(new ButtonClickListener());
    retrieveButton.addActionListener(new ButtonClickListener());
    saveButton.addActionListener(new ButtonClickListener());
    resetButton.addActionListener(new ButtonClickListener());
    upButton.addActionListener(new ButtonClickListener());
    downButton.addActionListener(new ButtonClickListener());
    leftButton.addActionListener(new ButtonClickListener());
    rightButton.addActionListener(new ButtonClickListener());

    // sliders
    vSlider = new JSlider(JSlider.VERTICAL, 0, 20, 10);
    hSlider = new JSlider(JSlider.VERTICAL, 0, 20, 10);
    vSlider.addChangeListener(new VSliderAction());
    hSlider.addChangeListener(new HSliderAction());
    // Create the label table.
    Hashtable<Integer, JLabel> vSliderTable = new Hashtable<Integer, JLabel>();
    vSliderTable.put(0, new JLabel("Down"));
    vSliderTable.put(5, new JLabel("45"));
    vSliderTable.put(10, new JLabel("90"));
    vSliderTable.put(15, new JLabel("135"));
    vSliderTable.put(20, new JLabel("Up"));
    Hashtable<Integer, JLabel> hSliderTable = new Hashtable<Integer, JLabel>();
    hSliderTable.put(0, new JLabel("Right"));
    hSliderTable.put(5, new JLabel("45"));
    hSliderTable.put(10, new JLabel("90"));
    hSliderTable.put(15, new JLabel("135"));
    hSliderTable.put(20, new JLabel("Left"));
    vSlider.setLabelTable(vSliderTable);
    hSlider.setLabelTable(hSliderTable);
    vSlider.setPaintLabels(true);
    hSlider.setPaintLabels(true);

    // add button and label to panel
    statusPanel.add(stateLabel, BorderLayout.EAST);
    statusPanel.add(logLabel, BorderLayout.WEST);
    controlPanel.add(captureButton);
    controlPanel.add(retrieveButton);
    controlPanel.add(saveButton);
    controlPanel.add(resetButton);
    sliderPanel.add(vSlider);
    sliderPanel.add(hSlider);
    motorPanel.add(upButton);
    motorPanel.add(downButton);
    motorPanel.add(leftButton);
    motorPanel.add(rightButton);
    leftPanel.add(imagePanel, BorderLayout.CENTER);
    leftPanel.add(statusPanel, BorderLayout.SOUTH);
    rightPanel.add(controlPanel, BorderLayout.NORTH);
    rightPanel.add(sliderPanel, BorderLayout.CENTER);
    rightPanel.add(motorPanel, BorderLayout.SOUTH);

    // add panel to main frame
    mainFrame.add(leftPanel, BorderLayout.CENTER);
    mainFrame.add(rightPanel, BorderLayout.EAST);
    mainFrame.setVisible(true);

    // set size
    // imagePanel.setSize(320, 240);
    mainFrame.setSize(560, 400);

    // set action listener
    mainFrame.addWindowListener(new WindowAdapter() {
      @Override
      public void windowClosing(WindowEvent windowEvent) {
        receiver.myStop();
        System.exit(0);
        mainPort.close();
      }
    });
  } // prepareGui

  /**
   * Listen to the vertical slider's action. Chnage value only at the end of the
   * action.
   * 
   * @author user
   * 
   */
  private class VSliderAction implements ChangeListener {
    @Override
    public void stateChanged(ChangeEvent arg0) {
      if (!vSlider.getValueIsAdjusting()) {
        int value = vSlider.getValue();
        ComportSender.send((byte) (96 + value));
      }
    }
  }

  /**
   * Listen to the horizontal slider's action. Change value only at the end of
   * the action.
   * 
   * @author user
   * 
   */
  private class HSliderAction implements ChangeListener {
    @Override
    public void stateChanged(ChangeEvent arg0) {
      if (!hSlider.getValueIsAdjusting()) {
        int value = hSlider.getValue();
        ComportSender.send((byte) (32 + value));
      }
    }
  }

  /**
   * Listen to the button's actions in the main interface and perform requrired
   * commands.
   * 
   * @author user
   * 
   */
  private class ButtonClickListener implements ActionListener {
    @Override
    public void actionPerformed(ActionEvent e) {
      String command = e.getActionCommand();
      logLabel.setText(command + " button clicked.");
      if (command.equals("Capture")) {
        ComportSender.send(ByteStrConverter.str2byte(CAPTURE_COMMAND));
      } else if (command.equals("Retrieve")) {
        ComportSender.send(ByteStrConverter.str2byte(RETRIEVE_COMMAND));
      } else if (command.equals("Save")) {
        saveImage(rawImage);
      } else if (command.equals("Reset")) {
        ComportSender.send(ByteStrConverter.str2byte(RESET_COMMAND));
      } else if (command.equals("Up")) {
        if (vSlider.getValue() < 20) {
          vSlider.setValue(vSlider.getValue() + 1);
        }
        // ComportSender.send(ByteStrConverter.str2byte(UP_COMMAND));
      } else if (command.equals("Down")) {
        if (vSlider.getValue() > 0) {
          vSlider.setValue(vSlider.getValue() - 1);
        }
        // ComportSender.send(ByteStrConverter.str2byte(DOWN_COMMAND));
      } else if (command.equals("Left")) {
        if (hSlider.getValue() < 20) {
          hSlider.setValue(hSlider.getValue() + 1);
        }
        // ComportSender.send(ByteStrConverter.str2byte(LEFT_COMMAND));
      } else if (command.equals("Right")) {
        if (hSlider.getValue() > 0) {
          hSlider.setValue(hSlider.getValue() - 1);
        }
        // ComportSender.send(ByteStrConverter.str2byte(RIGHT_COMMAND));
      } // command switch
    } // actionPerformed
  }

  /**
   * Convert the raw image and save it in a file.
   * 
   * @param rawImage
   *          The unconverted image received from the camera
   */
  public void saveImage(byte[] rawImage) {
    try {
      BufferedImage rgbImage = RawImageConverter.raw2rgb(rawImage);
      java.util.Date date = new java.util.Date();
      SimpleDateFormat sdf = new SimpleDateFormat("MM-dd-yyyy-h-mm-ss");
      String formattedDate = sdf.format(date);
      String fileName = "image_" + formattedDate + ".png";
      File outputfile = new File(fileName);
      ImageIO.write(rgbImage, "png", outputfile);
      System.out.println("Saved as: " + fileName);
    } catch (Exception e) {
      // TODO Auto-generated catch block
      e.printStackTrace();
    }
  }
}

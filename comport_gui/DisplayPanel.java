package comport_gui;

import java.awt.Graphics;
import java.awt.Image;
import java.awt.event.*;
import java.awt.image.BufferedImage;

import javax.swing.*;

/**
 * Disply the image in a JPanel
 * 
 * @author Yixing Lao
 * @author Zhixin Xu
 * 
 */
public class DisplayPanel extends JPanel implements ActionListener {
  private static final long serialVersionUID = 1L;
  private Image panelImage;

  /*
   * (non-Javadoc)
   * 
   * @see javax.swing.JComponent#paintComponent(java.awt.Graphics)
   */
  @Override
  public void paintComponent(Graphics g) {
    System.out.println("paintComponent()");
    g.drawImage(panelImage, 0, 0, getWidth(), getHeight(), this);
  }

  /*
   * Set the image in the JPanel to be displayed.
   * 
   * @param bufferImage The converted RGB image
   */
  public void setImage(BufferedImage bufferImage) {
    System.out.println("setImage()");
    this.panelImage = bufferImage;
    this.repaint();
  }

  /*
   * (non-Javadoc)
   * 
   * @see
   * java.awt.event.ActionListener#actionPerformed(java.awt.event.ActionEvent)
   */
  @Override
  public void actionPerformed(ActionEvent arg0) {
    // TODO Auto-generated method stub
  }
}

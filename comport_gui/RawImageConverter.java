package comport_gui;

import java.awt.image.BufferedImage;

/**
 * Convert the raw bayer patten image to RGB image using a library.
 * 
 * @author Yixing Lao
 * @author Zhixin Xu
 * 
 */
public class RawImageConverter {
  /**
   * Convert the raw bayer patten image to RGB image using a library.
   * 
   * @param rawImage
   *          The raw image to be converted.
   * @return
   */
  public static BufferedImage raw2rgb(byte[] rawImage) {
    BufferedImage rgbImage = null;
    try {
      rgbImage = SaveImage.BayerByteArrayToImage(rawImage, 320, 240,
          SaveImage.BAYER_PATTERN.BGGR);
    } catch (Exception e) {
      // TODO Auto-generated catch block
      e.printStackTrace();
    }
    return rgbImage;
  }
}
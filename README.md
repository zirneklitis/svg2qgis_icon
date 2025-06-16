# svg2qgis_icon

## In short
Optimizes SVG format images for use as QGIS mapping icons. 
As an input is directory name not a separate file name.

## Intro

To create SVG symbols with modifiable fill color, stroke color and 
stroke width in QGIS, you should replace the style attribute from the 
path element with these 5 attributes:

 ```
    fill="param(fill) #FFF"
    fill-opacity="param(fill-opacity)"
    stroke="param(outline) #000"
    stroke-opacity="param(outline-opacity)"
    stroke-width="param(outline-width) 0.2"
```

## What this script does

1. Removes 'transform' attributes by applying any geometric transformations.

2. Rescale all icons to the same size (can be disabled).

3. Replace or add «_QGIS_» supported fill and stroke attributes.

## Running the script


Usage: **perl svg2qgis_icon.pl --ind _DIR1_ --outd _DIR2_ [--size _NN_]**

 where:

  DIR1 – input directory

  DIR2 – output directory
  
  NN   – icon size (optional), default = _64_, use _-1_ to disable resize.

## Result

### Both stroke and fill attributes can be applied to the modified icons.

![22 1_22 3-fs8](https://github.com/user-attachments/assets/57c392f0-7820-45e6-91b8-c7689439b0da)

### Colour ramp works as well.

![22 2-edited_icon_cat](https://github.com/user-attachments/assets/25814246-4386-4f73-84ec-8f70f68578fb)

### A bit more complex example
#### Original *SVG* file as displayed in «*Inkscape*»
(Sorce: https://github.com/qgis/QGIS-Resources/tree/master/collections/gis_lab)

![Avots_Inkscape-fs8](https://github.com/user-attachments/assets/187cdc68-ce50-484d-92bb-904bc2bf9953)

#### The modified icon

![Avots_melns-fs8](https://github.com/user-attachments/assets/bec5e099-201c-40c1-9148-6345aad4c45b)

#### The filled colour is applied to the lines as well

![Avots_violets-fs8](https://github.com/user-attachments/assets/4288c3dd-2c03-49bb-bee3-6509490e49d1)

#### The stroke width is applied only to the line elements not the areas

![Avots_resns-fs8](https://github.com/user-attachments/assets/aa932e97-2222-4b57-874c-c2c9780d55e7)

#### Colour ramp impacts both lines and areas

![Avots_klases-fs8](https://github.com/user-attachments/assets/320b3d06-1ed3-497b-9a34-6273d11fbc20)




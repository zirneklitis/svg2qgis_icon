# svg2qgis_icon

## In short
Optimizes SVG format images for use as QGIS mapping icons. 
As an input is directory name not a separate file name.

## Intro

To create SVG symbols with modifiable fill color, stroke color and 
stroke width in QGIS, you should replace the style attribute from the 
path element with these 3 attributes:

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


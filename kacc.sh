#!/bin/bash
# KACC - Kiruna All-sky Camera Cloudiness, version 1
#
# The script uses imagemagick for identifying clouds in Kiruna All-sky
# camera images. The script tries to differentiate between clouds and
# aurora in images and computes a cloudiness fraction which is tested
# against a threshold value.
#
# Copyright 2015 by Jacco Geul <jacco@geul.net>
# Licensed under GNU General Public License 3.0 or later.
#
# https://github.com/magnific0/KACC

# Threshold
# Keep in mind that since this is a circle in a black image a good
# portion of the image remains black even when fully clouded. Fraction
# values range from 0.00 to 0.30ish.
threshold=0.004

# Filter settings for aurora map
# You obtain these by inspecting an image manually using the color
# picker in GIMP or PhotoShop. Make sure to get the HSL values (not
# RGB, HSV, HSB, CMY, etc!!!).
#
# Use broad ranges and tweak accordingly by inspecting the
# intermediate result (result1.png).
#
# (H)ue        [0,360]
# (S)aturation [0,100]
# (L)ightness  [0,100]
auror_Hmin=80
auror_Hmax=95
auror_Smin=30
auror_Smax=70
auror_Lmin=10
auror_Lmax=100

# Create filter
convert -size 1x360 gradient: -fx "(u>$auror_Hmin/360 && u<$auror_Hmax/360)?white:black" auror_h.png
convert -size 1x360 gradient: -fx "(u>$auror_Smin/100 && u<$auror_Smax/100)?white:black" auror_s.png
convert -size 1x360 gradient: -fx "(u>$auror_Lmin/100 && u<$auror_Lmax/100)?white:black" auror_l.png
convert auror_h.png auror_s.png auror_l.png -combine auror_lut.png
convert auror_lut.png -flip auror_lut.png

# Filter settings for cloud map (as before)
cloud_Hmin=20
cloud_Hmax=40
cloud_Smin=50
cloud_Smax=95
cloud_Lmin=10
cloud_Lmax=100

# Create filter
convert -size 1x360 gradient: -fx "(u>$cloud_Hmin/360 && u<$cloud_Hmax/360)?white:black" cloud_h.png
convert -size 1x360 gradient: -fx "(u>$cloud_Smin/100 && u<$cloud_Smax/100)?white:black" cloud_s.png
convert -size 1x360 gradient: -fx "(u>$cloud_Lmin/100 && u<$cloud_Lmax/100)?white:black" cloud_l.png
convert cloud_h.png cloud_s.png cloud_l.png -combine cloud_lut.png
convert cloud_lut.png -flip cloud_lut.png

# Loop over folder
for f in *.JPG
do
    convert $f temp0.png

    # Compute filtered images > maps
    convert \( temp0.png -colorspace HSL \) auror_lut.png -clut -separate -evaluate-sequence multiply temp1.png
    convert \( temp0.png -colorspace HSL \) cloud_lut.png -clut -separate -evaluate-sequence multiply temp2.png
    convert -monochrome temp1.png temp1.png
    convert -monochrome temp2.png temp2.png

    # We want to invert the aurora map and make the white transparent as
    # it is subtractive
    convert -negate temp1.png temp1.png
    convert temp1.png -transparent white temp1.png

    # Now create a composite map
    composite -compose Bumpmap temp1.png temp2.png -alpha Set temp3.png

    # Count white percentage
    fraction=$(convert temp3.png -format "%[fx:mean]" info:)

    # Do a test and do something based on outcome.
    if [ 1 -eq `echo "${fraction} < ${threshold}" | bc` ]; then
        echo "$f is NOT cloudy ($fraction/$threshold)"
    else
        echo "$f is too cloudy ($fraction/$threshold)"
    fi
done
